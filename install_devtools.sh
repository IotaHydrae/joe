#!/usr/bin/env bash
# =============================================================================
# joe devtools — 开发工具套件安装脚本 (跨发行版)
# =============================================================================
# 记录在服务器 (Fedora 44) 上安装过的一组开发工具，供新机器一键复现。
# 支持 apt (Debian/Ubuntu/Mint)、pacman (Arch/CachyOS)、dnf (Fedora/RHEL)、zypper (openSUSE)。
# 已实测: Ubuntu 24.04 / Linux Mint 22.3 (noble) / Arch Linux (CachyOS 基线) / Fedora。
#
# 用法:
#   ./install_devtools.sh            # 默认进入 TUI, 不预选; 非交互须指定组件
#   ./install_devtools.sh --all      # 显式安装全部组件
#   ./install_devtools.sh --node     # 只装 Node 工具链 (nvm)
#   ./install_devtools.sh --python   # 只装 pyenv + Python 编译依赖
#   ./install_devtools.sh --ai       # 只装 AI CLI (claude-code + codex)
#   ./install_devtools.sh --zed      # 只装 Zed 编辑器 + JetBrains Mono
#   ./install_devtools.sh --ghostty  # 安装/修复 Ghostty、terminfo 和桌面终端入口
#   ./install_devtools.sh --vscode   # 只装 VS Code 编辑器
#   ./install_devtools.sh --mimo     # 只装 MiMo Code (小米 AI 编程助手)
#   ./install_devtools.sh --chatgpt  # 只装 ChatGPT / Codex 桌面版
#   ./install_devtools.sh --ccswitch # 只装 CC Switch (AI CLI 配置切换器)
#   ./install_devtools.sh --tui      # 交互式勾选界面 (TUI)
#   ./install_devtools.sh --list     # 列出可安装组件
#   ./install_devtools.sh --check    # 只报告本机适配情况 (发行版/包名解析/安装方式), 不做改动
#
# 依赖: git, curl, sudo (非 root 时), bash/zsh
# 说明:
#   - nvm 装到 ~/.nvm, 默认 Node LTS
#   - pyenv 装到 ~/.pyenv, Python 版本与 pipx 由用户自行安装
#   - --ghostty 会修复已有安装的用户/系统 terminfo 与桌面入口; 系统条目缺失时需要 sudo
#   - 单独修复用 ./repair_ghostty.sh; --user-only 不写系统 terminfo
#   - 所有需要外网下载的步骤都尊重 https_proxy/http_proxy 环境变量
#   - 系统包名按发行版自动映射 (apt/dnf/pacman/zypper)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
NODE_LTS="${NODE_LTS:-}"                    # 留空 = 安装时最新 LTS
PROXY_URL="${PROXY_URL:-}"                  # 可选: http://host:7890

# 标记位
INSTALL_NODE=false
INSTALL_PYTHON=false
INSTALL_AI=false
INSTALL_ZED=false
INSTALL_GHOSTTY=false
INSTALL_VSCODE=false
INSTALL_MIMO=false
INSTALL_CHATGPT=false
INSTALL_CCSWITCH=false
INSTALL_ALL=false
TUI_MODE=false

