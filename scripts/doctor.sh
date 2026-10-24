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
# 未安装的 AI CLI、桌面 AI 工具和未选择的 MCP 记为跳过, 不算失败。
# 代码智能 MCP 三选一; 装了多个只警告。配置了但命令不可用则失败。
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

PASS=0; FAIL=0; WARN=0; SKIP=0
FAILED_ITEMS=()
JSON_ITEMS=()

c_g() { printf '\033[0;32m%s\033[0m' "$1"; }
c_r() { printf '\033[0;31m%s\033[0m' "$1"; }
c_y() { printf '\033[1;33m%s\033[0m' "$1"; }
c_b() { printf '\033[1;36m%s\033[0m' "$1"; }
c_d() { printf '\033[2m%s\033[0m' "$1"; }

section() { $QUIET || printf '\n%s\n' "$(c_b "── $* ──")"; }

# 记录结果: ok|fail|warn|skip  <名称>  <详情>
record() {
    local status="$1" name="$2" detail="${3:-}"
    case "$status" in
        ok)   PASS=$((PASS + 1)) ;;
        warn) WARN=$((WARN + 1)) ;;
        skip) SKIP=$((SKIP + 1)) ;;
        fail) FAIL=$((FAIL + 1)); FAILED_ITEMS+=("$name${detail:+ — $detail}") ;;
    esac
    JSON_ITEMS+=("$(printf '{"status":"%s","name":"%s","detail":"%s"}' \
        "$status" "${name//\"/}" "${detail//\"/}")")
    $JSON && return 0
    if $QUIET && { [ "$status" = "ok" ] || [ "$status" = "skip" ]; }; then return 0; fi
    local mark
    case "$status" in
        ok)   mark="$(c_g '✓')" ;;
        warn) mark="$(c_y '!')" ;;
        skip) mark="$(c_d '·')" ;;
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
    [ -x "$HOME/.grok/bin/$name" ] && { echo "$HOME/.grok/bin/$name"; return 0; }
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

# 可选命令: 没装就跳过, 不记失败
chk_cmd_optional() {
    local name="$1" hint="${2:-未安装（可选）}" path ver
    if path="$(find_bin "$name")"; then
        ver="$(_probe_version "$path")"
        record ok "$name" "${ver:-$path}"
    else
        record skip "$name" "$hint"
    fi
}

