#!/usr/bin/env bash
# =============================================================================
# 组件模块: brave
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_brave_install() {
    info "=== 安装 Brave 浏览器 ==="

    if command -v brave-browser >/dev/null 2>&1; then
        info "Brave 已安装: $(brave-browser --version 2>/dev/null | head -1)"
    else
        case "$PM" in
            apt)
                # 添加 Brave GPG 密钥和 APT 源
                sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
                    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
                echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
                    | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
                sudo apt-get update -qq
                sudo apt-get install -y brave-browser
                ;;
            dnf)
                sudo dnf install -y dnf-plugins-core
                sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
                sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
                sudo dnf install -y brave-browser
                ;;
            pacman)
                # Brave 在 AUR，需要用 AUR helper
                if command -v yay >/dev/null 2>&1; then
                    yay -S --needed --noconfirm brave-bin
                elif command -v paru >/dev/null 2>&1; then
                    paru -S --needed --noconfirm brave-bin
                else
                    warn "Brave 在 AUR 中，请手动安装 AUR helper (yay/paru) 后再试"
                    warn "或手动安装: https://aur.archlinux.org/packages/brave-bin"
                    return 1
                fi
                ;;
            zypper)
                sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
                sudo zypper addrepo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
                sudo zypper refresh
                sudo zypper install -y brave-browser
                ;;
            *)
                warn "Brave 安装方式未知, 请手动安装"
                warn "访问: https://brave.com/linux/"
                return 1
                ;;
        esac
    fi

    ok "Brave 浏览器配置完成"
}
