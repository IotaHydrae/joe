#!/usr/bin/env bash
# =============================================================================
# 依赖关系解析库
# =============================================================================
# 处理组件之间的依赖关系，自动补全和验证

# 依赖关系映射 (组件 -> 依赖列表)
declare -A COMPONENT_DEPS=(
    # AI CLI 都依赖 Node.js
    [claude]="node"
    [codex]="node"
    [gemini]="node"
    [opencode]="node"
    [copilot]="node"
    [grok]="node"
    [mimo]="node"
    [ccswitch]="node"

    # Python 工具依赖 Python 环境
    # (暂无)

    # 其他工具无依赖
    [node]=""
    [python]=""
    [zed]=""
    [vscode]=""
    [ghostty]=""
    [brave]=""
    [chatgpt]=""
)

# 组件分组定义
declare -A COMPONENT_GROUPS=(
    [runtime]="node python"
    [ai-cli]="claude codex gemini opencode copilot grok mimo"
    [editor]="zed vscode"
    [terminal]="ghostty"
    [browser]="brave"
    [desktop]="chatgpt"
    [utility]="ccswitch"
)

# 快捷组定义
declare -A SHORTCUT_GROUPS=(
    [ai]="claude codex"
    [all]="node python claude codex gemini opencode copilot grok zed vscode ghostty brave mimo chatgpt ccswitch"
)

# 组件显示名称
declare -A COMPONENT_NAMES=(
    [node]="Node.js LTS"
    [python]="pyenv + Python"
    [claude]="Claude Code"
    [codex]="Codex CLI"
    [gemini]="Gemini CLI"
    [opencode]="OpenCode"
    [copilot]="GitHub Copilot"
    [grok]="Grok Build"
    [zed]="Zed Editor"
    [vscode]="VS Code"
    [ghostty]="Ghostty Terminal"
    [brave]="Brave Browser"
    [mimo]="MiMo Code"
    [chatgpt]="ChatGPT Desktop"
    [ccswitch]="CC Switch"
)

