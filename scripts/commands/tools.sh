#!/usr/bin/env bash
# =============================================================================
# Tools 命令 - 开发工具管理
# =============================================================================
# 用法:
#   tools                    进入 TUI 选择界面
#   tools list               列出所有工具及状态
#   tools install <组件...>  安装指定工具
#   tools update [组件...] 统一更新; 指定组件时只更新这些
#   tools check              检查系统兼容性

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT_DIR="$(cd "$_SCRIPT_DIR/../.." && pwd)"

# 加载依赖
# shellcheck disable=SC1091
. "$_SCRIPT_DIR/../lib/deps.sh"
# shellcheck disable=SC1091
. "$_SCRIPT_DIR/../ui/tui_common.sh"

# 加载旧的安装逻辑（临时，直到完全重构）；DEVTOOLS_SCRIPT 可由测试环境覆盖为 stub
if [ -z "${DEVTOOLS_SCRIPT:-}" ] && [ -f "$_SCRIPT_DIR/../install_devtools.sh" ]; then
    DEVTOOLS_SCRIPT="$_SCRIPT_DIR/../install_devtools.sh"
fi
# UPDATE_SCRIPT 同样可由测试环境覆盖
UPDATE_SCRIPT="${UPDATE_SCRIPT:-$_SCRIPT_DIR/../update-all.sh}"

usage() {
    cat <<'EOF'
用法: tools <动作> [选项] [参数...]

动作:
    <无参数>           进入 TUI 交互选择界面
    list, status       列出所有工具及安装状态
    install <组件...>  安装指定工具
        --with-deps        自动安装依赖
        --ai               快捷安装 Claude + Codex
        --all              安装全部
    update [组件...]   统一更新; 指定组件时只更新这些
        --dry-run            只显示将执行什么
        --quiet              精简输出
        --system             额外升级系统包
    check              检查系统兼容性

可用组件:
    node, python, claude, codex, gemini, opencode, copilot, grok,
    zed, vscode, ghostty, brave, mimo, chatgpt, ccswitch

示例:
    tools                          # 进入 TUI
    tools list                     # 列出所有
    tools install node             # 装 Node.js
    tools install claude codex     # 装多个
    tools install --ai             # 装 AI 组
    tools install --with-deps claude   # 自动装依赖
    tools update                   # 统一更新所有工具
    tools update claude node       # 只更新指定组件
    tools update --dry-run         # 预览将执行的更新
    tools install node claude      # 安装指定组件 (已装的会跳过)

EOF
}

# 命令实现

cmd_list() {
    printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "%-15s %-25s %-10s %s\n" "组件" "名称" "状态" "版本/依赖"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

    local group comp
    for group in "${COMPONENT_GROUP_ORDER[@]}"; do
        printf "\n${COLOR_BOLD}%s:${COLOR_RESET}\n" "${COMPONENT_GROUP_NAMES[$group]:-}"

        for comp in ${COMPONENT_GROUPS[$group]:-}; do
            local name="${COMPONENT_NAMES[$comp]:-}"
            local status="未装"
            local extra=""

            if is_installed "$comp"; then
                status="${COLOR_GREEN}已装${COLOR_RESET}"
                local ver
                ver=$(get_version "$comp")
                [[ -n $ver ]] && extra="$ver"
            else
                status="${COLOR_GRAY}未装${COLOR_RESET}"
                local deps
                deps=$(get_deps "$comp")
                [[ -n $deps ]] && extra="${COLOR_YELLOW}需要:$deps${COLOR_RESET}"
            fi

            printf "  %-15s %-25s %b  %b\n" "$comp" "$name" "$status" "$extra"
        done
    done

    printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
}

