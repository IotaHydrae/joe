#!/usr/bin/env bash
# =============================================================================
# Skills 命令 - 新旧语法转换层
# =============================================================================
# 技能发现、分类校验与安装逻辑仍在 scripts/install_skills.sh,
# 本文件不重复维护技能或分类清单。

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SKILLS_SCRIPT 可由测试环境覆盖为 stub
SKILLS_SCRIPT="${SKILLS_SCRIPT:-$_SCRIPT_DIR/../install_skills.sh}"

usage() {
    cat <<'EOF'
用法: skills <动作> [选项] [技能...]

动作:
    <无参数>              进入技能组 / 分类选择
    list, status          列出技能及安装状态
    categories            列出分类及技能数量
    install <技能...>     安装指定技能 (可配 --category / --all)
    update [技能...]      重跑安装器刷新符号链接
    tui                   强制进入 TUI

选项:
    --project <目录>      目标项目 (安装/更新/列出必需; 技能装到该项目的 .agents/skills)

旧语法 (--list / --categories / --category <name> / --tui / --all / 位置技能名)
原样转发给安装器, 完整选项见: skills --help

EOF
}

forward() {
    [ -f "$SKILLS_SCRIPT" ] || {
        printf "错误: 找不到技能安装器: %s\n" "$SKILLS_SCRIPT" >&2
        exit 1
    }
    exec bash "$SKILLS_SCRIPT" "$@"
}

# 动作词只在开头 (或紧跟 --project <dir> 之后) 才是新语法动作;
# 出现在 --category/--tui/--list 等旧语法选项中间时原样透传, 不当作动作。
ACTION=""
REST=("$@")
case "${1:-}" in
    list|status|categories|install|update|tui)
        ACTION="$1"
        REST=("${@:2}")
        ;;
    --project)
        # --project <dir> 之后若紧跟动作词, 视为新语法动作
        case "${3:-}" in
            list|status|categories|install|update|tui)
                ACTION="$3"
                REST=("$1" "$2" "${@:4}")
                ;;
        esac
        ;;
esac

case "$ACTION" in
    '')          forward "$@" ;;
    list|status) forward --list "${REST[@]}" ;;
    categories)  forward --categories "${REST[@]}" ;;
    tui)         forward --tui "${REST[@]}" ;;
    install|update)
        forward "${REST[@]}"
        ;;
esac
