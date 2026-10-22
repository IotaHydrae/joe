#!/usr/bin/env bash
# =============================================================================
# Tools TUI - 开发工具交互选择界面
# =============================================================================

# 加载依赖
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$_SCRIPT_DIR/tui_common.sh"
# shellcheck disable=SC1091
. "$_SCRIPT_DIR/../lib/deps.sh"

# TUI 状态
declare -a TUI_ITEMS=()
declare -A TUI_SELECTED=()
declare -i TUI_CURSOR=0
declare -i TUI_SCROLL=0
declare -i TUI_PAGE_SIZE=15

# 初始化 TUI 项目列表
init_tui_items() {
    local group comp

    TUI_ITEMS=()
    for group in "${COMPONENT_GROUP_ORDER[@]}"; do
        TUI_ITEMS+=("GROUP:${COMPONENT_GROUP_NAMES[$group]:-}")
        for comp in ${COMPONENT_GROUPS[$group]:-}; do
            TUI_ITEMS+=("$comp")
        done
    done
}

# 绘制单个项目行
draw_item() {
    local idx="$1"
    local item="${TUI_ITEMS[$idx]:-}"
    local is_cursor=$2

    # 分组标题
    if [[ $item == GROUP:* ]]; then
        local group_name="${item#GROUP:}"
        if [[ $is_cursor -eq 1 ]]; then
            printf "${COLOR_BOLD}${COLOR_CYAN}> %s${COLOR_RESET}\n" "$group_name"
        else
            printf "${COLOR_DIM}  %s${COLOR_RESET}\n" "$group_name"
        fi
        return
    fi

    # 普通组件
    local checkbox=" "
    local status_icon=" "
    local version=""
    local deps=""
    local name="${COMPONENT_NAMES[$item]:-}"

    # 选中标记
    [[ -n ${TUI_SELECTED[$item]:-} ]] && checkbox="${COLOR_CYAN}✓${COLOR_RESET}"

    # 安装状态
    if is_installed "$item"; then
        status_icon="${COLOR_GREEN}●${COLOR_RESET}"
        version=$(get_version "$item")
        [[ -n $version ]] && version=" ${COLOR_DIM}v$version${COLOR_RESET}"
    else
        status_icon="${COLOR_GRAY}○${COLOR_RESET}"
    fi

    # 依赖标记
    local item_deps
    item_deps=$(get_deps "$item")
    if [[ -n $item_deps ]]; then
        deps=" ${COLOR_YELLOW}[需要:$item_deps]${COLOR_RESET}"
    fi

    # 光标高亮
    if [[ $is_cursor -eq 1 ]]; then
        printf "${COLOR_BOLD}> [%b] %b %-20s%b%b${COLOR_RESET}\n" \
            "$checkbox" "$status_icon" "$name" "$version" "$deps"
    else
        printf "  [%b] %b %-20s%b%b\n" \
            "$checkbox" "$status_icon" "$name" "$version" "$deps"
    fi
}

