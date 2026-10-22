#!/usr/bin/env bash
# =============================================================================
# 组件模块: vscode
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_vscode_install() {
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
