#!/usr/bin/env bash
# =============================================================================
# 组件模块: ccswitch
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_ccswitch_install() {
    info "=== 安装 CC Switch (AI CLI 配置切换器) ==="

    export PATH="$HOME/.local/bin:$PATH"
    local stamp="$HOME/.local/share/joe/cc-switch.version"
    local installed_tag=""
    [ -f "$stamp" ] && installed_tag="$(cat "$stamp")"

    # 普通安装保持幂等。update-all 设置 CCSWITCH_FORCE=1 时才按最新 release 升级。
    if command -v cc-switch >/dev/null 2>&1 && [ "${CCSWITCH_FORCE:-}" != 1 ]; then
        info "CC Switch 已安装${installed_tag:+ ($installed_tag)}"
        return 0
    fi

    local tag
    tag="$(ccswitch_latest_tag)" || die "无法确定 CC Switch 版本。可设置 CCSWITCH_VERSION=vX.Y.Z 后重试, 或从 https://github.com/farion1231/cc-switch/releases 手动安装"
    if command -v cc-switch >/dev/null 2>&1 && [ "$installed_tag" = "$tag" ]; then
        info "CC Switch 已是 $tag"
        return 0
    fi

    local arch arch_id
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch_id="x86_64" ;;
        aarch64|arm64) arch_id="arm64" ;;
        *) die "不支持的架构: $arch" ;;
    esac

    local pkg_suffix=".AppImage"
    local tmp_pkg gh_url

    case "$PM" in
        dnf|zypper) pkg_suffix=".rpm" ;;
        apt)        pkg_suffix=".deb" ;;
    esac
    gh_url="https://github.com/farion1231/cc-switch/releases/download/${tag}/CC-Switch-${tag}-Linux-${arch_id}${pkg_suffix}"
    make_tmp tmp_pkg "$pkg_suffix"
    github_mirror_download "$gh_url" "$tmp_pkg" \
        || die "CC Switch 下载失败, 请手动从 https://github.com/farion1231/cc-switch/releases 安装"

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
    export PATH="$HOME/.local/bin:$PATH"

    if command -v cc-switch >/dev/null 2>&1 || [ -x "$HOME/.local/bin/cc-switch" ]; then
        mkdir -p "$(dirname "$stamp")"
        printf '%s\n' "$tag" > "$stamp"
        ok "CC Switch 安装完成 ($tag)"
    else
        die "CC Switch 安装失败"
    fi
}
