#!/usr/bin/env bash
# =============================================================================
# 组件模块: python
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_python_install() {
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
