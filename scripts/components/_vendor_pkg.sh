#!/usr/bin/env bash
# =============================================================================
# 官方安装包下载 (微信 / QQ 组件 source, 不单独作为组件)
# =============================================================================
# 临时文件走安装器的 make_tmp。响应里若有十六进制 MD5 就必须通过;
# require_md5=yes 时缺少 MD5 直接拒绝。没有 MD5 时仍核对包魔数、体积
# 和 Content-Length, 避免把错误页交给包管理器。

# 取响应头里最后一个十六进制 MD5 (跟随重定向时前面的头不算)
read_pkg_md5() {
    local headers="$1" value=""
    value=$(awk '
        BEGIN { IGNORECASE = 1; found = "" }
        {
            key = $1
            val = $2
            gsub(/\r/, "", key)
            gsub(/\r/, "", val)
            if ((key == "X-COS-META-MD5:" || key == "Content-MD5:") && val ~ /^[0-9a-fA-F]{32}$/)
                found = tolower(val)
        }
        END { if (found != "") print found }
    ' "$headers") || return 1
    [ -n "$value" ] || return 1
    printf '%s\n' "$value"
}

pkg_magic_ok() {
    local file="$1" kind="$2" magic
    magic=$(od -An -tx1 -N 4 -- "$file" | tr -d ' \n')
    case "$kind" in
        deb) [ "$magic" = "213c6172" ] ;;   # !<ar
        rpm) [ "$magic" = "edabeedb" ] ;;
        *) return 1 ;;
    esac
}

pkg_content_length() {
    local headers="$1" value=""
    value=$(awk '
        BEGIN { IGNORECASE = 1; found = "" }
        {
            key = $1
            val = $2
            gsub(/\r/, "", key)
            gsub(/\r/, "", val)
            if (key == "Content-Length:" && val ~ /^[0-9]+$/)
                found = val
        }
        END { if (found != "") print found }
    ' "$headers") || return 1
    [ -n "$value" ] || return 1
    printf '%s\n' "$value"
}

# 官方桌面包远大于 1MB。这个下限用来拒绝错误页, 不是某个版本的体积。
pkg_payload_ok() {
    local file="$1" kind="$2" headers="$3"
    local actual="" expect=""
    pkg_magic_ok "$file" "$kind" || return 1
    actual=$(wc -c < "$file" | tr -d ' ')
    [[ $actual =~ ^[0-9]+$ ]] || return 1
    [ "$actual" -ge 1048576 ] || return 1
    if expect=$(pkg_content_length "$headers"); then
        [ "$actual" = "$expect" ] || return 1
    fi
    return 0
}

# install_vendor_package <url> <deb|rpm> <yes|no> [referer]
install_vendor_package() {
    local url="$1" kind="$2" require_md5="$3" referer="${4:-}"
    local pkg headers md5="" got=""
    local -a curl_args

    make_tmp pkg ".$kind"
    make_tmp headers
    curl_args=(-fL --connect-timeout 15 --retry 2 --retry-delay 2 -A "Mozilla/5.0")
    if [ -n "$referer" ]; then
        curl_args+=(-e "$referer")
    fi
    if ! curl "${curl_args[@]}" -D "$headers" -o "$pkg" "$url"; then
        die "下载失败: $url"
    fi
    if ! pkg_payload_ok "$pkg" "$kind" "$headers"; then
        die "下载内容不是完整的 $kind 安装包, 已拒绝安装"
    fi
    if md5=$(read_pkg_md5 "$headers"); then
        got=$(md5sum -- "$pkg" | awk '{print $1}')
        if [ "$got" != "$md5" ]; then
            die "MD5 校验失败, 已拒绝安装"
        fi
        info "MD5 校验通过"
    elif [ "$require_md5" = "yes" ]; then
        die "未能获取 MD5, 已拒绝安装"
    else
        info "响应未附带 MD5, 已核对安装包格式与大小"
    fi

    case "$PM" in
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y "$pkg"
            ;;
        dnf)
            sudo dnf install -y "$pkg"
            ;;
        zypper)
            sudo zypper install -y "$pkg"
            ;;
        *)
            die "不支持的包管理器: $PM"
            ;;
    esac
    rm -f -- "$pkg"
}
