#!/usr/bin/env bash
# =============================================================================
# 官方安装包下载 (微信 / QQ 组件 source, 不单独作为组件)
# =============================================================================
# 安装包缓存在用户私有目录, 失败保留供续传, 安装成功后删除; 响应头走 make_tmp。
# 响应里若有十六进制 MD5 就必须通过;
# require_md5=yes 时缺少 MD5 直接拒绝。没有 MD5 时仍核对包魔数、体积
# 和 Content-Length, 避免把错误页交给包管理器。

# 取响应头里最后一个十六进制 MD5 (跟随重定向时前面的头不算)
read_pkg_md5() {
    local headers="$1" value=""
    value=$(awk '
        BEGIN { found = "" }
        /^HTTP\// { found = "" }
        {
            key = tolower($1)
            val = $2
            gsub(/\r/, "", key)
            gsub(/\r/, "", val)
            if ((key == "x-cos-meta-md5:" || key == "content-md5:") && val ~ /^[0-9a-fA-F]{32}$/)
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

# 206 的 Content-Length 只代表剩余字节, 完整包大小以 Content-Range 为准。
pkg_content_length() {
    local headers="$1" value=""
    value=$(awk '
        /^HTTP\// { length_value = ""; total = "" }
        {
            key = tolower($1)
            val = $2
            gsub(/\r/, "", val)
            if (key == "content-length:" && val ~ /^[0-9]+$/)
                length_value = val
            if (key == "content-range:") {
                val = $3
                gsub(/\r/, "", val)
                sub(/^.*\//, "", val)
                if (val ~ /^[0-9]+$/) total = val
            }
        }
        END {
            if (total != "") print total
            else if (length_value != "") print length_value
        }
    ' "$headers") || return 1
    [ -n "$value" ] || return 1
    printf '%s\n' "$value"
}

# 只使用强 ETag。弱 ETag 不能保证断点前后的字节相同。
pkg_etag() {
    awk '
        /^HTTP\// { found = "" }
        tolower($1) == "etag:" { found=$2; gsub(/\r/, "", found) }
        END { if (found ~ /^".*"$/) print found }
    ' "$1"
}

pkg_identity() {
    local md5="" etag=""
    if md5=$(read_pkg_md5 "$1"); then
        printf 'md5:%s\n' "$md5"
    else
        etag=$(pkg_etag "$1") || return 1
        [ -n "$etag" ] || return 1
        printf 'etag:%s\n' "$etag"
    fi
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

# 三次独立 curl 请求, 每次从当前文件长度续传; curl 内置重试会回退到首次偏移。
# 403 等 HTTP 错误不重试, 下次运行由 QQ 组件获取新签名。
download_vendor_package() {
    local url="$1" pkg="$2" headers="$3" etag="$4" referer="$5"
    local attempt rc=0
    local -a curl_args=(-fL --connect-timeout 15 -A "Mozilla/5.0")
    [ -z "$referer" ] || curl_args+=(-e "$referer")
    [ -z "$etag" ] || curl_args+=(-H "If-Range: $etag")
    for ((attempt=0; attempt<3; attempt++)); do
        rc=0
        curl "${curl_args[@]}" -C - -D "$headers" -o "$pkg" "$url" || rc=$?
        [ "$rc" -ne 0 ] || return 0
        case "$rc" in
            33)
                warn "服务器无法续传该安装包, 将从头下载"
                rm -f -- "$pkg"
                ;;
            6|7|18|28|35|52|55|56|92) ;;
            *) break ;;
        esac
        if [ "$attempt" -lt 2 ]; then
            info "下载中断 (curl $rc), 正在从已下载位置重试..."
            sleep 2
        fi
    done
    die "下载失败 (curl $rc), 已保留缓存: $pkg; 重跑原安装命令可续传"
}

# install_vendor_package <url> <deb|rpm> <yes|no> [referer]
# 子 shell 限定文件锁与响应头生命周期; 部分包和元数据不进入临时文件清理列表。
install_vendor_package() (
    local url="$1" kind="$2" require_md5="$3" referer="${4:-}"
    local cache_dir key pkg metadata headers="" remote_headers="" cache_lock path
    local md5="" got="" identity="" previous="" expect="" etag=""
    local -a curl_args=(-fsSLI --connect-timeout 15 --retry 2 --retry-delay 2 -A "Mozilla/5.0")

    umask 077
    command -v flock >/dev/null 2>&1 || die "缺少 flock, 请安装 util-linux 后重试"
    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/joe/downloads"
    for path in "${cache_dir%/downloads}" "$cache_dir"; do
        [ ! -L "$path" ] || die "缓存目录不能是符号链接: $path"
        mkdir -p -- "$path"
        [ -O "$path" ] || die "缓存目录不属于当前用户: $path"
        chmod 700 -- "$path"
    done
    # 签名随请求变化, 不属于文件标识; 版本路径仍参与缓存键。
    key=$(printf '%s' "${url%%\?*}" | sha256sum | awk '{print $1}')
    pkg="$cache_dir/$key.$kind"
    metadata="$pkg.headers"
    for path in "$pkg" "$metadata" "$pkg.lock"; do
        [ ! -L "$path" ] && { [ ! -e "$path" ] || { [ -f "$path" ] && [ -O "$path" ]; }; } \
            || die "缓存路径不是当前用户的普通文件: $path"
    done
    exec {cache_lock}> "$pkg.lock"
    flock -n "$cache_lock" || die "另一个安装进程正在使用缓存: $pkg"
    make_tmp remote_headers
    make_tmp headers
    trap 'rm -f -- "$headers" "$remote_headers"' EXIT
    [ -z "$referer" ] || curl_args+=(-e "$referer")
    if ! curl "${curl_args[@]}" -o "$remote_headers" "$url"; then
        die "无法查询安装包信息, 已保留缓存: $pkg; 请重试"
    fi
    if ! expect=$(pkg_content_length "$remote_headers") || [ "$expect" -lt 1048576 ]; then
        die "无法获取安装包完整大小, 已保留缓存: $pkg"
    fi
    identity=$(pkg_identity "$remote_headers") || identity=""
    if [ -s "$pkg" ]; then
        previous=$(pkg_identity "$metadata" 2>/dev/null) || previous=""
        if [ -z "$identity" ] || [ "$identity" != "$previous" ] \
                || [ "$(wc -c < "$pkg")" -gt "$expect" ]; then
            info "安装包标识变化或无法确认, 清理旧缓存后重新下载"
            rm -f -- "$pkg"
        else
            info "发现下载缓存: $pkg ($(wc -c < "$pkg") 字节)"
        fi
    fi
    cp -- "$remote_headers" "$metadata"
    etag=$(pkg_etag "$remote_headers")
    if [ ! -f "$pkg" ] || [ "$(wc -c < "$pkg")" -ne "$expect" ]; then
        download_vendor_package "$url" "$pkg" "$headers" "$etag" "$referer"
    fi
    if ! pkg_payload_ok "$pkg" "$kind" "$remote_headers" \
            || { [ -s "$headers" ] && ! pkg_payload_ok "$pkg" "$kind" "$headers"; }; then
        rm -f -- "$pkg" "$metadata"
        die "下载内容不是完整的 $kind 安装包, 已清理缓存并拒绝安装"
    fi
    if md5=$(read_pkg_md5 "$headers") || md5=$(read_pkg_md5 "$remote_headers"); then
        got=$(md5sum -- "$pkg" | awk '{print $1}')
        if [ "$got" != "$md5" ]; then
            rm -f -- "$pkg" "$metadata"
            die "MD5 校验失败, 已清理缓存并拒绝安装"
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
    rm -f -- "$pkg" "$metadata"
)
