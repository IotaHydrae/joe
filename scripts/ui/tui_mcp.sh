#!/usr/bin/env bash
# =============================================================================
# MCP TUI - MCP 服务器交互选择界面
# =============================================================================
# 分组显示可用 MCP、是否已在已安装的 AI CLI 里配置、以及 Node/npx 依赖状态。
# 配置检测来自 install_mcp_servers.sh --list, 本文件不重复维护 id 或检测逻辑;
# 界面占用 stdout, 选择结果写入 TUI_RESULT_FILE 回传给调用方。

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$_SCRIPT_DIR/tui_common.sh"
# shellcheck disable=SC1091
. "$_SCRIPT_DIR/../lib/node.sh"

MCP_SCRIPT="${MCP_SCRIPT:-$_SCRIPT_DIR/../install_mcp_servers.sh}"
MCP_NPX_BIN="${MCP_NPX_BIN:-npx}"

declare -a MCP_ITEMS=()
declare -a MCP_IDS=()
declare -A MCP_STATUS=()
declare -A MCP_NAME=()
declare -A MCP_PICKED=()
declare -i MCP_CURSOR=0
declare -i MCP_SCROLL=0
declare -i MCP_PAGE=15

# 代码智能服务三选一 (与 doctor 的判断一致)
CODE_INTEL=" codebase-memory-mcp codegraph serena "


# 从 --list 读取 id / 状态 / 名称, 再按展示分组排好; 未知 id 归入"其他"
load_mcps() {
    local listing id status name group
    if [ ! -f "$MCP_SCRIPT" ]; then
        printf "错误: 找不到 MCP 安装器: %s\n" "$MCP_SCRIPT" >&2
        return 1
    fi
    if ! listing=$(bash "$MCP_SCRIPT" --list 2>/dev/null); then
        printf "错误: 读取 MCP 列表失败: %s --list\n" "$MCP_SCRIPT" >&2
        return 1
    fi

    while IFS= read -r line; do
        [[ $line == "  "* ]] || continue
        read -r id status name <<< "${line#  }"
        [[ -n $id ]] || continue
        MCP_IDS+=("$id")
        MCP_NAME[$id]="${name:-$id}"
        if [[ $status == "已配置" ]]; then
            MCP_STATUS[$id]=1
        fi
    done <<< "$listing"

    if [ "${#MCP_IDS[@]}" -eq 0 ]; then
        printf "错误: 没有解析到任何 MCP 服务\n" >&2
        return 1
    fi

    local -a groups=("文件与仓库:filesystem git"
                     "记忆与文档:memory context7"
                     "代码智能（三选一）:codebase-memory-mcp codegraph serena")
    local spec placed_ids=" "
    MCP_ITEMS=()
    for spec in "${groups[@]}"; do
        group="${spec%%:*}"
        MCP_ITEMS+=("GROUP:$group")
        for id in ${spec#*:}; do
            if [ -n "${MCP_NAME[$id]:-}" ]; then
                MCP_ITEMS+=("$id")
                placed_ids+="$id "
            fi
        done
    done

    # 列表里出现但分组表没覆盖的 id 也要显示, 避免新服务被静默隐藏
    local -a leftovers=()
    for id in "${MCP_IDS[@]}"; do
        case "$placed_ids" in
            *" $id "*) ;;
            *) leftovers+=("$id") ;;
        esac
    done
    if [ "${#leftovers[@]}" -gt 0 ]; then
        MCP_ITEMS+=("GROUP:其他")
        for id in "${leftovers[@]}"; do
            MCP_ITEMS+=("$id")
        done
    fi
    return 0
}

picked_count() {
    local n=0 id
    for id in "${!MCP_PICKED[@]}"; do
        [[ -n ${MCP_PICKED[$id]:-} ]] && n=$((n + 1))
    done
    printf '%d' "$n"
}

