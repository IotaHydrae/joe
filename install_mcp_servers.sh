#!/usr/bin/env bash
# =============================================================================
# joe install_mcp_servers — MCP 服务器安装器
# =============================================================================
# 安装并配置各种 MCP (Model Context Protocol) 服务器, 自动接入已安装的
# AI CLI 工具: Claude Code (claude), Codex (codex), MiMo Code (mimo)。
#
# 用法:
#   ./install_mcp_servers.sh                  # 安装全部 MCP 服务器 (当前: filesystem)
#   ./install_mcp_servers.sh --list           # 列出可安装的 MCP 服务器
#   ./install_mcp_servers.sh filesystem       # 只装 filesystem MCP
#
# 新增 MCP 服务器:
#   在下方 add_<name>_mcp() 函数中添加安装逻辑, 并加入 MAIN 数组。
#   支持两种配置目标:
#     - stdio 服务器: 用 mcp_add_stdio <name> <command...>
#     - 远程服务器:  用 mcp_add_remote <name> <url> [env_key=value...]
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
# 配置目标: Claude Code
# ---------------------------------------------------------------------------
mcp_add_claude_stdio() {
    local name="$1"; shift
    has_claude || { warn "未安装 claude, 跳过 Claude Code 配置"; return 0; }
    if claude mcp list -s user 2>/dev/null | grep -q "^${name}:"; then
        info "Claude Code(user): ${name} 已配置, 跳过"
    else
        claude mcp add -s user "$name" -- "$@" 2>&1 | tail -2
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
        codex mcp add "$name" -- "$@" 2>&1 | tail -2
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

# ---------------------------------------------------------------------------
# 具体 MCP 服务器
# ---------------------------------------------------------------------------
# Filesystem MCP — 安全的文件操作 (需指定可访问目录)
install_filesystem_mcp() {
    info "=== 安装 filesystem MCP (文件系统访问) ==="
    require_npx
    # 默认目录: 用户家目录 + /tmp (可用 FILESYSTEM_DIRS 覆盖, 空格分隔)
    local dirs
    if [ -n "${FILESYSTEM_DIRS:-}" ]; then
        read -ra dirs <<< "$FILESYSTEM_DIRS"
    else
        dirs=("$HOME" "/tmp")
    fi
    local cmd=(npx -y @modelcontextprotocol/server-filesystem "${dirs[@]}")

    mcp_add_claude_stdio filesystem "${cmd[@]}"
    mcp_add_codex_stdio filesystem "${cmd[@]}"
    mcp_add_mimo_stdio filesystem "${cmd[@]}"
    ok "filesystem MCP 配置完成 (可访问: ${dirs[*]})"
}

# ---------------------------------------------------------------------------
# 参数解析 / 主流程
# ---------------------------------------------------------------------------
usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    echo
    echo "可用 MCP 服务器:"
    echo "  filesystem   - 安全文件操作 (默认)"
    echo "  (通过 FILESYSTEM_DIRS 环境变量自定义可访问目录)"
    echo
    echo "示例:"
    echo "  ./install_mcp_servers.sh filesystem"
    echo "  FILESYSTEM_DIRS=\"/home/dev /data\" ./install_mcp_servers.sh filesystem"
    exit 0
}

TARGETS=()
if [ "$#" -eq 0 ]; then
    TARGETS=(filesystem)
else
    case "$1" in
        --list|-h|--help) usage ;;
        filesystem) TARGETS=(filesystem) ;;
        *) die "未知 MCP 服务器: $1 (可用: filesystem)" ;;
    esac
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
    esac
done
ok "全部 MCP 服务器安装完成!"
