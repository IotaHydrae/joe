#!/usr/bin/env bash
# =============================================================================
# joe update-all — 统一更新开发环境
# =============================================================================
# 利用各工具的**官方自更新机制**升级（这正是当初选官方安装路径的原因），
# MCP / 技能配置请运行对应安装器按需选择。
#
# 用法:
#   ./install.sh update             # 更新工具链 + AI CLI + MCP 引擎 + joe 仓库
#   ./install.sh update --system    # 额外升级系统包 (dnf/apt/pacman/zypper)
#   ./install.sh update --dry-run   # 只显示将要执行什么
#   ./install.sh update --quiet     # 精简输出
#   ./install.sh update --only node,claude  # 只更新指定条目
#
# 说明:
#   - 单项失败不影响其余项, 最后统一汇总
#   - 退出码: 0 = 全部成功, 1 = 有失败项
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
ONLY=""

# 可单独更新的条目 (key 与 devtools 组件 id 对齐: node/nvm, python/pyenv)
UPDATE_KEYS="joe node python uv pipx claude codex gemini opencode grok copilot ccswitch chatgpt mimo codebase-memory-mcp codegraph system"
# 没有自更新机制的组件: 明确告知改用重装
NO_SELF_UPDATE="zed vscode ghostty brave wechat qq rime godot"

# 用 while 而不是 for: --only 需要消费下一个参数
while [ "$#" -gt 0 ]; do
    case "$1" in
        --system)  WITH_SYSTEM=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --quiet)   QUIET=true; shift ;;
        --only)
            ONLY="${2:-}"
            [ -n "$ONLY" ] || { echo "--only 需要组件名 (可用: $UPDATE_KEYS)" >&2; exit 2; }
            shift 2 ;;
        -h|--help) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; exit 0 ;;
        *) echo "未知选项: $1" >&2; exit 2 ;;
    esac
done

# --only 校验: 未知名直接拒绝, 不做任何更新
if [ -n "$ONLY" ]; then
    for _only_id in ${ONLY//,/ }; do
        case " $UPDATE_KEYS " in
            *" $_only_id "*) continue ;;
        esac
        case " $NO_SELF_UPDATE " in
            *" $_only_id "*)
                echo "$_only_id 没有自更新机制; 请用 ./install.sh tools install $_only_id 重装" >&2 ;;
            *)
                echo "未知更新项: $_only_id (可用: ${UPDATE_KEYS// /,})" >&2 ;;
        esac
        exit 2
    done
    if [[ ",$ONLY," == *",system,"* ]] && ! $WITH_SYSTEM; then
        echo "system 需要与 --system 一起使用" >&2
        exit 2
    fi
fi

c_g() { printf '\033[0;32m%s\033[0m' "$1"; }
c_r() { printf '\033[0;31m%s\033[0m' "$1"; }
c_y() { printf '\033[1;33m%s\033[0m' "$1"; }
c_b() { printf '\033[1;36m%s\033[0m' "$1"; }
c_d() { printf '\033[2m%s\033[0m' "$1"; }

OK=0; SKIP=0; FAILED=0; DRY=0; FAILED_ITEMS=()

section() {
    # --only 时只列实际执行的条目, 不打印可能为空的分组标题
    if $QUIET || [ -n "$ONLY" ]; then
        return 0
    fi
    printf '\n%s\n' "$(c_b "── $* ──")"
}