# ---------------------------------------------------------------------------
# 前置依赖检查
# ---------------------------------------------------------------------------
check_prerequisites() {
    local missing=()

    # 基础工具
    command -v git >/dev/null 2>&1 || missing+=(git)
    command -v curl >/dev/null 2>&1 || missing+=(curl)

    # 如果要安装 Node 相关，检查编译依赖
    if $INSTALL_NODE || $INSTALL_ALL; then
        command -v gcc >/dev/null 2>&1 || command -v cc >/dev/null 2>&1 || missing+=(build-essential)
    fi

    # 如果要安装 Python 相关，检查必要依赖
    if $INSTALL_PYTHON || $INSTALL_ALL; then
        command -v python3 >/dev/null 2>&1 || missing+=(python3)
        # pyenv 需要这些包来编译 Python
        if ! pkg_installed libssl-dev 2>/dev/null && ! pkg_installed openssl-devel 2>/dev/null; then
            missing+=(libssl-dev)
        fi
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        warn "缺少必要依赖: ${missing[*]}"
        info "建议先运行: install_sys_pkg ${missing[*]}"
        info "或手动安装: sudo $PM install ${missing[*]}"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# 小工具函数
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*"; }
die()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# 临时文件登记 + 退出清理 (下载中途失败不残留 /tmp/chatgpt.rpm 之类文件)
TMP_FILES=()
cleanup_tmp() {
    if [ ${#TMP_FILES[@]} -gt 0 ]; then
        rm -f -- "${TMP_FILES[@]}"
    fi
}
trap cleanup_tmp EXIT

# make_tmp 变量名 [后缀] — 创建临时文件, 路径写入调用方变量并登记到 TMP_FILES。
# 注意不能用 `f=$(make_tmp ...)` 的命令替换形式: 那样在子 shell 里登记, 父进程的
# TMP_FILES 拿不到, EXIT trap 就清不掉了。
make_tmp() {
    local __var="$1" __suffix="${2:-}" __f
    if [ -n "$__suffix" ]; then
        __f=$(mktemp --suffix="$__suffix")
    else
        __f=$(mktemp)
    fi
    TMP_FILES+=("$__f")
    printf -v "$__var" '%s' "$__f"
}

# ---------------------------------------------------------------------------
# 发行版识别与包名解析 (统一由 lib_distro.sh 提供)
# ---------------------------------------------------------------------------
# 支持 apt (Debian/Ubuntu/Mint) / pacman (Arch/CachyOS) / dnf (Fedora) / zypper (openSUSE)
# 并处理版本差异, 例如 Ubuntu 24.04 的 t64 重命名 (libfuse2 -> libfuse2t64)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _lib in lib_distro.sh lib_github.sh lib_ghostty.sh; do
    if [ -f "$_LIB_DIR/$_lib" ]; then
        # shellcheck disable=SC1090
        . "$_LIB_DIR/$_lib"
    else
        die "缺少 $_lib (应与本脚本同目录)"
    fi
done
unset _lib _LIB_DIR

# 加载 nvm 到当前 shell
load_nvm() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}



# 加载 pyenv 到当前 shell
load_pyenv() {
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    [ -d "$PYENV_ROOT/bin" ] && export PATH="$PYENV_ROOT/bin:$PATH"
    command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init - bash)" 2>/dev/null || true
}

# 选择要写入的 shell 配置文件 (zsh 优先, 都没有时用 .bashrc)
pick_shell_rc() {
    if [ -f "$HOME/.zshrc" ]; then
        printf '%s\n' "$HOME/.zshrc"
    else
        printf '%s\n' "$HOME/.bashrc"
    fi
}

# 写 shell 配置片段 (幂等)
append_shell_cfg() {
    local block="$1"
    local f
    f=$(pick_shell_rc)
    if ! grep -qF "${block%%$'\n'*}" "$f" 2>/dev/null; then
        printf '\n%s\n' "$block" >> "$f"
        info "已追加配置到 $f"
    fi
}

# ---------------------------------------------------------------------------
# 组件: Node 工具链 (nvm)
# ---------------------------------------------------------------------------
install_node() {
    info "=== 安装 nvm (Node Version Manager) ==="
    if [ -d "$HOME/.nvm" ]; then
        info "nvm 已存在, 跳过安装"
        load_nvm
    else
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
        load_nvm
    fi

    append_shell_cfg 'export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

    if ! command -v node >/dev/null 2>&1; then
        info "安装 Node (LTS)..."
        if [ -n "$NODE_LTS" ]; then
            nvm install "$NODE_LTS"
        else
            nvm install --lts
        fi
        nvm alias default lts/* 2>/dev/null || true
    else
        info "Node 已就绪: $(node --version)"
    fi
    ok "nvm 配置完成"
}

# ---------------------------------------------------------------------------
# 组件: Python 版本管理器 (pyenv + 编译依赖)
# ---------------------------------------------------------------------------
install_python() {
    info "=== 安装 pyenv + Python 编译依赖 ==="

    case "$PM" in
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
                libreadline-dev libsqlite3-dev curl libncursesw5-dev xz-utils \
                tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm base-devel openssl zlib xz tk
            ;;
        dnf)
            sudo dnf install -y gcc make patch bzip2-devel readline-devel \
                sqlite-devel openssl-devel tk-devel libffi-devel xz-devel \
                zlib-ng-compat-devel
            ;;
        zypper)
            sudo zypper install -y gcc make patch bzip2-devel readline-devel \
                sqlite3-devel libopenssl-devel tk-devel libffi-devel xz-devel
            ;;
        *)
            warn "不支持的包管理器, 请手动安装 Python 编译依赖"
            ;;
    esac

    # pyenv
    if [ -d "$HOME/.pyenv" ]; then
        info "pyenv 已存在, 跳过安装"
        load_pyenv
    else
        curl -fsSL https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | bash
        load_pyenv
    fi

    # 片段要匹配实际写入的配置文件: 写进 .bashrc 就用 bash 初始化, 否则 zsh
    local rc shell_name=zsh
    rc=$(pick_shell_rc)
    case "$rc" in
        */.bashrc|*/.bash_profile) shell_name=bash ;;
    esac
    append_shell_cfg "$(printf '%s\n' \
        'export PYENV_ROOT="$HOME/.pyenv"' \
        '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' \
        "eval \"\$(pyenv init - $shell_name)\"" \
        'eval "$(pyenv virtualenv-init -)"')"

    ok "pyenv 配置完成"
    info "注意: 使用以下命令安装 Python 版本:"
    info "  pyenv install --list    # 列出可用版本"
    info "  pyenv install 3.12.0    # 安装特定版本"
    info "  pyenv global 3.12.0     # 设置全局版本"
    info "  pyenv local 3.12.0      # 设置项目版本"
}

