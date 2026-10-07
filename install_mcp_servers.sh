#!/usr/bin/env bash
# =============================================================================
# joe install_mcp_servers — MCP 服务器安装器 (含 TUI)
# =============================================================================
# 安装并配置各种 MCP (Model Context Protocol) 服务器, 自动接入已安装的
# AI CLI 工具: Claude Code (claude), Codex (codex), MiMo Code (mimo)。
#
# 用法:
#   ./install_mcp_servers.sh                  # 默认进入 TUI 交互选择 (非交互则全装)
#   ./install_mcp_servers.sh --tui            # 强制进入 TUI 勾选界面
#   ./install_mcp_servers.sh --list           # 列出可用 MCP 服务器及状态
#   ./install_mcp_servers.sh filesystem       # 只装 filesystem MCP
#   ./install_mcp_servers.sh git memory       # 装多个 MCP
#
# TUI 按键: ↑/↓ 移动, 空格 勾选, a 全选, n 全不选, i 仅未装, 回车 开始, q 退出
#
# 新增 MCP 服务器:
#   1. 添加 install_<name>_mcp() 函数
#   2. 加入 TUI_IDS / tui_component_installed / tui_component_name
#   3. 加入参数解析 case 与主流程 case
#
# 依赖: git, curl, npx (Node 18+), 已装的 AI CLI (claude/codex/mimo)
# 说明:
#   - 幂等: 已配置的服务器自动跳过
#   - 所有外网下载尊重 https_proxy/http_proxy 环境变量
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
PROXY_URL="${PROXY_URL:-}"

# 本脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 小工具函数
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*"; }
die()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

load_nvm() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

# 检测已安装的 AI CLI
has_claude() { command -v claude >/dev/null 2>&1; }
has_codex()  { command -v codex  >/dev/null 2>&1; }
has_mimo()   { command -v mimo   >/dev/null 2>&1; }

# npx 是否可用 (需要 Node)
require_npx() {
    load_nvm
    command -v npx >/dev/null 2>&1 || die "需要 Node/npx (请先运行 install_devtools.sh --node)"
}

# ---------------------------------------------------------------------------
# 配置目标: Claude Code (user 全局作用域)
# ---------------------------------------------------------------------------
mcp_add_claude_stdio() {
    local name="$1"; shift
    has_claude || { warn "未安装 claude, 跳过 Claude Code 配置"; return 0; }
    # claude mcp list 默认含 user 作用域 (不传 -s, 该参数不支持)
    if claude mcp list 2>/dev/null | grep -q "^${name}:"; then
        info "Claude Code(user): ${name} 已配置, 跳过"
    else
        claude mcp add -s user "$name" -- "$@" 2>&1 | tail -2 || true
        ok "Claude Code(user): ${name} MCP 已添加"
    fi
}

# ---------------------------------------------------------------------------
# 配置目标: Codex CLI
# ---------------------------------------------------------------------------
mcp_add_codex_stdio() {
    local name="$1"; shift
    has_codex || { warn "未安装 codex, 跳过 Codex 配置"; return 0; }
    if codex mcp list 2>/dev/null | grep -qE "^\s*${name}\s"; then
        info "Codex: ${name} 已配置, 跳过"
    else
        codex mcp add "$name" -- "$@" 2>&1 | tail -2 || true
        ok "Codex: ${name} MCP 已添加"
    fi
}

# ---------------------------------------------------------------------------
# 配置目标: MiMo Code (编辑 ~/.config/mimocode/mimocode.jsonc)
# ---------------------------------------------------------------------------
mcp_add_mimo_stdio() {
    local name="$1"; shift
    has_mimo || { warn "未安装 mimo, 跳过 MiMo Code 配置"; return 0; }
    local cfg="${MIMO_CONFIG:-$HOME/.config/mimocode/mimocode.jsonc}"
    if [ -f "$cfg" ] && grep -q "\"$name\"" "$cfg" 2>/dev/null; then
        info "MiMo Code: ${name} 已配置, 跳过"
        return 0
    fi
    mkdir -p "$(dirname "$cfg")"
    if [ ! -f "$cfg" ]; then
        printf '{\n  "$schema": "https://mimo.xiaomi.com/mimocode/config.json"\n}\n' > "$cfg"
    fi
    # 用 python 注入 MCP 配置 (保证 JSONC 合法)
    python3 - "$cfg" "$name" "$@" << 'PYEOF'
import json, sys, os
cfg, name = sys.argv[1], sys.argv[2]
cmd = sys.argv[3:]
s = open(cfg, encoding="utf-8").read()
if f'"{name}"' in s:
    print("already present")
    sys.exit(0)
import re
# 简单解析: 检查是否有 mcp 字段
if '"mcp"' not in s:
    entry = '\n  "mcp": {\n    "%s": {\n      "type": "local",\n      "command": %s,\n      "enabled": true\n    }\n  },' % (name, json.dumps(cmd))
    s = s.replace('{', '{\n' + entry, 1)
else:
    # 在 mcp 对象中追加 (简化处理: 在最后一个 } 前插入)
    entry = '    "%s": {\n      "type": "local",\n      "command": %s,\n      "enabled": true\n    },\n' % (name, json.dumps(cmd))
    idx = s.rindex('}')
    s = s[:idx] + entry + s[idx:]
open(cfg, "w", encoding="utf-8").write(s)
print("added")
PYEOF
    ok "MiMo Code: ${name} MCP 已添加 (${cfg})"
}

