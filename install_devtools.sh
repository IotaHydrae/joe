#!/usr/bin/env bash
# =============================================================================
# joe devtools — 开发工具套件安装脚本 (跨发行版)
# =============================================================================
# 记录在服务器 (Fedora 44) 上安装过的一组开发工具，供新机器一键复现。
# 支持 apt (Debian/Ubuntu)、dnf (Fedora/RHEL)、pacman (Arch)、zypper (openSUSE)。
#
# 用法:
#   ./install_devtools.sh            # 安装全部工具
#   ./install_devtools.sh --node     # 只装 Node 工具链 (nvm)
#   ./install_devtools.sh --python   # 只装 Python 工具链 (pyenv + pipx)
#   ./install_devtools.sh --ai       # 只装 AI CLI (claude-code + codex)
#   ./install_devtools.sh --zed      # 只装 Zed 编辑器 + JetBrains Mono
#   ./install_devtools.sh --ghostty  # 只装 Ghostty 终端 + Ctrl+Alt+T 快捷键
#   ./install_devtools.sh --vscode   # 只装 VS Code 编辑器
#   ./install_devtools.sh --mimo     # 只装 MiMo Code (小米 AI 编程助手)
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
INSTALL_ALL=true

# ---------------------------------------------------------------------------
# 小工具函数
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*"; }
die()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

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
    local pkg
    for logical in "$@"; do
        local real
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

# 写 shell 配置片段 (zsh 优先, 幂等)
append_shell_cfg() {
    local block="$1"
    local f="$HOME/.zshrc"
    [ -f "$f" ] || f="$HOME/.bashrc"
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

    append_shell_cfg 'export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
eval "$(pyenv virtualenv-init -)"'

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

    info "安装 Claude Code (@anthropic-ai/claude-code)..."
    npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code
    info "安装 Codex CLI (@openai/codex)..."
    npm install -g @openai/codex

    ok "AI CLI 安装完成: $(claude --version 2>/dev/null | head -1 || true), $(codex --version 2>/dev/null | head -1 || true)"
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
    if ! grep -q '\.local/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH=$HOME/.local/bin:$PATH' >> "$HOME/.zshrc"
        info ".zshrc 已追加 ~/.local/bin 到 PATH"
    fi

    # Zed 默认字体配置
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
    ok "Zed 配置完成 (JetBrains Mono)"
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
# 参数解析
# ---------------------------------------------------------------------------
usage() {
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --node)     INSTALL_NODE=true; INSTALL_ALL=false; shift ;;
        --python)   INSTALL_PYTHON=true; INSTALL_ALL=false; shift ;;
        --ai)       INSTALL_AI=true; INSTALL_ALL=false; shift ;;
        --zed)      INSTALL_ZED=true; INSTALL_ALL=false; shift ;;
        --ghostty)  INSTALL_GHOSTTY=true; INSTALL_ALL=false; shift ;;
        --vscode)   INSTALL_VSCODE=true; INSTALL_ALL=false; shift ;;
        --mimo)      INSTALL_MIMO=true; INSTALL_ALL=false; shift ;;
        --list)     usage ;;
        -h|--help)  usage ;;
        *)
            echo "未知选项: $1" >&2
            usage
            ;;
    esac
done

# ---------------------------------------------------------------------------
# 代理设置 (可选)
# ---------------------------------------------------------------------------
if [ -n "$PROXY_URL" ]; then
    export https_proxy="$PROXY_URL" http_proxy="$PROXY_URL"
    info "使用代理: $PROXY_URL"
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

ok "全部完成! 新开终端后生效 (或 source ~/.zshrc)"
