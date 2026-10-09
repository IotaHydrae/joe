#!/usr/bin/env bash
# =============================================================================
# joe install_skills — 代理技能 (Agent Skills) 安装器 (含 TUI)
# =============================================================================
# 把 ./skills/<name>/SKILL.md 安装到各 AI 代理的 skills 目录。
#
# 用法:
#   ./install.sh skills                # 技能组 → 分类 → 勾选, 默认不预选
#   ./install.sh skills --tui          # 同上; 带 --category 时直接进入分类勾选
#   ./install.sh skills --all          # 显式安装全部技能
#   ./install.sh skills --list         # 列出技能及安装状态
#   ./install.sh skills --categories   # 列出分类及技能数量
#   ./install.sh skills --category kernel-dev --tui  # 按分类勾选, 可重复 --category
#   ./install.sh skills --category kernel-dev --all  # 显式安装该分类全部技能
#   ./install.sh skills <name> [...]   # 只装指定技能
#   ./install.sh skills engineering-embedded-linux-driver-engineer  # 只装嵌入式驱动技能
#
# TUI 按键: ↑/↓ 移动, PgUp/PgDn 翻页, Home/End 首尾, 空格 勾选,
#           a 全选, n 全不选, i 仅未装, 回车 开始, q 退出
#
# 安装位置 (按已安装的代理自动选择):
#   ~/.agents/skills/          通用 (跨工具约定, 总是安装)
#   ~/.claude/skills/          Claude Code
#   ~/.codex/skills/           Codex CLI
#   ~/.config/mimocode/skills/ MiMo Code (原生)
#   ~/.copilot/skills/         GitHub Copilot (目录存在时)
#
# 说明:
#   - 默认菜单分为原有/本地技能和 low-level-dev-skills; 后者按分类进入勾选
#   - 编号进入子菜单, b/q 返回上一级; 安装完成后返回当前菜单
#   - 技能即 ./skills/<name>/, 需含 SKILL.md (YAML frontmatter 的 name/description)
#   - 整个技能目录(含 references/ scripts/ assets/)会被一并安装
#   - --category 可与 --list/--tui/--all/技能名组合; 未分类的技能属于 local
#   - 相关技能与系统工具不自动安装; 仅复制显式选择的技能目录
#   - 幂等: 内容有变则更新, 无变化跳过
#   - MiMo Code 也会扫描 ~/.claude、~/.agents、~/.codex 下的 skills, 故可复用
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"
CATEGORY_FILTERS=()
declare -A SKILL_CATEGORIES=()

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

# 分类只用于筛选, 技能清单仍从 SKILL.md 自动发现。
if [ -f "$SKILLS_SRC/categories.tsv" ]; then
    while IFS=$'\t' read -r skill category; do
        [[ -z "$skill" || "$skill" == \#* ]] && continue
        SKILL_CATEGORIES["$skill"]="$category"
    done < "$SKILLS_SRC/categories.tsv"
fi

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
    local d name category wanted
    for d in "$SKILLS_SRC"/*/SKILL.md; do
        [ -f "$d" ] || continue
        name="${d%/SKILL.md}"
        name="${name##*/}"
        category="${SKILL_CATEGORIES[$name]:-local}"
        if [ "${#CATEGORY_FILTERS[@]}" -gt 0 ]; then
            for wanted in "${CATEGORY_FILTERS[@]}"; do
                [ "$category" = "$wanted" ] && break
            done
            [ "$category" = "$wanted" ] || continue
        fi
        printf '%s\n' "$name"
    done
}

category_counts() {
    local name category
    local -A counts=()
    while IFS= read -r name; do
        category="${SKILL_CATEGORIES[$name]:-local}"
        counts[$category]=$(( ${counts[$category]:-0} + 1 ))
    done < <(discover_skills)
    for category in "${!counts[@]}"; do
        printf '%s\t%d\n' "$category" "${counts[$category]}"
    done | sort
}

list_categories() {
    local -a CATEGORY_FILTERS=()
    local category count
    printf '可用分类:\n'
    while IFS=$'\t' read -r category count; do
        printf '  %-24s %d 个技能\n' "$category" "$count"
    done < <(category_counts)
    exit 0
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
    local desc category="${SKILL_CATEGORIES[$1]:-local}"
    desc="$(skill_field "$1" description)"
    if [ -n "$desc" ]; then
        printf '[%s] %s — %s' "$category" "$1" "${desc:0:56}"
    else
        printf '[%s] %s' "$category" "$1"
    fi
}

tui_component_installed() {
    skill_installed "$1"
}

tui_select() {
    local -a ids=()
    mapfile -t ids < <(discover_skills)
    [ "${#ids[@]}" -gt 0 ] || die "在 $SKILLS_SRC 下没有找到任何技能 (需 <name>/SKILL.md)"

    TUI_IDS=("${ids[@]}")
    TUI_TITLE="${1:-joe 代理技能安装选择}"
    load_tui_module || die "未找到 tui_module.sh (与脚本同目录)"
    tui_available || die "当前不是交互式终端, 请指定技能或使用 --all (查看 --help)"
    run_tui
}

# ---------------------------------------------------------------------------
# 技能组 / 分类子菜单 (仅在未指定 --category 时使用)
# ---------------------------------------------------------------------------
install_selection() {
    info "joe 技能安装开始 $(date)"
    local name
    for name in "$@"; do
        install_skill "$name"
    done
    ok "全部技能安装完成! (代理下次启动时自动发现)"
}

