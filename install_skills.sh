#!/usr/bin/env bash
# =============================================================================
# joe install_skills — 代理技能 (Agent Skills) 安装器 (含 TUI)
# =============================================================================
# 把 ./skills/<name>/SKILL.md 安装到各 AI 代理的 skills 目录。
#
# 用法:
#   ./install_skills.sh                # 默认进入 TUI, 不预选; 非交互须指定技能
#   ./install_skills.sh --tui          # 强制进入 TUI 勾选界面
#   ./install_skills.sh --all          # 显式安装全部技能
#   ./install_skills.sh --list         # 列出技能及安装状态
#   ./install_skills.sh <name> [...]   # 只装指定技能
#
# TUI 按键: ↑/↓ 移动, 空格 勾选, a 全选, n 全不选, i 仅未装, 回车 开始, q 退出
#
# 安装位置 (按已安装的代理自动选择):
#   ~/.agents/skills/          通用 (跨工具约定, 总是安装)
#   ~/.claude/skills/          Claude Code
#   ~/.codex/skills/           Codex CLI
#   ~/.config/mimocode/skills/ MiMo Code (原生)
#   ~/.copilot/skills/         GitHub Copilot (目录存在时)
#
# 说明:
#   - 技能即 ./skills/<name>/, 需含 SKILL.md (YAML frontmatter 的 name/description)
#   - 整个技能目录(含 references/ scripts/ assets/)会被一并安装
#   - 幂等: 内容有变则更新, 无变化跳过
#   - MiMo Code 也会扫描 ~/.claude、~/.agents、~/.codex 下的 skills, 故可复用
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"

# 多字节文本按"字符"处理 (POSIX locale 下 bash 按字节截断会切坏中文)
if [ -z "${LC_ALL:-}" ]; then
    for _loc in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
        if locale -a 2>/dev/null | grep -qix "$_loc"; then
            export LC_ALL="$_loc"
            break
        fi
    done
    unset _loc
fi


# ---------------------------------------------------------------------------
# 小工具函数
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*"; }
die()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# 命令探测: PATH 或常见安装路径
_has_bin() {
    local name="$1"
    command -v "$name" >/dev/null 2>&1 && return 0
    [ -x "$HOME/.local/bin/$name" ] && return 0
    [ -x "$HOME/.mimocode/bin/$name" ] && return 0
    local f
    for f in "$HOME"/.nvm/versions/node/*/bin/"$name"; do
        [ -x "$f" ] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# 目标目录 (按已安装的代理)
# ---------------------------------------------------------------------------
skill_targets() {
    echo "$HOME/.agents/skills"                       # 通用, 总是装
    _has_bin claude && echo "$HOME/.claude/skills"
    _has_bin codex  && echo "$HOME/.codex/skills"
    _has_bin mimo   && echo "$HOME/.config/mimocode/skills"
    [ -d "$HOME/.copilot" ] && echo "$HOME/.copilot/skills"
    return 0
}

# ---------------------------------------------------------------------------
# 技能发现与元数据
# ---------------------------------------------------------------------------
discover_skills() {
    local d
    for d in "$SKILLS_SRC"/*/SKILL.md; do
        [ -f "$d" ] || continue
        basename "$(dirname "$d")"
    done
}

# 取 frontmatter 字段 (仅首个 --- 块)
skill_field() {
    local name="$1" field="$2" f="$SKILLS_SRC/$1/SKILL.md"
    [ -f "$f" ] || return 1
    awk -v want="$field" '
        NR == 1 && $0 ~ /^---[[:space:]]*$/ { inblk = 1; next }
        inblk && $0 ~ /^---[[:space:]]*$/ { exit }
        inblk {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (index(line, want ":") == 1) {
                sub("^" want ":[[:space:]]*", "", line)
                gsub(/^["\x27]|["\x27]$/, "", line)
                print line
                exit
            }
        }
    ' "$f"
}

# 技能是否已在所有目标目录中为最新
skill_installed() {
    local name="$1" srcdir="$SKILLS_SRC/$1" dir found_any=0
    [ -f "$srcdir/SKILL.md" ] || return 1
    while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        # 整个技能目录(含 references/scripts/assets)必须完全一致
        if [ -f "$dir/$name/SKILL.md" ] && diff -rq "$srcdir" "$dir/$name" >/dev/null 2>&1; then
            found_any=1
        else
            return 1   # 任一目标缺失/过旧 -> 视为未安装(需更新)
        fi
    done < <(skill_targets)
    [ "$found_any" = "1" ]
}

# 校验 frontmatter 必填字段
validate_skill() {
    local name="$1" f="$SKILLS_SRC/$1/SKILL.md"
    [ -f "$f" ] || { warn "$name: 缺少 SKILL.md"; return 1; }
    head -1 "$f" | grep -qE '^---[[:space:]]*$' || { warn "$name: 缺少 YAML frontmatter"; return 1; }
    [ -n "$(skill_field "$name" name)" ] || { warn "$name: frontmatter 缺少 name"; return 1; }
    [ -n "$(skill_field "$name" description)" ] || { warn "$name: frontmatter 缺少 description"; return 1; }
    return 0
}

