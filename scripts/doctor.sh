#!/usr/bin/env bash
# =============================================================================
# joe doctor — 开发环境体检
# =============================================================================
# 检查 joe 安装的工具 / MCP 服务器 / 代理技能是否就绪，并给出可执行的修复建议。
#
# 用法:
#   ./install.sh doctor              # 常规检查 (默认不测 MCP 连接, 较快)
#   ./install.sh doctor --mcp        # 额外实际连接每个 MCP (慢, 每个约 10-30s)
#   ./install.sh doctor --quiet      # 只输出问题项
#   ./install.sh doctor --json       # 机器可读输出
#
# 退出码: 0 = 无失败项, 1 = 有失败项(缺失/不可用)
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib_ghostty.sh
. "$SCRIPT_DIR/lib_ghostty.sh"

# 多字节文本按"字符"处理
if [ -z "${LC_ALL:-}" ]; then
    for _loc in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
        if locale -a 2>/dev/null | grep -qix "$_loc"; then export LC_ALL="$_loc"; break; fi
    done
    unset _loc
fi

CHECK_MCP_CONN=false
QUIET=false
JSON=false
for a in "$@"; do
    case "$a" in
        --mcp)   CHECK_MCP_CONN=true ;;
        --quiet) QUIET=true ;;
        --json)  JSON=true ;;
        -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "未知选项: $a" >&2; exit 2 ;;
    esac
done

PASS=0; FAIL=0; WARN=0
FAILED_ITEMS=()
JSON_ITEMS=()

c_g() { printf '\033[0;32m%s\033[0m' "$1"; }
c_r() { printf '\033[0;31m%s\033[0m' "$1"; }
c_y() { printf '\033[1;33m%s\033[0m' "$1"; }
c_b() { printf '\033[1;36m%s\033[0m' "$1"; }
c_d() { printf '\033[2m%s\033[0m' "$1"; }

section() { $QUIET || printf '\n%s\n' "$(c_b "── $* ──")"; }

# 记录结果: ok|fail|warn  <名称>  <详情>
record() {
    local status="$1" name="$2" detail="${3:-}"
    case "$status" in
        ok)   PASS=$((PASS + 1)) ;;
        warn) WARN=$((WARN + 1)) ;;
        fail) FAIL=$((FAIL + 1)); FAILED_ITEMS+=("$name${detail:+ — $detail}") ;;
    esac
    JSON_ITEMS+=("$(printf '{"status":"%s","name":"%s","detail":"%s"}' \
        "$status" "${name//\"/}" "${detail//\"/}")")
    $JSON && return 0
    if $QUIET && [ "$status" = "ok" ]; then return 0; fi
    local mark
    case "$status" in
        ok)   mark="$(c_g '✓')" ;;
        warn) mark="$(c_y '!')" ;;
        fail) mark="$(c_r '✗')" ;;
    esac
    if [ -n "$detail" ]; then
        printf '  %s %-34s %s\n' "$mark" "$name" "$(c_d "$detail")"
    else
        printf '  %s %s\n' "$mark" "$name"
    fi
}

