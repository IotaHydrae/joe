#!/usr/bin/env bash
# =============================================================================
# 组件模块: qq
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 下载地址来自官网使用的 linuxConfig.js, 且只接受 qqdl.gtimg.cn。
# 官方 deb/rpm 安装后命令是 qq。Arch 的 AUR 包 linuxqq 命令是 linuxqq。
# 官方配置不发布独立校验文件; 有 MD5 响应头时必须通过, 否则核对包格式与大小。
# =============================================================================

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/_vendor_pkg.sh"

QQ_CONFIG_URL="https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js"

# qq_arch_key <uname -m>
qq_arch_key() {
    case "$1" in
        x86_64|amd64) printf 'x64DownloadUrl\n' ;;
        aarch64|arm64) printf 'armDownloadUrl\n' ;;
        *) return 1 ;;
    esac
}

# qq_pkg_kind <pm>
qq_pkg_kind() {
    case "$1" in
        apt) printf 'deb\n' ;;
        dnf|zypper) printf 'rpm\n' ;;
        *) return 1 ;;
    esac
}

# qq_pick_url <config text> <x64DownloadUrl|armDownloadUrl> <deb|rpm>
# 配置是一段 JS。只取出对应对象里的直链, 并且主机必须是官方 CDN。
qq_pick_url() {
    local config="$1" arch_key="$2" kind="$3"
    local object="" url=""
    case "$arch_key" in
        x64DownloadUrl|armDownloadUrl) ;;
        *) return 1 ;;
    esac
    case "$kind" in
        deb|rpm) ;;
        *) return 1 ;;
    esac
    object=$(printf '%s\n' "$config" | sed -n "s/.*\"${arch_key}\":{\([^}]*\)}.*/\1/p" | head -n 1)
    [ -n "$object" ] || return 1
    url=$(printf '%s\n' "$object" | sed -n "s/.*\"${kind}\":\"\([^\"]*\)\".*/\1/p" | head -n 1)
    case "$url" in
        https://qqdl.gtimg.cn/*) printf '%s\n' "$url" ;;
        *) return 1 ;;
    esac
}

qq_present() {
    command -v qq >/dev/null 2>&1 || command -v linuxqq >/dev/null 2>&1
}

component_qq_install() {
    info "=== 安装 Linux QQ ==="

    if qq_present; then
        info "QQ 已安装"
        return 0
    fi

    local arch="" key="" kind="" config="" url=""
    arch=$(uname -m)
    case "$PM" in
        apt|dnf|zypper)
            if ! key=$(qq_arch_key "$arch"); then
                die "QQ 暂不支持该架构: $arch"
            fi
            if ! kind=$(qq_pkg_kind "$PM"); then
                die "QQ 暂不支持该包管理器: $PM"
            fi
            make_tmp config .js
            info "正在查询 Linux QQ 下载地址..."
            if ! curl -fsSL --connect-timeout 15 --retry 2 --retry-delay 2 \
                    -A "Mozilla/5.0" -o "$config" "$QQ_CONFIG_URL"; then
                die "无法获取 Linux QQ 下载配置, 请查看 https://im.qq.com/linuxqq/index.shtml"
            fi
            if ! url=$(qq_pick_url "$(cat -- "$config")" "$key" "$kind"); then
                die "下载配置里没有可用的 $kind 地址"
            fi
            rm -f -- "$config"
            info "正在下载 Linux QQ..."
            install_vendor_package "$url" "$kind" no "https://im.qq.com/linuxqq/index.shtml"
            qq_present || die "QQ 安装失败, 未找到 qq 命令"
            ;;
        pacman)
            info "通过 AUR 安装 linuxqq"
            if command -v yay >/dev/null 2>&1; then
                yay -S --needed --noconfirm linuxqq
            elif command -v paru >/dev/null 2>&1; then
                paru -S --needed --noconfirm linuxqq
            else
                die "请先安装 yay 或 paru, 再安装 AUR 包 linuxqq"
            fi
            qq_present || die "QQ 安装失败, 未找到 linuxqq 命令"
            ;;
        *)
            die "不支持的包管理器: $PM"
            ;;
    esac

    ok "QQ 安装完成"
}
