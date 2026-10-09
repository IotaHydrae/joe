#!/usr/bin/env bash
# =============================================================================
# joe bootstrap — 新机器一键部署
# =============================================================================
# 把"克隆 joe → 装开发工具 → 配 MCP → 装技能 → 体检"串成一条命令。
#
# 用法:
#   ./install.sh bootstrap                    # 交互模式: 各阶段进入 TUI, 不预选任何项
#   ./install.sh bootstrap --yes              # 非交互: 全部安装 (适合脚本/CI)
#   ./install.sh bootstrap --only mcp,skills  # 只跑指定阶段
#   ./install.sh bootstrap --skip devtools    # 跳过指定阶段
#   ./install.sh bootstrap --dir ~/joe        # 指定克隆目录
#
# 阶段: devtools | mcp | skills | doctor   (默认全部)
#
# 环境变量:
#   JOE_DIR    克隆/使用目录 (默认 ~/iotahydrae/joe)
#   JOE_REPO   git 地址 (默认 SSH, 失败自动回退 HTTPS)
#   PROXY_URL  代理, 如 http://host:7890
#
# 也可直接管道运行(此时会先克隆到自己):
#   curl -fsSL <raw-url>/install.sh | bash -s -- bootstrap
# =============================================================================

set -uo pipefail

if [ -z "${LC_ALL:-}" ]; then
    for _loc in C.UTF-8 C.utf8 en_US.UTF-8; do
        if locale -a 2>/dev/null | grep -qix "$_loc"; then export LC_ALL="$_loc"; break; fi
    done
    unset _loc
fi

# ---- 参数 ----
ASSUME_YES=false
ONLY=""
SKIP=""
JOE_DIR="${JOE_DIR:-$HOME/iotahydrae/joe}"
JOE_REPO="${JOE_REPO:-git@github.com:IotaHydrae/joe.git}"
JOE_REPO_HTTPS="https://github.com/IotaHydrae/joe.git"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --yes|-y)   ASSUME_YES=true; shift ;;
        --only)     ONLY="${2:-}"; shift 2 ;;
        --skip)     SKIP="${2:-}"; shift 2 ;;
        --dir)      JOE_DIR="${2:-}"; shift 2 ;;
        --repo)     JOE_REPO="${2:-}"; shift 2 ;;
        -h|--help)  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; exit 0 ;;
        *) echo "未知选项: $1" >&2; exit 2 ;;
    esac
done

c_g() { printf '\033[0;32m%s\033[0m' "$1"; }
c_r() { printf '\033[0;31m%s\033[0m' "$1"; }
c_y() { printf '\033[1;33m%s\033[0m' "$1"; }
c_b() { printf '\033[1;36m%s\033[0m' "$1"; }
c_d() { printf '\033[2m%s\033[0m' "$1"; }
step() { printf '\n%s %s\n' "$(c_b '▶')" "$(c_b "$1")"; }
die()  { printf '%s %s\n' "$(c_r '✗')" "$*" >&2; exit 1; }

want() {
    local s="$1"
    if [ -n "$ONLY" ]; then
        case ",$ONLY," in *",$s,"*) ;; *) return 1 ;; esac
    fi
    if [ -n "$SKIP" ]; then
        case ",$SKIP," in *",$s,"*) return 1 ;; esac
    fi
    return 0
}

printf '%s\n' "$(c_b 'joe bootstrap — 开发环境一键部署')"

# ---------------------------------------------------------------------------
# 1. 前置依赖 (git / curl)
# ---------------------------------------------------------------------------
step "检查前置依赖"
PKG=""
command -v dnf     >/dev/null 2>&1 && PKG=dnf
[ -z "$PKG" ] && command -v apt-get >/dev/null 2>&1 && PKG=apt
[ -z "$PKG" ] && command -v pacman  >/dev/null 2>&1 && PKG=pacman
[ -z "$PKG" ] && command -v zypper  >/dev/null 2>&1 && PKG=zypper

need_install=()
command -v git  >/dev/null 2>&1 || need_install+=(git)
command -v curl >/dev/null 2>&1 || need_install+=(curl)

if [ "${#need_install[@]}" -gt 0 ]; then
    printf '  缺少: %s\n' "${need_install[*]}"
    [ -z "$PKG" ] && die "无法自动安装(未知包管理器), 请手动安装: ${need_install[*]}"
    if $ASSUME_YES; then
        case "$PKG" in
            dnf)     sudo dnf install -y "${need_install[@]}" ;;
            apt)     sudo apt-get update -qq && sudo apt-get install -y "${need_install[@]}" ;;
            pacman)  sudo pacman -S --needed --noconfirm "${need_install[@]}" ;;
            zypper)  sudo zypper install -y "${need_install[@]}" ;;
        esac || die "依赖安装失败"
    else
        printf '  请手动安装: sudo %s install %s\n' "$PKG" "${need_install[*]}"
        die "缺少必要依赖"
    fi
fi
printf '  %s git %s / curl %s\n' "$(c_g '✓')" "$(git --version 2>/dev/null | awk '{print $3}')" "$(curl --version 2>/dev/null | head -1 | awk '{print $2}')"