# ---------------------------------------------------------------------------
# 组件: AI CLI (Claude Code + Codex)
# ---------------------------------------------------------------------------
install_ai() {
    info "=== 安装 AI CLI 工具 ==="
    load_nvm
    command -v node >/dev/null 2>&1 || die "需要 Node (先运行 --node)"

    if command -v claude >/dev/null 2>&1; then
        info "Claude Code 已安装: $(claude --version 2>/dev/null | head -1), 跳过"
    else
        # 优先官方安装脚本 (npm 方式已被官方标记 deprecated)
        local tpl=/tmp/claude-install.sh
        if download_installer https://claude.ai/install.sh "$tpl"; then
            info "安装 Claude Code (官方脚本)..."
            bash "$tpl" 2>&1 | tail -3 || true
            rm -f "$tpl"
            export PATH="$HOME/.local/bin:$PATH"
        else
            warn "官方安装脚本不可用 (网络/区域限制), 使用 npm (deprecated)"
        fi
        if ! command -v claude >/dev/null 2>&1; then
            npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code || true
        fi
    fi

    if command -v codex >/dev/null 2>&1; then
        info "Codex CLI 已安装: $(codex --version 2>/dev/null | head -1), 跳过"
    else
        info "安装 Codex CLI (@openai/codex)..."
        npm install -g @openai/codex
    fi

    ok "AI CLI 就绪: $(claude --version 2>/dev/null | head -1 || true), $(codex --version 2>/dev/null | head -1 || true)"
}

# ---------------------------------------------------------------------------
# 组件: Zed 编辑器 + JetBrains Mono 字体
# ---------------------------------------------------------------------------
install_zed() {
    info "=== 安装 Zed 编辑器 ==="

    # Vulkan (Zed 依赖 GPU 渲染) - 按发行版自动映射包名
    if ! command -v vulkaninfo >/dev/null 2>&1; then
        install_sys_pkg vulkan-loader vulkan-tools mesa-vulkan-drivers
    fi

    # JetBrains Mono 字体
    if ! fc-list 2>/dev/null | grep -qi "jetbrains mono"; then
        install_sys_pkg jetbrains-mono
    fi

    # Zed 本体 (官方安装脚本)
    if [ ! -x "$HOME/.local/bin/zed" ]; then
        curl -f https://zed.dev/install.sh | sh
    else
        info "Zed 已安装: $($HOME/.local/bin/zed --version | head -1)"
    fi

    # PATH 配置
    local rc_file
    rc_file=$(pick_shell_rc)
    if ! grep -q '\.local/bin' "$rc_file" 2>/dev/null; then
        printf '%s\n' 'export PATH=$HOME/.local/bin:$PATH' >> "$rc_file"
        info "$rc_file 已追加 ~/.local/bin 到 PATH"
    fi

    # Zed 默认字体配置; 已有配置时保留, 不覆盖用户设置
    if [ -f "$HOME/.config/zed/settings.json" ]; then
        info "Zed settings.json 已存在, 保留用户配置不覆盖"
    else
        mkdir -p "$HOME/.config/zed"
        cat > "$HOME/.config/zed/settings.json" << 'EOF'
{
  "ui_font_family": "JetBrains Mono",
  "ui_font_size": 14,
  "buffer_font_family": "JetBrains Mono",
  "buffer_font_size": 14,
  "terminal": {
    "font_family": "JetBrains Mono",
    "font_size": 14
  }
}
EOF
        info "已写入 Zed 默认字体配置 (JetBrains Mono)"
    fi
    ok "Zed 配置完成"
}

