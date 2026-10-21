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
cursor_up() { printf '\033[%dA' "${1:-1}"; }
cursor_down() { printf '\033[%dB' "${1:-1}"; }
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

# 绘制底部帮助栏
draw_footer() {
    local help_text="$1"
    printf "${COLOR_DIM}"
    draw_line "━"
    printf "%s\n" "$help_text"
    draw_line "━"
    printf "${COLOR_RESET}"
}

# 状态指示符
status_mark() {
    case "$1" in
        installed) printf "${COLOR_GREEN}✓${COLOR_RESET}" ;;
        not_installed) printf " " ;;
        selected) printf "${COLOR_CYAN}●${COLOR_RESET}" ;;
        dependency) printf "${COLOR_YELLOW}↳${COLOR_RESET}" ;;
        *) printf " " ;;
    esac
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

# 确认对话框
confirm_dialog() {
    local prompt="$1" default="${2:-y}"
    local answer

    if [[ $default == "y" ]]; then
        printf "${COLOR_YELLOW}%s [Y/n]: ${COLOR_RESET}" "$prompt"
    else
        printf "${COLOR_YELLOW}%s [y/N]: ${COLOR_RESET}" "$prompt"
    fi

    read -r answer
    answer=${answer:-$default}

    [[ $answer =~ ^[Yy]$ ]]
}

# 消息框
msg_box() {
    local type="$1" message="$2"
    local color

    case "$type" in
        info) color="$COLOR_BLUE" ;;
        success) color="$COLOR_GREEN" ;;
        warning) color="$COLOR_YELLOW" ;;
        error) color="$COLOR_RED" ;;
        *) color="$COLOR_RESET" ;;
    esac

    printf "${color}[${type^^}]${COLOR_RESET} %s\n" "$message"
}

# 进度指示器
show_spinner() {
    local pid=$1
    local message="${2:-处理中}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    cursor_hide
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${COLOR_CYAN}%s${COLOR_RESET} %s" \
            "${spin:i++%${#spin}:1}" "$message"
        sleep 0.1
    done
    printf "\r%*s\r" $((${#message} + 3)) ""
    cursor_show
}

# 导出函数供其他脚本使用
export -f cursor_hide cursor_show cursor_to clear_screen clear_line
export -f get_terminal_size tui_available draw_line draw_header draw_footer
export -f status_mark read_key confirm_dialog msg_box show_spinner
