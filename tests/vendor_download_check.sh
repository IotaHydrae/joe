#!/usr/bin/env bash
# 微信/QQ 安装包缓存回归: 临时 HOME、仓库副本、离线 curl/sudo stub。
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOX="$(mktemp -d)"
trap 'rm -rf -- "$BOX"' EXIT
mkdir -p "$BOX/repo" "$BOX/bin" "$BOX/tmp"
cp -a "$ROOT_DIR/scripts" "$BOX/repo/scripts"
export VENDOR_TEST_BOX="$BOX"
export PATH="$BOX/bin:$PATH"
export TMPDIR="$BOX/tmp"
export XDG_CACHE_HOME="$BOX/cache with ' quote"
export HOME="$BOX/home"
mkdir -p "$HOME"
PKG="$BOX/fixture.deb"
dd if=/dev/zero of="$PKG" bs=1048576 count=2 status=none
printf '!<arch>\n' | dd of="$PKG" conv=notrunc status=none
export VENDOR_TEST_MD5
VENDOR_TEST_MD5="$(md5sum "$PKG" | cut -d ' ' -f1)"
URL='https://qqdl.gtimg.cn/qqfile/test/amd64.deb'
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
cat > "$BOX/bin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
output='' headers='' head=false resume=false
url="${!#}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) output="$2"; shift ;;
        -D) headers="$2"; shift ;;
        -I|--head|-fsSLI) head=true ;;
        -C|--continue-at) [[ $2 == - ]] || exit 99; resume=true; shift ;;
    esac
    shift
done
size=$(stat -c %s "$VENDOR_TEST_BOX/fixture.deb")
etag="${VENDOR_TEST_ETAG:-v1}"
if $head; then
    printf 'HEAD|%s\n' "$url" >> "$VENDOR_TEST_BOX/requests"
    printf 'HTTP/1.1 200 OK\r\nContent-Length: %s\r\nETag: "%s"\r\nX-COS-META-MD5: %s\r\n\r\n' \
        "$size" "$etag" "${VENDOR_TEST_CHECKSUM:-$VENDOR_TEST_MD5}" > "$output"
    exit 0
fi
$resume || exit 99
[[ -f "$output" ]] || : > "$output"
offset=$(stat -c %s "$output")
printf 'GET|%s|%s\n' "$offset" "$url" >> "$VENDOR_TEST_BOX/requests"
if [[ ${VENDOR_TEST_MODE:-ok} == no_range && $offset -gt 0 ]]; then
    printf 'HTTP/1.1 200 OK\r\nContent-Length: %s\r\n\r\n' "$size" > "$headers"
    exit 33
fi
if [[ ${VENDOR_TEST_MODE:-ok} == forbidden ]]; then
    printf 'HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n' > "$headers"
    exit 22
fi
printf 'HTTP/1.1 206 Partial Content\r\nContent-Length: %s\r\nContent-Range: bytes %s-%s/%s\r\n\r\n' \
    "$((size - offset))" "$offset" "$((size - 1))" "$size" > "$headers"
if [[ ${VENDOR_TEST_MODE:-ok} == reset ]]; then
    dd if="$VENDOR_TEST_BOX/fixture.deb" bs=1 skip="$offset" count=65536 status=none >> "$output"
    exit 56
fi
tail -c "+$((offset + 1))" "$VENDOR_TEST_BOX/fixture.deb" >> "$output"
STUB
cat > "$BOX/bin/sudo" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$VENDOR_TEST_BOX/installs"
if [[ $* == 'apt-get install -y '* ]]; then
    [[ ${VENDOR_TEST_APT_FAIL:-0} == 0 ]] || exit 17
    cmp -s -- "${!#}" "$VENDOR_TEST_BOX/fixture.deb" || exit 99