# ---------------------------------------------------------------------------
# 组件: Ghostty 终端 + Ctrl+Alt+T 快捷键
# ---------------------------------------------------------------------------
# Ghostty: Ubuntu 24.04 / Mint 22.3 无官方包 (官方仓库 26.04 起才有)
# 回退顺序: 官方仓库 -> 社区 .deb (mkasberg, 已处理 Mint->Ubuntu 映射) -> snap
install_ghostty_apt() {
    # 1) 官方仓库 (Ubuntu 26.04+ / 部分衍生版)
    if pkg_available ghostty; then
        install_sys_pkg ghostty && command -v ghostty >/dev/null 2>&1 && return 0
    fi

    # 2) 社区 .deb: 先下载脚本并校验, 再执行 —— 不做 curl | bash
    info "官方仓库无 ghostty ($(distro_pretty)), 改用社区 .deb..."
    local tpl=/tmp/ghostty-ubuntu-install.sh
    if download_installer https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh "$tpl"; then
        # 该脚本用 curl -LO 把 .deb 下到"当前目录", 必须在可写的临时目录里执行
        local workdir
        workdir="$(mktemp -d)"
        if ( cd "$workdir" && bash "$tpl" ); then
            rm -rf "$workdir" "$tpl"
            return 0
        fi
        warn "社区 .deb 安装失败"
        rm -rf "$workdir"
    else
        warn "无法获取/校验社区安装脚本 (可能区域受限)"
    fi
    rm -f "$tpl"

    # 3) snap
    if command -v snap >/dev/null 2>&1; then
        info "尝试 snap 安装 ghostty..."
        sudo snap install ghostty --classic && return 0
    fi

    warn "Ghostty 未能自动安装, 请参考 https://ghostty.org/docs/install/binary"
    return 1
}

# xdg-terminal-exec: Ubuntu/Mint/Arch/Fedora 官方仓库均有; 缺失时用上游脚本兜底
ensure_xdg_terminal_exec() {
    command -v xdg-terminal-exec >/dev/null 2>&1 && return 0

    if install_sys_pkg xdg-terminal-exec >/dev/null 2>&1 \
       && command -v xdg-terminal-exec >/dev/null 2>&1; then
        return 0
    fi

    info "包不可用, 从上游安装 xdg-terminal-exec 到 ~/.local/bin..."
    local tpl=/tmp/xdg-terminal-exec.sh
    if curl -fsSL --connect-timeout 15 -o "$tpl" \
            https://raw.githubusercontent.com/Vladimir-csp/xdg-terminal-exec/master/xdg-terminal-exec 2>/dev/null \
       && [ -s "$tpl" ] && head -1 "$tpl" | grep -qE '^#!'; then
        mkdir -p "$HOME/.local/bin"
        install -m755 "$tpl" "$HOME/.local/bin/xdg-terminal-exec"
        rm -f "$tpl"
        ok "xdg-terminal-exec 已装到 ~/.local/bin"
        return 0
    fi
    rm -f "$tpl"
    warn "xdg-terminal-exec 不可用 (Ctrl+Alt+T 可能不生效)"
    return 1
}

