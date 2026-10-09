#!/usr/bin/env bash
# =============================================================================
# joe sync-configs — 把本机配置备份进仓库 / 从仓库恢复
# =============================================================================
# 设计原则:
#   * 白名单: 只处理明确列出的文件, 不做目录级全量拷贝
#   * 脱敏: 导出前统一过一遍敏感信息擦除 (API key / token / 密码 / Bearer)
#   * 隐私: ~/.claude.json 只提取 mcpServers, 丢弃 userID / machineID / projects
#   * 不自动提交: 导出后请自行 git diff 复核再提交
#
# 用法:
#   ./install.sh configs list            # 列出映射与状态
#   ./install.sh configs export          # 导出(脱敏)到 configs/
#   ./install.sh configs export --check  # 只检查会擦除多少敏感项, 不写文件
#   ./install.sh configs import          # 从 configs/ 恢复到本机 (原文件备份为 .bak.<时间>)
#   ./install.sh configs diff            # 显示本机与仓库备份的差异
#
# 退出码: 0 成功, 1 有错误
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_ROOT/configs"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.joe-config-backup}"

c_g() { printf '\033[0;32m%s\033[0m' "$1"; }
c_r() { printf '\033[0;31m%s\033[0m' "$1"; }
c_y() { printf '\033[1;33m%s\033[0m' "$1"; }
c_b() { printf '\033[1;36m%s\033[0m' "$1"; }
c_d() { printf '\033[2m%s\033[0m' "$1"; }
info() { printf '%s %s\n' "$(c_b '→')" "$*"; }
ok()   { printf '%s %s\n' "$(c_g '✓')" "$*"; }
warn() { printf '%s %s\n' "$(c_y '!')" "$*"; }
err()  { printf '%s %s\n' "$(c_r '✗')" "$*" >&2; }

# ---------------------------------------------------------------------------
# 映射表: 源路径 | 仓库内文件名 | 模式
#   copy       = 整体复制后脱敏
#   claude_json= 只提取 mcpServers (丢弃 userID/machineID/projects 等隐私)
# ---------------------------------------------------------------------------
MODE="list"
CHECK_ONLY=false
for a in "$@"; do
    case "$a" in
        list|export|import|diff) MODE="$a" ;;
        --check) CHECK_ONLY=true ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) err "未知参数: $a"; exit 2 ;;
    esac
done

map_entries() {
    cat <<EOF
$HOME/.zshrc|zshrc|copy
$HOME/.gitconfig|gitconfig|copy
$HOME/.claude.json|claude-mcp.json|claude_json
$HOME/.codex/config.toml|codex-config.toml|copy
$HOME/.config/mimocode/mimocode.jsonc|mimocode.jsonc|copy
$HOME/.config/zed/settings.json|zed-settings.json|copy
$HOME/.config/Code/User/mcp.json|vscode-mcp.json|copy
EOF
}