# 命令探测: PATH / ~/.local/bin / ~/.mimocode/bin / nvm 版本目录
find_bin() {
    local name="$1" f
    f="${NVM_DIR:-$HOME/.nvm}/current/bin/$name"
    [ -x "$f" ] && { printf '%s\n' "$f"; return 0; }
    command -v "$name" >/dev/null 2>&1 && { command -v "$name"; return 0; }
    [ -x "$HOME/.local/bin/$name" ] && { echo "$HOME/.local/bin/$name"; return 0; }
    [ -x "$HOME/.mimocode/bin/$name" ] && { echo "$HOME/.mimocode/bin/$name"; return 0; }
    [ -x "$HOME/.pyenv/bin/$name" ] && { echo "$HOME/.pyenv/bin/$name"; return 0; }
    [ -x "$HOME/.pyenv/shims/$name" ] && { echo "$HOME/.pyenv/shims/$name"; return 0; }
    for f in "$HOME"/.nvm/versions/node/*/bin/"$name"; do
        [ -x "$f" ] && { echo "$f"; return 0; }
    done
    return 1
}

# 带超时地取版本 (GUI 应用的 --version 可能会阻塞, 如 cc-switch 会启动界面)
_probe_version() {
    local path="$1"
    if command -v timeout >/dev/null 2>&1; then
        timeout 5 "$path" --version 2>/dev/null | head -1
    else
        "$path" --version 2>/dev/null | head -1
    fi
}

# 检查一个命令 (取版本)
chk_cmd() {
    local name="$1" hint="${2:-}" path ver
    if path="$(find_bin "$name")"; then
        ver="$(_probe_version "$path")"
        record ok "$name" "${ver:-$path}"
    else
        record fail "$name" "${hint:-未找到}"
    fi
}

# 检查一个命令 (仅确认存在, 不探测版本 —— 用于 GUI 应用)
chk_cmd_present() {
    local name="$1" hint="${2:-}" path
    if path="$(find_bin "$name")"; then
        record ok "$name" "$path"
    else
        record fail "$name" "${hint:-未找到}"
    fi
}

# 从 install_mcp_servers.sh 读取期望的 MCP 列表
expected_mcps() {
    local f="$SCRIPT_DIR/install_mcp_servers.sh"
    [ -f "$f" ] || return 1
    sed -n 's/^MCP_IDS_AVAILABLE=(\(.*\))$/\1/p' "$f" | head -1
}

# 从 skills/ 目录读取期望的技能列表
expected_skills() {
    local d
    for d in "$REPO_ROOT"/skills/*/SKILL.md; do
        [ -f "$d" ] || continue
        basename "$(dirname "$d")"
    done
}

# 代理端技能目录
skill_dirs() {
    find_bin claude >/dev/null 2>&1 && echo "$HOME/.claude/skills"
    find_bin codex  >/dev/null 2>&1 && echo "$HOME/.codex/skills"
    find_bin mimo   >/dev/null 2>&1 && echo "$HOME/.config/mimocode/skills"
    [ -d "$HOME/.copilot" ] && echo "$HOME/.copilot/skills"
    echo "$HOME/.agents/skills"
    return 0
}

# ---------------------------------------------------------------------------
# 1. 系统信息与兼容性
# ---------------------------------------------------------------------------
section "系统信息与兼容性"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    record ok "操作系统" "${PRETTY_NAME:-unknown}"

    # 检查发行版兼容性
    case "${ID:-unknown}" in
        ubuntu|debian|linuxmint|pop|elementary|arch|cachyos|manjaro|fedora|rhel|centos|opensuse*)
            record ok "发行版支持" "已验证兼容"
            ;;
        *)
            record warn "发行版支持" "未在此发行版上测试 ($ID)"
            ;;
    esac

    # Linux Mint 特别检查
    if [ "${ID:-}" = "linuxmint" ]; then
        if [ -n "${UBUNTU_CODENAME:-}" ]; then
            record ok "Ubuntu 基线" "${UBUNTU_CODENAME} (${UBUNTU_VERSION_ID:-未知})"
        else
            record warn "Ubuntu 基线" "无法确定对应的 Ubuntu 版本"
        fi
    fi
else
    record warn "操作系统" "无法读取 /etc/os-release"
fi
record ok "内核" "$(uname -r)"
record ok "架构" "$(uname -m)"