install_ghostty() {
    info "=== 安装 Ghostty 终端 ==="

    if ! ghostty_binary >/dev/null 2>&1; then
        case "$PM" in
            dnf)
                { sudo dnf copr enable -y scottames/ghostty && sudo dnf install -y ghostty; } \
                    || die "Ghostty dnf 安装失败"
                ;;
            apt)
                install_ghostty_apt || die "Ghostty apt 安装失败"
                ;;
            pacman)
                sudo pacman -S --needed --noconfirm ghostty \
                    || die "Ghostty pacman 安装失败"
                ;;
            zypper)
                sudo zypper install -y ghostty || die "Ghostty zypper 安装失败"
                ;;
            *)
                die "Ghostty 安装方式未知, 请手动安装"
                ;;
        esac
    else
        local bin
        bin="$(ghostty_binary)"
        info "Ghostty 已安装: $("$bin" --version | head -1)"
    fi

    ghostty_binary >/dev/null 2>&1 || die "Ghostty 安装后仍未找到可执行文件"
    if ! command -v infocmp >/dev/null 2>&1 || ! command -v tic >/dev/null 2>&1; then
        install_sys_pkg ncurses-tools
    fi
    repair_ghostty || die "Ghostty 兼容修复失败, 请查看上面的错误"

    # xdg-terminal-exec (默认终端执行器, Budgie/labwc 的 C-A-t 依赖它)
    # 发行版包缺失时自动回退到上游脚本, 不再直接放弃
    ensure_xdg_terminal_exec >/dev/null 2>&1 || true
    command -v xdg-terminal-exec >/dev/null 2>&1 \
        || warn "未装上 xdg-terminal-exec, Ctrl+Alt+T 可能不生效"

    # labwc (Budgie) Ctrl+Alt+T 快捷键: 确保绑定指向 xdg-terminal-exec
    local rc="$HOME/.config/budgie-desktop/labwc/rc.xml"
    if [ -f "$rc" ] && ! grep -q 'xdg-terminal-exec' "$rc"; then
        cp "$rc" "$rc.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        sed -i 's|command="xfce4-terminal"|command="xdg-terminal-exec"|g; s|command="ghostty"|command="xdg-terminal-exec"|g' "$rc"
        info "labwc rc.xml: Ctrl+Alt+T 已绑定 xdg-terminal-exec"
        if pgrep labwc >/dev/null 2>&1; then
            pkill -USR1 labwc 2>/dev/null || true
        fi
    fi

    ok "Ghostty 配置完成 (terminfo 与桌面入口已修复)"
}

# ---------------------------------------------------------------------------
# 组件: Visual Studio Code 编辑器
# ---------------------------------------------------------------------------
install_vscode() {
    info "=== 安装 Visual Studio Code ==="

    if command -v code >/dev/null 2>&1; then
        info "VS Code 已安装: $(code --version | head -1)"
    else
        case "$PM" in
            dnf)
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo bash -c 'echo -e "[code]\nname=VS Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
                sudo dnf install -y code
                ;;
            apt)
                sudo bash -c 'curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg'
                sudo bash -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
                sudo apt-get update -qq
                sudo apt-get install -y code
                ;;
            pacman)
                # Arch extra 官方仓库含 VS Code
                sudo pacman -S --needed --noconfirm code
                ;;
            zypper)
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo zypper addrepo -f https://packages.microsoft.com/yumrepos/vscode vscode
                sudo zypper install -y code
                ;;
            *)
                warn "VS Code 安装方式未知, 请手动安装"
                ;;
        esac
    fi

    ok "VS Code 配置完成"
}

# ---------------------------------------------------------------------------
# 组件: MiMo Code (小米 AI 编程助手)
# ---------------------------------------------------------------------------
install_mimo() {
    info "=== 安装 MiMo Code (小米 AI 编程助手) ==="

    load_nvm
    # 官方安装路径 (~/.mimocode/bin) 与用户级 bin
    export PATH="$HOME/.mimocode/bin:$HOME/.local/bin:$PATH"

    if command -v mimo >/dev/null 2>&1; then
        info "MiMo Code 已安装: $(mimo --version 2>/dev/null | head -1)"
    else
        # 官方脚本 (macOS/Linux 推荐; Windows 官方为 npm)
        local tpl=/tmp/mimo-install.sh
        if download_installer https://mimo.xiaomi.com/install "$tpl"; then
            info "安装 MiMo Code (官方脚本)..."
            bash "$tpl" 2>&1 | tail -3 || true
            rm -f "$tpl"
            export PATH="$HOME/.local/bin:$PATH"
        else
            warn "官方安装脚本不可用, 回退 npm"
        fi
        if ! command -v mimo >/dev/null 2>&1; then
            command -v node >/dev/null 2>&1 || die "需要 Node (先运行 --node) 或手动安装 MiMo Code"
            npm install -g --allow-scripts=@mimo-ai/cli @mimo-ai/cli || true
        fi
    fi

    if ! command -v mimo >/dev/null 2>&1; then
        die "MiMo Code 安装失败, 请检查网络"
    fi

    ok "MiMo Code 配置完成: $(mimo --version 2>/dev/null | head -1)"
}

