#!/usr/bin/env bash
# =============================================================================
# Joe 主菜单
# =============================================================================
# 由 install.sh 的 menu 分支调用, 需要交互式终端。
# 子动作通过 install.sh 自身的命令路由执行, 因此菜单与命令行用的是同一条路径,
# 不存在第二份命令表需要同步。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"

# shellcheck disable=SC1091
. "$SCRIPTS_DIR/lib/deps.sh"
# shellcheck disable=SC1091
. "$SCRIPTS_DIR/lib/mcp.sh"
# shellcheck disable=SC1091
. "$SCRIPTS_DIR/lib/node.sh"
# shellcheck disable=SC1091
. "$SCRIPTS_DIR/ui/tui_common.sh"

# 交给 install.sh 路由; 非零退出码只提示, 不让菜单结束
run_action() {
    local status=0
    bash "$ROOT_DIR/install.sh" "$@" || status=$?
    if [[ $status -ne 0 ]]; then
        printf "\n${COLOR_YELLOW}操作返回退出码 %d, 回到菜单。${COLOR_RESET}\n\n" "$status"
    else
        printf '\n操作完成, 返回菜单。\n'
    fi
}

# 安装子菜单共用编号、状态、全部安装和返回操作。
install_menu() {
    local title="$1" domain="$2"
    shift 2
    local -a ids=("$@") selected=()
    local choice i comp name status total all_idx
    local refresh=true
    while true; do
        if [[ $domain == mcp ]] && $refresh; then
            load_mcp_catalog || return 0
            ids=("${MCP_IDS[@]}")
            refresh=false
        fi
        total=${#ids[@]}
        all_idx=$((total + 1))
        printf '\n── %s ──\n' "$title"
        for ((i=0; i<total; i++)); do
            comp="${ids[i]}"
            status=""
            if [[ $domain == mcp ]]; then
                name="${MCP_NAME[$comp]:-$comp}"
                if [[ -n ${MCP_STATUS[$comp]:-} ]]; then
                    status=" (已配置)"
                fi
                if is_code_intel "$comp"; then
                    status+=" [三选一]"
                fi
            else
                name="${COMPONENT_NAMES[$comp]:-$comp}"
                if is_installed "$comp"; then
                    status=" (已安装)"
                fi
            fi
            printf '  %d) 安装 %s%s\n' "$((i+1))" "$name" "$status"
        done
        printf '  %d) 全部安装\n' "$all_idx"
        printf '  b) 返回主菜单\n'
        if [[ $domain == mcp ]]; then
            if node_has_bin "${MCP_NPX_BIN:-npx}"; then
                printf '\nNode/npx: 可用\n'
            else
                printf '\nNode/npx: 缺失 (请先运行 ./install.sh tools install node)\n'
            fi
            printf '代码智能 MCP 建议三选一。\n'
        fi
        printf '选择操作 [1-%d/b]: ' "$all_idx"
        IFS= read -r choice || return 0
        case "$choice" in
            b|B|q|Q) return 0 ;;
            '') continue ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
                        selected=("${ids[$((10#$choice-1))]}")
                    elif [ "$choice" -eq "$all_idx" ]; then
                        selected=("${ids[@]}")
                    else
                        printf '请输入有效编号或 b。\n'
                        continue
                    fi
                    if [[ $domain == mcp ]]; then
                        if ! node_has_bin "${MCP_NPX_BIN:-npx}"; then
                            printf 'MCP 安装需要 Node/npx, 请先运行: ./install.sh tools install node\n' >&2
                            continue
                        fi
                        run_action mcp install "${selected[@]}"
                        refresh=true
                    else
                        run_action tools install --with-deps "${selected[@]}"
                    fi
                else
                    printf '请输入有效编号或 b。\n'
                fi
                ;;
        esac
    done
}

apps_menu() {
    install_menu "日常软件安装" tools "${DAILY_IDS[@]}"
}

tools_menu() {
    local group comp
    local -a ids=()
    for group in "${COMPONENT_GROUP_ORDER[@]}"; do
        for comp in ${COMPONENT_GROUPS[$group]:-}; do
            ids+=("$comp")
        done
    done
    install_menu "开发工具安装" tools "${ids[@]}"
}

mcp_menu() {
    install_menu "MCP 服务器安装" mcp
}

config_menu() {
    local choice
    while true; do
        printf '\n── 配置备份与恢复 ──\n'
        printf '  1) 查看配置映射\n  2) 预览导出脱敏结果\n  3) 导出本机配置到仓库\n'
        printf '  4) 从仓库恢复配置 (备份现有文件)\n  5) 对比配置\n  b) 返回主菜单\n'
        printf '选择操作 [1-5/b]: '
        IFS= read -r choice || return 0
        case "$choice" in
            1) run_action config list ;;
            2) run_action config export --check ;;
            3) run_action config export ;;
            4) run_action config import ;;
            5) run_action config diff ;;
            b|B|q|Q) return 0 ;;
            '') continue ;;
            *) printf '请输入有效编号或 b。\n' ;;
        esac
    done
}

main_menu() {
    local choice
    while true; do
        printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        printf '        Joe 开发环境配置\n'
        printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n'
        printf '  1) 终端美化      zsh + Oh My Zsh\n'
        printf '  2) 日常软件      浏览器 / 微信 / QQ / Rime输入法\n'
        printf '  3) 开发工具      Node/Python/AI CLI/编辑器\n'
        printf '  4) MCP 服务器    代码智能/文件系统/浏览器\n'
        printf '  5) 代理技能      技能组与分类选择\n'
        printf '\n'
        printf '  6) 安装状态      工具 / MCP / 技能汇总\n'
        printf '  7) 环境体检      doctor 逐项诊断\n'
        printf '  8) 配置管理      备份/恢复/同步\n'
        printf '  9) 统一更新      各工具官方自更新\n'
        printf '\n'
        printf '  10) 新手引导     quick-start 推荐配置\n'
        printf '\n'
        printf '  q) 退出\n\n'
        printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        printf '选择 [1-10/q]: '

        IFS= read -r choice || return 0
        case "$choice" in
            1) run_action shell ;;
            2) apps_menu ;;
            3) tools_menu ;;
            4) mcp_menu ;;
            5) run_action skills ;;
            6) run_action status ;;
            7) run_action doctor ;;
            8) config_menu ;;
            9) run_action update ;;
            10) run_action quick-start ;;
            q|Q) return 0 ;;
            '') continue ;;
            *) printf '请输入有效编号或 q。\n' ;;
        esac
    done
}

main_menu
