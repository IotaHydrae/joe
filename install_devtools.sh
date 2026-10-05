#!/usr/bin/env bash
# =============================================================================
# joe devtools — 开发工具套件安装脚本
# =============================================================================
# 记录在服务器 (Fedora 44) 上安装过的一组开发工具，供新机器一键复现。
#
# 用法:
#   ./install_devtools.sh            # 安装全部工具
#   ./install_devtools.sh --node     # 只装 Node 工具链 (nvm)
#   ./install_devtools.sh --python   # 只装 Python 工具链 (pyenv + pipx)
#   ./install_devtools.sh --ai       # 只装 AI CLI (claude-code + codex)
#   ./install_devtools.sh --zed      # 只装 Zed 编辑器 + JetBrains Mono
#   ./install_devtools.sh --list     # 列出可安装组件
#
# 依赖: git, curl, sudo (非 root 时), bash/zsh
# 说明:
#   - nvm 装到 ~/.nvm, 默认 Node LTS
#   - pyenv 装到 ~/.pyenv, 默认 Python 3.12 (可改 PYTHON_VERSION)
#   - 所有需要外网下载的步骤都尊重 https_proxy/http_proxy 环境变量
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
INSTALL_ALL=true

# ---------------------------------------------------------------------------
# 小工具函数
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*"; }
die()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# 幂等安装系统包 (支持 apt/pacman/dnf/zypper)
install_sys_pkg() {
    local pkg="$1"
    if rpm -q "$pkg" &>/dev/null || pacman -Q "$pkg" &>/dev/null || dpkg -s "$pkg" &>/dev/null; then
        info "$pkg 已安装, 跳过"
        return 0
    fi
    info "安装系统包: $pkg"
    if command -v dnf &>/dev/null; then
        sudo dnf install -y "$pkg"
    elif command -v apt &>/dev/null; then
        sudo apt install -y "$pkg"
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm "$pkg"
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y "$pkg"
    else
        warn "不支持的包管理器, 请手动安装 $pkg"
    fi
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
    command -v pyenv &>/dev/null && eval "$(pyenv init - bash)" 2>/dev/null || true
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

    # 确保 shell 配置 (zsh 优先)
    if ! grep -q "NVM_DIR" "$HOME/.zshrc" 2>/dev/null; then
        cat >> "$HOME/.zshrc" << 'EOF'

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
        info ".zshrc 已追加 nvm 配置"
    fi

    if ! command -v node &>/dev/null; then
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

    # 编译依赖
    case "$(command -v dnf apt pacman zypper 2>/dev/null | head -1)" in
        *dnf)
            sudo dnf install -y gcc make patch bzip2-devel readline-devel \
                sqlite-devel openssl-devel tk-devel libffi-devel xz-devel \
                zlib-ng-compat-devel
            ;;
        *apt)
            sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
                libreadline-dev libsqlite3-dev curl libncursesw5-dev xz-utils \
                tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
            ;;
        *pacman)
            sudo pacman -S --needed --noconfirm base-devel openssl zlib xz tk
            ;;
        *zypper)
            sudo zypper install -y gcc make patch bzip2-devel readline-devel \
                sqlite3-devel libopenssl-devel tk-devel libffi-devel xz-devel
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

    # shell 配置
    if ! grep -q "PYENV_ROOT" "$HOME/.zshrc" 2>/dev/null; then
        cat >> "$HOME/.zshrc" << 'EOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
eval "$(pyenv virtualenv-init -)"
EOF
        info ".zshrc 已追加 pyenv 配置"
    fi

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
    if ! command -v pipx &>/dev/null; then
        python -m pip install --user pipx 2>/dev/null || python -m pip install pipx
        python -m pipx ensurepath
    fi
    if ! grep -q "pipx" "$HOME/.zshrc" 2>/dev/null; then
        echo 'command -v pipx >/dev/null && eval "$(register-python-argcomplete pipx)"' >> "$HOME/.zshrc" 2>/dev/null || true
    fi
    ok "pipx 配置完成"
}

# ---------------------------------------------------------------------------
# 组件: AI CLI (Claude Code + Codex)
# ---------------------------------------------------------------------------
install_ai() {
    info "=== 安装 AI CLI 工具 ==="
    load_nvm
    command -v node &>/dev/null || die "需要 Node (先运行 --node)"

    info "安装 Claude Code (@anthropic-ai/claude-code)..."
    npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code
    info "安装 Codex CLI (@openai/codex)..."
    npm install -g @openai/codex

    ok "AI CLI 安装完成: claude $(claude --version 2>/dev/null | head -1 || true), codex $(codex --version 2>/dev/null | head -1 || true)"
}

# ---------------------------------------------------------------------------
# 组件: Zed 编辑器 + JetBrains Mono 字体
# ---------------------------------------------------------------------------
install_zed() {
    info "=== 安装 Zed 编辑器 ==="

    # Vulkan (Zed 依赖 GPU 渲染)
    if ! command -v vulkaninfo &>/dev/null; then
        install_sys_pkg vulkan-loader
        install_sys_pkg vulkan-tools
        install_sys_pkg mesa-vulkan-drivers
    fi

    # JetBrains Mono 字体
    if ! fc-list 2>/dev/null | grep -qi "jetbrains mono"; then
        install_sys_pkg jetbrains-mono-fonts
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
# 参数解析
# ---------------------------------------------------------------------------
usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --node)     INSTALL_NODE=true; INSTALL_ALL=false; shift ;;
        --python)   INSTALL_PYTHON=true; INSTALL_ALL=false; shift ;;
        --ai)       INSTALL_AI=true; INSTALL_ALL=false; shift ;;
        --zed)      INSTALL_ZED=true; INSTALL_ALL=false; shift ;;
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
info "joe devtools 安装开始 $(date)"

if $INSTALL_ALL || $INSTALL_NODE; then install_node; fi
if $INSTALL_ALL || $INSTALL_PYTHON; then install_python; fi
if $INSTALL_ALL || $INSTALL_AI; then install_ai; fi
if $INSTALL_ALL || $INSTALL_ZED; then install_zed; fi

ok "全部完成! 新开终端后生效 (或 source ~/.zshrc)"