# ---------------------------------------------------------------------------
# 组件: ChatGPT / Codex 桌面版 (OpenAI 官方 Linux 预览版)
# ---------------------------------------------------------------------------
install_chatgpt() {
    info "=== 安装 ChatGPT / Codex 桌面版 ==="

    if command -v chatgpt >/dev/null 2>&1; then
        info "ChatGPT 已安装: $(chatgpt --version 2>/dev/null | head -1)"
        return 0
    fi

    local arch arch_suffix
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch_suffix="x86_64" ;;
        aarch64|arm64) arch_suffix="aarch64" ;;
        *) die "不支持的架构: $arch" ;;
    esac

    local tmp_pkg
    case "$PM" in
        dnf|zypper)
            local rpm_url
            if [ "$arch_suffix" = "x86_64" ]; then
                rpm_url="https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm"
            else
                rpm_url="https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.aarch64.rpm"
            fi
            info "下载 ChatGPT rpm (约 530MB)..."
            make_tmp tmp_pkg .rpm
            curl -fsSL --connect-timeout 15 -o "$tmp_pkg" "$rpm_url"
            if [ "$PM" = "dnf" ]; then
                sudo dnf install -y "$tmp_pkg"
            else
                sudo zypper install -y "$tmp_pkg"
            fi
            rm -f -- "$tmp_pkg"
            ;;
        apt)
            local deb_url
            if [ "$arch_suffix" = "x86_64" ]; then
                deb_url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"
            else
                deb_url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_arm64.deb"
            fi
            info "下载 ChatGPT deb (约 530MB)..."
            make_tmp tmp_pkg .deb
            curl -fsSL --connect-timeout 15 -o "$tmp_pkg" "$deb_url"
            sudo apt-get update -qq
            sudo apt-get install -y "$tmp_pkg"
            rm -f -- "$tmp_pkg"
            ;;
        pacman)
            local script_url="https://persistent.oaistatic.com/codex-app-prod/linux/install-arch.sh"
            make_tmp tmp_pkg .sh
            curl --proto '=https' --tlsv1.2 -fL -o "$tmp_pkg" "$script_url"
            sudo bash "$tmp_pkg"
            rm -f -- "$tmp_pkg"
            ;;
        *)
            warn "不支持的包管理器, 请手动安装 ChatGPT 桌面版"
            ;;
    esac

    if command -v chatgpt >/dev/null 2>&1; then
        ok "ChatGPT 桌面版安装完成: $(chatgpt --version 2>/dev/null | head -1)"
    else
        warn "ChatGPT 安装可能未成功, 请检查"
    fi
}

# ---------------------------------------------------------------------------
# 组件: CC Switch (AI CLI 配置切换器, 桌面版)
# ---------------------------------------------------------------------------
install_ccswitch() {
    info "=== 安装 CC Switch (AI CLI 配置切换器) ==="

    if command -v cc-switch >/dev/null 2>&1; then
        info "CC Switch 已安装"
        return 0
    fi

    local arch arch_id
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch_id="x86_64" ;;
        aarch64|arm64) arch_id="arm64" ;;
        *) die "不支持的架构: $arch" ;;
    esac

    # GitHub 官方 release 直链 + 镜像前缀 (GitHub CDN 走代理不稳定时用镜像)
    local gh_url="https://github.com/farion1231/cc-switch/releases/download/v3.20.4/CC-Switch-v3.20.4-Linux-${arch_id}"
    local mirrors=("" "https://ghfast.top/" "https://gh-proxy.com/" "https://ghproxy.net/")
    local dl=""
    local pkg_suffix=".AppImage"
    local tmp_pkg

    case "$PM" in
        dnf|zypper) pkg_suffix=".rpm" ;;
        apt)        pkg_suffix=".deb" ;;
    esac
    # 后缀要与 release 资产一致, 也便于包管理器识别本地文件类型
    make_tmp tmp_pkg "$pkg_suffix"

    for m in "${mirrors[@]}"; do
        info "尝试下载 CC Switch: ${m}${gh_url}${pkg_suffix}"
        if curl -fsSL --connect-timeout 15 -o "$tmp_pkg" "${m}${gh_url}${pkg_suffix}" 2>/dev/null; then
            dl="${m}${gh_url}${pkg_suffix}"
            break
        fi
    done

    if [ -z "$dl" ]; then
        die "CC Switch 下载失败, 请手动从 https://github.com/farion1231/cc-switch/releases 安装"
    fi

    case "$PM" in
        dnf)
            sudo dnf install -y "$tmp_pkg"
            ;;
        zypper)
            sudo zypper install -y "$tmp_pkg"
            ;;
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y "$tmp_pkg"
            ;;
        pacman|*)
            # AppImage 运行需要 FUSE (Arch: fuse2 / Ubuntu: libfuse2t64)
            install_sys_pkg fuse2 >/dev/null 2>&1 || true
            mkdir -p "$HOME/.local/bin"
            install -m755 "$tmp_pkg" "$HOME/.local/bin/cc-switch"
            ;;
    esac
    rm -f -- "$tmp_pkg"

    if command -v cc-switch >/dev/null 2>&1; then
        ok "CC Switch 安装完成"
    else
        warn "CC Switch 安装可能未成功 (AppImage 方式已放入 ~/.local/bin)"
    fi
}