# 解析快捷组和位置参数
# 输入: "ai gemini --all" 或 "claude codex"
# 输出: 展开后的组件列表（去重）
expand_components() {
    local -a expanded=()
    local -A seen=()

    for arg in "$@"; do
        case "$arg" in
            --all)
                for comp in ${SHORTCUT_GROUPS[all]}; do
                    [[ -z ${seen[$comp]:-} ]] && expanded+=("$comp") && seen[$comp]=1
                done
                ;;
            --ai)
                for comp in ${SHORTCUT_GROUPS[ai]}; do
                    [[ -z ${seen[$comp]:-} ]] && expanded+=("$comp") && seen[$comp]=1
                done
                ;;
            --*)
                # 移除前缀的选项标志
                local comp="${arg#--}"
                if [[ -n ${COMPONENT_NAMES[$comp]:-} ]]; then
                    [[ -z ${seen[$comp]:-} ]] && expanded+=("$comp") && seen[$comp]=1
                fi
                ;;
            *)
                # 位置参数
                if [[ -n ${COMPONENT_NAMES[$arg]:-} ]]; then
                    [[ -z ${seen[$arg]:-} ]] && expanded+=("$arg") && seen[$arg]=1
                elif [[ -n ${SHORTCUT_GROUPS[$arg]:-} ]]; then
                    for comp in ${SHORTCUT_GROUPS[$arg]:-}; do
                        [[ -z ${seen[$comp]:-} ]] && expanded+=("$comp") && seen[$comp]=1
                    done
                fi
                ;;
        esac
    done

    [[ ${#expanded[@]} -gt 0 ]] && printf '%s\n' "${expanded[@]}"
    return 0
}

# 获取组件的直接依赖
get_deps() {
    local component="$1"
    local deps="${COMPONENT_DEPS[$component]:-}"
    if [[ -n $deps ]]; then
        printf '%s\n' $deps
    fi
}

# 递归获取所有依赖（深度优先）
get_all_deps() {
    local component="$1"
    local -A visited=()
    local -a result=()

    _walk_deps() {
        local comp="$1"
        [[ -n ${visited[$comp]:-} ]] && return
        visited[$comp]=1

        local deps
        deps=$(get_deps "$comp")
        for dep in $deps; do
            _walk_deps "$dep"
        done

        result+=("$comp")
    }

    _walk_deps "$component"
    [[ ${#result[@]} -gt 0 ]] && printf '%s\n' "${result[@]}"
    return 0
}

# 解析安装列表并补全依赖
# 输入: 组件列表
# 输出: 包含所有依赖的完整列表（拓扑排序）
# 返回: 0=列表与请求一致, 1=补入了未请求的依赖（调用方据此提示用户）
resolve_deps() {
    local -a components=("$@")
    local -a full_list=()
    local -A seen=()
    local -a missing_deps=()

    # 收集所有组件及其依赖
    for comp in "${components[@]}"; do
        local all_deps
        all_deps=$(get_all_deps "$comp")
        for item in $all_deps; do
            if [[ -z ${seen[$item]:-} ]]; then
                full_list+=("$item")
                seen[$item]=1
            fi
        done
    done

    # 检查是否有依赖未在原始列表中
    for item in "${full_list[@]}"; do
        local is_requested=0
        for comp in "${components[@]}"; do
            [[ $item == "$comp" ]] && is_requested=1 && break
        done

        if [[ $is_requested -eq 0 ]]; then
            missing_deps+=("$item")
        fi
    done

    # 输出完整列表
    [[ ${#full_list[@]} -gt 0 ]] && printf '%s\n' "${full_list[@]}"

    # 返回 1 是正常信号而非错误: 调用方须用 `if ! ...` 或 `|| true` 捕获,
    # 简单赋值会在 set -e 下直接中止脚本。
    [[ ${#missing_deps[@]} -gt 0 ]] && return 1
    return 0
}

# 检查组件是否已安装
is_installed() {
    local component="$1"

    case "$component" in
        node)
            [ -d "$HOME/.nvm" ] && [ -n "$(command -v node 2>/dev/null)" ]
            ;;
        python)
            [ -d "$HOME/.pyenv" ]
            ;;
        claude)
            command -v claude >/dev/null 2>&1
            ;;
        codex)
            command -v codex >/dev/null 2>&1
            ;;
        gemini)
            command -v gemini >/dev/null 2>&1
            ;;
        opencode)
            command -v opencode >/dev/null 2>&1
            ;;
        copilot)
            command -v github-copilot-cli >/dev/null 2>&1
            ;;
        grok)
            command -v grok >/dev/null 2>&1
            ;;
        zed)
            command -v zed >/dev/null 2>&1 || [ -f "$HOME/.local/bin/zed" ]
            ;;
        vscode)
            command -v code >/dev/null 2>&1
            ;;
        ghostty)
            command -v ghostty >/dev/null 2>&1
            ;;
        brave)
            command -v brave-browser >/dev/null 2>&1 || command -v brave >/dev/null 2>&1
            ;;
        mimo)
            command -v mimo >/dev/null 2>&1
            ;;
        chatgpt)
            [ -f "$HOME/.local/bin/chatgpt" ] || command -v chatgpt >/dev/null 2>&1
            ;;
        ccswitch)
            command -v cc-switch >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# 获取已安装组件的版本
# 两道保护缺一不可: 分支里的 `|| true` 让直接调用时不会因命令不存在而中止;
# 末尾的 return 0 保证返回码为 0, 否则调用方的 `ver=$(get_version ...)` 仍会在
# set -e 下中止 (例如 ~/.local/bin/zed 存在但不在 PATH)。
get_version() {
    local component="$1"

    case "$component" in
        node)
            node --version 2>/dev/null | tr -d 'v' || true
            ;;
        python)
            if [ -d "$HOME/.pyenv" ]; then
                printf "pyenv"
            fi
            ;;
        claude)
            claude --version 2>/dev/null | head -1 | awk '{print $1}' || true
            ;;
        codex)
            codex --version 2>/dev/null | head -1 || true
            ;;
        zed)
            zed --version 2>/dev/null || true
            ;;
        vscode)
            code --version 2>/dev/null | head -1 || true
            ;;
        *)
            printf ""
            ;;
    esac
    return 0
}

# 获取组件所属的分组
get_component_group() {
    local component="$1"

    for group in "${!COMPONENT_GROUPS[@]}"; do
        if [[ " ${COMPONENT_GROUPS[$group]:-} " == *" $component "* ]]; then
            printf '%s' "$group"
            return 0
        fi
    done

    printf "other"
}

# 验证组件名是否有效
validate_component() {
    local component="$1"
    [[ -n ${COMPONENT_NAMES[$component]:-} ]]
}

# 导出函数和变量
export -f expand_components get_deps get_all_deps resolve_deps
export -f is_installed get_version get_component_group validate_component
