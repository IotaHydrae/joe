#!/usr/bin/env bash
# =============================================================================
# MCP 命令 - 新旧语法转换层
# =============================================================================
# 安装逻辑仍在 scripts/install_mcp_servers.sh; 服务清单与校验也由它负责,
# 本文件不重复维护 id 列表。

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# MCP_SCRIPT 可由测试环境覆盖为 stub
MCP_SCRIPT="${MCP_SCRIPT:-$_SCRIPT_DIR/../install_mcp_servers.sh}"

usage() {
    cat <<'EOF'
用法: mcp <动作> [选项] [服务...]

动作:
    <无参数>            进入 TUI 交互选择 (非交互终端会报错)
    list, status        列出所有服务及安装状态
    install <服务...>   安装指定服务
    update [服务...]    重跑安装器以刷新配置 (命令变化时才改写)
    tui                 强制进入 TUI

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

ACTION="${1:-}"

# 仅识别新动作词; 其余参数 (含 --list/--all/--tui 与位置服务名) 原样转发
case "$ACTION" in
    '')          forward ;;
    -h|--help)   usage; forward --help ;;
    list|status) forward --list ;;
    tui)         forward --tui ;;
    install|update)
        shift
        forward "$@"
        ;;
    *)           forward "$@" ;;
esac