is_code_intel() {
    case "$CODE_INTEL" in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

draw_row() {
    local idx="$1" is_cursor="$2"
    local item="${MCP_ITEMS[$idx]}"
    local prefix="  " attr=""

    if [[ $item == GROUP:* ]]; then
        if [[ $is_cursor -eq 1 ]]; then
            printf "${COLOR_BOLD}${COLOR_CYAN}> %s${COLOR_RESET}\n" "${item#GROUP:}"
        else
            printf "${COLOR_DIM}  %s${COLOR_RESET}\n" "${item#GROUP:}"
        fi
        return
    fi

    local box=" " mark=" " name="${MCP_NAME[$item]:-}"
    local extra=""
    [[ -n ${MCP_PICKED[$item]:-} ]] && box="${COLOR_CYAN}x${COLOR_RESET}"
    if [ -n "${MCP_STATUS[$item]:-}" ]; then
        mark="${COLOR_GREEN}●${COLOR_RESET}"
        extra="${COLOR_DIM}已配置${COLOR_RESET}"
    else
        mark="${COLOR_GRAY}○${COLOR_RESET}"
    fi
    if is_code_intel "$item"; then
        extra+="${COLOR_YELLOW} [三选一]${COLOR_RESET}"
    fi

    [[ $is_cursor -eq 1 ]] && prefix="> "
    printf "%b%-2s[%b] %b %-24s %b\n" "$attr" "$prefix" "$box" "$mark" "$name" "$extra"
}

draw_list() {
    local start=$MCP_SCROLL end=$((MCP_SCROLL + MCP_PAGE)) total=${#MCP_ITEMS[@]} i
    cursor_to 4 1
    for ((i = start; i < end && i < total; i++)); do
        [[ $i -eq $MCP_CURSOR ]] && draw_row "$i" 1 || draw_row "$i" 0
    done
    for ((i = 0; i < MCP_PAGE - (total - start); i++)); do
        clear_line
        printf "\n"
    done
}

draw_status() {
    local count deps code_picks=0 id
    count=$(picked_count)
    for id in "${!MCP_PICKED[@]}"; do
        is_code_intel "$id" && code_picks=$((code_picks + 1))
    done

    cursor_to $((TERM_ROWS - 3)) 1
    printf "${COLOR_DIM}"
    draw_line "━"
    printf "${COLOR_RESET}"

    if node_has_bin "$MCP_NPX_BIN"; then
        printf "Node/npx: ${COLOR_GREEN}可用${COLOR_RESET}"
    else
        printf "Node/npx: ${COLOR_RED}缺失${COLOR_RESET} (安装 MCP 前需 tools install node)"
    fi

    if [[ $count -eq 0 ]]; then
        printf " | 未选择\n"
    else
        printf " | 已选 ${COLOR_CYAN}%d${COLOR_RESET} 项" "$count"
        if [[ $code_picks -gt 1 ]]; then
            printf " ${COLOR_YELLOW}(代码智能选了 %d 个, 建议三选一)${COLOR_RESET}" "$code_picks"
        fi
        printf "\n"
    fi

    printf "${COLOR_DIM}"
    draw_line "━"
    printf "↑/↓:移动 PgUp/PgDn:翻页 Space:勾选 a:全选 n:清空 i:仅未配置 Enter:确认 q:退出\n"
    draw_line "━"
    printf "${COLOR_RESET}"
}

move_cursor() {
    local dir="$1" total=${#MCP_ITEMS[@]} i
    case "$dir" in
        up)
            ((MCP_CURSOR > 0)) && MCP_CURSOR=$((MCP_CURSOR - 1))
            while [[ $MCP_CURSOR -gt 0 && ${MCP_ITEMS[$MCP_CURSOR]} == GROUP:* ]]; do
                MCP_CURSOR=$((MCP_CURSOR - 1))
            done
            ;;
        down)
            ((MCP_CURSOR < total - 1)) && MCP_CURSOR=$((MCP_CURSOR + 1))
            while [[ $MCP_CURSOR -lt $((total - 1)) && ${MCP_ITEMS[$MCP_CURSOR]} == GROUP:* ]]; do
                MCP_CURSOR=$((MCP_CURSOR + 1))
            done
            ;;
        pgup)
            MCP_CURSOR=$((MCP_CURSOR - MCP_PAGE))
            ((MCP_CURSOR < 0)) && MCP_CURSOR=0
            while [[ $MCP_CURSOR -gt 0 && ${MCP_ITEMS[$MCP_CURSOR]} == GROUP:* ]]; do
                MCP_CURSOR=$((MCP_CURSOR - 1))
            done
            ;;
        pgdown)
            MCP_CURSOR=$((MCP_CURSOR + MCP_PAGE))
            ((MCP_CURSOR >= total)) && MCP_CURSOR=$((total - 1))
            while [[ $MCP_CURSOR -lt $((total - 1)) && ${MCP_ITEMS[$MCP_CURSOR]} == GROUP:* ]]; do
                MCP_CURSOR=$((MCP_CURSOR + 1))
            done
            ;;
        home)
            MCP_CURSOR=0
            while [[ ${MCP_ITEMS[$MCP_CURSOR]} == GROUP:* ]]; do
                MCP_CURSOR=$((MCP_CURSOR + 1))
            done
            ;;
        end)
            MCP_CURSOR=$((total - 1))
            while [[ $MCP_CURSOR -gt 0 && ${MCP_ITEMS[$MCP_CURSOR]} == GROUP:* ]]; do
                MCP_CURSOR=$((MCP_CURSOR - 1))
            done
            ;;
    esac

    if [[ $MCP_CURSOR -lt $MCP_SCROLL ]]; then
        MCP_SCROLL=$MCP_CURSOR
    elif [[ $MCP_CURSOR -ge $((MCP_SCROLL + MCP_PAGE)) ]]; then
        MCP_SCROLL=$((MCP_CURSOR - MCP_PAGE + 1))
    fi
    # 滚动起点落在分组标题上时下移一行, 避免整屏只显示标题
    if [[ ${MCP_ITEMS[$MCP_SCROLL]} == GROUP:* && $MCP_SCROLL -lt $MCP_CURSOR ]]; then
        MCP_SCROLL=$((MCP_SCROLL + 1))
    fi
}