fi
STUB
printf '#!/usr/bin/env bash\nexit 0\n' > "$BOX/bin/sleep"
chmod +x "$BOX/bin/"*
cat > "$BOX/run.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
PM=apt
info() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die() { printf '%s\n' "$*" >&2; exit 1; }
TMP_FILES=()
cleanup_tmp() { if [[ ${#TMP_FILES[@]} -gt 0 ]]; then rm -f -- "${TMP_FILES[@]}"; fi; }
trap cleanup_tmp EXIT
make_tmp() {
    local file
    file=$(mktemp)
    TMP_FILES+=("$file")
    printf -v "$1" '%s' "$file"
}
. "$VENDOR_TEST_BOX/repo/scripts/components/_vendor_pkg.sh"
install_vendor_package "$1" deb "${VENDOR_TEST_REQUIRE_MD5:-yes}"
RUNNER
run_download() { bash "$BOX/run.sh" "$URL?$1" > "$BOX/output" 2>&1; }

# 同次运行自动续传; 耗尽重试后保留部分文件; 签名刷新后仍复用同一缓存。
if VENDOR_TEST_MODE=reset run_download 'sign=old&t=1'; then fail '连接重置不应报告成功'; fi
partial=$(find "$XDG_CACHE_HOME" -type f -name '*.deb' -print -quit 2>/dev/null) || partial=""
[[ -n $partial && $(stat -c %s "$partial") -eq 196608 ]] || fail '失败后没有保留三次续传进度'
[[ ! -e "$BOX/installs" ]] || fail '下载中断时调用了包管理器'
grep -q '^GET|65536|' "$BOX/requests" || fail '首次自动重试未从断点续传'
grep -q '^GET|131072|' "$BOX/requests" || fail '第二次自动重试丢失断点'
grep -Fq "$partial" "$BOX/output" || fail '失败提示没有给出保留的缓存路径'
run_download 'sign=new&t=2' || fail "重跑续传失败: $(cat "$BOX/output")"
grep -Fq "GET|196608|$URL?sign=new&t=2" "$BOX/requests" || fail '新签名没有从旧断点续传'
[[ ! -f "$partial" ]] || fail '安装成功后未清理大文件'
printf 'PASS: 自动重试、失败保留和刷新签名后跨进程续传\n'

# QQ 的 CDN 可能只有强 ETag, 不带 MD5; 同样支持跨进程续传。
rm -f -- "$BOX/requests" "$BOX/installs"
if VENDOR_TEST_REQUIRE_MD5=no VENDOR_TEST_CHECKSUM=none VENDOR_TEST_MODE=reset run_download 'sign=old&t=1'; then
    fail '应先制造无 MD5 下载中断'
fi
VENDOR_TEST_REQUIRE_MD5=no VENDOR_TEST_CHECKSUM=none run_download 'sign=new&t=2' \
    || fail '只有 ETag 时续传失败'
grep -Fq "GET|196608|$URL?sign=new&t=2" "$BOX/requests" || fail '强 ETag 未复用同一文件的断点'
printf 'PASS: 无 MD5 的 QQ 安装包使用强 ETag 续传\n'

# 远端资源变化时不能拼接不同版本; 不支持 Range 时只允许从头下载。
for mode in changed no_range; do
    rm -f -- "$BOX/requests" "$BOX/installs"
    VENDOR_TEST_MODE=reset run_download 'sign=old&t=1' && fail '应先制造中断'
    if [[ $mode == changed ]]; then
        VENDOR_TEST_REQUIRE_MD5=no VENDOR_TEST_CHECKSUM=none VENDOR_TEST_ETAG=v2 run_download 'sign=new&t=2' || fail '资源变更后下载失败'
    else
        VENDOR_TEST_MODE=no_range run_download 'sign=new&t=2' || fail '不支持 Range 时不能重新下载'
    fi
    [[ $(grep -c '^GET|0|' "$BOX/requests") -eq 2 ]] || fail "$mode 未从头重建缓存"
    printf 'PASS: %s 安全重新下载\n' "$mode"
done

# 安装失败保留完整包, 重跑只检查远端元数据, 不重新传输安装包。
rm -f -- "$BOX/requests"
if VENDOR_TEST_APT_FAIL=1 run_download 'sign=first&t=1'; then fail '安装失败被吞掉'; fi
gets=$(grep -c '^GET|' "$BOX/requests")
run_download 'sign=second&t=2' || fail '无法复用完整缓存'
[[ $(grep -c '^GET|' "$BOX/requests") -eq $gets ]] || fail '完整安装包被重复下载'
printf 'PASS: 包管理器失败后复用完整包\n'

# 签名无效立即停止; 校验失败移除损坏缓存, 均不调用包管理器。
for mode in forbidden bad_md5; do
    rm -f -- "$BOX/requests" "$BOX/installs"
    if [[ $mode == forbidden ]]; then
        if VENDOR_TEST_MODE=forbidden run_download 'sign=bad&t=1'; then fail '403 被当作成功'; fi
        [[ $(grep -c '^GET|' "$BOX/requests") -eq 1 ]] || fail '403 被无意义重试'
    else
        if VENDOR_TEST_CHECKSUM=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa run_download 'sign=good&t=2'; then fail 'MD5 不匹配被接受'; fi
        [[ -z $(find "$XDG_CACHE_HOME" -name '*.deb' -print -quit) ]] || fail '损坏包未清理'
    fi
    [[ ! -e "$BOX/installs" ]] || fail "$mode 调用了包管理器"
    printf 'PASS: %s 拒绝安装\n' "$mode"
done

# 续传用 Content-Range 总长度, 并忽略重定向响应里的过期字段。
cat > "$BOX/check-headers.sh" <<'HEADERS'
#!/usr/bin/env bash
set -euo pipefail
. "$VENDOR_TEST_BOX/repo/scripts/components/_vendor_pkg.sh"
headers="$VENDOR_TEST_BOX/headers"
printf 'HTTP/1.1 200 Connection established\r\nContent-Length: 0\r\n\r\nHTTP/1.1 206 Partial Content\r\nContent-Length: 1048576\r\nContent-Range: bytes 1048576-2097151/2097152\r\n\r\n' > "$headers"
pkg_payload_ok "$VENDOR_TEST_BOX/fixture.deb" deb "$headers"
printf 'HTTP/1.1 302 Found\r\nContent-Length: 2097152\r\nX-COS-META-MD5: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n' > "$headers"
[[ $(pkg_content_length "$headers") == 9 ]]
if read_pkg_md5 "$headers"; then exit 1; fi
HEADERS
bash "$BOX/check-headers.sh" || fail '响应头/续传总大小解析失败'
printf 'PASS: 续传总大小、最终响应头校验\n'
[[ -z $(find "$TMPDIR" -mindepth 1 -print -quit) ]] || fail '响应头临时文件未清理'
