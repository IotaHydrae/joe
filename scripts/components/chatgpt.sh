#!/usr/bin/env bash
# =============================================================================
# 组件模块: chatgpt
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_chatgpt_install() {
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
            die "不支持的包管理器 ($PM), 请手动安装 ChatGPT 桌面版"
            ;;
    esac

    command -v chatgpt >/dev/null 2>&1 || die "ChatGPT 安装失败, 请检查网络或包管理器输出"
    ok "ChatGPT 桌面版安装完成: $(chatgpt --version 2>/dev/null | head -1)"
}
