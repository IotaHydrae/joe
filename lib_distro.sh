#!/usr/bin/env bash
# =============================================================================
# joe lib_distro — 跨发行版识别与包名解析
# =============================================================================
# 目标发行版 (已实测):
#   * Ubuntu 24.04 (noble)   -> apt
#   * Linux Mint 22.3        -> apt (基于 noble)
#   * CachyOS / Arch Linux   -> pacman
#   * Fedora                 -> dnf
#   * openSUSE               -> zypper
#
# 设计要点:
#   1. 不只看包管理器, 还识别 distro id/版本 (Ubuntu 24.04 的 t64 重命名等)
#   2. 逻辑包名 -> "候选列表", 按可用性动态解析 (版本差异不硬编码)
#   3. 缺失包名时给出清晰提示, 而不是静默失败
#
# 提供:
#   distro_id / distro_like / distro_version / distro_codename / distro_pretty
#   distro_family / distro_ubuntu_base / detect_pm
#   pkg_installed / pkg_available / pkg_candidates / pkg_resolve
#   apt_update_once / install_sys_pkg / distro_report
# =============================================================================

# ---- 日志 (调用方若已定义则复用) ----
declare -F info >/dev/null 2>&1 || info() { printf '[INFO] %s\n' "$*"; }
declare -F warn >/dev/null 2>&1 || warn() { printf '[WARN] %s\n' "$*"; }
declare -F ok   >/dev/null 2>&1 || ok()   { printf '[ OK ] %s\n' "$*"; }
declare -F die  >/dev/null 2>&1 || die()  { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

# ---- sudo 兼容 ----
# 已以 root 运行时无需 sudo; 精简系统/容器/WSL 可能根本没有 sudo。
if [ "$(id -u)" -eq 0 ]; then
    sudo() { "$@"; }
elif ! command -v sudo >/dev/null 2>&1; then
    sudo() {
        printf '[WARN] 该操作需要管理员权限, 但系统没有 sudo: %s\n' "$*" >&2
        printf '[WARN] 请以 root 重新运行, 或手动执行上述命令\n' >&2
        return 1
    }
fi

# ---------------------------------------------------------------------------
# 发行版识别
# ---------------------------------------------------------------------------
_distro_cache=""
_distro_load() {
    [ -n "$_distro_cache" ] && return 0
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
    fi
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
    DISTRO_VERSION="${VERSION_ID:-}"
    DISTRO_CODENAME="${VERSION_CODENAME:-}"
    # Ubuntu 衍生版 (Mint/Zorin/Pop 等) 会带这些字段
    DISTRO_UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"
    DISTRO_UBUNTU_VERSION="${UBUNTU_VERSION_ID:-}"
    DISTRO_PRETTY="${PRETTY_NAME:-${NAME:-unknown}}"
    _distro_cache=1
}

distro_id()       { _distro_load; echo "$DISTRO_ID"; }
distro_like()     { _distro_load; echo "$DISTRO_LIKE"; }
distro_version()  { _distro_load; echo "$DISTRO_VERSION"; }
distro_codename() { _distro_load; echo "$DISTRO_CODENAME"; }
distro_pretty()   { _distro_load; echo "$DISTRO_PRETTY"; }

# 发行版家族: debian | arch | redhat | suse | unknown
distro_family() {
    _distro_load
    local id="$DISTRO_ID" like="$DISTRO_LIKE"
    case "$id" in
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali|raspbian|neon|tuxedo) echo debian; return ;;
        arch|cachyos|manjaro|endeavouros|garuda|artix) echo arch; return ;;
        fedora|rhel|centos|rocky|almalinux|nobara) echo redhat; return ;;
        opensuse*|sles|sled) echo suse; return ;;
    esac
    case "$like" in
        *arch*) echo arch; return ;;
        *debian*|*ubuntu*) echo debian; return ;;
        *rhel*|*fedora*) echo redhat; return ;;
        *suse*) echo suse; return ;;
    esac
    echo unknown
}

# 对 Ubuntu 衍生版求其对应的 Ubuntu 版本 (如 Mint 22.3 -> 24.04)
# 返回空表示无法判定
distro_ubuntu_base() {
    _distro_load
    case "$DISTRO_ID" in
        ubuntu|pop|neon|tuxedo|elementary) echo "$DISTRO_VERSION"; return ;;
    esac
    [ -n "$DISTRO_UBUNTU_VERSION" ] && { echo "$DISTRO_UBUNTU_VERSION"; return; }
    case "$DISTRO_UBUNTU_CODENAME" in
        noble)   echo "24.04" ;;
        resolute) echo "26.04" ;;
        jammy)   echo "22.04" ;;
        focal)   echo "20.04" ;;
        *)       echo "" ;;
    esac
}

# 包管理器
detect_pm() {
    # 优先按发行版家族判定, 避免装了多个包管理器的系统误判
    case "$(distro_family)" in
        debian) echo apt; return ;;
        arch)   echo pacman; return ;;
        redhat) echo dnf; return ;;
        suse)   echo zypper; return ;;
    esac
    if command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v pacman >/dev/null 2>&1; then echo pacman
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    elif command -v zypper >/dev/null 2>&1; then echo zypper
    else echo unknown; fi
}