# ---------------------------------------------------------------------------
# 脱敏 (python: 值模式 + 键名模式 + JSON 结构)
# ---------------------------------------------------------------------------
sanitize_stream() {
    local mode="$1" src="$2"
    python3 - "$mode" "$src" <<'PYEOF'
import json, re, sys

mode = sys.argv[1]
src_path = sys.argv[2]
REDACT = "***REDACTED***"
try:
    raw = open(src_path, encoding="utf-8", errors="replace").read()
except OSError:
    sys.exit(2)

VALUE_PATTERNS = [
    re.compile(r'sk-ant-[A-Za-z0-9_\-]{8,}'),
    re.compile(r'sk-[A-Za-z0-9_\-]{16,}'),
    re.compile(r'ghp_[A-Za-z0-9]{16,}'),
    re.compile(r'gho_[A-Za-z0-9]{16,}'),
    re.compile(r'github_pat_[A-Za-z0-9_]{16,}'),
    re.compile(r'xox[baprs]-[A-Za-z0-9\-]{10,}'),
    re.compile(r'AKIA[0-9A-Z]{16}'),
    re.compile(r'(?i)\bBearer\s+[A-Za-z0-9._\-]{12,}'),
    re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----'),
]

# key = value / key: value (toml, yaml, shell, json-ish)
KV_PATTERN = re.compile(
    r'(?im)^([ \t]*[A-Za-z0-9_.\-]*'
    r'(?:api[_-]?key|apikey|token|secret|password|passwd|credential|auth)'
    r'[A-Za-z0-9_.\-]*[ \t]*[:=][ \t]*)'
    r'("?)(?!\*{3}REDACTED)([^"\n\r]{6,})\2'
)

SECRET_KEY = re.compile(
    r'(?i)(api[_-]?key|apikey|token|secret|password|passwd|credential|'
    r'authorization|auth[_-]?token|access[_-]?key)'
)

count = 0

def redact_text(text: str):
    global count
    for pat in VALUE_PATTERNS:
        text, n = pat.subn(REDACT, text)
        count += n
    def _kv(m):
        global count
        count += 1
        return f"{m.group(1)}{m.group(2)}{REDACT}{m.group(2)}"
    text = KV_PATTERN.sub(_kv, text)
    return text

def redact_obj(obj):
    """递归擦除键名敏感的 JSON 值。"""
    global count
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            if isinstance(v, str) and SECRET_KEY.search(str(k)) and v:
                out[k] = REDACT
                count += 1
            else:
                out[k] = redact_obj(v)
        return out
    if isinstance(obj, list):
        return [redact_obj(x) for x in obj]
    return obj

if mode == "claude_json":
    try:
        d = json.loads(raw)
    except Exception:
        print("__PARSE_ERROR__")
        sys.exit(0)
    # 只保留可复现的配置, 丢弃身份/历史 (userID, machineID, projects, ...)
    safe = {
        "_comment": "由 sync-configs.sh export 生成: 仅保留 mcpServers",
        "mcpServers": redact_obj(d.get("mcpServers") or {}),
    }
    if "installMethod" in d:
        safe["installMethod"] = d["installMethod"]
    out = json.dumps(safe, indent=2, ensure_ascii=False)
else:
    out = redact_text(raw)

# 统一以单个换行结尾, 保证导出/比较结果一致
sys.stdout.write(out if out.endswith("\n") else out + "\n")
sys.stderr.write(f"REDACTED={count}\n")
PYEOF
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------
do_list() {
    printf '%s\n' "$(c_b '配置映射 (源 → 仓库)')"
    printf '  %-42s %-20s %s\n' "源" "仓库内" "状态"
    local line src name mode
    while IFS='|' read -r src name mode; do
        [ -n "$src" ] || continue
        local st
        if [ ! -f "$src" ]; then
            st="$(c_d '本机无')"
        elif [ -f "$CONF_DIR/$name" ]; then
            if diff -q <(sanitize_stream "$mode" "$src" 2>/dev/null) "$CONF_DIR/$name" >/dev/null 2>&1; then
                st="$(c_g '已同步')"
            else
                st="$(c_y '有差异')"
            fi
        else
            st="$(c_y '未导出')"
        fi
        printf '  %-42s %-20s %s\n' "${src/#$HOME/\~}" "$name" "$st"
    done < <(map_entries)
}

# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------
do_export() {
    if $CHECK_ONLY; then
        info "试运行(不写文件), 仅统计将擦除的敏感项:"
    else
        mkdir -p "$CONF_DIR"
        info "导出到 $CONF_DIR"
    fi
    local total=0 line src name mode
    while IFS='|' read -r src name mode; do
        [ -n "$src" ] || continue
        if [ ! -f "$src" ]; then
            printf '  %s %-22s %s\n' "$(c_d '·')" "$name" "$(c_d '本机不存在, 跳过')"
            continue
        fi
        local out redacted
        out="$(sanitize_stream "$mode" "$src" 2>/tmp/.joe_redact)"
        redacted="$(sed -n 's/^REDACTED=//p' /tmp/.joe_redact | tail -1)"
        rm -f /tmp/.joe_redact
        [ "$redacted" = "0" ] && redacted=0
        total=$((total + redacted))

        if [ "$out" = "__PARSE_ERROR__" ]; then
            printf '  %s %-22s %s\n' "$(c_r '✗')" "$name" "$(c_r '解析失败, 已跳过')"
            continue
        fi
        if $CHECK_ONLY; then
            printf '  %s %-22s %s\n' "$(c_g '✓')" "$name" "$(c_d "会擦除 $redacted 处")"
        else
            printf '%s\n' "$out" > "$CONF_DIR/$name"
            printf '  %s %-22s %s\n' "$(c_g '✓')" "$name" \
                "$(c_d "$(stat -c%s "$CONF_DIR/$name") 字节, 擦除 $redacted 处")"
        fi
    done < <(map_entries)

    if ! $CHECK_ONLY; then
        # 写一份说明
        cat > "$CONF_DIR/README.md" <<'EOF'
# configs — 本机配置备份（自动生成）

由 `../install.sh configs export` 生成，**已做脱敏**（API key / token / 密码 / Bearer 等被替换为 `***REDACTED***`）。

| 文件 | 来源 | 说明 |
|---|---|---|
| `zshrc` | `~/.zshrc` | shell 环境 |
| `gitconfig` | `~/.gitconfig` | git 身份与别名 |
| `claude-mcp.json` | `~/.claude.json` | **仅** `mcpServers`；已丢弃 userID/machineID/projects |
| `codex-config.toml` | `~/.codex/config.toml` | Codex CLI 配置 |
| `mimocode.jsonc` | `~/.config/mimocode/mimocode.jsonc` | MiMo Code 配置 |
| `zed-settings.json` | `~/.config/zed/settings.json` | Zed 设置 |
| `vscode-mcp.json` | `~/.config/Code/User/mcp.json` | VS Code MCP 配置 |

## 恢复

```bash
./install.sh configs import     # 原文件会备份为 .bak.<时间戳>
```

## 提交前请复核

```bash
git diff configs/
```

> 脱敏是**尽力而为**的兜底，不保证覆盖所有密钥形式。提交前请自行确认没有敏感信息。
EOF
        ok "导出完成 (共擦除 $total 处敏感项)"
        printf '\n%s\n' "$(c_y '请先复核再提交: git diff configs/')"
    else
        printf '\n共会擦除 %s 处\n' "$total"
    fi
}

# ---------------------------------------------------------------------------
# import
# ---------------------------------------------------------------------------
do_import() {
    [ -d "$CONF_DIR" ] || { err "configs/ 不存在, 请先 export 或 clone 仓库"; exit 1; }
    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    info "从 $CONF_DIR 恢复 (原文件备份到 $BACKUP_ROOT/$ts)"
    local line src name mode
    while IFS='|' read -r src name mode; do
        [ -n "$src" ] || continue
        local bak="$CONF_DIR/$name"
        if [ ! -f "$bak" ]; then
            printf '  %s %-22s %s\n' "$(c_d '·')" "$name" "$(c_d '仓库无备份, 跳过')"
            continue
        fi
        mkdir -p "$(dirname "$src")" "$BACKUP_ROOT/$ts/$(dirname "${src/#$HOME/}")"
        if [ -f "$src" ]; then
            cp -a "$src" "$BACKUP_ROOT/$ts/${src/#$HOME/}"
        fi

        if [ "$mode" = "claude_json" ]; then
            # 合并: 只替换 mcpServers, 保留本机身份/历史
            if python3 - "$src" "$bak" <<'PYEOF'
import json, sys, os
dst, src_bak = sys.argv[1], sys.argv[2]
try:
    cur = json.load(open(dst)) if os.path.exists(dst) else {}
except Exception:
    cur = {}
try:
    new = json.load(open(src_bak))
except Exception:
    sys.exit(1)
cur["mcpServers"] = new.get("mcpServers", {})
json.dump(cur, open(dst, "w"), indent=2, ensure_ascii=False)
PYEOF
            then
                printf '  %s %-22s %s\n' "$(c_g '✓')" "$name" "$(c_d '已合并 mcpServers')"
            else
                printf '  %s %-22s %s\n' "$(c_r '✗')" "$name" "$(c_r '合并失败')"
            fi
        else
            cp "$bak" "$src"
            printf '  %s %-22s %s\n' "$(c_g '✓')" "$name" "$(c_d "→ ${src/#$HOME/\~}")"
        fi
    done < <(map_entries)
    ok "恢复完成 (备份在 $BACKUP_ROOT/$ts)"
}

# ---------------------------------------------------------------------------
# diff
# ---------------------------------------------------------------------------
do_diff() {
    local line src name mode
    while IFS='|' read -r src name mode; do
        [ -n "$src" ] || continue
        [ -f "$src" ] || continue
        local bak="$CONF_DIR/$name"
        [ -f "$bak" ] || { printf '%s %s\n' "$(c_y '!')" "$name: 仓库无备份"; continue; }
        if diff -q <(sanitize_stream "$mode" "$src" 2>/dev/null) "$bak" >/dev/null 2>&1; then
            printf '%s %-22s %s\n' "$(c_g '=')" "$name" "$(c_d '一致')"
        else
            printf '\n%s %s\n' "$(c_y '≠')" "$(c_b "$name")"
            diff -u <(sanitize_stream "$mode" "$src" 2>/dev/null) "$bak" | tail -n +3 | head -30 | sed 's/^/    /'
        fi
    done < <(map_entries)
}

case "$MODE" in
    list)   do_list ;;
    export) do_export ;;
    import) do_import ;;
    diff)   do_diff ;;
esac