# 统一入口: 添加到所有已安装的 AI CLI
mcp_add_all() {
    local name="$1"; shift
    mcp_add_claude_stdio "$name" "$@"
    mcp_add_codex_stdio "$name" "$@"
    mcp_add_mimo_stdio "$name" "$@"
}

# ---------------------------------------------------------------------------
# 具体 MCP 服务器
# ---------------------------------------------------------------------------
# Filesystem MCP — 安全的文件操作 (需指定可访问目录)
install_filesystem_mcp() {
    info "=== 安装 filesystem MCP (文件系统访问) ==="
    require_npx
    local dirs
    if [ -n "${FILESYSTEM_DIRS:-}" ]; then
        read -ra dirs <<< "$FILESYSTEM_DIRS"
    else
        dirs=("$HOME" "/tmp")
    fi
    local cmd=(npx -y @modelcontextprotocol/server-filesystem "${dirs[@]}")
    mcp_add_all filesystem "${cmd[@]}"
    ok "filesystem MCP 配置完成 (可访问: ${dirs[*]})"
}

# Git MCP — 读取/搜索/操作 Git 仓库 (官方 PyPI 包, 用 uvx 运行)
install_git_mcp() {
    info "=== 安装 git MCP (Git 仓库操作) ==="
    require_npx
    # 需要 uvx (uv 的 Runner)
    if ! command -v uvx >/dev/null 2>&1; then
        info "安装 uv (提供 uvx)..."
        if command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; then
            (command -v pip >/dev/null 2>&1 && pip install --user uv 2>&1 | tail -2) || \
            (pip3 install --user uv 2>&1 | tail -2)
            export PATH="$HOME/.local/bin:$PATH"
        elif command -v brew >/dev/null 2>&1; then
            brew install uv 2>&1 | tail -2
        else
            # 官方安装脚本
            curl -LsSf https://astral.sh/uv/install.sh | sh
            export PATH="$HOME/.local/bin:$PATH"
        fi
    fi
    command -v uvx >/dev/null 2>&1 || die "无法安装 uvx, 请手动安装: pip install uv"
    local cmd=(uvx mcp-server-git)
    mcp_add_all git "${cmd[@]}"
    ok "git MCP 配置完成 (uvx mcp-server-git)"
}

# Memory MCP — 知识图谱持久记忆
install_memory_mcp() {
    info "=== 安装 memory MCP (持久记忆) ==="
    require_npx
    local cmd=(npx -y @modelcontextprotocol/server-memory)
    mcp_add_all memory "${cmd[@]}"
    ok "memory MCP 配置完成"
}

# ---------------------------------------------------------------------------
# TUI 相关 (复用 tui_module.sh 通用库)
# ---------------------------------------------------------------------------
load_tui_module() {
    local module="$SCRIPT_DIR/tui_module.sh"
    if [ ! -f "$module" ]; then
        return 1
    fi
    # shellcheck disable=SC1091
    . "$module"
}

# MCP 组件定义 (覆盖 tui_module.sh 默认)
MCP_IDS_AVAILABLE=(filesystem git memory)

# 检测 claude 是否已配置某 MCP (claude mcp list 默认含 user 作用域)
claude_has_mcp() {
    has_claude || return 1
    claude mcp list 2>/dev/null | grep -q "^$1:"
}

