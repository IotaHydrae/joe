#!/usr/bin/env bash
# =============================================================================
# joe update-all — 统一更新开发环境
# =============================================================================
# 利用各工具的**官方自更新机制**升级（这正是当初选官方安装路径的原因），
# MCP / 技能配置请运行对应安装器按需选择。
#
# 用法:
#   ./update-all.sh             # 更新工具链 + AI CLI + MCP 引擎 + joe 仓库
#   ./update-all.sh --system    # 额外升级系统包 (dnf/apt/pacman/zypper)
#   ./update-all.sh --dry-run   # 只显示将要执行什么
#   ./update-all.sh --quiet     # 精简输出
#
# 说明:
#   - 单项失败不影响其余项, 最后统一汇总
#   - 退出码: 0 = 全部成功, 1 = 有失败项
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共享的 GitHub 下载/校验函数 (镜像回退等)
if [ -f "$SCRIPT_DIR/lib_github.sh" ]; then
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/lib_github.sh"
fi

if [ -z "${LC_ALL:-}" ]; then
    for _loc in C.UTF-8 C.utf8 en_US.UTF-8; do
        if locale -a 2>/dev/null | grep -qix "$_loc"; then export LC_ALL="$_loc"; break; fi
    done
    unset _loc
fi

WITH_SYSTEM=false
DRY_RUN=false
QUIET=false
for a in "$@"; do
    case "$a" in
        --system)  WITH_SYSTEM=true ;;
        --dry-run) DRY_RUN=true ;;
        --quiet)   QUIET=true ;;
        -h|--help) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; exit 0 ;;
        *) echo "未知选项: $a" >&2; exit 2 ;;
    esac
done

c_g() { printf '\033[0;32m%s\033[0m' "$1"; }
c_r() { printf '\033[0;31m%s\033[0m' "$1"; }
c_y() { printf '\033[1;33m%s\033[0m' "$1"; }
c_b() { printf '\033[1;36m%s\033[0m' "$1"; }
c_d() { printf '\033[2m%s\033[0m' "$1"; }

OK=0; SKIP=0; FAILED=0; FAILED_ITEMS=()

section() { $QUIET || printf '\n%s\n' "$(c_b "── $* ──")"; }

