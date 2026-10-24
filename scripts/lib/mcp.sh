#!/usr/bin/env bash
# MCP 菜单与 TUI 共用的服务清单; id、名称和状态均来自安装器 --list。

MCP_SCRIPT="${MCP_SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install_mcp_servers.sh}"

declare -a MCP_IDS=()
declare -A MCP_STATUS=()
declare -A MCP_NAME=()

load_mcp_catalog() {
    local listing line id status name
    if [ ! -f "$MCP_SCRIPT" ]; then
        printf "错误: 找不到 MCP 安装器: %s\n" "$MCP_SCRIPT" >&2
        return 1
    fi
    if ! listing=$(bash "$MCP_SCRIPT" --list 2>/dev/null); then
        printf "错误: 读取 MCP 列表失败: %s --list\n" "$MCP_SCRIPT" >&2
        return 1
    fi

    MCP_IDS=()
    MCP_STATUS=()
    MCP_NAME=()
    while IFS= read -r line; do
        [[ $line == "  "* ]] || continue
        read -r id status name <<< "${line#  }"
        [[ -n $id && ( $status == "已配置" || $status == "未配置" ) ]] || continue
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
    return 0
}

# 代码智能服务三选一 (与 doctor 的判断一致)
is_code_intel() {
    case "$1" in
        codebase-memory-mcp|codegraph|serena) return 0 ;;
        *) return 1 ;;
    esac
}
