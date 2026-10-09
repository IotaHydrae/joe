#!/usr/bin/env bash
# =============================================================================
# joe TUI 交互式组件选择器 (通用库)
# =============================================================================
# 提供方向键/空格/回车选择的勾选界面。通用设计, 可供多个安装脚本复用:
#
#   install_devtools.sh --tui       (devtools 组件)
#   install_mcp_servers.sh --tui    (MCP 服务器)
#   install_skills.sh --tui         (代理技能)
#
# 调用方可在 source 本文件之前定义以下内容覆盖默认值:
#   TUI_IDS=(...)                    组件 id 列表 (顺序即显示顺序)
#   TUI_TITLE="..."                  界面标题
#   tui_component_installed()        已安装检测 (返回 0=已装, 1=未装)
#   tui_component_name()             组件显示名称 (echo)
# 未定义时使用 devtools 的默认值。
#
# 按键:
#   ↑/↓      移动光标
#   PgUp/PgDn 翻页 (列表按终端高度显示)
#   Home/End  到第一项 / 最后一项
#   空格      勾选 / 取消 (已安装组件固定跳过)
#   a         全选 (未安装)
#   n         全不选
#   i         仅选未安装
#   回车      开始安装
#   q / Esc   退出
# =============================================================================

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

# ---- 默认组件 (devtools); 调用方可预先覆盖 ----
if [ -z "${TUI_IDS+x}" ]; then
    TUI_IDS=(node python ai zed ghostty vscode mimo chatgpt ccswitch)
fi
if [ -z "${TUI_TITLE+x}" ]; then
    TUI_TITLE="joe devtools 组件安装选择"
fi

# 仅在无 TTY 时返回错误 (由调用方决定是否回退)
tui_available() {
    [ -t 1 ] && [ -t 0 ]
}