PM="$(detect_pm)"

# ---------------------------------------------------------------------------
# 包状态
# ---------------------------------------------------------------------------
pkg_installed() {
    local pkg="$1"
    case "$PM" in
        apt)    dpkg -s "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -Q "$pkg" >/dev/null 2>&1 ;;
        dnf|zypper) rpm -q "$pkg" >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

# 该包当前是否"可安装"(有可用候选)
pkg_available() {
    local pkg="$1"
    case "$PM" in
        apt)
            local cand
            cand="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/{print $2; exit}')"
            [ -n "$cand" ] && [ "$cand" != "(none)" ]
            ;;
        pacman)
            pacman -Si "$pkg" >/dev/null 2>&1
            ;;
        dnf)
            dnf -q info "$pkg" >/dev/null 2>&1
            ;;
        zypper)
            zypper --quiet info "$pkg" >/dev/null 2>&1
            ;;
        *) return 0 ;;
    esac
}

# ---------------------------------------------------------------------------
# 逻辑包名 -> 候选包名列表
#   格式: 以空格分隔的"组"; 组内以 | 分隔"备选项"
#     "vulkan-radeon vulkan-intel"   -> 两个包都要装
#     "libfuse2t64|libfuse2"         -> 二者取其一 (按可用性)
# ---------------------------------------------------------------------------
pkg_candidates() {
    local logical="$1"
    case "$PM" in
        apt)
            case "$logical" in
                vulkan-loader)       echo "libvulkan1" ;;
                vulkan-tools)        echo "vulkan-tools" ;;
                mesa-vulkan-drivers) echo "mesa-vulkan-drivers" ;;
                jetbrains-mono)      echo "fonts-jetbrains-mono" ;;
                xdg-terminal-exec)   echo "xdg-terminal-exec" ;;
                # Ubuntu 24.04 起 t64 重命名; 按可用性二选一
                fuse2)               echo "libfuse2t64|libfuse2" ;;
                ncurses-dev)         echo "libncurses-dev|libncursesw5-dev" ;;
                fontconfig)          echo "fontconfig" ;;
                unzip)               echo "unzip" ;;
                *)                   echo "$logical" ;;
            esac ;;
        pacman)
            case "$logical" in
                vulkan-loader)       echo "vulkan-icd-loader" ;;
                vulkan-tools)        echo "vulkan-tools" ;;
                mesa-vulkan-drivers) echo "vulkan-radeon vulkan-intel" ;;
                jetbrains-mono)      echo "ttf-jetbrains-mono" ;;
                xdg-terminal-exec)   echo "xdg-terminal-exec" ;;   # 官方仓库已有
                fuse2)               echo "fuse2" ;;
                ncurses-dev)         echo "" ;;                    # base-devel 已覆盖
                fontconfig)          echo "fontconfig" ;;
                unzip)               echo "unzip" ;;
                *)                   echo "$logical" ;;
            esac ;;
        dnf)
            case "$logical" in
                vulkan-loader)       echo "vulkan-loader" ;;
                vulkan-tools)        echo "vulkan-tools" ;;
                mesa-vulkan-drivers) echo "mesa-vulkan-drivers" ;;
                jetbrains-mono)      echo "jetbrains-mono-fonts" ;;
                xdg-terminal-exec)   echo "xdg-terminal-exec" ;;
                fuse2)               echo "fuse" ;;
                ncurses-dev)         echo "ncurses-devel" ;;
                fontconfig)          echo "fontconfig" ;;
                unzip)               echo "unzip" ;;
                *)                   echo "$logical" ;;
            esac ;;
        zypper)
            case "$logical" in
                vulkan-loader)       echo "libvulkan1" ;;
                vulkan-tools)        echo "vulkan-tools" ;;
                mesa-vulkan-drivers) echo "libvulkan_radeon" ;;
                jetbrains-mono)      echo "jetbrains-mono-fonts" ;;
                xdg-terminal-exec)   echo "" ;;   # 未打包, 走脚本回退
                fuse2)               echo "libfuse2" ;;
                ncurses-dev)         echo "ncurses-devel" ;;
                fontconfig)          echo "fontconfig" ;;
                unzip)               echo "unzip" ;;
                *)                   echo "$logical" ;;
            esac ;;
        *) echo "$logical" ;;
    esac
}

