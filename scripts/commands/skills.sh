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

ACTION="${1:-}"

# 仅识别新动作词; 其余参数原样转发
case "$ACTION" in
    '')          forward ;;
    -h|--help)   usage; forward --help ;;
    list|status) shift; forward --list "$@" ;;
    categories)  shift; forward --categories "$@" ;;
    tui)         forward --tui ;;
    install|update)
        shift
        forward "$@"
        ;;
    *)           forward "$@" ;;
esac
