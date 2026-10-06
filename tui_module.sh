#!/usr/bin/env bash
# =============================================================================
# joe devtools — TUI 交互式组件选择器
# =============================================================================
# 由 install_devtools.sh --tui 调用。提供方向键/空格/回车选择的勾选界面。
# 已安装的组件自动检测并标记为 [已安装]（灰色、默认跳过）。
#
# 按键:
#   ↑/↓      移动光标
#   ←/→      快速翻页(未实现, 保留)
#   空格      勾选 / 取消
#   a         全选
#   n         全不选
#   i         仅选未安装
#   回车      开始安装
#   q / Esc   退出
# =============================================================================

# 仅在无 TTY 时返回错误 (由调用方决定是否回退)
tui_available() {
    [ -t 1 ] && [ -t 0 ]
}

# 每个组件: 名称 + 检测是否已安装的函数
# 返回 0 = 已安装, 1 = 未安装
tui_component_installed() {
    local id="$1"
    case "$id" in
        node)     [ -d "$HOME/.nvm" ] && command -v node >/dev/null 2>&1 ;;
        python)   [ -d "$HOME/.pyenv" ] && command -v pyenv >/dev/null 2>&1 ;;
        ai)       command -v claude >/dev/null 2>&1 && command -v codex >/dev/null 2>&1 ;;
        zed)      [ -x "$HOME/.local/bin/zed" ] || command -v zed >/dev/null 2>&1 ;;
        ghostty)  command -v ghostty >/dev/null 2>&1 ;;
        vscode)   command -v code >/dev/null 2>&1 ;;
        mimo)     command -v mimo >/dev/null 2>&1 ;;
        chatgpt)  command -v chatgpt >/dev/null 2>&1 ;;
        ccswitch) command -v cc-switch >/dev/null 2>&1 ;;
        *)        return 1 ;;
    esac
}

# 组件显示名称
tui_component_name() {
    case "$1" in
        node)     echo "Node 工具链 (nvm + LTS)" ;;
        python)   echo "Python 工具链 (pyenv + pipx)" ;;
        ai)       echo "AI CLI (Claude Code + Codex)" ;;
        zed)      echo "Zed 编辑器 + JetBrains Mono" ;;
        ghostty)  echo "Ghostty 终端 + Ctrl+Alt+T" ;;
        vscode)   echo "VS Code 编辑器" ;;
        mimo)     echo "MiMo Code (小米 AI 助手)" ;;
        chatgpt)  echo "ChatGPT / Codex 桌面版" ;;
        ccswitch) echo "CC Switch (AI CLI 配置切换器)" ;;
        *)        echo "$1" ;;
    esac
}

# 运行 TUI, 通过全局变量 TUI_SELECTED (以空格分隔的选中组件 id) 返回结果
run_tui() {
    local ids=(node python ai zed ghostty vscode mimo chatgpt ccswitch)
    local names=() inst=() sel=()
    local i

    # 预计算名称与已安装状态
    for i in "${!ids[@]}"; do
        names[$i]=$(tui_component_name "${ids[$i]}")
        if tui_component_installed "${ids[$i]}"; then
            inst[$i]=1
            sel[$i]=0   # 已安装默认不勾选 (跳过)
        else
            inst[$i]=0
            sel[$i]=1   # 未安装默认勾选
        fi
    done

    local cur=0
    local key
    local cols
    local -a selcount

    # 终端状态 (关闭 echo/规范模式/CR映射/流控, 保证 read -n1 正确读取)
    stty -echo -icanon -icrnl -ixon 2>/dev/null
    printf '\033[?25l'   # 隐藏光标

    # 读单个按键 (用 dd 保证在 pty/规范模式下也能读到 CR 等字节)
    read_key() {
        ch=$(dd bs=1 count=1 2>/dev/null)
        if [ "$ch" = $'\x1b' ]; then
            IFS= read -r -n2 ch2 2>/dev/null || true
            case "$ch2" in
                '[A') key=UP ;;
                '[B') key=DOWN ;;
                '[D') key=LEFT ;;
                '[C') key=RIGHT ;;
                *)    key=ESC ;;
            esac
        elif [ "$ch" = " " ]; then
            key=SPACE
        elif [ "$ch" = $'\n' ] || [ "$ch" = $'\r' ]; then
            key=ENTER
        elif [ "$ch" = "q" ] || [ "$ch" = "Q" ]; then
            key=Q
        elif [ "$ch" = "a" ] || [ "$ch" = "A" ]; then
            key=A
        elif [ "$ch" = "n" ] || [ "$ch" = "N" ]; then
            key=N
        elif [ "$ch" = "i" ] || [ "$ch" = "I" ]; then
            key=I
        else
            key="$ch"
        fi
    }

    # 渲染
    render() {
        printf '\033[2J\033[H'  # 清屏
        printf '\033[1;36m═══ joe devtools 组件安装选择 ═══\033[0m\n'
        printf '\033[2m↑↓移动 空格勾选 a全选 n全不选 i仅未装 回车开始 q退出\033[0m\n'
        printf '%s\n' "──────────────────────────────────────────"
        local checked=0
        for i in "${!ids[@]}"; do
            local box=" "
            if [ "${sel[$i]}" = "1" ]; then box="[x]"; else box="[ ]"; fi
            if [ "${inst[$i]}" = "1" ]; then
                # 已安装: 显示 [装] 标记, 灰色
                printf '\033[2m  %s %-3s  %s\033[0m\n' "$box" "✓装" "${names[$i]}"
            else
                if [ "$i" = "$cur" ]; then
                    printf '\033[7m> %s %-3s  %s\033[0m\n' "$box" "   " "${names[$i]}"
                else
                    printf '  %s %-3s  %s\n' "$box" "   " "${names[$i]}"
                fi
            fi
        done
        printf '%s\n' "──────────────────────────────────────────"
        checked=0
        for i in "${!sel[@]}"; do
            [ "${sel[$i]}" = "1" ] && checked=$((checked+1))
        done
        printf '\033[1;32m已选 %d 项\033[0m  (已安装组件显示 [✓装] 将自动跳过)\n' "$checked"
    }

    # 主循环
    while true; do
        render
        read_key
        case "$key" in
            UP)
                if [ "$cur" -gt 0 ]; then cur=$((cur-1)); fi
                ;;
            DOWN)
                if [ "$cur" -lt $(( ${#ids[@]} - 1 )) ]; then cur=$((cur+1)); fi
                ;;
            SPACE)
                if [ "${inst[$cur]}" != "1" ]; then
                    if [ "${sel[$cur]}" = "1" ]; then sel[$cur]=0; else sel[$cur]=1; fi
                fi
                ;;
            A)  for i in "${!sel[@]}"; do [ "${inst[$i]}" != "1" ] && sel[$i]=1; done ;;
            N)  for i in "${!sel[@]}"; do sel[$i]=0; done ;;
            I)  for i in "${!sel[@]}"; do
                    if [ "${inst[$i]}" = "1" ]; then sel[$i]=0; else sel[$i]=1; fi
                done ;;
            ENTER)
                TUI_SELECTED=""
                for i in "${!sel[@]}"; do
                    [ "${sel[$i]}" = "1" ] && TUI_SELECTED="${TUI_SELECTED} ${ids[$i]}"
                done
                break
                ;;
            Q|ESC)
                TUI_SELECTED=""
                break
                ;;
        esac
    done

    # 恢复终端
    printf '\033[?25h'   # 显示光标
    stty echo icanon icrnl ixon 2>/dev/null
    printf '\033[2J\033[H'
}
