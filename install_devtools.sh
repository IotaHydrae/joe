#!/usr/bin/env bash
# =============================================================================
# joe devtools — 开发工具套件安装脚本 (跨发行版)
# =============================================================================
# 记录在服务器 (Fedora 44) 上安装过的一组开发工具，供新机器一键复现。
# 支持 apt (Debian/Ubuntu)、dnf (Fedora/RHEL)、pacman (Arch)、zypper (openSUSE)。
#
# 用法:
#   ./install_devtools.sh            # 默认进入 TUI 交互选择界面 (非交互式终端改为安装全部)
#   ./install_devtools.sh --node     # 只装 Node 工具链 (nvm)
#   ./install_devtools.sh --python   # 只装 Python 工具链 (pyenv + pipx)
#   ./install_devtools.sh --ai       # 只装 AI CLI (claude-code + codex)
#   ./install_devtools.sh --zed      # 只装 Zed 编辑器 + JetBrains Mono
#   ./install_devtools.sh --ghostty  # 只装 Ghostty 终端 + Ctrl+Alt+T 快捷键
#   ./install_devtools.sh --vscode   # 只装 VS Code 编辑器
#   ./install_devtools.sh --mimo     # 只装 MiMo Code (小米 AI 编程助手)
#   ./install_devtools.sh --chatgpt  # 只装 ChatGPT / Codex 桌面版
#   ./install_devtools.sh --ccswitch # 只装 CC Switch (AI CLI 配置切换器)
#   ./install_devtools.sh --tui      # 交互式勾选界面 (TUI)
#   ./install_devtools.sh --list     # 列出可安装组件
#
# 依赖: git, curl, sudo (非 root 时), bash/zsh
# 说明:
#   - nvm 装到 ~/.nvm, 默认 Node LTS
#   - pyenv 装到 ~/.pyenv, 默认 Python 3.12 (可改 PYTHON_VERSION)
#   - 所有需要外网下载的步骤都尊重 https_proxy/http_proxy 环境变量
#   - 系统包名按发行版自动映射 (apt/dnf/pacman/zypper)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
NODE_LTS="${NODE_LTS:-}"                    # 留空 = 安装时最新 LTS
PYTHON_VERSION="${PYTHON_VERSION:-3.12.10}"
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
INSTALL_ALL=true
TUI_MODE=false

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
# 包管理器探测 + 包名映射 (核心跨发行版逻辑)
# ---------------------------------------------------------------------------
detect_pm() {
    if command -v apt-get >/dev/null 2>&1; then echo "apt"
    elif command -v pacman >/dev/null 2>&1; then echo "pacman"
    elif command -v dnf >/dev/null 2>&1; then echo "dnf"
    elif command -v zypper >/dev/null 2>&1; then echo "zypper"
    else echo "unknown"; fi
}
PM=$(detect_pm)

# 包是否已安装
pkg_installed() {
    local pkg="$1"
    case "$PM" in
        apt)    dpkg -s "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -Q "$pkg" >/dev/null 2>&1 ;;
        dnf|zypper) rpm -q "$pkg" >/dev/null 2>&1 ;;
        *)      false ;;
    esac
}

# 逻辑包名 → 发行版实际包名
# 用 {logical} 时返回一组包名 (空格分隔)
pkg_map() {
    local logical="$1"
    case "$PM" in
        apt)
            case "$logical" in
                vulkan-loader)          echo "libvulkan1" ;;
                vulkan-tools)           echo "vulkan-tools" ;;
                mesa-vulkan-drivers)    echo "mesa-vulkan-drivers" ;;
                jetbrains-mono)         echo "fonts-jetbrains-mono" ;;
                xdg-terminal-exec)      echo "xdg-terminal-exec" ;;
                *)                      echo "$logical" ;;
            esac ;;
        pacman)
            case "$logical" in
                vulkan-loader)          echo "vulkan-icd-loader" ;;
                vulkan-tools)           echo "vulkan-tools" ;;
                mesa-vulkan-drivers)    echo "vulkan-radeon vulkan-intel" ;;
                jetbrains-mono)         echo "ttf-jetbrains-mono" ;;
                xdg-terminal-exec)      echo "" ;;  # AUR, 不装
                *)                      echo "$logical" ;;
            esac ;;
        zypper)
            case "$logical" in
                vulkan-loader)          echo "libvulkan1" ;;
                vulkan-tools)           echo "vulkan-tools" ;;
                mesa-vulkan-drivers)    echo "libvulkan_radeon" ;;
                jetbrains-mono)         echo "jetbrains-mono-fonts" ;;
                xdg-terminal-exec)      echo "" ;;
                *)                      echo "$logical" ;;
            esac ;;
        *) # dnf 及默认
            case "$logical" in
                vulkan-loader)          echo "vulkan-loader" ;;
                vulkan-tools)           echo "vulkan-tools" ;;
                mesa-vulkan-drivers)    echo "mesa-vulkan-drivers" ;;
                jetbrains-mono)         echo "jetbrains-mono-fonts" ;;
                xdg-terminal-exec)      echo "xdg-terminal-exec" ;;
                *)                      echo "$logical" ;;
            esac ;;
    esac
}

