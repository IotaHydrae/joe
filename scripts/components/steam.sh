#!/usr/bin/env bash
# =============================================================================
# 组件模块: steam
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

# 系统包把启动器放在 /usr/games/steam (通常不在默认 PATH), 一并探测。
_steam_present() {
    command -v steam >/dev/null 2>&1 || [ -x /usr/games/steam ]
}

component_steam_install() {
    info "=== 安装 Steam 游戏平台 ==="

    if _steam_present; then
        local ver=""
        if command -v dpkg-query >/dev/null 2>&1; then
            ver="$(dpkg-query -W -f='${Version}' steam 2>/dev/null || true)"
        fi
        info "Steam 已安装${ver:+ (版本 $ver)}"
        return 0
    fi

    case "$PM" in
        apt)
            # Ubuntu/Mint: multiverse 的 steam 包, 依赖 i386 架构
            sudo dpkg --add-architecture i386 2>/dev/null || true
            sudo apt-get update -qq
            sudo apt-get install -y steam
            ;;
        pacman)
            # Arch: multilib 仓库的 steam 包 (需已启用 multilib)
            if ! sudo pacman -S --needed --noconfirm steam; then
                warn "pacman 安装 Steam 失败, 请确认已启用 multilib 仓库"
                return 1
            fi
            ;;
        dnf|zypper)
            # 该发行版官方仓库没有 Steam; 优先用 Flatpak 安装官方包
            if command -v flatpak >/dev/null 2>&1; then
                info "通过 Flatpak 安装 Steam..."
                flatpak remote-add --if-not-exists --user flathub \
                    https://flathub.org/repo/flathub.flatpakrepo || true
                flatpak install -y --user flathub com.valvesoftware.Steam
            else
                warn "该发行版没有官方 Steam 包, 也未安装 flatpak"
                warn "请手动安装: https://store.steampowered.com/about/"
                return 1
            fi
            ;;
        *)
            warn "未知包管理器 ($PM), 请手动安装 Steam"
            warn "访问: https://store.steampowered.com/about/"
            return 1
            ;;
    esac

    # 原生包会在 PATH 或 /usr/games 下生成 steam; Flatpak 安装不生成该系统二进制,
    # 由 flatpak install 的退出码负责失败(VALVE 包已写入 ~/.local/share/flatpak)。
    case "$PM" in
        apt|pacman)
            _steam_present || die "Steam 安装失败, 请检查网络或包管理器输出"
            ;;
    esac
    ok "Steam 安装完成 (首次启动会下载客户端并更新, 需要联网)"
}
