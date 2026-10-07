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

# 下载安装脚本并校验 (避免把 HTML 错误页/区域限制页当脚本执行)
# 返回 0 = 拿到合法脚本, 1 = 失败(网络/HTML/非脚本)
download_installer() {
    local url="$1" out="$2"
    curl -fsSL "$url" -o "$out" 2>/dev/null || return 1
    [ -s "$out" ] || return 1
    head -c 200 "$out" | grep -qiE '<html|<!doctype|<script' && return 1
    head -1 "$out" | grep -qE '^#!' || return 1
    return 0
}


# 命令探测: 优先 PATH, 其次 nvm 的 node 版本目录与 ~/.local/bin
_has_bin() {
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
# 确保 uvx 可用 (官方独立安装器优先, 支持 uv self update)
ensure_uvx() {
    _has_bin uvx && return 0
    local tpl=/tmp/uv-install.sh
    if download_installer https://astral.sh/uv/install.sh "$tpl"; then
        info "安装 uv (官方独立安装器)..."
        sh "$tpl" 2>&1 | tail -2 || true
        rm -f "$tpl"
        export PATH="$HOME/.local/bin:$PATH"
    else
        warn "官方安装脚本不可用, 回退包管理器/pip (无自更新)"
        if command -v brew >/dev/null 2>&1; then
            brew install uv 2>&1 | tail -2 || true
        elif command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; then
            (command -v pip >/dev/null 2>&1 && pip install --user uv 2>&1 | tail -2) || \
            (pip3 install --user uv 2>&1 | tail -2) || true
            export PATH="$HOME/.local/bin:$PATH"
        fi
    fi
    _has_bin uvx || die "无法安装 uvx, 请手动安装: pip install uv"
}

install_git_mcp() {
    info "=== 安装 git MCP (Git 仓库操作) ==="
    require_npx
    ensure_uvx
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

# Context7 MCP — 实时文档/代码示例检索 (Upstash 官方)
# 无需 API Key 即可用; 有 CONTEXT7_API_KEY 时限流更高
install_context7_mcp() {
    info "=== 安装 Context7 MCP (实时文档检索) ==="
    require_npx
    local cmd=(npx --prefer-offline -y @upstash/context7-mcp)
    mcp_add_all context7 "${cmd[@]}"
    ok "Context7 MCP 配置完成 (@upstash/context7-mcp)"
}

# CodeGraph MCP — 跨语言代码图谱 (42 工具 / 38 语言)
# 官方为全局安装: npm install -g @astudioplus/codegraph-mcp
# 引擎由 postinstall 从 GitHub release 下载, npm 11 默认拦截脚本 -> 需 --allow-scripts
install_codegraph_mcp() {
    info "=== 安装 CodeGraph MCP (跨语言代码图谱) ==="
    require_npx
    local bin
    bin="$(_resolve_codegraph_bin)"
    if [ -z "$bin" ]; then
        info "全局安装 @astudioplus/codegraph-mcp (含引擎下载)..."
        npm install -g --allow-scripts=@astudioplus/codegraph-mcp \
            @astudioplus/codegraph-mcp 2>&1 | tail -3 || true
        bin="$(_resolve_codegraph_bin)"
    fi
    [ -n "$bin" ] || die "CodeGraph 安装失败 (npm 全局)"
    # 引擎缺失时先试官方补拉命令
    if ! "$bin" --help >/dev/null 2>&1; then
        info "引擎缺失, 用官方命令补拉..."
        npx --prefer-offline -y codegraph-mcp-fetch-engine 2>&1 | tail -3 || true
    fi
    # 官方补拉失败(如 GitHub CDN 不稳)时, 改用镜像下载并校验 SHA256
    if ! "$bin" --help >/dev/null 2>&1; then
        _codegraph_fetch_engine_mirror || warn "镜像补拉也失败, CodeGraph 可能不可用"
    fi
    mcp_add_all codegraph "$bin"
    ok "CodeGraph MCP 配置完成 ($bin)"
}

# 通过镜像下载 CodeGraph 引擎并校验 SHA256
# (官方 fetch-engine 直连 GitHub releases, 在部分网络下会中途截断)
_codegraph_fetch_engine_mirror() {
    local pkgdir engine_ver asset plat arch
    pkgdir="$(npm root -g 2>/dev/null)/@astudioplus/codegraph-mcp"
    [ -d "$pkgdir" ] || return 1

    case "$(uname -s)" in Darwin) plat=darwin ;; *) plat=linux ;; esac
    case "$(uname -m)" in
        x86_64|amd64) arch=x64 ;;
        aarch64|arm64) arch=arm64 ;;
        *) return 1 ;;
    esac
    asset="codegraph-server-${plat}-${arch}"

    # 从包内读取引擎版本 (与客户端版本独立)
    engine_ver="$(grep -oE 'ENGINE_VERSION = "[^"]+"' "$pkgdir/bin/fetch-engine.js" 2>/dev/null \
        | head -1 | sed 's/.*"\(.*\)"/\1/')"
    [ -n "$engine_ver" ] || engine_ver="$(cat "$pkgdir/bin/.engine-version" 2>/dev/null)"
    [ -n "$engine_ver" ] || { warn "无法确定引擎版本"; return 1; }

    local base="https://github.com/codegraph-ai/CodeGraph/releases/download/v${engine_ver}"
    local mirror
    for mirror in "https://ghfast.top/" "https://gh-proxy.com/" ""; do
        info "镜像补拉引擎: ${mirror:-直连} (v${engine_ver}/${asset})"
        if curl -fsSL --retry 3 --retry-all-errors --connect-timeout 20 \
                -o /tmp/cbm-engine "${mirror}${base}/${asset}" 2>/dev/null; then
            break
        fi
    done
    [ -s /tmp/cbm-engine ] || return 1

    # 校验 SHA256 (失败则拒绝安装)
    if curl -fsSL --connect-timeout 15 -o /tmp/cbm-engine.sha256 "${base}/${asset}.sha256" 2>/dev/null; then
        local want got
        want="$(awk '{print $1}' /tmp/cbm-engine.sha256)"
        got="$(sha256sum /tmp/cbm-engine | awk '{print $1}')"
        if [ -n "$want" ] && [ "$want" != "$got" ]; then
            warn "引擎 SHA256 校验失败 (want=$want got=$got), 拒绝安装"
            return 1
        fi
        info "引擎 SHA256 校验通过"
    else
        warn "未能获取 .sha256, 跳过校验"
    fi

    install -m 755 /tmp/cbm-engine "$pkgdir/bin/$asset" || return 1
    printf '%s\n' "$engine_ver" > "$pkgdir/bin/.engine-version"
    rm -f /tmp/cbm-engine /tmp/cbm-engine.sha256 "$pkgdir/bin/"*.partial 2>/dev/null || true
    ok "引擎已安装: $pkgdir/bin/$asset"
    return 0
}