# 绘制完整列表
draw_list() {
    local visible_start=$TUI_SCROLL
    local visible_end=$((TUI_SCROLL + TUI_PAGE_SIZE))
    local total=${#TUI_ITEMS[@]}

    cursor_to 4 1

    for ((i=visible_start; i<visible_end && i<total; i++)); do
        local is_cursor=0
        [[ $i -eq $TUI_CURSOR ]] && is_cursor=1
        draw_item "$i" "$is_cursor"
    done

    # 清除剩余行
    for ((i=0; i<TUI_PAGE_SIZE - (total - visible_start); i++)); do
        clear_line
        printf "\n"
    done
}

# 绘制底部状态栏
draw_status() {
    local selected_count=0
    local -a selected_list=()
    local -a missing_deps=()

    for item in "${TUI_ITEMS[@]}"; do
        [[ $item == GROUP:* ]] && continue
        if [[ -n ${TUI_SELECTED[$item]:-} ]]; then
            ((selected_count++))
            selected_list+=("$item")
        fi
    done

    # 检查依赖
    if [[ $selected_count -gt 0 ]]; then
        for item in "${selected_list[@]}"; do
            local deps
            deps=$(get_deps "$item")
            for dep in $deps; do
                if [[ -z ${TUI_SELECTED[$dep]:-} ]] && ! is_installed "$dep"; then
                    missing_deps+=("$dep")
                fi
            done
        done
    fi

    cursor_to $((TERM_ROWS - 3)) 1
    printf "${COLOR_DIM}"
    draw_line "━"
    printf "${COLOR_RESET}"

    if [[ $selected_count -eq 0 ]]; then
        printf "未选择任何组件\n"
    else
        printf "已选: ${COLOR_CYAN}%d${COLOR_RESET} 项 (" "$selected_count"
        printf "%s" "${selected_list[0]}"
        for ((i=1; i<${#selected_list[@]} && i<3; i++)); do
            printf ", %s" "${selected_list[$i]:-}"
        done
        [[ ${#selected_list[@]} -gt 3 ]] && printf ", ..."
        printf ")"

        # 依赖警告
        if [[ ${#missing_deps[@]} -gt 0 ]]; then
            local -A unique_deps=()
            for dep in "${missing_deps[@]}"; do
                unique_deps[$dep]=1
            done
            printf " ${COLOR_YELLOW}| 需要安装依赖: %s${COLOR_RESET}" "${!unique_deps[*]}"
        fi
        printf "\n"
    fi

    printf "${COLOR_DIM}"
    draw_line "━"
    printf "↑/↓:移动  Space:勾选  a:全选  n:全不选  i:仅未装  /:搜索  Enter:确认  q:退出\n"
    draw_line "━"
    printf "${COLOR_RESET}"
}

# 移动光标
move_cursor() {
    local direction="$1"
    local old_cursor=$TUI_CURSOR
    local total=${#TUI_ITEMS[@]}

    case "$direction" in
        up)
            ((TUI_CURSOR > 0)) && ((TUI_CURSOR--))
            # 跳过分组标题
            while [[ $TUI_CURSOR -gt 0 && ${TUI_ITEMS[$TUI_CURSOR]:-} == GROUP:* ]]; do
                ((TUI_CURSOR--))
            done
            ;;
        down)
            ((TUI_CURSOR < total - 1)) && ((TUI_CURSOR++))
            # 跳过分组标题
            while [[ $TUI_CURSOR -lt $((total - 1)) && ${TUI_ITEMS[$TUI_CURSOR]:-} == GROUP:* ]]; do
                ((TUI_CURSOR++))
            done
            ;;
        pgup)
            ((TUI_CURSOR -= 5))
            ((TUI_CURSOR < 0)) && TUI_CURSOR=0
            while [[ $TUI_CURSOR -gt 0 && ${TUI_ITEMS[$TUI_CURSOR]:-} == GROUP:* ]]; do
                ((TUI_CURSOR--))
            done
            ;;
        pgdown)
            ((TUI_CURSOR += 5))
            ((TUI_CURSOR >= total)) && TUI_CURSOR=$((total - 1))
            while [[ $TUI_CURSOR -lt $((total - 1)) && ${TUI_ITEMS[$TUI_CURSOR]:-} == GROUP:* ]]; do
                ((TUI_CURSOR++))
            done
            ;;
        home)
            TUI_CURSOR=0
            while [[ ${TUI_ITEMS[$TUI_CURSOR]:-} == GROUP:* ]]; do
                ((TUI_CURSOR++))
            done
            ;;
        end)
            TUI_CURSOR=$((total - 1))
            while [[ ${TUI_ITEMS[$TUI_CURSOR]:-} == GROUP:* ]]; do
                ((TUI_CURSOR--))
            done
            ;;
    esac

    # 调整滚动
    if [[ $TUI_CURSOR -lt $TUI_SCROLL ]]; then
        TUI_SCROLL=$TUI_CURSOR
    elif [[ $TUI_CURSOR -ge $((TUI_SCROLL + TUI_PAGE_SIZE)) ]]; then
        TUI_SCROLL=$((TUI_CURSOR - TUI_PAGE_SIZE + 1))
    fi
}

# 切换选中状态
toggle_selection() {
    local item="${TUI_ITEMS[$TUI_CURSOR]:-}"
    [[ $item == GROUP:* ]] && return

    if [[ -n ${TUI_SELECTED[$item]:-} ]]; then
        unset "TUI_SELECTED[$item]"
    else
        TUI_SELECTED[$item]=1
    fi
}

# 全选/全不选/仅未装
bulk_selection() {
    local mode="$1"

    for item in "${TUI_ITEMS[@]}"; do
        [[ $item == GROUP:* ]] && continue

        case "$mode" in
            all)
                TUI_SELECTED[$item]=1
                ;;
            none)
                unset "TUI_SELECTED[$item]"
                ;;
            uninstalled)
                if ! is_installed "$item"; then
                    TUI_SELECTED[$item]=1
                else
                    unset "TUI_SELECTED[$item]"
                fi
                ;;
            installed)
                if is_installed "$item"; then
                    TUI_SELECTED[$item]=1
                else
                    unset "TUI_SELECTED[$item]"
                fi
                ;;
        esac
    done
}

# 主 TUI 循环
run_tools_tui() {
    if ! tui_available; then
        printf "错误: TUI 需要交互式终端\n" >&2
        return 1
    fi

    get_terminal_size
    TUI_PAGE_SIZE=$((TERM_ROWS - 10))

    init_tui_items

    # 设置终端
    tui_enter_raw

    cursor_hide
    clear_screen

    # 绘制标题
    draw_header "开发工具安装器"
    printf "\n"

    # 主循环
    local running=true
    while $running; do
        draw_list
        draw_status

        local key
        key=$(read_key)

        case "$key" in
            up|down|pgup|pgdown|home|end)
                move_cursor "$key"
                ;;
            space)
                toggle_selection
                ;;
            a)
                bulk_selection all
                ;;
            n)
                bulk_selection none
                ;;
            i)
                bulk_selection uninstalled
                ;;
            d)
                bulk_selection installed
                ;;
            enter)
                running=false
                ;;
            q|esc)
                TUI_SELECTED=()
                running=false
                ;;
        esac
    done

    # 恢复终端
    tui_leave_raw

    # 界面渲染占用 stdout, 选择结果写入 TUI_RESULT_FILE 回传给调用方
    if [[ ${#TUI_SELECTED[@]} -eq 0 ]]; then
        return 1
    fi

    if [[ -n ${TUI_RESULT_FILE:-} ]]; then
        printf '%s\n' "${!TUI_SELECTED[@]}" > "$TUI_RESULT_FILE"
    else
        printf '%s\n' "${!TUI_SELECTED[@]}"
    fi
    return 0
}

# 直接运行时的自检入口 (需要真实终端)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tools_tui
    if [[ ${#TUI_SELECTED[@]} -gt 0 ]]; then
        printf "选择的组件: %s\n" "${!TUI_SELECTED[*]}"
    else
        printf "未选择任何组件\n"
    fi
fi
