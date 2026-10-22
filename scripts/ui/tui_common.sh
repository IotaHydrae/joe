#!/usr/bin/env bash
# =============================================================================
# TUI 通用函数库
# =============================================================================
# 提供终端 UI 的基础功能：颜色、光标控制、输入处理等

# 颜色与样式
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_DIM='\033[2m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_GRAY='\033[0;90m'

# 光标控制
cursor_hide() { printf '\033[?25l'; }
cursor_show() { printf '\033[?25h'; }
cursor_to() { printf '\033[%d;%dH' "$1" "$2"; }
clear_screen() { printf '\033[2J\033[H'; }
clear_line() { printf '\033[2K'; }

# 获取终端尺寸
get_terminal_size() {
    local size
    size=$(stty size 2>/dev/null) || size="24 80"
    TERM_ROWS=${size%% *}
    TERM_COLS=${size##* }
}

# 检查 TUI 是否可用
tui_available() {
    [ -t 0 ] && [ -t 1 ] && command -v stty >/dev/null 2>&1
}

# 进入 raw 模式; 正常退出、Ctrl-C 或被杀都要恢复回显与光标
tui_enter_raw() {
    TUI_OLD_STTY=$(stty -g)
    trap 'tui_restore_term' EXIT
    trap 'tui_restore_term; exit 130' INT TERM
    # -icrnl: 回车保持 CR, 否则 LF 会被命令替换剥掉, 永远收不到 Enter
    # -ixon: 避免 Ctrl-Q/S 流量控制吞掉按键
    stty -echo -icanon -icrnl -ixon min 1 time 0
}

tui_restore_term() {
    cursor_show
    stty "$TUI_OLD_STTY" 2>/dev/null || true
}

tui_leave_raw() {
    tui_restore_term
    trap - EXIT INT TERM
}

# TUI 渲染占用 stdout, 选择结果只能经临时文件回传: 命令替换会把整屏 ANSI
# 输出一起捕获, 当成安装参数就是垃圾。$1 是 TUI 脚本, 其余参数按 VAR=值 传入。
# 结果行存入全局 TUI_PICKS, 返回 TUI 的退出码。
collect_tui_selection() {
    local script="$1" rc=0 file line
    shift
    TUI_PICKS=()
    file=$(mktemp)
    trap 'rm -f "$file"' EXIT
    TUI_RESULT_FILE="$file" env "$@" bash "$script" || rc=$?
    while IFS= read -r line; do
        if [[ -n $line ]]; then
            TUI_PICKS+=("$line")
        fi
    done < "$file"
    rm -f "$file"
    trap - EXIT
    return "$rc"
}

# 绘制水平线
draw_line() {
    local char="${1:-─}" width="${2:-$TERM_COLS}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# 绘制标题
draw_header() {
    local title="$1"
    printf "${COLOR_BOLD}${COLOR_CYAN}"
    draw_line "━"
    printf "%*s\n" $(( (TERM_COLS + ${#title}) / 2 )) "$title"
    draw_line "━"
    printf "${COLOR_RESET}"
}

# 读取单个按键（支持方向键、ESC 序列）
read_key() {
    local key escape1 escape2
    # 用 dd 而非 read -n1: read 把 CR/LF 当行终止符, 取不到回车按键
    key=$(dd bs=1 count=1 2>/dev/null)

    # ESC 序列检测
    if [[ $key == $'\x1b' ]]; then
        read -rsn2 -t 0.01 escape1
        case "$escape1" in
            '[A') key='up' ;;
            '[B') key='down' ;;
            '[C') key='right' ;;
            '[D') key='left' ;;
            '[5') read -rsn1 -t 0.01 escape2; [[ $escape2 == '~' ]] && key='pgup' ;;
            '[6') read -rsn1 -t 0.01 escape2; [[ $escape2 == '~' ]] && key='pgdown' ;;
            '[H'|'[1~') key='home' ;;
            '[F'|'[4~') key='end' ;;
            '') key='esc' ;;
            *) key='unknown' ;;
        esac
    fi

    # 特殊字符转换
    case "$key" in
        $'\x0a'|$'\x0d') key='enter' ;;
        $'\x7f'|$'\x08') key='backspace' ;;
        $'\x09') key='tab' ;;
        ' ') key='space' ;;
    esac

    printf '%s' "$key"
}

# 导出函数供其他脚本使用
export -f cursor_hide cursor_show cursor_to clear_screen clear_line
export -f get_terminal_size tui_available draw_line draw_header
export -f read_key collect_tui_selection
