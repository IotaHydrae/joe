#!/usr/bin/env bash
# =============================================================================
# joe lib/mcp_clients — 各 AI 代理的 MCP 配置写入
# =============================================================================
# 由 install_mcp_servers.sh 在定义好 log/agents 辅助后 source。
# 提供: claude_user_has_mcp, sync_stdio_client (按 backend 写 JSON/TOML/JSONC),
# mcp_add_<agent>_stdio, mimo_config, mcp_add_all。
# 仅定义函数, 调用时才使用 info/warn/die/_has_bin 与 HOME。
# =============================================================================

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
