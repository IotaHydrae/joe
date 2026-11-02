#!/usr/bin/env bash
# =============================================================================
# 组件模块: obsidian
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_obsidian_install() {
    info "=== 安装 Obsidian (个人知识库) ==="

    export PATH="$HOME/.local/bin:$PATH"
    local stamp="$HOME/.local/share/joe/obsidian.version"
    local installed_tag=""
    [ -f "$stamp" ] && installed_tag="$(cat "$stamp")"

    local tag
    tag="$(obsidian_latest_tag)" \
        || die "无法确定 Obsidian 版本。可设置 OBSIDIAN_VERSION=vX.Y.Z 后重试, 或从 https://obsidian.md 手动安装"
    local ver="${tag#v}"

    # 已是最新则跳过; deb 安装出 obsidian 命令, AppImage 路径在 ~/.local/bin/obsidian。
    # 重跑本命令且 stamp 落后于最新 tag 时按新版本重装 (升级)。
    if { command -v obsidian >/dev/null 2>&1 || [ -x "$HOME/.local/bin/obsidian" ]; } \
        && [ "$installed_tag" = "$tag" ]; then
        info "Obsidian 已是 $tag"
        return 0
    fi

    local arch arch_suffix=""
    arch=$(uname -m)
    case "$arch" in
        x86_64)        ;;
        aarch64|arm64) arch_suffix="-arm64" ;;
        *) die "不支持的架构: $arch" ;;
    esac

    local tmp_pkg gh_url
    case "$PM" in
        apt)
            gh_url="https://github.com/obsidianmd/obsidian-releases/releases/download/${tag}/obsidian_${ver}_amd64.deb"
            info "下载 Obsidian deb (约 100MB)..."
            make_tmp tmp_pkg .deb
            github_mirror_download "$gh_url" "$tmp_pkg" \
                || die "Obsidian 下载失败, 请手动从 https://obsidian.md 安装"
            sudo apt-get update -qq
            sudo apt-get install -y "$tmp_pkg"
            rm -f -- "$tmp_pkg"
            ;;
        pacman|dnf|zypper|*)
            # AppImage 运行需要 FUSE (Arch: fuse2 / Ubuntu: libfuse2t64)
            install_sys_pkg fuse2 >/dev/null 2>&1 || true
            gh_url="https://github.com/obsidianmd/obsidian-releases/releases/download/${tag}/Obsidian-${ver}${arch_suffix}.AppImage"
            info "下载 Obsidian AppImage (约 100MB)..."
            make_tmp tmp_pkg .AppImage
            github_mirror_download "$gh_url" "$tmp_pkg" \
                || die "Obsidian 下载失败, 请手动从 https://obsidian.md 安装"
            mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
            install -m755 "$tmp_pkg" "$HOME/.local/bin/obsidian"
            rm -f -- "$tmp_pkg"

            # deb 包自带桌面入口; AppImage 路径补一个用户级菜单项
            local desktop="$HOME/.local/share/applications/obsidian.desktop"
            if [ ! -f "$desktop" ]; then
                cat > "$desktop" <<EOF
[Desktop Entry]
Name=Obsidian
Comment=个人知识库与 Markdown 笔记
Exec=$HOME/.local/bin/obsidian %u
Icon=obsidian
Type=Application
MimeType=x-scheme-handler/obsidian;
Categories=Office;
StartupWMClass=obsidian
EOF
                command -v update-desktop-database >/dev/null 2>&1 \
                    && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
            fi
            ;;
    esac

    if command -v obsidian >/dev/null 2>&1 || [ -x "$HOME/.local/bin/obsidian" ]; then
        mkdir -p "$(dirname "$stamp")"
        printf '%s\n' "$tag" > "$stamp"
        ok "Obsidian 安装完成 ($tag)"
    else
        die "Obsidian 安装失败"
    fi
}