# 安装系统包 (接受多个逻辑包名)
install_sys_pkg() {
    local missing=()
    local logical real pkg
    for logical in "$@"; do
        real=$(pkg_map "$logical")
        [ -z "$real" ] && { warn "发行版 $PM 无 $logical 包, 跳过"; continue; }
        for pkg in $real; do
            if pkg_installed "$pkg"; then
                info "$pkg 已安装, 跳过"
            else
                missing+=("$pkg")
            fi
        done
    done
    [ ${#missing[@]} -eq 0 ] && return 0

    info "安装系统包: ${missing[*]}"
    case "$PM" in
        apt)    sudo apt-get update -qq && sudo apt-get install -y "${missing[@]}" ;;
        pacman) sudo pacman -S --needed --noconfirm "${missing[@]}" ;;
        dnf)    sudo dnf install -y "${missing[@]}" ;;
        zypper) sudo zypper install -y "${missing[@]}" ;;
        *)      warn "不支持的包管理器, 请手动安装: ${missing[*]}" ;;
    esac
}

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
# 组件: Python 工具链 (pyenv + pipx)
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

    # 安装默认 Python
    if ! pyenv versions --bare 2>/dev/null | grep -qx "$PYTHON_VERSION"; then
        info "pyenv 编译安装 Python $PYTHON_VERSION (需要几分钟)..."
        pyenv install "$PYTHON_VERSION"
    else
        info "Python $PYTHON_VERSION 已存在"
    fi
    pyenv global "$PYTHON_VERSION"
    ok "pyenv 配置完成: Python $(pyenv global)"

    # pipx
    info "=== 安装 pipx ==="
    if ! command -v pipx >/dev/null 2>&1; then
        python -m pip install --user pipx 2>/dev/null || python -m pip install pipx
        python -m pipx ensurepath
    fi
    ok "pipx 配置完成"
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
        info "安装 Claude Code (@anthropic-ai/claude-code)..."
        npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code
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
install_ghostty() {
    info "=== 安装 Ghostty 终端 ==="

    if ! command -v ghostty >/dev/null 2>&1; then
        case "$PM" in
            dnf)
                sudo dnf copr enable -y scottames/ghostty
                sudo dnf install -y ghostty
                ;;
            apt)
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
                ;;
            pacman)
                sudo pacman -S --needed --noconfirm ghostty
                ;;
            zypper)
                sudo zypper install -y ghostty
                ;;
            *)
                warn "Ghostty 安装方式未知, 请手动安装"
                ;;
        esac
    else
        info "Ghostty 已安装: $(ghostty --version | head -1)"
    fi

    # xdg-terminal-exec (默认终端执行器, Budgie/labwc 的 C-A-t 依赖它)
    if ! command -v xdg-terminal-exec >/dev/null 2>&1; then
        local real
        real=$(pkg_map xdg-terminal-exec)
        if [ -n "$real" ]; then
            install_sys_pkg xdg-terminal-exec
        else
            warn "发行版 $PM 没有 xdg-terminal-exec 包, 跳过 (Ctrl+Alt+T 可能不生效)"
        fi
    fi

    # 配置 Ghostty 为默认终端 (xdg-terminal-exec 首选)
    if command -v xdg-terminal-exec >/dev/null 2>&1; then
        mkdir -p "$HOME/.config"
        if [ -f /usr/share/applications/com.mitchellh.ghostty.desktop ]; then
            printf 'com.mitchellh.ghostty.desktop\n' > "$HOME/.config/xdg-terminals.list"
            printf 'com.mitchellh.ghostty.desktop\n' > "$HOME/.config/budgie-xdg-terminals.list"
            info "已配置 Ghostty 为默认终端"
        fi
    fi

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

    ok "Ghostty 配置完成 (Ctrl+Alt+T 打开)"
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
    command -v node >/dev/null 2>&1 || die "需要 Node (先运行 --node)"

    if command -v mimo >/dev/null 2>&1; then
        info "MiMo Code 已安装: $(mimo --version 2>/dev/null | head -1)"
    else
        info "安装 @mimo-ai/cli..."
        npm install -g --allow-scripts=@mimo-ai/cli @mimo-ai/cli
    fi

    if ! command -v mimo >/dev/null 2>&1; then
        die "MiMo Code 安装失败, 请检查 npm 和网络"
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
        --node)     INSTALL_NODE=true; INSTALL_ALL=false; shift ;;
        --python)   INSTALL_PYTHON=true; INSTALL_ALL=false; shift ;;
        --ai)       INSTALL_AI=true; INSTALL_ALL=false; shift ;;
        --zed)      INSTALL_ZED=true; INSTALL_ALL=false; shift ;;
        --ghostty)  INSTALL_GHOSTTY=true; INSTALL_ALL=false; shift ;;
        --vscode)   INSTALL_VSCODE=true; INSTALL_ALL=false; shift ;;
        --mimo)      INSTALL_MIMO=true; INSTALL_ALL=false; shift ;;
        --chatgpt)   INSTALL_CHATGPT=true; INSTALL_ALL=false; shift ;;
        --ccswitch)  INSTALL_CCSWITCH=true; INSTALL_ALL=false; shift ;;
        --tui)       TUI_MODE=true; INSTALL_ALL=false; shift ;;
        --list)     list_components; exit 0 ;;
        -h|--help)  usage; exit 0 ;;
        *)
            printf '未知选项: %s\n\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# 无参数时默认进入 TUI 交互选择 (除非是纯脚本/非交互环境)
if [ "$HAS_ARGS" = "false" ]; then
    if [ -t 1 ] && [ -t 0 ]; then
        TUI_MODE=true
        INSTALL_ALL=false
    else
        INSTALL_ALL=true
    fi
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
        warn "未找到 tui_module.sh, 跳过 TUI"
        exit 0
    fi
    if ! tui_available; then
        warn "当前不是交互式终端, 跳过 TUI, 使用 --help 查看选项"
        exit 0
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