# 解析逻辑名 -> 实际要安装的包名列表 (空格分隔)
#   * 每个"组"内选出第一个可用项
#   * 组之间全部保留 (多包场景)
#   * 组内全不可用时保留第一个, 以便安装时报出明确错误
pkg_resolve() {
    local logical="$1" list group rest cand picked out=""
    list="$(pkg_candidates "$logical")"
    [ -z "$list" ] && return 1

    # shellcheck disable=SC2086
    for group in $list; do
        picked=""
        rest="$group"
        while [ -n "$rest" ]; do
            cand="${rest%%|*}"
            if [ "$rest" = "$cand" ]; then rest=""; else rest="${rest#*|}"; fi
            [ -z "$picked" ] && picked="$cand"     # 兜底: 组内第一项
            if pkg_installed "$cand" || pkg_available "$cand"; then
                picked="$cand"
                break
            fi
        done
        out="$out $picked"
    done

    out="${out# }"; out="${out% }"
    [ -n "$out" ] || return 1
    echo "$out"
    return 0
}

# ---------------------------------------------------------------------------
# 安装系统包 (接受逻辑包名, 支持多个)
# ---------------------------------------------------------------------------
_apt_updated=false
apt_update_once() {
    [ "$PM" = "apt" ] || return 0
    $_apt_updated && return 0
    info "更新 apt 索引..."
    sudo apt-get update -qq || warn "apt-get update 有告警, 继续尝试"
    _apt_updated=true
    return 0
}

install_sys_pkg() {
    [ "$PM" = "unknown" ] && { warn "未知包管理器, 请手动安装: $*"; return 1; }

    local missing=() logical real pkg
    for logical in "$@"; do
        if ! real="$(pkg_resolve "$logical")" || [ -z "$real" ]; then
            warn "$logical: 当前发行版 ($(distro_pretty)) 无对应包, 跳过"
            continue
        fi
        # shellcheck disable=SC2086
        for pkg in $real; do
            if pkg_installed "$pkg"; then
                info "$pkg 已安装, 跳过"
            else
                missing+=("$pkg")
            fi
        done
    done
    [ "${#missing[@]}" -eq 0 ] && return 0

    info "安装系统包: ${missing[*]}"
    local rc=0
    case "$PM" in
        apt)
            apt_update_once
            sudo apt-get install -y "${missing[@]}" || rc=$?
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm "${missing[@]}" || rc=$?
            ;;
        dnf)
            sudo dnf install -y "${missing[@]}" || rc=$?
            ;;
        zypper)
            sudo zypper install -y "${missing[@]}" || rc=$?
            ;;
    esac
    [ $rc -ne 0 ] && warn "部分包安装失败 (rc=$rc): ${missing[*]}"
    return $rc
}

# ---------------------------------------------------------------------------
# Linux Mint 特有兼容性检查
# ---------------------------------------------------------------------------
check_mint_compatibility() {
    [ "$(distro_id)" = "linuxmint" ] || return 0

    local issues=0

    # 检查是否基于已知的 Ubuntu 版本
    local ubuntu_base
    ubuntu_base="$(distro_ubuntu_base)"
    if [ -z "$ubuntu_base" ]; then
        warn "无法确定此 Mint 版本对应的 Ubuntu 基线，某些功能可能不兼容"
        issues=$((issues + 1))
    elif [ "$ubuntu_base" != "24.04" ] && [ "$ubuntu_base" != "22.04" ]; then
        warn "此脚本主要在 Mint 22.x (Ubuntu 24.04 基线) 上测试，当前版本可能存在兼容性问题"
        issues=$((issues + 1))
    fi

    # 检查 PPA 支持（Mint 有时会禁用某些 Ubuntu PPA）
    if [ -d /etc/apt/sources.list.d ]; then
        if ! grep -qr "noble\|jammy" /etc/apt/sources.list.d/ 2>/dev/null && \
           ! grep -q "noble\|jammy" /etc/apt/sources.list 2>/dev/null; then
            warn "未检测到 Ubuntu noble/jammy 源，某些第三方软件可能无法安装"
            info "Mint 用户可能需要手动启用 Ubuntu 源或使用官方下载"
            issues=$((issues + 1))
        fi
    fi

    return "$issues"
}

# ---------------------------------------------------------------------------
# 发行版报告 (排查兼容性问题用)
# ---------------------------------------------------------------------------
distro_report() {
    _distro_load
    printf '  发行版:      %s\n' "$DISTRO_PRETTY"
    printf '  ID/ID_LIKE:  %s / %s\n' "$DISTRO_ID" "${DISTRO_LIKE:-<无>}"
    printf '  版本/代号:   %s / %s\n' "${DISTRO_VERSION:-<无>}" "${DISTRO_CODENAME:-<无>}"
    printf '  家族:        %s\n' "$(distro_family)"
    printf '  包管理器:    %s\n' "$PM"
    local ub; ub="$(distro_ubuntu_base)"
    [ -n "$ub" ] && printf '  Ubuntu 基线: %s\n' "$ub"

    # Mint 兼容性检查
    if [ "$(distro_id)" = "linuxmint" ]; then
        printf '\n'
        if check_mint_compatibility; then
            printf '  Mint 兼容性: %s\n' "$(printf '\033[0;32m✓ 无已知问题\033[0m')"
        else
            printf '  Mint 兼容性: %s\n' "$(printf '\033[1;33m⚠ 发现 %d 个潜在问题（见上方）\033[0m' $?)"
        fi
    fi

    return 0
}