chk_cmd_present_optional() {
    local name="$1" hint="${2:-未安装（可选）}" path
    if path="$(find_bin "$name")"; then
        record ok "$name" "$path"
    else
        record skip "$name" "$hint"
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
    find_bin gemini >/dev/null 2>&1 && echo "$HOME/.gemini/skills"
    find_bin opencode >/dev/null 2>&1 && echo "$HOME/.config/opencode/skills"
    find_bin grok >/dev/null 2>&1 && echo "$HOME/.grok/skills"
    find_bin mimo   >/dev/null 2>&1 && echo "$HOME/.config/mimocode/skills"
    if find_bin copilot >/dev/null 2>&1 || [ -d "$HOME/.copilot" ]; then
        echo "$HOME/.copilot/skills"
    fi
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
chk_cmd_optional claude   "未安装（可选，./install.sh devtools --claude）"
chk_cmd_optional codex    "未安装（可选，./install.sh devtools --codex）"
chk_cmd_optional gemini   "未安装（可选，./install.sh devtools --gemini）"
chk_cmd_optional opencode "未安装（可选，./install.sh devtools --opencode）"
chk_cmd_optional copilot  "未安装（可选，./install.sh devtools --copilot）"
chk_cmd_optional grok     "未安装（可选，./install.sh devtools --grok）"
chk_cmd_optional mimo     "未安装（可选，./install.sh devtools --mimo）"

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
chk_cmd_optional chatgpt "未安装（可选，./install.sh devtools --chatgpt）"
chk_cmd_present_optional cc-switch "未安装（可选，./install.sh devtools --ccswitch）"   # GUI 应用, --version 会启动界面
if find_bin godot >/dev/null 2>&1; then
    record ok "Godot" "$(find_bin godot) ($(godot --version 2>/dev/null | head -1))"
else
    record skip "Godot" "未安装（可选，./install.sh tools install godot）"
fi
# 微信/QQ 的 --version 会拉起界面。官方包命令是 wechat/qq, AUR 封装是另一套命令名。
if find_bin wechat >/dev/null 2>&1 || find_bin wechat-universal >/dev/null 2>&1; then
    record ok "微信" "$(find_bin wechat 2>/dev/null || find_bin wechat-universal)"
else
    record skip "微信" "未安装（可选，./install.sh tools install wechat）"
fi
if find_bin qq >/dev/null 2>&1 || find_bin linuxqq >/dev/null 2>&1; then
    record ok "QQ" "$(find_bin qq 2>/dev/null || find_bin linuxqq)"
else
    record skip "QQ" "未安装（可选，./install.sh tools install qq）"
fi
if find_bin fcitx5 >/dev/null 2>&1 && [ -f "$HOME/.local/share/fcitx5/rime/default.yaml" ]; then
    record ok "Rime 雾凇拼音" "Fcitx 5 + 雾凇词库"
else
    record skip "Rime 雾凇拼音" "未安装（可选，./install.sh tools install rime）"
fi

# ---------------------------------------------------------------------------
# 6. MCP 服务器
# ---------------------------------------------------------------------------
section "MCP 服务器"
EXPECTED_MCPS="$(expected_mcps || true)"
if [ -z "$EXPECTED_MCPS" ]; then
    record warn "MCP 清单" "无法从 install_mcp_servers.sh 读取"
else
    # 列出某个客户端已配置的 MCP: 每行 name<TAB>command
    list_client_mcps() {
        python3 - "$1" "$2" << 'PY'
import json, os, re, sys

kind, path = sys.argv[1], sys.argv[2]
if not os.path.exists(path):
    sys.exit(0)

def emit(name, command):
    if name:
        sys.stdout.write("%s\t%s\n" % (name, command or ""))

def command_of(entry):
    if not isinstance(entry, dict):
        return ""
    raw = entry.get("command")
    if isinstance(raw, str):
        return raw
    if isinstance(raw, list) and raw:
        return str(raw[0])
    if isinstance(raw, dict):
        return str(raw.get("path") or raw.get("command") or "")
    return ""

try:
    if kind == "toml":
        text = open(path, encoding="utf-8").read()
        pattern = re.compile(r"(?m)^\[mcp_servers\.([^\]]+)\][ \t]*$(.*?)(?=^\[|\Z)", re.S)
        for match in pattern.finditer(text):
            body = match.group(2)
            cmd = ""
            for line in body.splitlines():
                stripped = line.strip()
                if stripped.startswith("command") and "=" in stripped:
                    cmd = stripped.split("=", 1)[1].strip().strip('"').strip("'")
                    break
            emit(match.group(1).strip(), cmd)
    else:
        bucket = {
            "claude": "mcpServers",
            "gemini": "mcpServers",
            "zed": "context_servers",
            "vscode": "servers",
            "mimo": "mcp",
            "opencode": "mcp",
        }[kind]
        raw = open(path, encoding="utf-8-sig").read()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            raw = re.sub(r"/\*.*?\*/", "", raw, flags=re.S)
            raw = re.sub(r"(^|[^\\:])//.*?$", r"\1", raw, flags=re.M)
            data = json.loads(raw)
        servers = data.get(bucket) or {}
        if isinstance(servers, dict):
            for name, entry in servers.items():
                emit(name, command_of(entry))
except Exception:
    sys.exit(2)
PY
    }

    command_usable() {
        local cmd="$1"
        [ -n "$cmd" ] || return 1
        case "$cmd" in
            /*) [ -x "$cmd" ] ;;
            *) find_bin "$cmd" >/dev/null 2>&1 ;;
        esac
    }

    report_client_mcps() {
        local label="$1" kind="$2" path="$3"
        local rows rc=0 missing="" intel=0 cmd
        rows="$(list_client_mcps "$kind" "$path")" || rc=$?
        if [ "$rc" -ne 0 ]; then
            record fail "$label MCP 配置" "无法解析 $path"
            return
        fi
        if [ -z "$rows" ]; then
            record warn "$label MCP" "已安装客户端, 但还没有 MCP 配置"
            return
        fi
        for m in $EXPECTED_MCPS; do
            cmd="$(printf '%s\n' "$rows" | awk -F '\t' -v id="$m" '$1 == id { print $2; exit }')"
            if ! printf '%s\n' "$rows" | awk -F '\t' -v id="$m" '$1 == id { found=1 } END { exit !found }'; then
                case " $m " in
                    *" codebase-memory-mcp "*|*" codegraph "*|*" serena "*) ;;
                    *) missing="$missing $m" ;;
                esac
                continue
            fi
            case "$m" in
                codebase-memory-mcp|codegraph|serena) intel=$((intel + 1)) ;;
            esac
            if command_usable "$cmd"; then
                record ok "$label: $m"
            else
                record fail "$label: $m" "命令不可用: ${cmd:-<空>}"
            fi
        done
        if [ -n "$missing" ]; then
            record skip "$label 可选 MCP" "未配置:${missing}"
        fi
        if [ "$intel" -eq 0 ]; then
            record warn "$label 代码智能" "未配置。三选一: codebase-memory-mcp / codegraph / serena"
        elif [ "$intel" -gt 1 ]; then
            record warn "$label 代码智能" "同时启用了 ${intel} 个, 通常保留一个即可"
        fi
    }

    if find_bin claude >/dev/null 2>&1; then
        report_client_mcps claude claude "$HOME/.claude.json"
    fi
    if find_bin codex >/dev/null 2>&1; then
        report_client_mcps codex toml "$HOME/.codex/config.toml"
    fi
    if find_bin mimo >/dev/null 2>&1; then
        report_client_mcps mimo mimo "$HOME/.config/mimocode/mimocode.jsonc"
    fi
    if find_bin gemini >/dev/null 2>&1; then
        report_client_mcps gemini gemini "$HOME/.gemini/settings.json"
    fi
    if find_bin opencode >/dev/null 2>&1; then
        opencode_cfg="$HOME/.config/opencode/opencode.json"
        if [ -f "$HOME/.config/opencode/opencode.jsonc" ] && [ ! -f "$opencode_cfg" ]; then
            opencode_cfg="$HOME/.config/opencode/opencode.jsonc"
        fi
        report_client_mcps opencode opencode "$opencode_cfg"
    fi
    if find_bin grok >/dev/null 2>&1; then
        report_client_mcps grok toml "$HOME/.grok/config.toml"
    fi
    if find_bin zed >/dev/null 2>&1 || [ -x "$HOME/.local/bin/zed" ]; then
        report_client_mcps zed zed "$HOME/.config/zed/settings.json"
    fi
    if find_bin code >/dev/null 2>&1; then
        report_client_mcps vscode vscode "$HOME/.config/Code/User/mcp.json"
    fi
    if ! find_bin claude >/dev/null 2>&1 && ! find_bin codex >/dev/null 2>&1 \
        && ! find_bin mimo >/dev/null 2>&1 && ! find_bin gemini >/dev/null 2>&1 \
        && ! find_bin opencode >/dev/null 2>&1 && ! find_bin grok >/dev/null 2>&1 \
        && ! find_bin zed >/dev/null 2>&1 \
        && ! { [ -x "$HOME/.local/bin/zed" ] || find_bin code >/dev/null 2>&1; }; then
        record skip "MCP 客户端" "未安装支持的 AI 客户端, 跳过 MCP 检查"
    fi
fi

# 可选: 实际连接测试
if $CHECK_MCP_CONN; then
    if find_bin claude >/dev/null 2>&1; then
        section "MCP 连接测试 (claude, 较慢)"
        MCP_OUT="$(timeout 600 claude mcp list 2>/dev/null || true)"
        CONNECTED="$(printf '%s\n' "$MCP_OUT" | grep -c '✔ Connected' || true)"
        FAILED_CONN="$(printf '%s\n' "$MCP_OUT" | grep -E '✘|Failed' || true)"
        if [ -n "$FAILED_CONN" ]; then
            record fail "MCP 连接" "${CONNECTED:-0} 个已连接, 有服务器连接失败"
            printf '%s\n' "$FAILED_CONN" | head -5 | sed 's/^/      /'
        elif [ "${CONNECTED:-0}" -gt 0 ]; then
            record ok "MCP 连接" "${CONNECTED} 个已连接"
        else
            record warn "MCP 连接" "没有已连接的 MCP"
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
        label="$(echo "$d" | sed "s|$HOME/||")"
        if [ ! -d "$d" ]; then
            record skip "$label" "未安装技能（可选）"
            continue
        fi
        missing=""
        for s in $EXPECTED_SKILLS; do
            [ -f "$d/$s/SKILL.md" ] || missing="$missing $s"
        done
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
    printf '{"pass":%d,"skip":%d,"warn":%d,"fail":%d,"items":[%s]}\n' \
        "$PASS" "$SKIP" "$WARN" "$FAIL" "$(IFS=,; echo "${JSON_ITEMS[*]}")"
else
    printf '\n%s\n' "$(c_b '── 汇总 ──')"
    printf '  %s 通过   %s 跳过   %s 警告   %s 失败\n' \
        "$(c_g "$PASS")" "$(c_d "$SKIP")" "$(c_y "$WARN")" "$(c_r "$FAIL")"
    if [ "$FAIL" -gt 0 ]; then
        printf '\n%s\n' "$(c_r '需要处理:')"
        for i in "${FAILED_ITEMS[@]}"; do printf '  • %s\n' "$i"; done
    else
        printf '\n%s\n' "$(c_g '环境就绪 ✓')"
    fi
fi

[ "$FAIL" -eq 0 ]