# 磁盘空间检查（开发工具需要较多空间）
section "系统资源"
HOME_AVAIL=$(df -BG "$HOME" 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
if [ -n "$HOME_AVAIL" ]; then
    if [ "$HOME_AVAIL" -ge 10 ]; then
        record ok "磁盘空间" "${HOME_AVAIL}GB 可用"
    elif [ "$HOME_AVAIL" -ge 5 ]; then
        record warn "磁盘空间" "${HOME_AVAIL}GB 可用 (建议至少 10GB)"
    else
        record fail "磁盘空间" "${HOME_AVAIL}GB 可用 (不足，建议至少 10GB)"
    fi
else
    record warn "磁盘空间" "无法检测"
fi

# 网络连接检查
section "网络连接"
if curl -fsSL --connect-timeout 5 --max-time 10 https://github.com >/dev/null 2>&1; then
    record ok "GitHub 连接" "可访问"
else
    record warn "GitHub 连接" "无法访问 (某些安装步骤可能失败)"
fi

if curl -fsSL --connect-timeout 5 --max-time 10 https://registry.npmjs.org >/dev/null 2>&1; then
    record ok "npm registry" "可访问"
else
    record warn "npm registry" "无法访问 (Node 包安装可能失败)"
fi

# ---------------------------------------------------------------------------
# 2. 基础工具
# ---------------------------------------------------------------------------
section "基础工具"
for c in git curl; do
    chk_cmd "$c" "请先安装 $c"
done

# ---------------------------------------------------------------------------
# 3. Node / Python 工具链
# ---------------------------------------------------------------------------
section "Node / Python 工具链"
for c in node npm npx; do
    chk_cmd "$c" "运行 ./install.sh devtools --node"
done
for c in python3 pipx; do
    chk_cmd "$c" "运行 ./install.sh devtools --python"
done
chk_cmd pyenv "运行 ./install.sh devtools --python"
for c in uv uvx; do
    chk_cmd "$c" "运行 ./install.sh mcp git (会装 uv)"
done

# ---------------------------------------------------------------------------
# 4. AI CLI
# ---------------------------------------------------------------------------
section "AI CLI"
chk_cmd claude "运行 ./install.sh devtools --ai"
chk_cmd codex  "运行 ./install.sh devtools --ai"
chk_cmd mimo   "运行 ./install.sh devtools --mimo"

# ---------------------------------------------------------------------------
# 5. 编辑器 / 终端 / 桌面
# ---------------------------------------------------------------------------
section "编辑器 / 终端 / 桌面"
chk_cmd zed      "运行 ./install.sh devtools --zed"
chk_cmd code     "运行 ./install.sh devtools --vscode"
chk_cmd ghostty  "运行 ./install.sh devtools --ghostty"
if find_bin ghostty >/dev/null 2>&1; then
    if command -v infocmp >/dev/null 2>&1 && infocmp -x xterm-ghostty >/dev/null 2>&1; then
        record ok "Ghostty terminfo" "当前用户的 xterm-ghostty 可用"
    else
        record fail "Ghostty terminfo" "运行 ./install.sh repair-ghostty (minicom 等终端程序需要)"
    fi
    if ghostty_system_terminfo_available; then
        record ok "Ghostty 系统 terminfo" "sudo 下的 xterm-ghostty 可用"
    else
        record fail "Ghostty 系统 terminfo" "运行 ./install.sh repair-ghostty 并完成 sudo 认证 (仅 ~/.terminfo 无法支持 sudo minicom)"
    fi
fi
chk_cmd chatgpt  "运行 ./install.sh devtools --chatgpt"
chk_cmd_present cc-switch "运行 ./install.sh devtools --ccswitch"   # GUI 应用, --version 会启动界面

# ---------------------------------------------------------------------------
# 6. MCP 服务器
# ---------------------------------------------------------------------------
section "MCP 服务器"
EXPECTED_MCPS="$(expected_mcps || true)"
if [ -z "$EXPECTED_MCPS" ]; then
    record warn "MCP 清单" "无法从 install_mcp_servers.sh 读取"
else
    # Claude Code (user 作用域)
    if [ -f "$HOME/.claude.json" ]; then
        for m in $EXPECTED_MCPS; do
            if python3 -c "
import json,sys
try:
    d=json.load(open('$HOME/.claude.json'))
except Exception:
    sys.exit(1)
sys.exit(0 if '$m' in (d.get('mcpServers') or {}) else 1)
" 2>/dev/null; then
                record ok "claude: $m"
            else
                record fail "claude: $m" "运行 ./install.sh mcp $m"
            fi
        done
    else
        record warn "claude MCP 配置" "~/.claude.json 不存在 (未用过 Claude Code?)"
    fi

    # Codex
    if find_bin codex >/dev/null 2>&1; then
        CODEX_MCP="$(codex mcp list 2>/dev/null | awk 'NR>1 && NF {print $1}')"
        for m in $EXPECTED_MCPS; do
            if printf '%s\n' "$CODEX_MCP" | grep -qx "$m"; then
                record ok "codex: $m"
            else
                record fail "codex: $m" "运行 ./install.sh mcp $m"
            fi
        done
    fi

    # MiMo Code
    MIMO_CFG="$HOME/.config/mimocode/mimocode.jsonc"
    if [ -f "$MIMO_CFG" ]; then
        for m in $EXPECTED_MCPS; do
            if grep -q "\"$m\"" "$MIMO_CFG" 2>/dev/null; then
                record ok "mimo: $m"
            else
                record fail "mimo: $m" "运行 ./install.sh mcp $m"
            fi
        done
    fi
fi

# 可选: 实际连接测试
if $CHECK_MCP_CONN; then
    if find_bin claude >/dev/null 2>&1; then
        section "MCP 连接测试 (claude, 较慢)"
        MCP_OUT="$(timeout 600 claude mcp list 2>/dev/null || true)"
        CONNECTED="$(printf '%s\n' "$MCP_OUT" | grep -c '✔ Connected' || true)"
        TOTAL="$(printf '%s\n' "$EXPECTED_MCPS" | wc -w)"
        if [ "${CONNECTED:-0}" -ge "${TOTAL:-0}" ] && [ "${TOTAL:-0}" -gt 0 ]; then
            record ok "MCP 连接" "${CONNECTED}/${TOTAL} 已连接"
        else
            record fail "MCP 连接" "仅 ${CONNECTED:-0}/${TOTAL:-0} 已连接"
            printf '%s\n' "$MCP_OUT" | grep -E '✘|Failed' | head -5 | sed 's/^/      /'
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 7. 代理技能
# ---------------------------------------------------------------------------
section "代理技能"
EXPECTED_SKILLS="$(expected_skills || true)"
if [ -z "$EXPECTED_SKILLS" ]; then
    record warn "技能清单" "skills/ 下没有技能"
else
    for d in $(skill_dirs); do
        missing=""
        for s in $EXPECTED_SKILLS; do
            [ -f "$d/$s/SKILL.md" ] || missing="$missing $s"
        done
        label="$(echo "$d" | sed "s|$HOME/||")"
        if [ -z "$missing" ]; then
            record ok "$label" "$(printf '%s' "$EXPECTED_SKILLS" | wc -w) 个技能就绪"
        else
            record fail "$label" "缺少:$missing (运行 ./install.sh skills)"
        fi
    done
fi

# ---------------------------------------------------------------------------
# 8. 前端校验 (frontmatter 是否合法)
# ---------------------------------------------------------------------------
section "技能定义校验"
bad=0
for s in $EXPECTED_SKILLS; do
    f="$REPO_ROOT/skills/$s/SKILL.md"
    [ -f "$f" ] || continue
    if ! head -1 "$f" | grep -qE '^---[[:space:]]*$'; then
        record fail "$s frontmatter" "缺少 YAML frontmatter"; bad=1; continue
    fi
    if ! awk 'NR==1{f=1;next} f&&/^---/{exit} f&&/^name:/{found=1} END{exit !found}' "$f"; then
        record fail "$s frontmatter" "缺少 name"; bad=1; continue
    fi
    if ! awk 'NR==1{f=1;next} f&&/^---/{exit} f&&/^description:/{found=1} END{exit !found}' "$f"; then
        record fail "$s frontmatter" "缺少 description"; bad=1; continue
    fi
    record ok "$s"
done
[ "$bad" = "0" ] && $QUIET || true

# ---------------------------------------------------------------------------
# 9. 代理连通性 (可选)
# ---------------------------------------------------------------------------
if [ -n "${PROXY_URL:-}" ]; then
    section "代理"
    if curl -fsS -o /dev/null --connect-timeout 8 -x "$PROXY_URL" https://github.com 2>/dev/null; then
        record ok "PROXY_URL" "$PROXY_URL 可达"
    else
        record warn "PROXY_URL" "$PROXY_URL 不可达"
    fi
fi

# ---------------------------------------------------------------------------
# 汇总
# ---------------------------------------------------------------------------
if $JSON; then
    printf '{"pass":%d,"warn":%d,"fail":%d,"items":[%s]}\n' \
        "$PASS" "$WARN" "$FAIL" "$(IFS=,; echo "${JSON_ITEMS[*]}")"
else
    printf '\n%s\n' "$(c_b '── 汇总 ──')"
    printf '  %s 通过   %s 警告   %s 失败\n' "$(c_g "$PASS")" "$(c_y "$WARN")" "$(c_r "$FAIL")"
    if [ "$FAIL" -gt 0 ]; then
        printf '\n%s\n' "$(c_r '需要处理:')"
        for i in "${FAILED_ITEMS[@]}"; do printf '  • %s\n' "$i"; done
    else
        printf '\n%s\n' "$(c_g '环境就绪 ✓')"
    fi
fi

[ "$FAIL" -eq 0 ]
