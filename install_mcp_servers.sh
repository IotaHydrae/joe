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
#   2. 把 id 加入 MCP_IDS_AVAILABLE, 并在 tui_component_installed / _name 中登记
#   3. 加入参数解析 case 与主流程 case
#
# 依赖: git, curl, npx (Node 18+), 已装的 AI CLI (claude/codex/mimo)
# 说明:
#   - 幂等: 已配置的服务器自动跳过
#   - 所有外网下载尊重 https_proxy/http_proxy 环境变量
#   - npx 一律带 --prefer-offline, 避免无代理时联网检查超时
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
PROXY_URL="${PROXY_URL:-}"
CBM_VARIANT="${CBM_VARIANT:-}"          # 设为 ui 时安装带图谱可视化的版本

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
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
    fi
    return 0
}

# 命令探测: 优先 PATH, 其次 nvm 的 node 版本目录与 ~/.local/bin
_has_bin() {
    local name="$1"
    command -v "$name" >/dev/null 2>&1 && return 0
    [ -x "$HOME/.local/bin/$name" ] && return 0
    local f
    for f in "$HOME"/.nvm/versions/node/*/bin/"$name"; do
        [ -x "$f" ] && return 0
    done
    return 1
}

has_claude() { _has_bin claude; }
has_codex()  { _has_bin codex; }
has_mimo()   { _has_bin mimo; }

require_npx() {
    load_nvm
    _has_bin npx || die "需要 Node/npx (请先运行 install_devtools.sh --node)"
}

# ---------------------------------------------------------------------------
# 配置目标: Claude Code (user 全局作用域)
# ---------------------------------------------------------------------------
# 只看 user 作用域 (~/.claude.json 顶层 mcpServers), 不依赖 `claude mcp list`
# ——后者会混入 project/local 作用域, 导致误判"已配置"而漏加全局配置
claude_user_has_mcp() {
    local name="$1"
    [ -f "$HOME/.claude.json" ] || return 1
    python3 - "$HOME/.claude.json" "$name" << 'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(1)
sys.exit(0 if sys.argv[2] in (d.get("mcpServers") or {}) else 1)
PYEOF
}

mcp_add_claude_stdio() {
    local name="$1"; shift
    has_claude || { warn "未安装 claude, 跳过 Claude Code 配置"; return 0; }
    if claude_user_has_mcp "$name"; then
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
    mkdir -p "$(dirname "$cfg")"
    if [ ! -f "$cfg" ]; then
        printf '{\n  "$schema": "https://mimo.xiaomi.com/mimocode/config.json"\n}\n' > "$cfg"
    fi
    # 用 python 注入 (先严格 JSON, 失败再用字符串感知的 jsonc 解析)
    local result
    result=$(python3 - "$cfg" "$name" "$@" << 'PYEOF'
import json, re, sys

def strip_jsonc(text):
    """去 // 与 /* */ 注释, 正确跳过字符串内部 (避免误伤 https://)。"""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(text[i + 1]); i += 2; continue
            if c == '"':
                in_str = False
            i += 1; continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            i = n if j == -1 else j
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            i = n if j == -1 else j + 2
            continue
        out.append(c); i += 1
    return ''.join(out)

cfg, name = sys.argv[1], sys.argv[2]
cmd = sys.argv[3:]
raw = open(cfg, encoding="utf-8").read()
data = None
if raw.strip():
    try:
        data = json.loads(raw)                      # 严格 JSON 优先
    except Exception:
        txt = strip_jsonc(raw)
        txt = re.sub(r',(\s*[}\]])', r'\1', txt)    # 去尾随逗号
        try:
            data = json.loads(txt)
        except Exception:
            sys.stderr.write("warning: 无法解析 %s, 将重建配置\n" % cfg)
            data = None
if not isinstance(data, dict):
    data = {}
data.setdefault("$schema", "https://mimo.xiaomi.com/mimocode/config.json")
mcp = data.get("mcp")
if not isinstance(mcp, dict):
    mcp = {}
    data["mcp"] = mcp
if name in mcp:
    print("already present")
    sys.exit(0)
mcp[name] = {"type": "local", "command": cmd, "enabled": True}
open(cfg, "w", encoding="utf-8").write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print("added")
PYEOF
)
    if [ "$result" = "added" ]; then
        ok "MiMo Code: ${name} MCP 已添加 (${cfg})"
    else
        info "MiMo Code: ${name} 已配置, 跳过"
    fi
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
    local cmd=(npx --prefer-offline -y @modelcontextprotocol/server-filesystem "${dirs[@]}")
    mcp_add_all filesystem "${cmd[@]}"
    ok "filesystem MCP 配置完成 (可访问: ${dirs[*]})"
}

# Git MCP — 读取/搜索/操作 Git 仓库 (官方 PyPI 包, 用 uvx 运行)
install_git_mcp() {
    info "=== 安装 git MCP (Git 仓库操作) ==="
    require_npx
    if ! _has_bin uvx; then
        info "安装 uv (提供 uvx)..."
        if command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; then
            (command -v pip >/dev/null 2>&1 && pip install --user uv 2>&1 | tail -2) || \
            (pip3 install --user uv 2>&1 | tail -2)
            export PATH="$HOME/.local/bin:$PATH"
        elif command -v brew >/dev/null 2>&1; then
            brew install uv 2>&1 | tail -2
        else
            curl -LsSf https://astral.sh/uv/install.sh | sh
            export PATH="$HOME/.local/bin:$PATH"
        fi
    fi
    _has_bin uvx || die "无法安装 uvx, 请手动安装: pip install uv"
    # 预热缓存 (避免首次连接超时)
    info "预热 uvx 缓存..."
    uvx mcp-server-git --help >/dev/null 2>&1 || true
    local cmd=(uvx mcp-server-git)
    mcp_add_all git "${cmd[@]}"
    ok "git MCP 配置完成 (uvx mcp-server-git)"
}