# 定位 codegraph-mcp 可执行文件
_resolve_codegraph_bin() {
    if command -v codegraph-mcp >/dev/null 2>&1; then
        command -v codegraph-mcp; return 0
    fi
    local f
    for f in "$HOME"/.nvm/versions/node/*/bin/codegraph-mcp; do
        [ -x "$f" ] && { echo "$f"; return 0; }
    done
    return 1
}

# Serena MCP — 语义代码检索/编辑 (oraios 官方, PyPI serena-agent, uvx 运行)
# 按客户端传入对应 --context, 使 Serena 的工具集与提示词适配该代理
install_serena_mcp() {
    info "=== 安装 Serena MCP (语义代码检索/编辑) ==="
    require_npx
    ensure_uvx
    info "预热 uvx 缓存 (首次会下载依赖, 可能较慢)..."
    uvx --from serena-agent serena --help >/dev/null 2>&1 || true

    mcp_add_claude_stdio serena uvx --from serena-agent serena start-mcp-server \
        --context claude-code --project-from-cwd
    mcp_add_codex_stdio serena uvx --from serena-agent serena start-mcp-server \
        --context codex --project-from-cwd
    mcp_add_mimo_stdio serena uvx --from serena-agent serena start-mcp-server \
        --context agent --project-from-cwd
    ok "Serena MCP 配置完成 (uvx --from serena-agent serena)"
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
MCP_IDS_AVAILABLE=(filesystem git memory codebase-memory-mcp context7 codegraph serena)

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
        context7)            echo "Context7 MCP (实时文档检索)" ;;
        codegraph)           echo "CodeGraph MCP (跨语言代码图谱)" ;;
        serena)              echo "Serena MCP (语义检索/编辑)" ;;
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
# 确保 AI CLI 在 PATH 中 (nvm 环境 + 官方 MiMo 路径 + ~/.local/bin)
export PATH="$HOME/.mimocode/bin:$HOME/.local/bin:$PATH"
load_nvm

usage() {
    sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
    echo
    echo "可用 MCP 服务器:"
    echo "  filesystem           - 安全文件操作"
    echo "  git                  - Git 仓库操作"
    echo "  memory               - 知识图谱持久记忆"
    echo "  codebase-memory-mcp  - 代码库知识图谱 (158 语言, 子毫秒查询)"
    echo "  context7             - 实时文档/代码示例检索 (Upstash)"
    echo "  codegraph            - 跨语言代码图谱 (42 工具 / 38 语言)"
    echo "  serena               - 语义代码检索与编辑 (oraios)"
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
                filesystem|git|memory|codebase-memory-mcp|context7|codegraph|serena) TARGETS+=("$1"); shift ;;
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
        context7)            install_context7_mcp ;;
        codegraph)           install_codegraph_mcp ;;
        serena)              install_serena_mcp ;;
    esac
done
ok "全部 MCP 服务器安装完成!"
