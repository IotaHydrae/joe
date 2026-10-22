#!/usr/bin/env bash
# =============================================================================
# Status 命令 - 一屏汇总各域安装状态
# =============================================================================
# 只做计数; 逐项诊断与修复建议用 `./install.sh doctor`。
# 状态取自各安装器自己的 --list 输出, 不在此重复维护检测逻辑。
#
# 用法:
#   status            汇总 工具 / MCP / 技能
#   status --short    单行输出, 便于脚本使用
#
# 退出码: 0 = 各域都读到了状态; 1 = 有域的 --list 失败 (显示为 n/a)

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$_SCRIPT_DIR/../lib/deps.sh"
# shellcheck disable=SC1091
. "$_SCRIPT_DIR/../ui/tui_common.sh"

# 多字节文本按"字符"处理 (POSIX locale 下 printf 按字节补宽, 中英混排会错位)
if [ -z "${LC_ALL:-}" ]; then
    for _loc in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
        if locale -a 2>/dev/null | grep -qix "$_loc"; then
            export LC_ALL="$_loc"
            break
        fi
    done
    unset _loc
fi

# 两个 *_SCRIPT 可由测试环境覆盖为 stub
MCP_SCRIPT="${MCP_SCRIPT:-$_SCRIPT_DIR/../install_mcp_servers.sh}"
SKILLS_SCRIPT="${SKILLS_SCRIPT:-$_SCRIPT_DIR/../install_skills.sh}"

usage() {
    cat <<'EOF'
用法: status [--short]

    --short    单行输出 (tools 8/15 | mcp 4/7 | skills 12/150)
    -h         显示此帮助

细节诊断: ./install.sh doctor
EOF
}

# 只统计状态列命中两种取值的行; 安装器 --list 结尾的其它段落 (如安装位置) 不计入
# 安装器失败时返回 n/a, 不能把 "n/a" 拼接到已经算出的计数后面
count_installed() {
    local yes="$1" no="$2" script="$3" listing
    if [ ! -f "$script" ]; then
        printf "n/a"
        return 0
    fi
    if ! listing=$(bash "$script" --list 2>/dev/null); then
        printf "n/a"
        return 0
    fi
    awk -v yes="$yes" -v no="$no" '
        /^  [^ ]/ { if ($2 == yes) { done++; total++ } else if ($2 == no) total++ }
        END { printf "%d/%d", done + 0, total + 0 }' <<< "$listing"
}

SHORT=false
for arg in "$@"; do
    case "$arg" in
        --short) SHORT=true ;;
        -h|--help) usage; exit 0 ;;
        *) printf "未知选项: %s (查看 --help)\n" "$arg" >&2; exit 1 ;;
    esac
done

# 工具域直接用 deps.sh 的判定
tools="$(count_installed_tools)"
mcp="$(count_installed '已配置' '未配置' "$MCP_SCRIPT")"
skills="$(count_installed '已安装' '未安装' "$SKILLS_SCRIPT")"

rc=0
if [[ $mcp == n/a || $skills == n/a ]]; then
    rc=1
fi

if $SHORT; then
    printf 'tools %s | mcp %s | skills %s\n' "$tools" "$mcp" "$skills"
    exit "$rc"
fi

printf '\n'
printf "${COLOR_BOLD}Joe 安装状态${COLOR_RESET}\n\n"
# 标签用字面宽度补齐: printf 的 %Ns 按字符计宽, 中英混排会错位
printf '  工具   %s\n' "$tools"
printf '  MCP    %s\n' "$mcp"
printf '  技能   %s\n' "$skills"
printf "\n${COLOR_DIM}逐项诊断与修复建议: ./install.sh doctor${COLOR_RESET}\n"
if [[ $rc -ne 0 ]]; then
    printf "${COLOR_YELLOW}有域无法读取状态 (n/a): 对应安装器的 --list 执行失败${COLOR_RESET}\n"
fi
printf '\n'
exit "$rc"
