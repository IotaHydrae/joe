#!/usr/bin/env bash
# =============================================================================
# joe install_mcp_servers — MCP 服务器安装器 (含 TUI)
# =============================================================================
# 安装并配置各种 MCP (Model Context Protocol) 服务器, 自动接入已安装的
# AI CLI (Claude Code, Codex, Gemini CLI, OpenCode, Grok Build, MiMo Code) 以及已安装的 Zed / VS Code。
# Copilot CLI 的 MCP 用 `copilot mcp add` 自行配置。
# 已有同名配置会比较命令和参数, 有变化时就地更新。
#
# 用法:
#   ./install.sh mcp                  # 默认进入 TUI, 不预选; 非交互须指定服务器
#   ./install.sh mcp --tui            # 强制进入 TUI 勾选界面
#   ./install.sh mcp --all            # 显式安装全部 MCP
#   ./install.sh mcp --list           # 列出可用 MCP 服务器及状态
#   ./install.sh mcp filesystem       # 只装 filesystem MCP
#   ./install.sh mcp git memory       # 装多个 MCP
#
# 新语法别名 (由 scripts/commands/mcp.sh 转换, 行为与上面的旧写法一致):
#   ./install.sh mcp list                    # = --list
#   ./install.sh mcp install git memory      # = git memory
#   ./install.sh mcp update filesystem       # = filesystem (重跑即刷新配置)
#
# TUI 按键: ↑/↓ 移动, PgUp/PgDn 翻页, Home/End 首尾, 空格 勾选,
#           a 全选, n 全不选, i 仅未装, 回车 开始, q 退出
#
# 新增 MCP 服务器:
#   1. 添加 install_<name>_mcp() 函数
#   2. 把 id 加入 MCP_IDS_AVAILABLE, 并在 tui_component_installed / _name 中登记
#   3. 加入参数解析 case 与主流程 case
#
# 依赖: git, curl, npx (Node 18+), python3 (Claude/MiMo 配置), 已装的 AI CLI
# 说明:
#   - 幂等: 命令和参数都没变时跳过; 变了则更新
#   - filesystem 必须用 FILESYSTEM_DIRS 指定目录, 不再默认开放整个主目录
#   - 代码智能 MCP (codebase-memory-mcp / codegraph / serena) 是三选一
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