toggle_pick() {
    local item="${MCP_ITEMS[$MCP_CURSOR]}"
    [[ $item == GROUP:* ]] && return
    if [[ -n ${MCP_PICKED[$item]:-} ]]; then
        unset "MCP_PICKED[$item]"
    else
        MCP_PICKED[$item]=1
    fi
}

bulk_pick() {
    local mode="$1" item
    for item in "${MCP_ITEMS[@]}"; do
        [[ $item == GROUP:* ]] && continue
        case "$mode" in
            all) MCP_PICKED[$item]=1 ;;
            none) unset "MCP_PICKED[$item]" ;;
            unconfigured)
                if [ -n "${MCP_STATUS[$item]:-}" ]; then
                    unset "MCP_PICKED[$item]"
                else
                    MCP_PICKED[$item]=1
                fi
                ;;
        esac
    done
}

run_mcp_tui() {
    if ! tui_available; then
        printf "错误: TUI 需要交互式终端\n" >&2
        return 2
    fi

    get_terminal_size
    MCP_PAGE=$((TERM_ROWS - 10))
    ((MCP_PAGE < 1)) && MCP_PAGE=1

    printf "正在检测已配置的 MCP...\n"
    if ! load_mcps; then
        return 2
    fi

    local old_stty
    old_stty=$(stty -g)
    # 正常退出、Ctrl-C 或被杀都要恢复回显与光标
    trap 'printf "\033[?25h"; stty "$old_stty" 2>/dev/null || true' EXIT
    trap 'printf "\033[?25h"; stty "$old_stty" 2>/dev/null || true; exit 130' INT TERM
    stty -echo -icanon -icrnl -ixon min 1 time 0

    cursor_hide
    clear_screen
    draw_header "MCP 服务器选择"
    printf "\n"

    local running=true key
    while $running; do
        draw_list
        draw_status
        key=$(read_key)
        case "$key" in
            up|down|pgup|pgdown|home|end) move_cursor "$key" ;;
            space) toggle_pick ;;
            a) bulk_pick all ;;
            n) bulk_pick none ;;
            i) bulk_pick unconfigured ;;
            enter) running=false ;;
            q|esc) MCP_PICKED=(); running=false ;;
        esac
    done

    cursor_show
    stty "$old_stty"
    trap - EXIT INT TERM
    clear_screen
    printf '\n'

    if [[ ${#MCP_PICKED[@]} -eq 0 ]]; then
        return 1
    fi

    if [[ -n ${TUI_RESULT_FILE:-} ]]; then
        printf '%s\n' "${!MCP_PICKED[@]}" > "$TUI_RESULT_FILE"
    else
        printf '%s\n' "${!MCP_PICKED[@]}"
    fi
    return 0
}

# 直接运行时的自检入口 (需要真实终端)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_mcp_tui
    if [[ ${#MCP_PICKED[@]} -gt 0 ]]; then
        printf "选择的 MCP: %s\n" "${!MCP_PICKED[*]}"
    else
        printf "未选择任何 MCP\n"
    fi
fi
