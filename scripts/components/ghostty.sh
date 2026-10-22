#!/usr/bin/env bash
# =============================================================================
# 组件模块: ghostty
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_ghostty_install() {
    info "=== 安装 Ghostty 终端 ==="

    if ! ghostty_binary >/dev/null 2>&1; then
        case "$PM" in
            dnf)
                { sudo dnf copr enable -y scottames/ghostty && sudo dnf install -y ghostty; } \
                    || die "Ghostty dnf 安装失败"
                ;;
            apt)
                _ghostty_apt || die "Ghostty apt 安装失败"
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
    _ghostty_xdg_terminal_exec >/dev/null 2>&1 || true
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

_ghostty_apt() {
    # 1) 官方仓库 (Ubuntu 26.04+ / 部分衍生版)
    if pkg_available ghostty; then
        install_sys_pkg ghostty && command -v ghostty >/dev/null 2>&1 && return 0
    fi

    # 2) 社区 .deb: 先下载脚本并校验, 再执行 —— 不做 curl | bash
    info "官方仓库无 ghostty ($(distro_pretty)), 改用社区 .deb..."
    local tpl
    make_tmp tpl .sh
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

_ghostty_xdg_terminal_exec() {
    command -v xdg-terminal-exec >/dev/null 2>&1 && return 0

    if install_sys_pkg xdg-terminal-exec >/dev/null 2>&1 \
       && command -v xdg-terminal-exec >/dev/null 2>&1; then
        return 0
    fi

    info "包不可用, 从上游安装 xdg-terminal-exec 到 ~/.local/bin..."
    local tpl
    make_tmp tpl .sh
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