select_category() {
    # Bash 动态作用域: 仅在本次选择中覆盖分类过滤, 不影响后续菜单。
    local -a CATEGORY_FILTERS=("$1")
    local -a selected=()
    tui_select "joe 技能安装 — $1"
    if [ -z "$TUI_SELECTED" ]; then
        info "未选择任何技能, 返回菜单"
        return 0
    fi
    read -r -a selected <<< "$TUI_SELECTED"
    info "已选择技能:${TUI_SELECTED}"
    install_selection "${selected[@]}"
}

low_level_menu() {
    local -a categories=("$@")
    local choice category count index
    while true; do
        printf '\n── low-level-dev-skills 分类 ──\n'
        for index in "${!categories[@]}"; do
            IFS=$'\t' read -r category count <<< "${categories[$index]}"
            printf '  %2d) %-24s (%d 个技能)\n' "$((index + 1))" "$category" "$count"
        done
        printf '  b/q) 返回技能组菜单\n选择分类 [1-%d/b/q]: ' "${#categories[@]}"
        IFS= read -r choice || return 0
        case "$choice" in
            b|B|q|Q|0) return 0 ;;
            '') continue ;;
        esac
        # 字符串匹配编号, 避免将用户输入当作算术表达式执行。
        for index in "${!categories[@]}"; do
            [ "$choice" = "$((index + 1))" ] && break
        done
        if [ "$choice" != "$((index + 1))" ]; then
            printf '请输入有效编号或 b/q。\n'
            continue
        fi
        IFS=$'\t' read -r category count <<< "${categories[$index]}"
        select_category "$category"
    done
}

skills_menu() {
    [ -t 0 ] && [ -t 1 ] || die "当前不是交互式终端, 请指定技能或使用 --all (查看 --help)"
    local -a categories=()
    local local_count=0 imported_count=0 category count choice
    while IFS=$'\t' read -r category count; do
        if [ "$category" = local ]; then
            local_count="$count"
        else
            categories+=("$category"$'\t'"$count")
            imported_count=$((imported_count + count))
        fi
    done < <(category_counts)
    while true; do
        printf '\n── joe 技能组 (按需勾选) ──\n'
        printf '  1) 原有/本地技能 (%d 个技能)\n' "$local_count"
        printf '  2) low-level-dev-skills (%d 个技能, %d 个分类)\n' "$imported_count" "${#categories[@]}"
        printf '  b/q) 返回上一级 / 退出\n选择技能组 [1-2/b/q]: '
        IFS= read -r choice || return 0
        case "$choice" in
            1)
                [ "$local_count" -gt 0 ] || { warn "没有原有/本地技能"; continue; }
                select_category local ;;
            2)
                [ "${#categories[@]}" -gt 0 ] || { warn "没有已分类的技能"; continue; }
                low_level_menu "${categories[@]}" ;;
            b|B|q|Q|0) return 0 ;;
            '') continue ;;
            *) printf '请输入有效编号或 b/q。\n' ;;
        esac
    done
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
    local s status desc category
    for s in $(discover_skills); do
        if skill_installed "$s"; then status="已安装"; else status="未安装"; fi
        desc="$(skill_field "$s" description)"
        category="${SKILL_CATEGORIES[$s]:-local}"
        printf '  %-22s %-4s [%-16s] %s\n' "$s" "$status" "$category" "${desc:0:60}"
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
HELP_MODE=false
LIST_MODE=false
CATEGORIES_MODE=false
while [[ $# -gt 0 ]]; do
    HAS_ARGS=true
    case "$1" in
        --tui)       TUI_MODE=true; shift ;;
        --all)       ALL_MODE=true; shift ;;
        --list|-l)   LIST_MODE=true; shift ;;
        --categories) CATEGORIES_MODE=true; shift ;;
        --category)
            [ "$#" -ge 2 ] && [[ "$2" != -* ]] || die "--category 需要分类名 (查看 --categories)"
            CATEGORY_FILTERS+=("$2"); shift 2 ;;
        -h|--help)   HELP_MODE=true; shift ;;
        *)
            if [[ "$1" != */* && -f "$SKILLS_SRC/$1/SKILL.md" ]]; then
                TARGETS+=("$1"); shift
            else
                die "未知技能: $1"
            fi
            ;;
    esac
done

$HELP_MODE && usage
for category in "${CATEGORY_FILTERS[@]}"; do
    known=false
    for skill in local "${SKILL_CATEGORIES[@]}"; do
        if [ "$category" = "$skill" ]; then known=true; break; fi
    done
    $known || die "未知分类: $category (查看 --categories)"
done
$CATEGORIES_MODE && list_categories
$LIST_MODE && list_skills

for skill in "${TARGETS[@]}"; do
    if [ "${#CATEGORY_FILTERS[@]}" -gt 0 ]; then
        category="${SKILL_CATEGORIES[$skill]:-local}"
        known=false
        for wanted in "${CATEGORY_FILTERS[@]}"; do
            if [ "$category" = "$wanted" ]; then known=true; break; fi
        done
        $known || die "技能 $skill 不属于所选分类"
    fi
done

# 无参数只进入交互选择, 非交互调用须显式指定技能。
if [ "$HAS_ARGS" = "false" ] || { ! $ALL_MODE && ! $TUI_MODE && [ "${#TARGETS[@]}" -eq 0 ]; }; then
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
    if [ "${#CATEGORY_FILTERS[@]}" -eq 0 ]; then
        skills_menu
        exit 0
    fi
    if tui_select; then
        if [ -n "$TUI_SELECTED" ]; then
            read -r -a TARGETS <<< "$TUI_SELECTED"
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

install_selection "${TARGETS[@]}"
