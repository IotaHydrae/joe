#!/usr/bin/env bash
# =============================================================================
# 组件模块: wechat
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 官方 deb/rpm 来自 linux.weixin.qq.com, 安装后命令是 wechat。
# Arch 用 AUR 的 wechat-universal-bwrap (官方包的沙箱封装), 命令是 wechat-universal。
# =============================================================================

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/_vendor_pkg.sh"

# wechat_package_url <arch> <pm>
# 稳定文件名由官网下载按钮给出, 不带版本号。
wechat_package_url() {
    local arch="$1" pm="$2" file_arch="" kind=""
    case "$arch" in
        x86_64|amd64) file_arch="x86_64" ;;
        aarch64|arm64) file_arch="arm64" ;;
        *) return 1 ;;
    esac
    case "$pm" in
        apt) kind="deb" ;;
        dnf|zypper) kind="rpm" ;;
        *) return 1 ;;
    esac
    printf 'https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_%s.%s\n' \
        "$file_arch" "$kind"
}

wechat_present() {
    command -v wechat >/dev/null 2>&1 || command -v wechat-universal >/dev/null 2>&1
}

component_wechat_install() {
    info "=== 安装微信 Linux 原生版 ==="

    if wechat_present; then
        info "微信已安装"
        return 0
    fi

    local arch="" url="" kind=""
    arch=$(uname -m)
    case "$PM" in
        apt|dnf|zypper)
            if ! url=$(wechat_package_url "$arch" "$PM"); then
                die "微信暂不支持该架构或包管理器: $arch / $PM"
            fi
            kind="${url##*.}"
            info "正在下载微信安装包..."
            # 官方 CDN 在响应头里带 X-COS-META-MD5, 没有校验值就拒绝安装
            install_vendor_package "$url" "$kind" yes "https://linux.weixin.qq.com/"
            wechat_present || die "微信安装失败, 未找到 wechat 命令"
            ;;
        pacman)
            info "通过 AUR 安装 wechat-universal-bwrap"
            if command -v yay >/dev/null 2>&1; then
                yay -S --needed --noconfirm wechat-universal-bwrap
            elif command -v paru >/dev/null 2>&1; then
                paru -S --needed --noconfirm wechat-universal-bwrap
            else
                die "请先安装 yay 或 paru, 再安装 AUR 包 wechat-universal-bwrap"
            fi
            wechat_present || die "微信安装失败, 未找到 wechat-universal 命令"
            ;;
        *)
            die "不支持的包管理器: $PM"
            ;;
    esac

    ok "微信安装完成"
}
