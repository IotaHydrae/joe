#!/usr/bin/env bash
# =============================================================================
# joe lib_github — GitHub 下载与校验的共享函数
# =============================================================================
# 被 install_mcp_servers.sh / update-all.sh 等 source 复用。
#
# 提供:
#   download_installer <url> <out>          下载并校验是"合法脚本"(拒绝 HTML 错误页)
#   github_mirror_download <gh_url> <out>   经镜像下载 (应对 GitHub CDN 截断)
#   codegraph_fetch_engine_mirror           补拉 CodeGraph 引擎并校验 SHA256
#
# 调用方若已定义 info/ok/warn 则复用, 否则使用内置简易实现。
# =============================================================================

declare -F info >/dev/null 2>&1 || info() { printf '[INFO] %s\n' "$*"; }
declare -F warn >/dev/null 2>&1 || warn() { printf '[WARN] %s\n' "$*"; }
declare -F ok   >/dev/null 2>&1 || ok()   { printf '[ OK ] %s\n' "$*"; }

# 下载安装脚本并校验 (避免把 HTML 错误页/区域限制页当脚本执行)
# 返回 0 = 拿到合法脚本, 1 = 失败(网络/HTML/非脚本)
download_installer() {
    local url="$1" out="$2" attempt
    rm -f "$out"
    for attempt in 1 2 3; do
        if curl -fsSL --retry 2 --retry-all-errors --connect-timeout 20 \
                "$url" -o "$out" 2>/dev/null && [ -s "$out" ]; then
            break
        fi
        [ "$attempt" -lt 3 ] && sleep 2
    done
    [ -s "$out" ] || return 1
    head -c 200 "$out" | grep -qiE '<html|<!doctype|<script' && return 1
    head -1 "$out" | grep -qE '^#!' || return 1
    return 0
}

# 经 GitHub 镜像下载 (部分网络下直连 GitHub releases 会中途截断)
# 用法: github_mirror_download <完整GitHub URL> <输出文件> [重试次数]
github_mirror_download() {
    local url="$1" out="$2" retries="${3:-3}" mirror
    [ -n "$url" ] && [ -n "$out" ] || return 2
    for mirror in "https://ghfast.top/" "https://gh-proxy.com/" "https://ghproxy.net/" ""; do
        info "下载 (镜像: ${mirror:-直连}): ${url##*/}"
        if curl -fsSL --retry "$retries" --retry-all-errors --connect-timeout 20 \
                -o "$out" "${mirror}${url}" 2>/dev/null && [ -s "$out" ]; then
            return 0
        fi
    done
    return 1
}

# 通过镜像补拉 CodeGraph 引擎并校验 SHA256
# (官方 fetch-engine 直连 GitHub releases, 在部分网络下会中途截断)
codegraph_fetch_engine_mirror() {
    local pkgdir engine_ver asset plat arch
    pkgdir="$(npm root -g 2>/dev/null)/@astudioplus/codegraph-mcp"
    [ -d "$pkgdir" ] || return 1

    case "$(uname -s)" in Darwin) plat=darwin ;; *) plat=linux ;; esac
    case "$(uname -m)" in
        x86_64|amd64) arch=x64 ;;
        aarch64|arm64) arch=arm64 ;;
        *) return 1 ;;
    esac
    asset="codegraph-server-${plat}-${arch}"

    # 从包内读取引擎版本 (与客户端版本独立)
    engine_ver="$(grep -oE 'ENGINE_VERSION = "[^"]+"' "$pkgdir/bin/fetch-engine.js" 2>/dev/null \
        | head -1 | sed 's/.*"\(.*\)"/\1/')"
    [ -n "$engine_ver" ] || engine_ver="$(cat "$pkgdir/bin/.engine-version" 2>/dev/null)"
    [ -n "$engine_ver" ] || { warn "无法确定 CodeGraph 引擎版本"; return 1; }

    local base="https://github.com/codegraph-ai/CodeGraph/releases/download/v${engine_ver}"
    github_mirror_download "${base}/${asset}" /tmp/cg-engine || return 1

    # 校验 SHA256 (校验失败则拒绝安装)
    if curl -fsSL --connect-timeout 15 -o /tmp/cg-engine.sha256 "${base}/${asset}.sha256" 2>/dev/null; then
        local want got
        want="$(awk '{print $1}' /tmp/cg-engine.sha256)"
        got="$(sha256sum /tmp/cg-engine | awk '{print $1}')"
        if [ -n "$want" ] && [ "$want" != "$got" ]; then
            warn "CodeGraph 引擎 SHA256 校验失败 (want=$want got=$got), 拒绝安装"
            return 1
        fi
        info "CodeGraph 引擎 SHA256 校验通过"
    else
        warn "未能获取 .sha256, 跳过校验"
    fi

    install -m 755 /tmp/cg-engine "$pkgdir/bin/$asset" || return 1
    printf '%s\n' "$engine_ver" > "$pkgdir/bin/.engine-version"
    rm -f /tmp/cg-engine /tmp/cg-engine.sha256 "$pkgdir/bin/"*.partial 2>/dev/null || true
    ok "CodeGraph 引擎已安装: $pkgdir/bin/$asset"
    return 0
}
