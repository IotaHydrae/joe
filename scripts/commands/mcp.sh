#!/usr/bin/env bash
# =============================================================================
# MCP 命令 - 新旧语法转换层
# =============================================================================
# 安装逻辑仍在 scripts/install_mcp_servers.sh; 服务清单与校验也由它负责,
# 本文件不重复维护 id 列表。

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# MCP_SCRIPT / TUI_SCRIPT / MCP_NPX_BIN 可由测试环境覆盖
MCP_SCRIPT="${MCP_SCRIPT:-$_SCRIPT_DIR/../install_mcp_servers.sh}"
TUI_SCRIPT="${TUI_SCRIPT:-$_SCRIPT_DIR/../ui/tui_mcp.sh}"
# shellcheck disable=SC1091
. "$_SCRIPT_DIR/../lib/node.sh"
# shellcheck disable=SC1091
. "$_SCRIPT_DIR/../ui/tui_common.sh"
MCP_NPX_BIN="${MCP_NPX_BIN:-npx}"

usage() {
    cat <<'EOF'
用法: mcp <动作> [选项] [服务...]

动作:
    <无参数>            进入 TUI 交互选择 (非交互终端会报错)
    list, status        列出所有服务及安装状态
    install <服务...>   安装指定服务
    update [服务...]    重跑安装器以刷新配置 (命令变化时才改写)
    tui                 强制进入 TUI

TUI: 分组显示服务、已配置状态、代码智能三选一提示, 以及 Node/npx 依赖状态;
需要 Node/npx 才能安装, 缺失时给出先装 node 的命令。

旧语法 (--list / --all / --tui / 位置服务名) 原样转发给安装器,
完整选项见: mcp --help

EOF
}

forward() {
    [ -f "$MCP_SCRIPT" ] || {
        printf "错误: 找不到 MCP 安装器: %s\n" "$MCP_SCRIPT" >&2
        exit 1
    }
    exec bash "$MCP_SCRIPT" "$@"
}

# 所有 MCP 服务都通过 npx 运行, 缺 Node 时安装必然失败, 提前给出可执行提示

cmd_tui() {
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        printf "TUI 需要交互式终端; 请用: mcp install <服务...> 或 mcp --all\n" >&2
        return 1
    fi
    if [ ! -f "$TUI_SCRIPT" ]; then
        printf "错误: 找不到 MCP TUI: %s\n" "$TUI_SCRIPT" >&2
        return 1
    fi

    # 界面占用 stdout, 选择结果经临时文件回传
    local rc=0
    collect_tui_selection "$TUI_SCRIPT" MCP_SCRIPT="$MCP_SCRIPT" MCP_NPX_BIN="$MCP_NPX_BIN" \
        || rc=$?
    local -a ids=("${TUI_PICKS[@]}")

    if [[ $rc -eq 2 ]]; then
        return 1   # 加载失败, TUI 已打印原因
    fi
    if [[ ${#ids[@]} -eq 0 ]]; then
        printf "未选择任何 MCP\n"
        return 0
    fi
    if ! node_has_bin "$MCP_NPX_BIN"; then
        printf "MCP 安装需要 Node/npx, 请先运行: ./install.sh tools install node\n" >&2
        return 1
    fi

    forward "${ids[@]}"
}

ACTION="${1:-}"

# 仅识别新动作词; 其余参数 (含 --list/--all/位置服务名) 原样转发
case "$ACTION" in
    ''|tui|--tui) cmd_tui ;;
    -h|--help)    usage; forward --help ;;
    list|status)  shift; forward --list "$@" ;;
    install|update)
        shift
        forward "$@"
        ;;
    *)            forward "$@" ;;
esac