# Memory MCP — 知识图谱持久记忆
install_memory_mcp() {
    info "=== 安装 memory MCP (持久记忆) ==="
    require_npx
    local cmd=(npx --prefer-offline -y @modelcontextprotocol/server-memory)
    mcp_add_all memory "${cmd[@]}"
    ok "memory MCP 配置完成"
}

# codebase-memory-mcp — 代码库知识图谱 (DeusData, 纯 C 静态二进制)
# 官方安装器会自动配置 claude/codex/zed/vscode 等; MiMo 需手动补
install_codebase_memory_mcp() {
    info "=== 安装 codebase-memory-mcp (代码知识图谱) ==="
    local bin="$HOME/.local/bin/codebase-memory-mcp"
    if [ -x "$bin" ]; then
        info "codebase-memory-mcp 已安装: $("$bin" --version 2>/dev/null | head -1)"
    else
        info "运行官方安装脚本 (自动配置已支持的 AI 代理)..."
        local args=""
        [ "$CBM_VARIANT" = "ui" ] && args="--ui"
        curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh \
            | bash -s -- $args
    fi
    [ -x "$bin" ] || die "codebase-memory-mcp 安装失败"

    # 官方安装器已配置 claude/codex; 这里统一确保三个工具都有 (幂等)
    mcp_add_all codebase-memory-mcp "$bin"
    ok "codebase-memory-mcp 配置完成 ($("$bin" --version 2>/dev/null | head -1))"
}

# ---------------------------------------------------------------------------
# TUI 相关 (复用 tui_module.sh 通用库)
# ---------------------------------------------------------------------------
load_tui_module() {
    local module="$SCRIPT_DIR/tui_module.sh"
    [ -f "$module" ] || return 1
    # shellcheck disable=SC1091
    . "$module"
}

# MCP 组件定义 (覆盖 tui_module.sh 默认)
MCP_IDS_AVAILABLE=(filesystem git memory codebase-memory-mcp)

claude_has_mcp() {
    claude_user_has_mcp "$1"
}

codex_has_mcp() {
    has_codex || return 1
    codex mcp list 2>/dev/null | grep -qE "^\s*$1\s"
}

mimo_has_mcp() {
    has_mimo || return 1
    grep -q "\"$1\"" "${MIMO_CONFIG:-$HOME/.config/mimocode/mimocode.jsonc}" 2>/dev/null
}

tui_component_installed() {
    local id="$1"
    claude_has_mcp "$id" || codex_has_mcp "$id" || mimo_has_mcp "$id"
}

tui_component_name() {
    case "$1" in
        filesystem)          echo "filesystem MCP (安全文件操作)" ;;
        git)                 echo "git MCP (Git 仓库操作)" ;;
        memory)              echo "memory MCP (持久记忆)" ;;
        codebase-memory-mcp) echo "codebase-memory MCP (代码知识图谱)" ;;
        *)                   echo "$1" ;;
    esac
}

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
# 确保 AI CLI 在 PATH 中 (nvm 环境 + ~/.local/bin)
export PATH="$HOME/.local/bin:$PATH"
load_nvm

usage() {
    sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
    echo
    echo "可用 MCP 服务器:"
    echo "  filesystem           - 安全文件操作"
    echo "  git                  - Git 仓库操作"
    echo "  memory               - 知识图谱持久记忆"
    echo "  codebase-memory-mcp  - 代码库知识图谱 (158 语言, 子毫秒查询)"
    echo
    echo "环境变量:"
    echo "  FILESYSTEM_DIRS  自定义 filesystem 可访问目录 (空格分隔)"
    echo "  CBM_VARIANT=ui   安装带图谱可视化的 codebase-memory-mcp"
    echo "  PROXY_URL        代理地址, 如 http://host:7890"
    echo
    echo "示例:"
    echo "  ./install_mcp_servers.sh"
    echo "  ./install_mcp_servers.sh --tui"
    echo "  ./install_mcp_servers.sh filesystem git memory codebase-memory-mcp"
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
        printf '  %-22s %-4s %s\n' "$id" "$status" "$(tui_component_name "$id")"
    done
    exit 0
}

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
                filesystem|git|memory|codebase-memory-mcp) TARGETS+=("$1"); shift ;;
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

if [ -n "$PROXY_URL" ]; then
    export https_proxy="$PROXY_URL" http_proxy="$PROXY_URL"
    info "使用代理: $PROXY_URL"
fi

info "joe MCP 安装器开始 $(date)"
for t in "${TARGETS[@]}"; do
    case "$t" in
        filesystem)          install_filesystem_mcp ;;
        git)                 install_git_mcp ;;
        memory)              install_memory_mcp ;;
        codebase-memory-mcp) install_codebase_memory_mcp ;;
    esac
done
ok "全部 MCP 服务器安装完成!"