# 环境 PATH
# shellcheck source=lib_node.sh
. "$SCRIPT_DIR/lib_node.sh"
load_node
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
export PATH="$HOME/.grok/bin:$HOME/.mimocode/bin:$HOME/.local/bin:$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# 命令探测
find_bin() {
    local name="$1" dir f
    command -v "$name" >/dev/null 2>&1 && { command -v "$name"; return 0; }
    for dir in "$HOME/.local/bin" "$HOME/.mimocode/bin" "$HOME/.grok/bin"; do
        if [ -x "$dir/$name" ]; then
            printf '%s\n' "$dir/$name"
            return 0
        fi
    done
    for f in "$HOME"/.nvm/versions/node/*/bin/"$name"; do
        [ -x "$f" ] && { printf '%s\n' "$f"; return 0; }
    done
    return 1
}

# 该项是否被 --only 选中; ONLY 为空表示全部
want_item() {
    if [ -z "$ONLY" ]; then
        return 0
    fi
    case ",$ONLY," in
        *",$1,"*) return 0 ;;
        *) return 1 ;;
    esac
}

# 执行一项更新: update_item <key> <名称> <命令...>
update_item() {
    local key="$1" name="$2"; shift 2
    want_item "$key" || return 0
    if $DRY_RUN; then
        DRY=$((DRY + 1))
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

# 跳过一项: skip_item <key> <名称> [原因]
skip_item() {
    local key="$1" name="$2"
    want_item "$key" || return 0
    SKIP=$((SKIP + 1))
    $QUIET || printf '  %s %-26s %s\n' "$(c_d '·')" "$name" "$(c_d "${3:-未安装}")"
}

printf '%s\n' "$(c_b 'joe 统一更新')"
[ -n "$ONLY" ] && printf '%s\n' "$(c_d "只更新: $ONLY")"
$DRY_RUN && printf '%s\n' "$(c_y '(dry-run 模式, 不会真正执行)')"

# ---------------------------------------------------------------------------
# 1. joe 仓库
# ---------------------------------------------------------------------------
section "joe 仓库"
if [ -e "$REPO_ROOT/.git" ]; then
    update_item joe "joe (git pull)" git -C "$REPO_ROOT" pull --ff-only
else
    skip_item joe "joe (git pull)" "非 git 仓库"
fi

# ---------------------------------------------------------------------------
# 2. 工具链 (官方自更新)
# ---------------------------------------------------------------------------
section "工具链"

# nvm: git pull
if [ -d "$HOME/.nvm/.git" ]; then
    update_item node "nvm" git -C "$HOME/.nvm" pull --ff-only --quiet
else
    skip_item node "nvm"
fi

# pyenv: 官方 update 插件
if find_bin pyenv >/dev/null 2>&1; then
    if pyenv commands 2>/dev/null | grep -qx update; then
        update_item python "pyenv" pyenv update
    else
        update_item python "pyenv (git pull)" git -C "$PYENV_ROOT" pull --ff-only --quiet
    fi
else
    skip_item python "pyenv"
fi

# uv: 官方自更新
if find_bin uv >/dev/null 2>&1; then
    update_item uv "uv" uv self update
else
    skip_item uv "uv"
fi

# pipx: 由 pip 管理
if find_bin pipx >/dev/null 2>&1; then
    if find_bin python3 >/dev/null 2>&1; then
        update_item pipx "pipx" python3 -m pip install --user --upgrade --quiet pipx
    else
        skip_item pipx "pipx" "无 python3"
    fi
else
    skip_item pipx "pipx"
fi

# ---------------------------------------------------------------------------
# 3. AI CLI
# ---------------------------------------------------------------------------
section "AI CLI"

if find_bin claude >/dev/null 2>&1; then
    update_item claude "claude (Claude Code)" claude update
else
    skip_item claude "claude"
fi

if find_bin codex >/dev/null 2>&1; then
    codex_bin="$(find_bin codex)"
    if command -v timeout >/dev/null 2>&1; then
        codex_help="$(timeout 15 "$codex_bin" --help 2>&1 || true)"
    else
        codex_help="$("$codex_bin" --help 2>&1 || true)"
    fi
    if printf '%s\n' "$codex_help" | grep -Eq '^[[:space:]]+update([[:space:]]|$)'; then
        update_item codex "codex (Codex CLI)" "$codex_bin" update
    elif find_bin npm >/dev/null 2>&1; then
        update_item codex "codex (Codex CLI)" npm update -g @openai/codex
    else
        skip_item codex "codex" "无 codex update 或 npm"
    fi
else
    skip_item codex "codex"
fi

if find_bin gemini >/dev/null 2>&1; then
    if find_bin npm >/dev/null 2>&1; then
        update_item gemini "gemini (Gemini CLI)" npm update -g @google/gemini-cli
    else
        skip_item gemini "gemini" "无 npm"
    fi
else
    skip_item gemini "gemini"
fi

if find_bin opencode >/dev/null 2>&1; then
    update_item opencode "opencode" opencode upgrade
else
    skip_item opencode "opencode"
fi

if find_bin grok >/dev/null 2>&1; then
    update_item grok "grok (Grok Build)" grok update
else
    skip_item grok "grok"
fi

if find_bin copilot >/dev/null 2>&1; then
    update_item copilot "copilot (Copilot CLI)" env COPILOT_FORCE=1 \
        bash "$SCRIPT_DIR/install_devtools.sh" --copilot
else
    skip_item copilot "copilot"
fi

if find_bin cc-switch >/dev/null 2>&1; then
    cc_tag="$(ccswitch_latest_tag 2>/dev/null || true)"
    cc_stamp="$(cat "$HOME/.local/share/joe/cc-switch.version" 2>/dev/null || true)"
    if [ -z "$cc_tag" ]; then
        skip_item ccswitch "cc-switch" "无法查询最新版本"
    elif [ "$cc_stamp" = "$cc_tag" ]; then
        skip_item ccswitch "cc-switch" "已是 $cc_tag"
    else
        update_item ccswitch "cc-switch" env CCSWITCH_FORCE=1 CCSWITCH_VERSION="$cc_tag" \
            bash "$SCRIPT_DIR/install_devtools.sh" --ccswitch
    fi
else
    skip_item ccswitch "cc-switch"
fi

if find_bin chatgpt >/dev/null 2>&1; then
    skip_item chatgpt "chatgpt 桌面版" "应用内自行更新; 要重装请卸掉后运行 devtools --chatgpt"
else
    skip_item chatgpt "chatgpt"
fi

if find_bin mimo >/dev/null 2>&1; then
    update_item mimo "mimo (MiMo Code)" mimo upgrade
else
    skip_item mimo "mimo"
fi

# ---------------------------------------------------------------------------
# 4. MCP 引擎 / 工具
# ---------------------------------------------------------------------------
section "MCP 工具"

if find_bin codebase-memory-mcp >/dev/null 2>&1; then
    update_item codebase-memory-mcp "codebase-memory-mcp" codebase-memory-mcp update -y
else
    skip_item codebase-memory-mcp "codebase-memory-mcp"
fi

if find_bin codegraph-mcp >/dev/null 2>&1; then
    # 官方 fetch-engine 直连 GitHub CDN 易截断 -> 优先镜像补拉(带 SHA256 校验)
    if declare -F codegraph_fetch_engine_mirror >/dev/null 2>&1; then
        # 用子 bash 调用共享函数 (timeout 只能执行文件, 不能直接调用 shell 函数)
        update_item codegraph "codegraph 引擎" bash -c \
            '. "$1/lib_github.sh"; codegraph_fetch_engine_mirror' _ "$SCRIPT_DIR"
    elif find_bin codegraph-mcp-fetch-engine >/dev/null 2>&1; then
        update_item codegraph "codegraph 引擎" codegraph-mcp-fetch-engine --force
    else
        skip_item codegraph "codegraph 引擎" "无补拉方式"
    fi
else
    skip_item codegraph "codegraph"
fi

# ---------------------------------------------------------------------------
# 5. 按需配置提示
# ---------------------------------------------------------------------------
if ! $QUIET; then
    section "按需配置"
    printf '  MCP 配置: ./install.sh mcp --tui\n'
    printf '  技能安装/更新: ./install.sh skills --tui\n'
fi

# ---------------------------------------------------------------------------
# 6. 系统包 (可选)
# ---------------------------------------------------------------------------
if $WITH_SYSTEM; then
    section "系统包"
    if command -v dnf >/dev/null 2>&1; then
        update_item system "dnf upgrade" sudo dnf upgrade -y
    elif command -v apt-get >/dev/null 2>&1; then
        update_item system "apt upgrade" sudo apt-get update -y
    elif command -v pacman >/dev/null 2>&1; then
        update_item system "pacman -Syu" sudo pacman -Syu --noconfirm
    elif command -v zypper >/dev/null 2>&1; then
        update_item system "zypper update" sudo zypper update -y
    else
        skip_item system "系统包" "未知包管理器"
    fi
fi

# ---------------------------------------------------------------------------
# 汇总
# ---------------------------------------------------------------------------
printf '\n%s\n' "$(c_b '── 汇总 ──')"
printf '  %s 成功   %s 跳过   %s 失败\n' "$(c_g "$OK")" "$(c_d "$SKIP")" "$(c_r "$FAILED")"
[ "$DRY" -gt 0 ] && printf '  %s\n' "$(c_y "dry-run: $DRY 项将执行")"
if [ "$FAILED" -gt 0 ]; then
    printf '\n%s\n' "$(c_r '失败项:')"
    for i in "${FAILED_ITEMS[@]}"; do printf '  • %s\n' "$i"; done
    printf '\n提示: 单项网络问题可稍后重试；也可查看 ./install.sh doctor --mcp\n'
fi
[ "$FAILED" -eq 0 ]
