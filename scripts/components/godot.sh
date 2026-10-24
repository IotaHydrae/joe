#!/usr/bin/env bash
# =============================================================================
# 组件模块: godot
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, pick_shell_rc,
# 以及 scripts/lib_*.sh。
# =============================================================================

godot_present() {
    command -v godot >/dev/null 2>&1 || [ -x "$HOME/.local/bin/godot" ]
}

_install_godot_binary() {
    local arch arch_id
    arch=$(uname -m)
    case "$arch" in
        x86_64)        arch_id="x86_64" ;;
        aarch64|arm64) arch_id="arm64" ;;
        *) die "Godot 暂不支持该架构: $arch" ;;
    esac

    local version="4.3-stable"
    local filename="Godot_v${version}_linux.${arch_id}"
    local url="https://github.com/godotengine/godot-builds/releases/download/${version}/${filename}.zip"

    info "从官方 Release 下载 Godot $version..."
    local tmp_zip tmp_dir
    make_tmp tmp_zip ".zip"
    github_mirror_download "$url" "$tmp_zip" \
        || die "Godot 下载失败, 请检查网络或 PROXY_URL 设置"

    mkdir -p "$HOME/.local/bin"
    tmp_dir=$(mktemp -d)
    if ! unzip -q -o "$tmp_zip" -d "$tmp_dir"; then
        rm -rf "$tmp_dir"
        die "解压 Godot 失败"
    fi

    local bin
    bin=$(find "$tmp_dir" -maxdepth 1 -type f -name 'Godot*' | head -n 1)
    if [ -z "$bin" ] || [ ! -f "$bin" ]; then
        rm -rf "$tmp_dir"
        die "解压包中未找到 Godot 可执行程序"
    fi

    mv -f "$bin" "$HOME/.local/bin/godot"
    chmod +x "$HOME/.local/bin/godot"
    rm -rf "$tmp_dir"

    local rc_file
    rc_file=$(pick_shell_rc)
    if ! grep -q '\.local/bin' "$rc_file" 2>/dev/null; then
        printf '%s\n' 'export PATH=$HOME/.local/bin:$PATH' >> "$rc_file"
        info "$rc_file 已追加 ~/.local/bin 到 PATH"
    fi
}

component_godot_install() {
    info "=== 安装 Godot 游戏引擎 ==="

    if godot_present; then
        local ver=""
        ver=$(godot --version 2>/dev/null || "$HOME/.local/bin/godot" --version 2>/dev/null || true)
        info "Godot 已安装${ver:+ ($ver)}"
        return 0
    fi

    case "$PM" in
        dnf)
            info "通过 dnf 安装 Godot..."
            sudo dnf install -y godot
            ;;
        pacman)
            info "通过 pacman 安装 Godot..."
            sudo pacman -S --needed --noconfirm godot
            ;;
        zypper)
            info "通过 zypper 安装 Godot..."
            sudo zypper install -y godot
            ;;
        apt)
            if apt-cache show godot 2>/dev/null | grep -q "Version: [4-9]"; then
                info "通过 apt 安装 Godot..."
                sudo apt-get update -qq
                sudo apt-get install -y godot
            else
                _install_godot_binary
            fi
            ;;
        *)
            _install_godot_binary
            ;;
    esac

    godot_present || die "Godot 安装失败, 未找到 godot 命令"
    ok "Godot 游戏引擎安装完成: $(godot --version 2>/dev/null || "$HOME/.local/bin/godot" --version 2>/dev/null || true)"
}
