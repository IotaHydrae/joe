#!/usr/bin/env bash
# =============================================================================
# 组件模块: blender — 官方最新稳定版, 重跑检查并升级, 不依赖发行版仓库版本。
# =============================================================================

blender_present() {
    command -v blender >/dev/null 2>&1 || [ -x "$HOME/.local/bin/blender" ]
}

# 官方直连优先; 不可达时依次尝试国内镜像 (安装包与校验文件取自同一镜像)。
BLENDER_RELEASE_BASES=(
    "https://download.blender.org/release"
    "https://mirrors.tuna.tsinghua.edu.cn/blender/release"
    "https://mirror.nju.edu.cn/blender/release"
    "https://mirrors.aliyun.com/blender/release"
)

blender_arch_id() {
    case "$(uname -m)" in
        x86_64|amd64)  printf 'x64\n' ;;
        aarch64|arm64) printf 'arm64\n' ;;
        *) return 1 ;;
    esac
}

# 解析最新稳定版: 只认同时提供 Linux 包与 .sha256 的 X.Y.Z;
# 某个大版本目录只有 alpha/beta 时回退到上一个目录。
# 输出: <镜像基址> <版本目录> <版本>
blender_resolve_release() {
    local arch base index dir listing file version prefix
    local -a dirs
    arch=$(blender_arch_id) || return 1
    for base in "${BLENDER_RELEASE_BASES[@]}"; do
        index=$(curl -fsSL --connect-timeout 10 --max-time 30 "$base/" 2>/dev/null) || continue
        mapfile -t dirs < <(grep -oE 'Blender[0-9]+\.[0-9]+/' <<<"$index" | tr -d '/' | sort -V -u | tac)
        [ "${#dirs[@]}" -gt 0 ] || continue
        for dir in "${dirs[@]:0:3}"; do
            listing=$(curl -fsSL --connect-timeout 10 --max-time 30 "$base/$dir/" 2>/dev/null) || continue
            prefix="${dir#Blender}"
            prefix="${prefix//./\\.}"
            file=$(grep -oE "blender-${prefix}\.[0-9]+-linux-${arch}\.tar\.xz" <<<"$listing" \
                | sort -V -u | tail -n 1)
            [ -n "$file" ] || continue
            version="${file#blender-}"
            version="${version%-linux-*}"
            grep -qE "blender-${version}\.sha256" <<<"$listing" || continue
            printf '%s %s %s\n' "$base" "$dir" "$version"
            return 0
        done
    done
    return 1
}

# 桌面菜单项: Exec 指向稳定路径 ~/.local/bin/blender, 图标复制到 hicolor 目录。
_blender_write_desktop_entry() {
    local app_dir="$1" apps icons
    apps="$HOME/.local/share/applications"
    icons="$HOME/.local/share/icons/hicolor/scalable/apps"
    mkdir -p "$apps" "$icons"
    if [ -f "$app_dir/blender.svg" ]; then
        cp -f -- "$app_dir/blender.svg" "$icons/blender.svg"
    fi
    if [ -f "$app_dir/blender.desktop" ]; then
        sed -e "s|^Exec=blender |Exec=$HOME/.local/bin/blender |" \
            -e "s|^TryExec=blender$|TryExec=$HOME/.local/bin/blender|" \
            -e "s|^Icon=blender$|Icon=$icons/blender.svg|" \
            "$app_dir/blender.desktop" > "$apps/.blender.desktop.tmp"
        mv -f -- "$apps/.blender.desktop.tmp" "$apps/blender.desktop"
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$apps" >/dev/null 2>&1 || true
    fi
}

# 独立子 shell 清理下载与解压暂存; 任何失败都不覆盖现有安装。
_install_blender_binary() (
    local base="$1" dir="$2" version="$3" arch filename archive sumfile
    local expected actual tmp_dir="" staged_dir="" candidate_version="" rc_file=""
    arch=$(blender_arch_id) || die "Blender 暂不支持该架构: $(uname -m)"
    if ! command -v xz >/dev/null 2>&1; then
        install_sys_pkg xz || die "Blender 需要 xz, 安装依赖失败"
    fi
    filename="blender-${version}-linux-${arch}"
    trap 'rm -f -- "$archive" "$sumfile"; [ -z "$tmp_dir" ] || rm -rf -- "$tmp_dir"' EXIT
    make_tmp archive .tar.xz
    make_tmp sumfile
    info "从 ${base#https://} 下载 Blender $version..."
    curl -fsSL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 600 \
        -o "$archive" "$base/$dir/$filename.tar.xz" \
        || die "Blender 下载失败, 请检查网络或 PROXY_URL 设置"
    curl -fsSL --retry 3 --connect-timeout 20 --max-time 60 \
        -o "$sumfile" "$base/$dir/blender-$version.sha256" \
        || die "无法获取 Blender SHA-256 校验文件, 已拒绝安装"
    expected=$(awk -v file="$filename.tar.xz" '$2 == file || $2 == "*" file { print $1 }' "$sumfile")
    [[ $expected =~ ^[[:xdigit:]]{64}$ ]] || die "校验文件缺少 Blender 安装包的 SHA-256, 已拒绝安装"
    actual=$(sha256sum -- "$archive" | awk '{print $1}')
    [ "$actual" = "${expected,,}" ] || die "Blender SHA-256 校验失败, 已拒绝安装"
    info "Blender SHA-256 校验通过"

    tmp_dir=$(mktemp -d)
    tar -xJf "$archive" -C "$tmp_dir" || die "解压 Blender 失败"
    staged_dir="$tmp_dir/$filename"
    [ -x "$staged_dir/blender" ] || die "解压包中未找到 Blender 可执行程序"
    candidate_version=$("$staged_dir/blender" --version 2>/dev/null | head -n 1) \
        || die "Blender 新版本无法运行, 已保留原安装"
    case "$candidate_version" in
        "Blender $version"*) ;;
        *) die "Blender 可执行程序版本不符, 已保留原安装" ;;
    esac

    mkdir -p "$HOME/.local/bin"
    rm -rf -- "$HOME/.local/blender-$version"
    mv -- "$staged_dir" "$HOME/.local/blender-$version"
    ln -sfn "$HOME/.local/blender-$version/blender" "$HOME/.local/bin/blender"
    _blender_write_desktop_entry "$HOME/.local/blender-$version"

    rc_file=$(pick_shell_rc)
    if ! grep -qF 'export PATH=$HOME/.local/bin:$PATH' "$rc_file" 2>/dev/null; then
        printf '%s\n' 'export PATH=$HOME/.local/bin:$PATH' >> "$rc_file"
        info "$rc_file 已追加 ~/.local/bin 到 PATH"
    fi
)

component_blender_install() {
    info "=== 安装/更新 Blender ==="
    local release base dir version installed=""
    export PATH="$HOME/.local/bin:$PATH"
    if ! release=$(blender_resolve_release); then
        die "无法确定 Blender 官方最新稳定版, 请检查网络或 PROXY_URL 后重试"
    fi
    read -r base dir version <<< "$release"
    if blender_present; then
        installed=$(blender --version 2>/dev/null | head -n 1) || installed=""
        case "$installed" in
            "Blender $version"*)
                info "Blender 已是最新稳定版 ($installed)"
                return 0 ;;
        esac
        info "将 Blender ${installed:-未知版本} 更新到 $version"
    fi
    _install_blender_binary "$base" "$dir" "$version"
    blender_present || die "Blender 安装失败, 未找到 blender 命令"
    installed=$(blender --version 2>/dev/null | head -n 1) || die "Blender 安装后无法运行"
    ok "Blender 安装完成: $installed"
}