# ---------------------------------------------------------------------------
# --check: 只报告本机适配情况, 不做任何改动 (跨发行版验证用)
# ---------------------------------------------------------------------------
cmd_check() {
    printf '\n%s\n' "== 发行版 =="
    distro_report

    printf '\n%s\n' "== 系统包解析 =="
    local logical resolved mark
    for logical in vulkan-loader vulkan-tools mesa-vulkan-drivers \
                   jetbrains-mono xdg-terminal-exec fuse2 ncurses-dev \
                   fontconfig unzip; do
        resolved="$(pkg_resolve "$logical" 2>/dev/null || echo "")"
        if [ -z "$resolved" ]; then
            printf '  %-22s %s\n' "$logical" "$(printf '\033[1;33m%-24s\033[0m' '<本发行版无')"
        else
            printf '  %-22s -> %s\n' "$logical" "$resolved"
        fi
    done

    printf '\n%s\n' "== 各组件安装方式 =="
    case "$PM" in
        apt)    printf '  %-12s %s\n' ghostty  "官方仓库(26.04+) / 社区 .deb / snap" ;;
        pacman) printf '  %-12s %s\n' ghostty  "官方 extra 仓库 (pacman -S ghostty)" ;;
        dnf)    printf '  %-12s %s\n' ghostty  "COPR scottames/ghostty" ;;
        zypper) printf '  %-12s %s\n' ghostty  "官方 repo-oss" ;;
    esac
    case "$PM" in
        apt)    printf '  %-12s %s\n' vscode   "微软 apt 源 (packages.microsoft.com)" ;;
        pacman) printf '  %-12s %s\n' vscode   "官方 extra 仓库 (pacman -S code)" ;;
        dnf)    printf '  %-12s %s\n' vscode   "微软 dnf 源" ;;
        zypper) printf '  %-12s %s\n' vscode   "微软 zypper 源" ;;
    esac
    case "$PM" in
        apt)    printf '  %-12s %s\n' chatgpt  "官方 .deb" ;;
        pacman) printf '  %-12s %s\n' chatgpt  "官方 install-arch.sh" ;;
        dnf|zypper) printf '  %-12s %s\n' chatgpt "官方 .rpm" ;;
    esac
    case "$PM" in
        apt)    printf '  %-12s %s\n' ccswitch "官方 .deb" ;;
        pacman) printf '  %-12s %s\n' ccswitch "AppImage + fuse2" ;;
        dnf|zypper) printf '  %-12s %s\n' ccswitch "官方 .rpm" ;;
    esac
    printf '  %-12s %s\n' node   "nvm (发行版无关)"
    printf '  %-12s %s\n' python "pyenv (需构建依赖)"
    printf '  %-12s %s\n' ai     "npm 全局安装"
    printf '  %-12s %s\n' zed    "Zed 官方安装脚本 (发行版无关)"
    printf '  %-12s %s\n' mimo   "MiMo 官方安装脚本 (发行版无关)"
    printf '\n'
}

# ---------------------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------------------
# 打印文件头部注释块 (去掉 # 前缀); 按注释边界截取, 不依赖硬编码行号,
# 以后增删注释不会再把「依赖」「说明」两节截掉
usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

# 加载 TUI 模块 (--tui 与 --list 共用); 成功时可直接调用其函数
load_tui_module() {
    local module
    module="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tui_module.sh"
    if [ ! -f "$module" ]; then
        return 1
    fi
    # shellcheck disable=SC1091
    . "$module"
}

# --list: 列出可安装组件及当前安装状态
list_components() {
    local id status
    if ! load_tui_module; then
        die "未找到 tui_module.sh, 无法列出组件"
    fi
    printf '可安装组件:\n'
    for id in "${TUI_IDS[@]}"; do
        if tui_component_installed "$id"; then
            status="已安装"
        else
            status="未安装"
        fi
        printf '  %-9s %-4s %s\n' "$id" "$status" "$(tui_component_name "$id")"
    done
}

