#!/usr/bin/env bash
# =============================================================================
# joe lib/doctor_checks — 体检辅助函数
# =============================================================================
# 由 doctor.sh 在定义好 QUIET/JSON/PASS/... 全局量并 source log.sh 之后 source。
# =============================================================================

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

# 代理端技能目录 (项目级: 实体副本在 <project>/.agents/skills, 其余为符号链接)
skill_dirs() {
    echo "$PROJECT_DIR/.agents/skills"
    find_bin claude >/dev/null 2>&1 && echo "$PROJECT_DIR/.claude/skills"
    find_bin codex  >/dev/null 2>&1 && echo "$PROJECT_DIR/.codex/skills"
    find_bin grok   >/dev/null 2>&1 && echo "$PROJECT_DIR/.grok/skills"
    if find_bin copilot >/dev/null 2>&1 || [ -d "$HOME/.copilot" ]; then
        echo "$PROJECT_DIR/.copilot/skills"
    fi
    return 0
}