# 共享的 GitHub 下载/校验函数
if [ -f "$SCRIPT_DIR/lib_github.sh" ]; then
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/lib_github.sh"
fi

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 临时文件登记 + 退出清理 (uv 安装脚本等)
TMP_FILES=()
cleanup_tmp() {
    if [ ${#TMP_FILES[@]} -gt 0 ]; then
        rm -f -- "${TMP_FILES[@]}"
    fi
}
trap cleanup_tmp EXIT

make_tmp() {
    local __var="$1" __suffix="${2:-}" __f
    if [ -n "$__suffix" ]; then
        __f=$(mktemp --suffix="$__suffix")
    else
        __f=$(mktemp)
    fi
    TMP_FILES+=("$__f")
    printf -v "$__var" '%s' "$__f"
}

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
    [ -x "$HOME/.mimocode/bin/$name" ] && return 0   # MiMo Code 官方安装路径
    [ -x "$HOME/.grok/bin/$name" ] && return 0       # Grok Build 官方安装路径
    local f
    for f in "$HOME"/.nvm/versions/node/*/bin/"$name"; do
        [ -x "$f" ] && return 0
    done
    return 1
}

has_claude()   { _has_bin claude; }
has_codex()    { _has_bin codex; }
has_gemini()   { _has_bin gemini; }
has_opencode() { _has_bin opencode; }
has_grok()     { _has_bin grok; }
has_mimo()     { _has_bin mimo; }
has_zed()    { [ -x "$HOME/.local/bin/zed" ] || command -v zed >/dev/null 2>&1; }
has_code()   { command -v code >/dev/null 2>&1; }

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
    command -v python3 >/dev/null 2>&1 || die "需要 python3 来读取 Claude Code 配置"
    python3 - "$HOME/.claude.json" "$name" << 'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(1)
sys.exit(0 if sys.argv[2] in (d.get("mcpServers") or {}) else 1)
PYEOF
}

# 写入或更新一个 stdio MCP。stdout 只打印 same|added|updated。
# 配置无法安全解析时退出 2 (调用方跳过, 不覆盖用户文件)。
sync_stdio_client() {
    local backend="$1" name="$2" result rc=0
    shift 2
    result="$(python3 - "$backend" "$name" "$@" << 'PY'
import json, os, re, stat, sys, tempfile

backend, name = sys.argv[1], sys.argv[2]
argv = sys.argv[3:]
if not argv:
    sys.stderr.write("缺少 MCP 命令\n")
    sys.exit(1)
command, args = argv[0], argv[1:]
home = os.environ["HOME"]


def atomic_write(path, data):
    parent = os.path.dirname(path)
    os.makedirs(parent, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix="." + os.path.basename(path) + ".", dir=parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        if os.path.exists(path):
            os.chmod(tmp, stat.S_IMODE(os.stat(path).st_mode))
        else:
            os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def same_args(current, desired):
    if current is None:
        current = []
    return list(current) == list(desired)


def load_json(path):
    with open(path, encoding="utf-8-sig") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("配置根节点必须是对象")
    return data


def dump_json(data):
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def upsert_json_server(path, bucket, entry):
    if os.path.exists(path):
        try:
            data = load_json(path)
        except (OSError, json.JSONDecodeError, ValueError) as error:
            sys.stderr.write("无法解析 %s (%s), 已跳过\n" % (path, error))
            sys.exit(2)
    else:
        data = {}
    servers = data.get(bucket)
    if servers is None:
        servers = {}
    if not isinstance(servers, dict):
        sys.stderr.write("%s 的 %s 不是对象, 已跳过\n" % (path, bucket))
        sys.exit(2)
    current = servers.get(name)
    if isinstance(current, dict) and current.get("command") == command and same_args(current.get("args"), args):
        print("same")
        return
    status = "updated" if isinstance(current, dict) else "added"
    if not isinstance(current, dict):
        current = {}
    current.update(entry)
    servers[name] = current
    data[bucket] = servers
    atomic_write(path, dump_json(data))
    print(status)


def unquote_toml(raw):
    raw = raw.strip().rstrip(",")
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'":
        if raw[0] == '"':
            try:
                return json.loads(raw)
            except json.JSONDecodeError:
                return None
        return raw[1:-1]
    return raw


def parse_toml_section(body):
    found_cmd = None
    found_args = []
    saw_args = False
    for line in body.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("command") and "=" in stripped:
            found_cmd = unquote_toml(stripped.split("=", 1)[1])
        elif stripped.startswith("args") and "=" in stripped:
            saw_args = True
            raw = stripped.split("=", 1)[1].strip()
            if not raw.startswith("["):
                return None
            try:
                found_args = json.loads(raw)
            except json.JSONDecodeError:
                return None
    if found_cmd is None or not isinstance(found_args, list):
        return None
    if not saw_args:
        found_args = []
    return found_cmd, [str(item) for item in found_args]


def format_toml_section():
    lines = [
        "[mcp_servers.%s]" % name,
        "command = %s" % json.dumps(command, ensure_ascii=False),
    ]
    if args:
        rendered = ", ".join(json.dumps(item, ensure_ascii=False) for item in args)
        lines.append("args = [%s]" % rendered)
    return "\n".join(lines) + "\n"


def upsert_codex(path):
    text = ""
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    pattern = re.compile(r"(?m)^\[mcp_servers\.%s\][ \t]*$" % re.escape(name))
    match = pattern.search(text)
    block = format_toml_section()
    if not match:
        if text and not text.endswith("\n"):
            text += "\n"
        if text and not text.endswith("\n\n"):
            text += "\n"
        atomic_write(path, text + block)
        print("added")
        return
    rest = text[match.end():]
    nxt = re.search(r"(?m)^\[", rest)
    end = match.end() + (nxt.start() if nxt else len(rest))
    parsed = parse_toml_section(text[match.start():end])
    if parsed == (command, list(args)):
        print("same")
        return
    atomic_write(path, text[:match.start()] + block + text[end:].lstrip("\n"))
    print("updated")


try:
    if backend == "claude":
        upsert_json_server(
            os.path.join(home, ".claude.json"),
            "mcpServers",
            {"type": "stdio", "command": command, "args": args},
        )
    elif backend == "zed":
        upsert_json_server(
            os.path.join(home, ".config", "zed", "settings.json"),
            "context_servers",
            {"command": command, "args": args},
        )
    elif backend == "vscode":
        upsert_json_server(
            os.path.join(home, ".config", "Code", "User", "mcp.json"),
            "servers",
            {"type": "stdio", "command": command, "args": args},
        )
    elif backend == "codex":
        upsert_codex(os.path.join(home, ".codex", "config.toml"))
    elif backend == "grok":
        upsert_codex(os.path.join(home, ".grok", "config.toml"))
    elif backend == "gemini":
        upsert_json_server(
            os.path.join(home, ".gemini", "settings.json"),
            "mcpServers",
            {"command": command, "args": args},
        )
    elif backend == "opencode":
        base = os.path.join(home, ".config", "opencode")
        path = os.path.join(base, "opencode.json")
        jsonc = os.path.join(base, "opencode.jsonc")
        if os.path.exists(jsonc) and not os.path.exists(path):
            path = jsonc
        desired = [command] + list(args)
        if os.path.exists(path):
            try:
                data = load_json(path)
            except (OSError, json.JSONDecodeError, ValueError) as error:
                sys.stderr.write("无法解析 %s (%s), 已跳过\n" % (path, error))
                sys.exit(2)
        else:
            data = {}
        mcp = data.get("mcp")
        if mcp is None:
            mcp = {}
        if not isinstance(mcp, dict):
            sys.stderr.write("%s 的 mcp 不是对象, 已跳过\n" % path)
            sys.exit(2)
        current = mcp.get(name)
        current_cmd = current.get("command") if isinstance(current, dict) else None
        if isinstance(current_cmd, str):
            current_cmd = [current_cmd]
        if isinstance(current, dict) and list(current_cmd or []) == desired:
            print("same")
        else:
            status = "updated" if isinstance(current, dict) else "added"
            if not isinstance(current, dict):
                current = {}
            current["type"] = "local"
            current["command"] = desired
            if "enabled" not in current:
                current["enabled"] = True
            mcp[name] = current
            data["mcp"] = mcp
            atomic_write(path, dump_json(data))
            print(status)
    else:
        sys.stderr.write("未知配置目标: %s\n" % backend)
        sys.exit(1)
except OSError as error:
    sys.stderr.write("写入 MCP 配置失败: %s\n" % error)
    sys.exit(1)
PY
)" || rc=$?
    if [ "$rc" -eq 2 ]; then
        warn "${backend}: ${name} 配置无法解析, 已跳过"
        return 0
    fi
    if [ "$rc" -ne 0 ]; then
        return 1
    fi
    local label="$backend"
    case "$backend" in
        claude) label="Claude Code" ;;
        codex)  label="Codex" ;;
        zed)    label="Zed" ;;
        vscode) label="VS Code" ;;
        gemini) label="Gemini CLI" ;;
        opencode) label="OpenCode" ;;
        grok) label="Grok Build" ;;
    esac
    case "$result" in
        same) info "${label}: ${name} 已配置且命令未变, 跳过" ;;
        added) ok "${label}: ${name} MCP 已添加" ;;
        updated) ok "${label}: ${name} 命令已更新" ;;
        *) warn "${label}: ${name} 同步结果异常: ${result}"; return 1 ;;
    esac
}

mcp_add_claude_stdio() {
    local name="$1"; shift
    has_claude || { warn "未安装 claude, 跳过 Claude Code 配置"; return 0; }
    sync_stdio_client claude "$name" "$@"
}

mcp_add_gemini_stdio() {
    local name="$1"; shift
    has_gemini || { info "未安装 Gemini CLI, 跳过 Gemini 配置"; return 0; }
    sync_stdio_client gemini "$name" "$@"
}

mcp_add_opencode_stdio() {
    local name="$1"; shift
    has_opencode || { info "未安装 OpenCode, 跳过 OpenCode 配置"; return 0; }
    sync_stdio_client opencode "$name" "$@"
}

mcp_add_grok_stdio() {
    local name="$1"; shift
    has_grok || { info "未安装 Grok Build, 跳过 Grok 配置"; return 0; }
    sync_stdio_client grok "$name" "$@"
}

# ---------------------------------------------------------------------------
# 配置目标: Codex CLI
# ---------------------------------------------------------------------------
mcp_add_codex_stdio() {
    local name="$1"; shift
    has_codex || { warn "未安装 codex, 跳过 Codex 配置"; return 0; }
    sync_stdio_client codex "$name" "$@"
}

mcp_add_zed_stdio() {
    local name="$1"; shift
    has_zed || { info "未安装 Zed, 跳过 Zed 配置"; return 0; }
    sync_stdio_client zed "$name" "$@"
}

mcp_add_vscode_stdio() {
    local name="$1"; shift
    has_code || { info "未安装 VS Code, 跳过 VS Code 配置"; return 0; }
    sync_stdio_client vscode "$name" "$@"
}

# ---------------------------------------------------------------------------
# 配置目标: MiMo Code (编辑 ~/.config/mimocode/mimocode.jsonc)
# ---------------------------------------------------------------------------
# 状态检测与写入使用同一 JSONC 解析器, 只检查 mcp 对象。
mimo_config() {
    command -v python3 >/dev/null 2>&1 || die "需要 python3 来处理 MiMo Code 配置"
    python3 - "$@" << 'PYEOF'
import json, os, re, shutil, stat, sys, tempfile, time


def strip_jsonc(text):
    """去注释与尾随逗号, 两步均跳过字符串内部。"""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif c == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            out.append(' ')
            i = n if j == -1 else j
            continue
        elif c == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            if j == -1:
                raise ValueError("块注释未闭合")
            out.append(' ')
            i = j + 2
            continue
        else:
            out.append(c)
        i += 1

    text = ''.join(out)
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif c == ',':
            j = i + 1
            while j < n and text[j].isspace():
                j += 1
            if j == n or text[j] not in '}]':
                out.append(c)
        else:
            out.append(c)
        i += 1
    return ''.join(out)


mode, cfg, name = sys.argv[1:4]
try:
    if os.path.exists(cfg):
        with open(cfg, encoding="utf-8-sig") as f:
            raw = f.read()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            data = json.loads(strip_jsonc(raw))
        if not isinstance(data, dict):
            raise ValueError("配置根节点必须是对象")
        if "mcp" in data and not isinstance(data["mcp"], dict):
            raise ValueError("mcp 配置必须是对象")
    else:
        if mode == "has":
            sys.exit(1)
        data = {"$schema": "https://mimo.xiaomi.com/mimocode/config.json"}

    mcp = data.get("mcp", {})
    if mode == "has":
        sys.exit(0 if name in mcp else 1)
    desired = sys.argv[4:]
    if name in mcp and isinstance(mcp.get(name), dict):
        current = mcp[name].get("command")
        if isinstance(current, str):
            current = [current]
        if list(current or []) == desired:
            print("same")
            sys.exit(0)
        mcp[name]["type"] = mcp[name].get("type") or "local"
        mcp[name]["command"] = desired
        if "enabled" not in mcp[name]:
            mcp[name]["enabled"] = True
        data["mcp"] = mcp
        status = "updated"
    else:
        mcp[name] = {"type": "local", "command": desired, "enabled": True}
        data["mcp"] = mcp
        status = "added"
    data["mcp"] = mcp
    payload = json.dumps(data, indent=2, ensure_ascii=False) + "\n"

    # 保留符号链接及权限, 在同目录写临时文件后替换。
    target = os.path.realpath(cfg)
    parent = os.path.dirname(target)
    os.makedirs(parent, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix="." + os.path.basename(target) + ".", dir=parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(payload)
            f.flush()
            os.fsync(f.fileno())
        if os.path.exists(target):
            os.chmod(tmp, stat.S_IMODE(os.stat(target).st_mode))
            backup = target + ".bak." + time.strftime("%Y%m%d%H%M%S")
            candidate, index = backup, 0
            while os.path.exists(candidate):
                index += 1
                candidate = backup + "." + str(index)
            shutil.copy2(target, candidate)
        os.replace(tmp, target)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

    pattern = re.compile(re.escape(os.path.basename(target)) + r"\.bak\.\d+(?:\.\d+)?$")
    backups = [os.path.join(parent, f) for f in os.listdir(parent) if pattern.fullmatch(f)]
    backups.sort(key=lambda p: os.stat(p).st_mtime_ns, reverse=True)
    for old in backups[5:]:
        os.unlink(old)
    print(status)
except (OSError, ValueError) as error:
    sys.stderr.write("MiMo Code 配置处理失败 (%s): %s\n" % (cfg, error))
    sys.exit(1)
PYEOF
}

mcp_add_mimo_stdio() {
    local name="$1"; shift
    has_mimo || { warn "未安装 mimo, 跳过 MiMo Code 配置"; return 0; }
    local cfg="${MIMO_CONFIG:-$HOME/.config/mimocode/mimocode.jsonc}" result
    if result=$(mimo_config add "$cfg" "$name" "$@"); then
        case "$result" in
            added) ok "MiMo Code: ${name} MCP 已添加 (${cfg})" ;;
            updated) ok "MiMo Code: ${name} 命令已更新 (${cfg})" ;;
            same) info "MiMo Code: ${name} 已配置且命令未变, 跳过" ;;
            *) warn "MiMo Code: ${name} 同步结果异常: ${result}"; return 1 ;;
        esac
    else
        return 1
    fi
}

# 统一入口: 添加到所有已安装的 AI CLI
mcp_add_all() {
    local name="$1"; shift
    mcp_add_claude_stdio "$name" "$@" || return 1
    mcp_add_codex_stdio "$name" "$@" || return 1
    mcp_add_gemini_stdio "$name" "$@" || return 1
    mcp_add_opencode_stdio "$name" "$@" || return 1
    mcp_add_grok_stdio "$name" "$@" || return 1
    mcp_add_mimo_stdio "$name" "$@" || return 1
    mcp_add_zed_stdio "$name" "$@" || return 1
    mcp_add_vscode_stdio "$name" "$@" || return 1
}

# ---------------------------------------------------------------------------
# 具体 MCP 服务器
# ---------------------------------------------------------------------------
# Filesystem MCP — 安全的文件操作 (需指定可访问目录)
install_filesystem_mcp() {
    info "=== 安装 filesystem MCP (文件系统访问) ==="
    local -a dirs=()
    local line
    if [ -n "${FILESYSTEM_DIRS:-}" ]; then
        read -ra dirs <<< "$FILESYSTEM_DIRS"
    elif [ -t 0 ]; then
        printf 'filesystem MCP 需要明确可访问目录（不再默认开放整个主目录）。\n'
        printf '请输入空格分隔的绝对路径，直接回车则取消: '
        IFS= read -r line || true
        if [ -n "$line" ]; then
            read -ra dirs <<< "$line"
        fi
    fi
    if [ "${#dirs[@]}" -eq 0 ]; then
        if $ALL_MODE; then
            warn "跳过 filesystem: 请设置 FILESYSTEM_DIRS (空格分隔的目录) 后重新运行 ./install.sh mcp filesystem"
            return 0
        fi
        die "安装 filesystem MCP 必须设置 FILESYSTEM_DIRS (空格分隔的目录)。不再默认开放 \$HOME 和 /tmp。"
    fi
    require_npx
    local cmd=(npx --prefer-offline -y @modelcontextprotocol/server-filesystem "${dirs[@]}")
    mcp_add_all filesystem "${cmd[@]}"
    ok "filesystem MCP 配置完成 (可访问: ${dirs[*]})"
}

# Git MCP — 读取/搜索/操作 Git 仓库 (官方 PyPI 包, 用 uvx 运行)
# 确保 uvx 可用 (官方独立安装器优先, 支持 uv self update)
ensure_uvx() {
    _has_bin uvx && return 0
    local tpl
    make_tmp tpl .sh
    if download_installer https://astral.sh/uv/install.sh "$tpl"; then
        info "安装 uv (官方独立安装器)..."
        if ! sh "$tpl" 2>&1 | tail -2; then
            warn "uv 官方安装脚本执行失败, 尝试其他方式"
        fi
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
    bin="$(_resolve_codegraph_bin)" || bin=""
    if [ -z "$bin" ]; then
        info "全局安装 @astudioplus/codegraph-mcp (含引擎下载)..."
        npm install -g --allow-scripts=@astudioplus/codegraph-mcp \
            @astudioplus/codegraph-mcp 2>&1 | tail -3 || die "CodeGraph npm 安装失败"
        bin="$(_resolve_codegraph_bin)" || bin=""
    fi
    [ -n "$bin" ] || die "CodeGraph 安装失败 (npm 全局)"
    # 引擎缺失时先试官方补拉命令
    if ! "$bin" --help >/dev/null 2>&1; then
        info "引擎缺失, 用官方命令补拉..."
        npx --prefer-offline -y codegraph-mcp-fetch-engine 2>&1 | tail -3 || true
    fi
    # 官方补拉失败(如 GitHub CDN 不稳)时, 改用镜像下载并校验 SHA256
    if ! "$bin" --help >/dev/null 2>&1; then
        codegraph_fetch_engine_mirror || die "CodeGraph 引擎补拉失败"
    fi
    "$bin" --help >/dev/null 2>&1 || die "CodeGraph 引擎不可用"
    mcp_add_all codegraph "$bin"
    ok "CodeGraph MCP 配置完成 ($bin)"
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
    mcp_add_gemini_stdio serena uvx --from serena-agent serena start-mcp-server \
        --context agent --project-from-cwd
    mcp_add_opencode_stdio serena uvx --from serena-agent serena start-mcp-server \
        --context agent --project-from-cwd
    mcp_add_grok_stdio serena uvx --from serena-agent serena start-mcp-server \
        --context agent --project-from-cwd
    mcp_add_zed_stdio serena uvx --from serena-agent serena start-mcp-server \
        --context ide --project-from-cwd
    mcp_add_vscode_stdio serena uvx --from serena-agent serena start-mcp-server \
        --context ide --project-from-cwd
    ok "Serena MCP 配置完成 (uvx --from serena-agent serena)"
}

# ---------------------------------------------------------------------------
# TUI 相关: 交互选择由 scripts/ui/tui_mcp.sh 提供, 本文件只负责安装
# ---------------------------------------------------------------------------
# MCP 组件定义 (供 --list 与调用方使用)
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
    mimo_config has "${MIMO_CONFIG:-$HOME/.config/mimocode/mimocode.jsonc}" "$1"
}

tui_component_installed() {
    local id="$1" found=false
    if has_claude; then
        claude_has_mcp "$id" || return 1
        found=true
    fi
    if has_codex; then
        codex_has_mcp "$id" || return 1
        found=true
    fi
    if has_gemini; then
        gemini_has_mcp "$id" || return 1
        found=true
    fi
    if has_opencode; then
        opencode_has_mcp "$id" || return 1
        found=true
    fi
    if has_grok; then
        grok_has_mcp "$id" || return 1
        found=true
    fi
    if has_mimo; then
        mimo_has_mcp "$id" || return 1
        found=true
    fi
    if has_zed; then
        zed_has_mcp "$id" || return 1
        found=true
    fi
    if has_code; then
        vscode_has_mcp "$id" || return 1
        found=true
    fi
    $found
}

gemini_has_mcp() {
    has_gemini || return 1
    python3 - "$HOME/.gemini/settings.json" "$1" << 'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    sys.exit(1)
servers = data.get("mcpServers") or {}
sys.exit(0 if isinstance(servers, dict) and name in servers else 1)
PY
}

grok_has_mcp() {
    has_grok || return 1
    local cfg="$HOME/.grok/config.toml"
    [ -f "$cfg" ] || return 1
    grep -qE "^\\[mcp_servers\\.${1}\\][[:space:]]*$" "$cfg"
}

opencode_has_mcp() {
    has_opencode || return 1
    local cfg="$HOME/.config/opencode/opencode.json"
    if [ -f "$HOME/.config/opencode/opencode.jsonc" ] && [ ! -f "$cfg" ]; then
        cfg="$HOME/.config/opencode/opencode.jsonc"
    fi
    python3 - "$cfg" "$1" << 'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    sys.exit(1)
servers = data.get("mcp") or {}
sys.exit(0 if isinstance(servers, dict) and name in servers else 1)
PY
}

zed_has_mcp() {
    has_zed || return 1
    python3 - "$HOME/.config/zed/settings.json" "$1" << 'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    sys.exit(1)
servers = data.get("context_servers") or {}
sys.exit(0 if isinstance(servers, dict) and name in servers else 1)
PY
}

vscode_has_mcp() {
    has_code || return 1
    python3 - "$HOME/.config/Code/User/mcp.json" "$1" << 'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    sys.exit(1)
servers = data.get("servers") or {}
sys.exit(0 if isinstance(servers, dict) and name in servers else 1)
PY
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

# 交互选择委托给 MCP TUI; 选择结果经临时文件回填到 TUI_SELECTED
tui_select() {
    local tui="$SCRIPT_DIR/ui/tui_mcp.sh" result rc=0
    [ -f "$tui" ] || die "未找到 MCP TUI: $tui"
    result=$(mktemp)
    trap 'rm -f "$result"' EXIT
    TUI_RESULT_FILE="$result" MCP_SCRIPT="$0" bash "$tui" || rc=$?
    if [ "$rc" -eq 2 ]; then
        exit 1   # 终端不可用或列表读取失败, TUI 已打印原因
    fi
    TUI_SELECTED="$(tr '\n' ' ' < "$result")"
    rm -f "$result"
    trap - EXIT
    return 0
}

# ---------------------------------------------------------------------------
# 参数解析 / 主流程
# ---------------------------------------------------------------------------
# 确保 AI CLI 在 PATH 中 (nvm 环境 + 官方 MiMo 路径 + ~/.local/bin)
export PATH="$HOME/.grok/bin:$HOME/.mimocode/bin:$HOME/.local/bin:$PATH"
load_nvm

usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
    echo
    echo "可用 MCP 服务器:"
    echo "  filesystem           - 安全文件操作"
    echo "  git                  - Git 仓库操作"
    echo "  memory               - 知识图谱持久记忆"
    echo "  codebase-memory-mcp  - 代码库知识图谱 (158 语言, 子毫秒查询; 三选一)"
    echo "  context7             - 实时文档/代码示例检索 (Upstash)"
    echo "  codegraph            - 跨语言代码图谱 (42 工具 / 38 语言; 三选一)"
    echo "  serena               - 语义代码检索与编辑 (oraios; 三选一)"
    echo
    echo "环境变量:"
    echo "  FILESYSTEM_DIRS  filesystem 可访问目录 (空格分隔, 必填; 不再默认开放整个主目录)"
    echo "  CBM_VARIANT=ui   安装带图谱可视化的 codebase-memory-mcp"
    echo "  PROXY_URL        代理地址, 如 http://host:7890"
    echo
    echo "示例:"
    echo "  ./install.sh mcp"
    echo "  ./install.sh mcp --tui"
    echo "  ./install.sh mcp filesystem git memory codebase-memory-mcp"
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
ALL_MODE=false
HAS_ARGS=false
while [[ $# -gt 0 ]]; do
    HAS_ARGS=true
    case "$1" in
        --tui)       TUI_MODE=true; shift ;;
        --all)       ALL_MODE=true; shift ;;
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

# 无参数时只提供交互选择, 非交互调用须显式指定安装项。
if [ "$HAS_ARGS" = "false" ]; then
    if [ -t 1 ] && [ -t 0 ]; then
        TUI_MODE=true
    else
        die "当前不是交互式终端, 请指定 MCP 服务器或使用 --all (查看 --help)"
    fi
fi

if $ALL_MODE; then
    $TUI_MODE && die "--all 不能与 --tui 同时使用"
    TARGETS=("${MCP_IDS_AVAILABLE[@]}")
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

[ "${#TARGETS[@]}" -gt 0 ] || die "没有要安装的 MCP 服务器"

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
printf '下一步: 将 %s/templates/AGENTS.md 和 CLAUDE.md 复制到项目根目录, 助手才会稳定使用这些 MCP。\n' "$REPO_ROOT"
printf '代码智能 MCP (codebase-memory-mcp / codegraph / serena) 三选一。装好后在项目里说「索引这个项目」。\n'
printf '重复运行 ./install.sh mcp <id> 会在命令或参数变化时更新已有配置。\n'