# 环境 PATH
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
export PATH="$HOME/.mimocode/bin:$HOME/.local/bin:$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# 命令探测
find_bin() {
    local name="$1" f
    command -v "$name" >/dev/null 2>&1 && { command -v "$name"; return 0; }
    [ -x "$HOME/.local/bin/$name" ] && { echo "$HOME/.local/bin/$name"; return 0; }
    [ -x "$HOME/.mimocode/bin/$name" ] && { echo "$HOME/.mimocode/bin/$name"; return 0; }
    for f in "$HOME"/.nvm/versions/node/*/bin/"$name"; do
        [ -x "$f" ] && { echo "$f"; return 0; }
    done
    return 1
}

# 执行一项更新: update_item <名称> <命令...>
update_item() {
    local name="$1"; shift
    if $DRY_RUN; then
        printf '  %s %-26s %s\n' "$(c_y '→')" "$name" "$(c_d "$*")"
        return 0
    fi
    if ! $QUIET; then printf '  %s %-26s ' "$(c_b '↓')" "$name"; fi
    local out rc
    # 加超时, 避免某个慢命令(如直连 GitHub)拖住整轮更新
    if command -v timeout >/dev/null 2>&1; then
        out="$(timeout "${UPDATE_TIMEOUT:-300}" "$@" 2>&1)"; rc=$?
    else
        out="$("$@" 2>&1)"; rc=$?
    fi
    if [ $rc -eq 0 ]; then
        OK=$((OK + 1))
        $QUIET || printf '%s\n' "$(c_g '已更新')"
    elif [ $rc -eq 124 ]; then
        FAILED=$((FAILED + 1))
        FAILED_ITEMS+=("$name (超时 ${UPDATE_TIMEOUT:-300}s)")
        $QUIET || printf '%s\n' "$(c_y "超时 ${UPDATE_TIMEOUT:-300}s")"
    else
        FAILED=$((FAILED + 1))
        FAILED_ITEMS+=("$name")
        $QUIET || printf '%s\n' "$(c_r '失败')"
        [ -n "$out" ] && printf '%s\n' "$out" | tail -3 | sed 's/^/      /'
    fi
}

# 跳过一项
skip_item() {
    SKIP=$((SKIP + 1))
    $QUIET || printf '  %s %-26s %s\n' "$(c_d '·')" "$1" "$(c_d "${2:-未安装}")"
}

printf '%s\n' "$(c_b 'joe 统一更新')"
$DRY_RUN && printf '%s\n' "$(c_y '(dry-run 模式, 不会真正执行)')"

# ---------------------------------------------------------------------------
# 1. joe 仓库
# ---------------------------------------------------------------------------
section "joe 仓库"
if [ -d "$SCRIPT_DIR/.git" ]; then
    update_item "joe (git pull)" git -C "$SCRIPT_DIR" pull --ff-only
else
    skip_item "joe (git pull)" "非 git 仓库"
fi

# ---------------------------------------------------------------------------
# 2. 工具链 (官方自更新)
# ---------------------------------------------------------------------------
section "工具链"

# nvm: git pull
if [ -d "$HOME/.nvm/.git" ]; then
    update_item "nvm" git -C "$HOME/.nvm" pull --ff-only --quiet
else
    skip_item "nvm"
fi

# pyenv: 官方 update 插件
if find_bin pyenv >/dev/null 2>&1; then
    if pyenv commands 2>/dev/null | grep -qx update; then
        update_item "pyenv" pyenv update
    else
        update_item "pyenv (git pull)" git -C "$PYENV_ROOT" pull --ff-only --quiet
    fi
else
    skip_item "pyenv"
fi

# uv: 官方自更新
if find_bin uv >/dev/null 2>&1; then
    update_item "uv" uv self update
else
    skip_item "uv"
fi

# pipx: 由 pip 管理
if find_bin pipx >/dev/null 2>&1; then
    if find_bin python3 >/dev/null 2>&1; then
        update_item "pipx" python3 -m pip install --user --upgrade --quiet pipx
    else
        skip_item "pipx" "无 python3"
    fi
else
    skip_item "pipx"
fi

# ---------------------------------------------------------------------------
# 3. AI CLI
# ---------------------------------------------------------------------------
section "AI CLI"

if find_bin claude >/dev/null 2>&1; then
    update_item "claude (Claude Code)" claude update
else
    skip_item "claude"
fi

if find_bin codex >/dev/null 2>&1; then
    if find_bin npm >/dev/null 2>&1; then
        update_item "codex (Codex CLI)" npm update -g @openai/codex
    else
        skip_item "codex" "无 npm"
    fi
else
    skip_item "codex"
fi

if find_bin mimo >/dev/null 2>&1; then
    update_item "mimo (MiMo Code)" mimo upgrade
else
    skip_item "mimo"
fi

# ---------------------------------------------------------------------------
# 4. MCP 引擎 / 工具
# ---------------------------------------------------------------------------
section "MCP 工具"

if find_bin codebase-memory-mcp >/dev/null 2>&1; then
    update_item "codebase-memory-mcp" codebase-memory-mcp update -y
else
    skip_item "codebase-memory-mcp"
fi

if find_bin codegraph-mcp >/dev/null 2>&1; then
    # 官方 fetch-engine 直连 GitHub CDN 易截断 -> 优先镜像补拉(带 SHA256 校验)
    if declare -F codegraph_fetch_engine_mirror >/dev/null 2>&1; then
        # 用子 bash 调用共享函数 (timeout 只能执行文件, 不能直接调用 shell 函数)
        update_item "codegraph 引擎" bash -c \
            '. "$1/lib_github.sh"; codegraph_fetch_engine_mirror' _ "$SCRIPT_DIR"
    elif find_bin codegraph-mcp-fetch-engine >/dev/null 2>&1; then
        update_item "codegraph 引擎" codegraph-mcp-fetch-engine --force
    else
        skip_item "codegraph 引擎" "无补拉方式"
    fi
else
    skip_item "codegraph"
fi

# ---------------------------------------------------------------------------
# 5. 按需配置提示
# ---------------------------------------------------------------------------
if ! $QUIET; then
    section "按需配置"
    printf '  MCP 配置: ./install_mcp_servers.sh --tui\n'
    printf '  技能安装/更新: ./install_skills.sh --tui\n'
fi

# ---------------------------------------------------------------------------
# 6. 系统包 (可选)
# ---------------------------------------------------------------------------
if $WITH_SYSTEM; then
    section "系统包"
    if command -v dnf >/dev/null 2>&1; then
        update_item "dnf upgrade" sudo dnf upgrade -y
    elif command -v apt-get >/dev/null 2>&1; then
        update_item "apt upgrade" sudo apt-get update -y
    elif command -v pacman >/dev/null 2>&1; then
        update_item "pacman -Syu" sudo pacman -Syu --noconfirm
    elif command -v zypper >/dev/null 2>&1; then
        update_item "zypper update" sudo zypper update -y
    else
        skip_item "系统包" "未知包管理器"
    fi
fi

# ---------------------------------------------------------------------------
# 汇总
# ---------------------------------------------------------------------------
printf '\n%s\n' "$(c_b '── 汇总 ──')"
printf '  %s 成功   %s 跳过   %s 失败\n' "$(c_g "$OK")" "$(c_d "$SKIP")" "$(c_r "$FAILED")"
if [ "$FAILED" -gt 0 ]; then
    printf '\n%s\n' "$(c_r '失败项:')"
    for i in "${FAILED_ITEMS[@]}"; do printf '  • %s\n' "$i"; done
    printf '\n提示: 单项网络问题可稍后重试；也可查看 ./doctor.sh --mcp\n'
fi
[ "$FAILED" -eq 0 ]