tui_component_installed() {
    local id="$1"
    case "$id" in
        filesystem)
            claude_has_mcp filesystem || \
            ( has_codex && codex mcp list 2>/dev/null | grep -qE "^\s*filesystem\s" ) || \
            ( has_mimo && grep -q '"filesystem"' "$HOME/.config/mimocode/mimocode.jsonc" 2>/dev/null )
            ;;
        git)
            claude_has_mcp git || \
            ( has_codex && codex mcp list 2>/dev/null | grep -qE "^\s*git\s" ) || \
            ( has_mimo && grep -q '"git"' "$HOME/.config/mimocode/mimocode.jsonc" 2>/dev/null )
            ;;
        memory)
            claude_has_mcp memory || \
            ( has_codex && codex mcp list 2>/dev/null | grep -qE "^\s*memory\s" ) || \
            ( has_mimo && grep -q '"memory"' "$HOME/.config/mimocode/mimocode.jsonc" 2>/dev/null )
            ;;
        *) return 1 ;;
    esac
}

tui_component_name() {
    case "$1" in
        filesystem) echo "filesystem MCP (安全文件操作)" ;;
        git)        echo "git MCP (Git 仓库操作)" ;;
        memory)     echo "memory MCP (持久记忆)" ;;
        *)          echo "$1" ;;
    esac
}

# 运行 TUI, 通过全局变量 TUI_SELECTED 返回选中 id 列表
tui_select() {
    TUI_IDS=("${MCP_IDS_AVAILABLE[@]}")
    TUI_TITLE="joe MCP 服务器安装选择"
    load_tui_module || die "未找到 tui_module.sh (与脚本同目录)"
    tui_available || { warn "当前不是交互式终端, 跳过 TUI"; return 1; }
    run_tui
}

# ---------------------------------------------------------------------------
# 参数解析 / 主流程
# ---------------------------------------------------------------------------
# 确保 AI CLI 在 PATH 中 (nvm 环境)
load_nvm || true

usage() {
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
    echo
    echo "可用 MCP 服务器:"
    echo "  filesystem   - 安全文件操作 (默认)"
    echo "  git          - Git 仓库操作"
    echo "  memory       - 知识图谱持久记忆"
    echo
    echo "filesystem 可通过 FILESYSTEM_DIRS 环境变量自定义可访问目录"
    echo "示例:"
    echo "  ./install_mcp_servers.sh filesystem"
    echo "  ./install_mcp_servers.sh git memory"
    echo "  ./install_mcp_servers.sh --tui"
    exit 0
}

list_mcps() {
    printf '可用 MCP 服务器:\n'
    local id status
    for id in "${MCP_IDS_AVAILABLE[@]}"; do
        if tui_component_installed "$id"; then
            status="已配置"
        else
            status="未配置"
        fi
        printf '  %-10s %-4s %s\n' "$id" "$status" "$(tui_component_name "$id")"
    done
    exit 0
}

# 解析参数
TARGETS=()
TUI_MODE=false
HAS_ARGS=false
while [[ $# -gt 0 ]]; do
    HAS_ARGS=true
    case "$1" in
        --tui)       TUI_MODE=true; shift ;;
        --list|-l)   list_mcps ;;
        -h|--help)   usage ;;
        *)
            case "$1" in
                filesystem|git|memory) TARGETS+=("$1"); shift ;;
                *) die "未知 MCP 服务器: $1 (可用: ${MCP_IDS_AVAILABLE[*]})" ;;
            esac
            ;;
    esac
done

# 无参数时: 交互终端默认 TUI, 非交互默认全装
if [ "$HAS_ARGS" = "false" ]; then
    if [ -t 1 ] && [ -t 0 ]; then
        TUI_MODE=true
    else
        TARGETS=("${MCP_IDS_AVAILABLE[@]}")
    fi
fi

# TUI 模式
if $TUI_MODE; then
    if tui_select; then
        if [ -n "$TUI_SELECTED" ]; then
            # shellcheck disable=SC2206
            TARGETS=($TUI_SELECTED)
            info "已选择 MCP:${TUI_SELECTED}"
        else
            info "TUI 未选择任何 MCP, 退出"
            exit 0
        fi
    else
        exit 0
    fi
fi

# 代理
if [ -n "$PROXY_URL" ]; then
    export https_proxy="$PROXY_URL" http_proxy="$PROXY_URL"
    info "使用代理: $PROXY_URL"
fi

info "joe MCP 安装器开始 $(date)"
for t in "${TARGETS[@]}"; do
    case "$t" in
        filesystem) install_filesystem_mcp ;;
        git)        install_git_mcp ;;
        memory)     install_memory_mcp ;;
    esac
done
ok "全部 MCP 服务器安装完成!"
