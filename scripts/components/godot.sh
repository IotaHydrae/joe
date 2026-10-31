#!/usr/bin/env bash
# =============================================================================
# 组件模块: godot — 官方最新稳定版, 重跑检查并升级, 不依赖发行版仓库版本。
# =============================================================================

godot_present() {
    command -v godot >/dev/null 2>&1 || [ -x "$HOME/.local/bin/godot" ]
}

# 使用 latest 的官方重定向, 避免写死版本或受 GitHub API 未认证额度限制。
godot_latest_version() {
    local release_url="" version=""
    release_url=$(curl -fsSLI --connect-timeout 15 --max-time 30 -o /dev/null \
        -w '%{url_effective}' https://github.com/godotengine/godot-builds/releases/latest) || return 1
    case "$release_url" in
        https://github.com/godotengine/godot-builds/releases/tag/*)
            version="${release_url##*/}" ;;
        *) return 1 ;;
    esac
    [[ $version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?-stable$ ]] || return 1
    printf '%s\n' "$version"
}

# 独立子 shell 清理下载、解压和原子替换暂存文件, 失败时保留已安装版本。
_install_godot_binary() (
    local version="$1" arch arch_id filename base_url
    local tmp_zip="" sums="" tmp_dir="" staged_bin="" expected="" actual="" candidate_version=""
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) arch_id="x86_64" ;;
        aarch64|arm64) arch_id="arm64" ;;
        *) die "Godot 暂不支持该架构: $arch" ;;
    esac
    if ! command -v unzip >/dev/null 2>&1; then
        install_sys_pkg unzip || die "Godot 需要 unzip, 安装依赖失败"
    fi
    filename="Godot_v${version}_linux.${arch_id}"
    base_url="https://github.com/godotengine/godot-builds/releases/download/$version"
    trap 'rm -f -- "$tmp_zip" "$sums" "$staged_bin"; [ -z "$tmp_dir" ] || rm -rf -- "$tmp_dir"' EXIT
    make_tmp tmp_zip .zip
    make_tmp sums
    info "从官方 Release 下载 Godot $version..."
    github_mirror_download "$base_url/$filename.zip" "$tmp_zip" \
        || die "Godot 下载失败, 请检查网络或 PROXY_URL 设置"
    github_mirror_download "$base_url/SHA512-SUMS.txt" "$sums" \
        || die "无法获取 Godot SHA-512 校验文件, 已拒绝安装"
    expected=$(awk -v file="$filename.zip" '$2 == file || $2 == "*" file { print $1 }' "$sums")
    [[ $expected =~ ^[[:xdigit:]]{128}$ ]] || die "校验文件缺少 Godot 安装包的 SHA-512, 已拒绝安装"
    actual=$(sha512sum -- "$tmp_zip" | awk '{print $1}')
    [ "$actual" = "${expected,,}" ] || die "Godot SHA-512 校验失败, 已拒绝安装"
    info "Godot SHA-512 校验通过"

    tmp_dir=$(mktemp -d)
    unzip -q "$tmp_zip" "$filename" -d "$tmp_dir" || die "解压 Godot 失败"
    [ -f "$tmp_dir/$filename" ] || die "解压包中未找到 Godot 可执行程序"
    mkdir -p "$HOME/.local/bin"
    staged_bin=$(mktemp "$HOME/.local/bin/.godot.XXXXXX")
    install -m755 -- "$tmp_dir/$filename" "$staged_bin"
    candidate_version=$("$staged_bin" --headless --version) || die "Godot 新版本无法运行, 已保留原安装"
    case "$candidate_version" in
        "${version%-stable}.stable"|"${version%-stable}.stable."*) ;;
        *) die "Godot 可执行程序版本不符, 已保留原安装" ;;
    esac
    mv -fT -- "$staged_bin" "$HOME/.local/bin/godot"

    local rc_file
    rc_file=$(pick_shell_rc)
    if ! grep -q '\.local/bin' "$rc_file" 2>/dev/null; then
        printf '%s\n' 'export PATH=$HOME/.local/bin:$PATH' >> "$rc_file"
        info "$rc_file 已追加 ~/.local/bin 到 PATH"
    fi
)

component_godot_install() {
    info "=== 安装/更新 Godot 游戏引擎 ==="
    local version="" installed=""
    export PATH="$HOME/.local/bin:$PATH"
    if ! version=$(godot_latest_version); then
        die "无法确定 Godot 官方最新稳定版, 请检查网络或 PROXY_URL 后重试"
    fi
    if godot_present; then
        installed=$(godot --headless --version 2>/dev/null) || installed=""
        case "$installed" in
            "${version%-stable}.stable"|"${version%-stable}.stable."*)
                info "Godot 已是最新稳定版 ($installed)"
                return 0 ;;
        esac
        info "将 Godot ${installed:-未知版本} 更新到 $version"
    fi
    _install_godot_binary "$version"
    godot_present || die "Godot 安装失败, 未找到 godot 命令"
    installed=$(godot --headless --version) || die "Godot 安装后无法运行"
    ok "Godot 游戏引擎安装完成: $installed"
}