cmd_install() {
    local -a components=()
    local with_deps=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --with-deps)
                with_deps=true
                shift
                ;;
            --ai|--all)
                local expanded
                expanded=$(expand_components "$1")
                while IFS= read -r comp; do
                    [[ -n $comp ]] && components+=("$comp")
                done <<< "$expanded"
                shift
                ;;
            *)
                local comp="${1#--}"
                if validate_component "$comp"; then
                    components+=("$comp")
                else
                    printf "未知组件: %s\n" "$comp" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ ${#components[@]} -eq 0 ]]; then
        printf "错误: 未指定组件\n" >&2
        usage >&2
        return 1
    fi

    # 解析依赖
    local full_list
    local has_missing_deps=false
    if ! full_list=$(resolve_deps "${components[@]}"); then
        has_missing_deps=true
    fi

    local -a resolved=()
    local comp
    while IFS= read -r comp; do
        if [[ -n $comp ]]; then
            resolved+=("$comp")
        fi
    done <<< "$full_list"

    local -a install_list=("${components[@]}")
    if $with_deps; then
        # resolve_deps 补入依赖时返回 1 是正常信号, 上面的 if 已经吞掉了
        install_list=("${resolved[@]}")
    elif $has_missing_deps; then
        local -A requested=()
        local -a missing_deps=()
        for comp in "${components[@]}"; do
            requested[$comp]=1
        done
        for comp in "${resolved[@]}"; do
            if [[ -z ${requested[$comp]:-} ]]; then
                missing_deps+=("$comp")
            fi
        done

        printf "\n${COLOR_YELLOW}警告:${COLOR_RESET} 以下组件需要依赖:\n"
        for dep in "${missing_deps[@]}"; do
            printf "  - %s (%s)\n" "$dep" "${COMPONENT_NAMES[$dep]:-}"
        done
        printf "\n"

        if ! read -p "是否自动安装依赖？[Y/n] " -r answer; then
            printf "非交互环境无法确认依赖, 请改用: tools install --with-deps %s\n" "${components[*]}" >&2
            return 1
        fi
        if [[ $answer =~ ^[Nn]$ ]]; then
            printf "已取消安装\n"
            return 1
        fi

        install_list=("${resolved[@]}")
    fi

    # 过滤已安装的组件
    local -a to_install=()
    for comp in "${install_list[@]}"; do
        if is_installed "$comp"; then
            printf "${COLOR_DIM}跳过已安装: %s${COLOR_RESET}\n" "$comp"
        else
            to_install+=("$comp")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        printf "\n${COLOR_GREEN}所有组件已安装${COLOR_RESET}\n"
        return 0
    fi

    # 显示安装计划
    printf "\n将安装以下组件:\n"
    for comp in "${to_install[@]}"; do
        printf "  ✓ %s - %s\n" "$comp" "${COMPONENT_NAMES[$comp]:-}"
    done
    printf "\n"

    # 调用旧的安装脚本（临时方案）
    # TODO: 逐步迁移每个组件的安装逻辑到独立模块
    if [[ -n ${DEVTOOLS_SCRIPT:-} ]]; then
        local -a old_flags=()
        for comp in "${to_install[@]}"; do
            old_flags+=("--$comp")
        done
        bash "$DEVTOOLS_SCRIPT" "${old_flags[@]}"
    else
        printf "错误: 找不到安装脚本\n" >&2
        return 1
    fi
}

cmd_tui() {
    if ! tui_available; then
        printf "错误: TUI 需要交互式终端\n" >&2
        printf "请使用: tools install <组件...>\n" >&2
        return 1
    fi

    local tui_script="$_SCRIPT_DIR/../ui/tui_tools.sh"
    if [ ! -f "$tui_script" ]; then
        # 回退到旧 TUI
        [[ -n ${DEVTOOLS_SCRIPT:-} ]] || { printf "错误: 找不到 TUI 实现\n" >&2; return 1; }
        bash "$DEVTOOLS_SCRIPT" --tui
        return
    fi

    # TUI 占用 stdout 渲染界面, 选择结果只能用临时文件回传
    local -a selected=()
    collect_tui_selection "$tui_script" || true
    selected=("${TUI_PICKS[@]}")

    if [[ ${#selected[@]} -eq 0 ]]; then
        printf "\n未选择任何组件\n"
        return 0
    fi

    cmd_install --with-deps "${selected[@]}"
}

cmd_update() {
    local -a flags=()
    local -a ids=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|--quiet|--system) flags+=("$1") ;;
            --only)
                # 与 update-all 的 --only 同名, 便于偏好显式写法的用户
                [ -n "${2:-}" ] || { printf "错误: --only 需要组件名\n" >&2; return 1; }
                flags+=(--only "$2")
                shift
                ;;
            -h|--help) usage; return 0 ;;
            *)
                if validate_component "$1"; then
                    ids+=("$1")
                else
                    printf "未知组件: %s\n" "$1" >&2
                    return 1
                fi
                ;;
        esac
        shift
    done

    # 指定组件时转成 update-all 的 --only; 能更新哪些组件由 update-all 校验
    if [[ ${#ids[@]} -gt 0 ]]; then
        local only
        only=$(IFS=,; printf '%s' "${ids[*]}")
        flags+=(--only "$only")
    fi

    if [ ! -f "$UPDATE_SCRIPT" ]; then
        printf "错误: 找不到更新脚本: %s\n" "$UPDATE_SCRIPT" >&2
        return 1
    fi

    bash "$UPDATE_SCRIPT" "${flags[@]}"
}

cmd_check() {
    if [[ -n ${DEVTOOLS_SCRIPT:-} ]]; then
        bash "$DEVTOOLS_SCRIPT" --check
    else
        printf "检查功能暂不可用\n" >&2
        return 1
    fi
}

# 主入口
ACTION="${1:-}"
shift || true

case "$ACTION" in
    ''|tui|--tui)
        cmd_tui
        ;;
    list|status)
        cmd_list
        ;;
    install)
        cmd_install "$@"
        ;;
    update)
        cmd_update "$@"
        ;;
    check)
        cmd_check
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf "未知动作: %s\n\n" "$ACTION" >&2
        usage >&2
        exit 1
        ;;
esac