# 命令探测: 优先 PATH, 其次 nvm 的 node 版本目录
# (非交互 shell 下 PATH 往往不含 nvm/pyenv, 仅用 command -v 会误判)
_tui_has_bin() {
    local name="$1"
    command -v "$name" >/dev/null 2>&1 && return 0
    [ -x "$HOME/.local/bin/$name" ] && return 0
    [ -x "$HOME/.mimocode/bin/$name" ] && return 0   # MiMo Code 官方安装路径
    local f
    for f in "$HOME"/.nvm/versions/node/*/bin/"$name"; do
        [ -x "$f" ] && return 0
    done
    return 1
}

# 默认已安装检测 (devtools); 调用方可预先定义覆盖
if ! declare -F tui_component_installed >/dev/null 2>&1; then
    tui_component_installed() {
        local id="$1"
        case "$id" in
            node)     _tui_has_bin node ;;
            python)   [ -x "$HOME/.pyenv/bin/pyenv" ] || command -v pyenv >/dev/null 2>&1 ;;
            ai)       _tui_has_bin claude && _tui_has_bin codex ;;
            zed)      [ -x "$HOME/.local/bin/zed" ] || command -v zed >/dev/null 2>&1 ;;
            ghostty)  command -v ghostty >/dev/null 2>&1 ;;
            vscode)   command -v code >/dev/null 2>&1 ;;
            mimo)     _tui_has_bin mimo ;;
            chatgpt)  command -v chatgpt >/dev/null 2>&1 ;;
            ccswitch) command -v cc-switch >/dev/null 2>&1 ;;
            *)        return 1 ;;
        esac
    }
fi

# 默认组件显示名称 (devtools); 调用方可预先定义覆盖
if ! declare -F tui_component_name >/dev/null 2>&1; then
    tui_component_name() {
        case "$1" in
            node)     echo "Node 工具链 (nvm + LTS)" ;;
            python)   echo "Python 版本管理器 (pyenv + 编译依赖)" ;;
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
fi

# 运行 TUI, 通过全局变量 TUI_SELECTED (以空格分隔的选中组件 id) 返回结果
run_tui() {
    local -a ids=("${TUI_IDS[@]}")
    local names=() inst=() sel=()
    local i

    # 预计算名称与已安装状态
    for i in "${!ids[@]}"; do
        names[$i]=$(tui_component_name "${ids[$i]}")
        if tui_component_installed "${ids[$i]}"; then
            inst[$i]=1
        else
            inst[$i]=0
        fi
        sel[$i]=0       # 按需勾选, 不预选任何组件
    done

    local cur=0
    local key

    # 终端状态 (关闭 echo/规范模式/CR映射/流控, 保证 read 正确读取)
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
                '[H') key=HOME ;;
                '[F') key=END ;;
                '[5'|'[6'|'[1'|'[4')
                    IFS= read -r -n1 ch3 2>/dev/null || true
                    if [ "$ch3" = '~' ]; then
                        case "$ch2" in
                            '[5') key=PAGE_UP ;;
                            '[6') key=PAGE_DOWN ;;
                            '[1') key=HOME ;;
                            '[4') key=END ;;
                        esac
                    else
                        key=ESC
                    fi
                    ;;
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

    # 按显示宽度截断, 避免长技能名/中文描述换行后挤出分页视口。
    fit_label() {
        local label="$1" limit="$2" result="" width=0 char char_width pos
        for ((pos=0; pos<${#label}; pos++)); do
            char="${label:pos:1}"
            case "$char" in
                [\ -~]) char_width=1 ;;
                *) char_width=2 ;;
            esac
            [ "$((width + char_width))" -le "$limit" ] || break
            result+="$char"
            width=$((width + char_width))
        done
        printf '%s' "$result"
    }

    local page_size=16
    # 渲染
    render() {
        local rows=24 columns=80 dimensions start end label
        dimensions="$(stty size 2>/dev/null || true)"
        if [[ "$dimensions" =~ ^([0-9]+)[[:space:]]+([0-9]+)$ ]]; then
            [ "${BASH_REMATCH[1]}" -gt 0 ] && rows="${BASH_REMATCH[1]}"
            [ "${BASH_REMATCH[2]}" -gt 0 ] && columns="${BASH_REMATCH[2]}"
        fi
        page_size=$((rows - 8))
        [ "$page_size" -ge 1 ] || page_size=1
        start=$((cur / page_size * page_size))
        end=$((start + page_size))
        [ "$end" -le "${#ids[@]}" ] || end="${#ids[@]}"
        printf '\033[2J\033[H'  # 清屏
        printf '\033[1;36m%s\033[0m\n' "$(fit_label "═══ $TUI_TITLE ═══" "$columns")"
        printf '\033[2m%s\033[0m\n' "$(fit_label '↑↓/PgUp/PgDn移动 空格勾选 a/n/i 回车开始 q退出' "$columns")"
        printf '%s\n' "$(fit_label '──────────────────────────────────────────' "$columns")"
        local checked=0
        for i in "${!sel[@]}"; do
            [ "${sel[$i]}" = "1" ] && checked=$((checked+1))
        done

        for ((i=start; i<end; i++)); do
            local box="[ ]"
            local tag="   "
            local prefix="  "
            local attr='\033[0m'
            [ "${sel[$i]}" = "1" ] && box="[x]"
            if [ "${inst[$i]}" = "1" ]; then
                tag="✓装"
                attr='\033[2m'
            fi
            # 光标行: 已安装行用 反色+暗淡, 保证移动到该行时仍能看见光标
            if [ "$i" = "$cur" ]; then
                prefix="> "
                if [ "${inst[$i]}" = "1" ]; then attr='\033[7;2m'; else attr='\033[7m'; fi
            fi
            label="$(fit_label "${names[$i]}" "$((columns - 13))")"
            printf '%b%s %-3s  %s\033[0m\n' "$attr" "$prefix$box" "$tag" "$label"
        done
        printf '%s\n' "$(fit_label '──────────────────────────────────────────' "$columns")"
        printf '\033[1;32m已选 %d 项\033[0m  显示 %d-%d/%d 项\n' "$checked" "$((start + 1))" "$end" "${#ids[@]}"
        printf '%s\n' "$(fit_label '已安装组件显示 [✓装] 将自动跳过' "$columns")"
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
            PAGE_UP)
                cur=$((cur - page_size))
                [ "$cur" -ge 0 ] || cur=0
                ;;
            PAGE_DOWN)
                cur=$((cur + page_size))
                [ "$cur" -lt "${#ids[@]}" ] || cur=$((${#ids[@]} - 1))
                ;;
            HOME) cur=0 ;;
            END) cur=$((${#ids[@]} - 1)) ;;
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