HAS_ARGS=false
while [[ $# -gt 0 ]]; do
    HAS_ARGS=true
    case "$1" in
        --node)     INSTALL_NODE=true; shift ;;
        --python)   INSTALL_PYTHON=true; shift ;;
        --ai)       INSTALL_AI=true; shift ;;
        --zed)      INSTALL_ZED=true; shift ;;
        --ghostty)  INSTALL_GHOSTTY=true; shift ;;
        --vscode)   INSTALL_VSCODE=true; shift ;;
        --mimo)     INSTALL_MIMO=true; shift ;;
        --chatgpt)  INSTALL_CHATGPT=true; shift ;;
        --ccswitch) INSTALL_CCSWITCH=true; shift ;;
        --all)      INSTALL_ALL=true; shift ;;
        --tui)      TUI_MODE=true; shift ;;
        --list)     list_components; exit 0 ;;
        --check)    cmd_check; exit 0 ;;
        -h|--help)  usage; exit 0 ;;
        *)
            printf '未知选项: %s\n\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# 无参数只进入交互选择, 非交互调用须显式指定组件。
if [ "$HAS_ARGS" = "false" ]; then
    if [ -t 1 ] && [ -t 0 ]; then
        TUI_MODE=true
    else
        die "当前不是交互式终端, 请指定组件选项或使用 --all (查看 --help)"
    fi
fi

if $TUI_MODE && $INSTALL_ALL; then
    die "--all 不能与 --tui 同时使用"
fi

# ---------------------------------------------------------------------------
# 代理设置 (可选)
# ---------------------------------------------------------------------------
if [ -n "$PROXY_URL" ]; then
    export https_proxy="$PROXY_URL" http_proxy="$PROXY_URL"
    info "使用代理: $PROXY_URL"
fi

# ---------------------------------------------------------------------------
# TUI 交互选择 (--tui)
# ---------------------------------------------------------------------------
if $TUI_MODE; then
    if ! load_tui_module; then
        die "未找到 tui_module.sh"
    fi
    if ! tui_available; then
        die "当前不是交互式终端, 请指定组件选项或使用 --all (查看 --help)"
    fi
    info "启动 TUI 选择界面 (已安装组件自动跳过)..."
    run_tui
    if [ -z "$TUI_SELECTED" ]; then
        info "TUI 未选择任何组件 (或退出), 跳过安装"
        exit 0
    fi
    INSTALL_ALL=false
    INSTALL_NODE=false; INSTALL_PYTHON=false; INSTALL_AI=false
    INSTALL_ZED=false; INSTALL_GHOSTTY=false; INSTALL_VSCODE=false
    INSTALL_MIMO=false; INSTALL_CHATGPT=false; INSTALL_CCSWITCH=false
    for comp in $TUI_SELECTED; do
        case "$comp" in
            node)     INSTALL_NODE=true ;;
            python)   INSTALL_PYTHON=true ;;
            ai)       INSTALL_AI=true ;;
            zed)      INSTALL_ZED=true ;;
            ghostty)  INSTALL_GHOSTTY=true ;;
            vscode)   INSTALL_VSCODE=true ;;
            mimo)     INSTALL_MIMO=true ;;
            chatgpt)  INSTALL_CHATGPT=true ;;
            ccswitch) INSTALL_CCSWITCH=true ;;
        esac
    done
    info "已选择:${TUI_SELECTED}"
fi

# 前置检查放在选择之后, 只检查用户选中的组件。
info "=== 开发工具安装器 ==="
distro_report
printf '\n'
if ! check_prerequisites; then
    warn "前置检查发现问题，但继续执行（部分安装可能失败）"
    sleep 2
fi

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
info "joe devtools 安装开始 $(date) [包管理器: $PM]"

if $INSTALL_ALL || $INSTALL_NODE; then install_node; fi
if $INSTALL_ALL || $INSTALL_PYTHON; then install_python; fi
if $INSTALL_ALL || $INSTALL_AI; then install_ai; fi
if $INSTALL_ALL || $INSTALL_ZED; then install_zed; fi
if $INSTALL_ALL || $INSTALL_GHOSTTY; then install_ghostty; fi
if $INSTALL_ALL || $INSTALL_VSCODE; then install_vscode; fi
if $INSTALL_ALL || $INSTALL_MIMO; then install_mimo; fi
if $INSTALL_ALL || $INSTALL_CHATGPT; then install_chatgpt; fi
if $INSTALL_ALL || $INSTALL_CCSWITCH; then install_ccswitch; fi

ok "全部完成! 新开终端后生效 (或 source ~/.zshrc)"