# ---------------------------------------------------------------------------
# 2. 定位或克隆 joe
# ---------------------------------------------------------------------------
step "准备 joe 仓库"

SELF="${BASH_SOURCE[0]:-}"
SRC_DIR=""
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
    SRC_DIR="$(cd "$(dirname "$SELF")/.." && pwd)"
fi

if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/scripts/install_devtools.sh" ]; then
    JOE_DIR="$SRC_DIR"
    printf '  %s 已在仓库内: %s\n' "$(c_g '✓')" "$JOE_DIR"
elif [ -f "$JOE_DIR/scripts/install_devtools.sh" ]; then
    printf '  %s 复用已有仓库: %s\n' "$(c_g '✓')" "$JOE_DIR"
    git -C "$JOE_DIR" pull --ff-only 2>/dev/null | tail -1 || true
else
    mkdir -p "$(dirname "$JOE_DIR")"
    printf '  克隆 %s\n' "$JOE_REPO"
    printf '  → %s\n' "$JOE_DIR"
    if ! git clone --depth 1 "$JOE_REPO" "$JOE_DIR" 2>/dev/null; then
        printf '  %s SSH 克隆失败, 回退 HTTPS\n' "$(c_y '!')"
        git clone --depth 1 "$JOE_REPO_HTTPS" "$JOE_DIR" || die "克隆失败, 请检查网络/代理"
    fi
    printf '  %s 已克隆\n' "$(c_g '✓')"
fi

cd "$JOE_DIR" || die "无法进入 $JOE_DIR"

# 代理
if [ -n "${PROXY_URL:-}" ]; then
    export https_proxy="$PROXY_URL" http_proxy="$PROXY_URL"
    printf '  %s 使用代理 %s\n' "$(c_g '✓')" "$PROXY_URL"
fi

# 统一环境 PATH (nvm / pyenv / mimo / 用户 bin)
# shellcheck source=lib_node.sh
. "$JOE_DIR/scripts/lib_node.sh"
load_node
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
export PATH="$HOME/.mimocode/bin:$HOME/.local/bin:$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# ---------------------------------------------------------------------------
# 3. 依次执行各阶段
# ---------------------------------------------------------------------------
FAILED_STAGES=()

# 计算总阶段数
TOTAL_STAGES=0
want devtools && TOTAL_STAGES=$((TOTAL_STAGES + 1))
want mcp && TOTAL_STAGES=$((TOTAL_STAGES + 1))
want skills && TOTAL_STAGES=$((TOTAL_STAGES + 1))
want doctor && TOTAL_STAGES=$((TOTAL_STAGES + 1))

CURRENT_STAGE=0

run_stage() {
    local stage="$1" label="$2" script="$3"
    want "$stage" || return 0
    if [ ! -f "$script" ]; then
        printf '  %s %s: 脚本不存在 %s\n' "$(c_y '!')" "$label" "$script"
        return 0
    fi

    CURRENT_STAGE=$((CURRENT_STAGE + 1))
    step "[$CURRENT_STAGE/$TOTAL_STAGES] $label"

    if $ASSUME_YES; then
        # --yes 是调用者显式选择全部安装, 不依赖安装器的默认行为。
        if bash "$script" --all < /dev/null; then
            printf '  %s %s 完成\n' "$(c_g '✓')" "$label"
        else
            printf '  %s %s 失败\n' "$(c_r '✗')" "$label"
            FAILED_STAGES+=("$label")
        fi
    else
        # 交互: 进入各自 TUI
        if bash "$script"; then
            printf '  %s %s 完成\n' "$(c_g '✓')" "$label"
        else
            printf '  %s %s 失败\n' "$(c_r '✗')" "$label"
            FAILED_STAGES+=("$label")
        fi
    fi
}

run_stage devtools "开发工具"    ./scripts/install_devtools.sh
run_stage mcp      "MCP 服务器" ./scripts/install_mcp_servers.sh
run_stage skills   "代理技能"   ./scripts/install_skills.sh

# ---------------------------------------------------------------------------
# 4. 体检
# ---------------------------------------------------------------------------
if want doctor; then
    step "环境体检 (doctor.sh)"
    if [ -f ./scripts/doctor.sh ]; then
        bash ./scripts/doctor.sh || true
    else
        printf '  %s doctor.sh 不存在\n' "$(c_y '!')"
    fi
fi

# ---------------------------------------------------------------------------
# 汇总
# ---------------------------------------------------------------------------
printf '\n%s\n' "$(c_b '── bootstrap 完成 ──')"
if [ "${#FAILED_STAGES[@]}" -gt 0 ]; then
    printf '%s\n' "$(c_r '有阶段失败:')"
    for s in "${FAILED_STAGES[@]}"; do printf '  • %s\n' "$s"; done
    printf '\n可重新单独执行对应脚本重试。\n'
    exit 1
fi
printf '%s\n' "$(c_g '全部阶段完成 ✓')"
printf '新开一个终端 (或 source ~/.zshrc) 使环境变量生效。\n'