# ---------------------------------------------------------------------------
# 安装单个技能
# ---------------------------------------------------------------------------
install_skill() {
    local name="$1" srcdir="$SKILLS_SRC/$1" dir updated=0

    validate_skill "$name" || die "技能 $name 校验失败"
    local declared
    declared="$(skill_field "$name" name)"
    if [ "$declared" != "$name" ]; then
        warn "$name: frontmatter name($declared) 与目录名不一致 (以 frontmatter 为准)"
    fi

    while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        # 整个目录已一致 -> 跳过
        if [ -f "$dir/$name/SKILL.md" ] && diff -rq "$srcdir" "$dir/$name" >/dev/null 2>&1; then
            continue
        fi
        mkdir -p "$dir/$name"
        # 复制整个技能目录 (SKILL.md + references/ + scripts/ + assets/ ...)
        cp -R "$srcdir/." "$dir/$name/"
        updated=$((updated + 1))
    done < <(skill_targets)

    if [ "$updated" -gt 0 ]; then
        ok "$name: 已安装/更新 ($updated 个目录)"
    else
        info "$name: 已是最新, 跳过"
    fi
}

# ---------------------------------------------------------------------------
# TUI 相关 (复用 tui_module.sh 通用库)
# ---------------------------------------------------------------------------
load_tui_module() {
    local module="$SCRIPT_DIR/tui_module.sh"
    [ -f "$module" ] || return 1
    # shellcheck disable=SC1091
    . "$module"
}

# 技能显示名: "name — 简短描述"
tui_component_name() {
    local desc
    desc="$(skill_field "$1" description)"
    if [ -n "$desc" ]; then
        printf '%s — %.56s' "$1" "$desc"
    else
        echo "$1"
    fi
}

tui_component_installed() {
    skill_installed "$1"
}

tui_select() {
    local ids
    # shellcheck disable=SC2207
    ids=($(discover_skills))
    [ "${#ids[@]}" -gt 0 ] || die "在 $SKILLS_SRC 下没有找到任何技能 (需 <name>/SKILL.md)"

    TUI_IDS=("${ids[@]}")
    TUI_TITLE="joe 代理技能安装选择"
    load_tui_module || die "未找到 tui_module.sh (与脚本同目录)"
    tui_available || die "当前不是交互式终端, 请指定技能或使用 --all (查看 --help)"
    run_tui
}

# ---------------------------------------------------------------------------
# 参数解析 / 主流程
# ---------------------------------------------------------------------------
usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
    echo
    echo "可用技能 (来自 $SKILLS_SRC):"
    local s
    for s in $(discover_skills); do
        echo "  $s"
    done
    echo
    echo "安装位置:"
    local d
    for d in $(skill_targets); do
        echo "  $d"
    done
    exit 0
}

list_skills() {
    printf '可用技能 (%s):\n' "$SKILLS_SRC"
    local s status desc
    for s in $(discover_skills); do
        if skill_installed "$s"; then status="已安装"; else status="未安装"; fi
        desc="$(skill_field "$s" description)"
        printf '  %-22s %-4s %s\n' "$s" "$status" "${desc:0:60}"
    done
    printf '\n安装位置:\n'
    for d in $(skill_targets); do
        printf '  %s\n' "$d"
    done
    exit 0
}

TARGETS=()
TUI_MODE=false
ALL_MODE=false
HAS_ARGS=false
while [[ $# -gt 0 ]]; do
    HAS_ARGS=true
    case "$1" in
        --tui)       TUI_MODE=true; shift ;;
        --all)       ALL_MODE=true; shift ;;
        --list|-l)   list_skills ;;
        -h|--help)   usage ;;
        *)
            if [ -d "$SKILLS_SRC/$1" ]; then
                TARGETS+=("$1"); shift
            else
                die "未知技能: $1"
            fi
            ;;
    esac
done

# 无参数只进入交互选择, 非交互调用须显式指定技能。
if [ "$HAS_ARGS" = "false" ]; then
    if [ -t 1 ] && [ -t 0 ]; then
        TUI_MODE=true
    else
        die "当前不是交互式终端, 请指定技能或使用 --all (查看 --help)"
    fi
fi

if $ALL_MODE; then
    $TUI_MODE && die "--all 不能与 --tui 同时使用"
    mapfile -t TARGETS < <(discover_skills)
fi

if $TUI_MODE; then
    if tui_select; then
        if [ -n "$TUI_SELECTED" ]; then
            # shellcheck disable=SC2206
            TARGETS=($TUI_SELECTED)
            info "已选择技能:${TUI_SELECTED}"
        else
            info "TUI 未选择任何技能, 退出"
            exit 0
        fi
    else
        exit 0
    fi
fi

[ "${#TARGETS[@]}" -gt 0 ] || die "没有要安装的技能"

info "joe 技能安装开始 $(date)"
for t in "${TARGETS[@]}"; do
    install_skill "$t"
done
ok "全部技能安装完成! (代理下次启动时自动发现)"
