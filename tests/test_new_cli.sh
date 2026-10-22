#!/usr/bin/env bash
# =============================================================================
# 测试新 CLI 的基础功能
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    printf "${GREEN}✓${RESET} %s\n" "$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    printf "${RED}✗${RESET} %s\n" "$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_info() {
    printf "${YELLOW}ℹ${RESET} %s\n" "$1"
}

# 失败/崩溃退出时也要清理测试创建的临时目录与文件
TEST_TMPS=()
cleanup_test_tmps() {
    [ ${#TEST_TMPS[@]} -gt 0 ] && rm -rf "${TEST_TMPS[@]}"
}
trap cleanup_test_tmps EXIT
# 结果写入 TMP_PATH: 在 $(...) 里调用时数组注册会丢在子 shell 中
TMP_PATH=""
make_tmp() {
    TMP_PATH=$(mktemp "$@")
    TEST_TMPS+=("$TMP_PATH")
}

# 断言转换层把参数原样交给底层安装器 (FWD_STUB 打印 "FWD|<args>")
assert_forward() {
    local label="$1" expected="$2"
    shift 2
    local out="" got
    out=$(MCP_SCRIPT="$FWD_STUB" SKILLS_SCRIPT="$FWD_STUB" timeout 10 bash install.sh "$@" 2>&1) || true
    # 精确比对最后一行: 前缀匹配会放过多余或错位的参数
    got=$(tail -n1 <<<"$out" | tr -d '\r')
    if [[ $got == "FWD|$expected" ]]; then
        test_pass "$label"
    else
        test_fail "$label: 期望 [FWD|$expected], 实际 [$got]"
    fi
}

# =============================================================================
# 测试用例
# =============================================================================

test_help() {
    test_info "测试帮助命令"

    if timeout 2 bash install.sh --help &>/dev/null; then
        test_pass "install.sh --help"
    else
        test_fail "install.sh --help"
    fi

    if timeout 2 bash install.sh -h &>/dev/null; then
        test_pass "install.sh -h"
    else
        test_fail "install.sh -h"
    fi
}

test_version() {
    test_info "测试版本命令"

    local version
    version=$(timeout 2 bash install.sh --version 2>&1)

    if [[ $version =~ joe\ v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        test_pass "install.sh --version: $version"
    else
        test_fail "install.sh --version (输出: $version)"
    fi
}

test_tools_list() {
    test_info "测试 tools list 命令"

    local output
    output=$(timeout 5 bash install.sh tools list 2>&1)

    if [[ $output == *"Node.js LTS"* ]]; then
        test_pass "tools list 包含组件列表"
    else
        test_fail "tools list 输出不正确"
    fi

    if [[ $output == *"环境管理"* ]]; then
        test_pass "tools list 包含分组"
    else
        test_fail "tools list 缺少分组标题"
    fi
}

test_dependency_resolution() {
    test_info "测试依赖解析"

    # shellcheck disable=SC1091
    source scripts/lib/deps.sh

    # 测试 expand_components
    local expanded
    expanded=$(expand_components --ai gemini)
    if [[ $expanded =~ claude.*codex.*gemini ]]; then
        test_pass "expand_components --ai gemini"
    else
        test_fail "expand_components 展开错误: $expanded"
    fi

    # 测试 resolve_deps（opencode 依赖 node；缺失依赖时返回 1，属正常情况）
    local full_list
    full_list=$(resolve_deps opencode 2>/dev/null || true)
    if [[ $full_list =~ node.*opencode ]]; then
        test_pass "resolve_deps 正确识别依赖"
    else
        test_fail "resolve_deps 依赖解析错误"
    fi

    # 测试已安装检测
    # 检测结果取决于主机, 只断言判定本身不报错且拒绝未知组件
    if is_installed node; then
        test_pass "is_installed node (本机已装)"
    else
        test_pass "is_installed node (本机未装)"
    fi

    if is_installed nonexistent; then
        test_fail "is_installed 不应认定未知组件"
    else
        test_pass "is_installed 拒绝未知组件"
    fi
}

test_backward_compatibility() {
    test_info "测试向后兼容性"

    # 旧命令应该仍然工作
    if timeout 2 bash install.sh devtools --help &>/dev/null; then
        test_pass "devtools 命令仍可用"
    else
        test_fail "devtools 命令不可用"
    fi

    # tools --help 应该显示帮助
    if timeout 2 bash install.sh tools --help &>/dev/null; then
        test_pass "tools --help 可用"
    else
        test_fail "tools --help 不可用"
    fi
}

test_component_validation() {
    test_info "测试组件验证"

    # shellcheck disable=SC1091
    source scripts/lib/deps.sh

    if validate_component "node"; then
        test_pass "validate_component node"
    else
        test_fail "validate_component node 验证失败"
    fi

    if ! validate_component "nonexistent"; then
        test_pass "validate_component 拒绝无效组件"
    else
        test_fail "validate_component 应该拒绝 nonexistent"
    fi
}

test_unknown_command() {
    test_info "测试错误处理"

    if ! timeout 2 bash install.sh totally_unknown_command &>/dev/null; then
        test_pass "拒绝未知命令"
    else
        test_fail "应该拒绝未知命令"
    fi
}

# =============================================================================
# 2.0 重构回归
# =============================================================================

test_deps_set_e_contract() {
    test_info "测试依赖解析的 set -e 契约"

    # resolve_deps 补入未请求的依赖时返回 1; 调用方简单赋值不得被 set -e 中止
    if timeout 5 bash -c '
        set -euo pipefail
        source scripts/lib/deps.sh
        out=$(resolve_deps claude) || true
        [[ $out == *node* && $out == *claude* ]]
    ' &>/dev/null; then
        test_pass "resolve_deps 补全依赖且不中止脚本"
    else
        test_fail "resolve_deps 在 set -e 下丢失依赖或中止"
    fi

    # 无匹配时不能输出空白项 (空白会污染组件列表并触发 bad array subscript)
    local blank
    blank=$(timeout 5 bash -c 'set -euo pipefail; source scripts/lib/deps.sh; expand_components nonexistent')
    if [[ -z $blank ]]; then
        test_pass "expand_components 无匹配时输出为空"
    else
        test_fail "expand_components 输出了空白项: $(printf '%q' "$blank")"
    fi
}

test_install_plan_uses_deps() {
    test_info "测试安装计划自动补依赖 (stub 安装器)"

    local tmp_home stub out
    make_tmp -d; tmp_home=$TMP_PATH
    make_tmp; stub=$TMP_PATH
    printf '#!/usr/bin/env bash\nprintf "STUB_ARGS %%s\\n" "$*"\n' > "$stub"
    chmod +x "$stub"

    # copilot 依赖 node; 用临时 HOME 让 node 判定为未安装
    out=$(HOME="$tmp_home" DEVTOOLS_SCRIPT="$stub" timeout 15 bash install.sh tools install --with-deps copilot 2>&1) || true
    if grep -q 'STUB_ARGS --node' <<<"$out"; then
        test_pass "--with-deps 自动补入 node 并调用安装器"
    else
        test_fail "--with-deps 输出不符: $(head -3 <<<"$out" | tr '\n' ' ')"
    fi

    # 非交互且未指定 --with-deps: 给出可操作提示, 而不是静默退出 (该分支返回 1)
    out=$(HOME="$tmp_home" DEVTOOLS_SCRIPT="$stub" timeout 15 bash install.sh tools install copilot </dev/null 2>&1) || true
    if grep -q 'tools install --with-deps' <<<"$out"; then
        test_pass "非交互依赖提示可操作"
    else
        test_fail "非交互依赖提示缺失"
    fi

    rm -rf "$tmp_home" "$stub"
}

test_tools_list_clean_home() {
    test_info "测试全新环境的 tools list"

    local tmp_home out rows
    make_tmp -d; tmp_home=$TMP_PATH
    out=$(HOME="$tmp_home" timeout 15 bash install.sh tools list 2>&1)
    rows=$(grep -cE '^  [a-z]+ ' <<<"$out")
    rm -rf "$tmp_home"

    if [[ $rows -eq 15 ]]; then
        test_pass "全新环境列出 15 个组件"
    else
        test_fail "tools list 组件行数=$rows (期望 15)"
    fi
}

# 运行 pty 回归脚本; 脚本用退出码 2 表示环境不支持
run_pty_check() {
    local label="$1" script="$2"
    if ! command -v python3 >/dev/null 2>&1; then
        test_info "缺少 python3, 跳过 $label"
        return
    fi

    local rc=0
    timeout 90 python3 "$script" >/dev/null 2>&1 || rc=$?
    case $rc in
        0) test_pass "$label" ;;
        2) test_info "无 pty 支持, 跳过 $label" ;;
        *) test_fail "$label 失败 (rc=$rc)" ;;
    esac
}

test_tui_pty() {
    test_info "测试交互界面 (pty)"

    run_pty_check "TUI 渲染/回车确认/选择回传" tests/tui_pty_check.py
    run_pty_check "主菜单浏览不触发安装" tests/menu_pty_check.py
}

test_command_adapters() {
    test_info "测试 mcp/skills 语法转换层"

    make_tmp; FWD_STUB=$TMP_PATH
    cat > "$FWD_STUB" <<'STUB'
#!/usr/bin/env bash
printf 'FWD|%s\n' "$*"
STUB
    chmod +x "$FWD_STUB"

    # 新动作词
    assert_forward "mcp list" "--list" mcp list
    assert_forward "mcp status" "--list" mcp status
    assert_forward "mcp install <id>" "memory git" mcp install memory git
    assert_forward "mcp update <id>" "filesystem" mcp update filesystem
    assert_forward "mcp tui" "--tui" mcp tui
    assert_forward "skills categories" "--categories" skills categories
    assert_forward "skills install <id>" "gdb" skills install gdb
    assert_forward "skills install --category" "--category kernel-dev --all" skills install --category kernel-dev --all

    # 旧语法必须逐字透传 (转换层只认动作词)
    assert_forward "mcp --list 透传" "--list" mcp --list
    assert_forward "mcp --all 透传" "--all" mcp --all
    assert_forward "mcp <id> 透传" "memory git" mcp memory git
    assert_forward "skills --category 透传" "--category kernel-dev --tui" skills --category kernel-dev --tui
    assert_forward "skills --all 透传" "--all" skills --all

    rm -f "$FWD_STUB"
}

test_tools_update() {
    test_info "测试 tools update"

    local stub out
    make_tmp; stub=$TMP_PATH
    cat > "$stub" <<'STUB'
#!/usr/bin/env bash
printf 'UPD:'
for a in "$@"; do printf ' [%s]' "$a"; done
printf '\n'
STUB
    chmod +x "$stub"

    out=$(UPDATE_SCRIPT="$stub" timeout 15 bash install.sh tools update --dry-run 2>&1) || true
    if [[ $out == *"UPD: [--dry-run]"* ]]; then
        test_pass "tools update 把选项交给 update-all"
    else
        test_fail "tools update 未转发选项: $out"
    fi

    # 按组件更新不受支持, 应给出替代命令而不是调用更新器
    out=$(UPDATE_SCRIPT="$stub" timeout 15 bash install.sh tools update node 2>&1) || true
    if [[ $out == *"tools install node"* && $out != *UPD:* ]]; then
        test_pass "tools update 拒绝按组件并提示重装"
    else
        test_fail "tools update 按组件行为不符: $out"
    fi

    rm -f "$stub"
}

test_status_summary() {
    test_info "测试 status 汇总"

    local tmp mcp skills out
    make_tmp -d; tmp=$TMP_PATH
    mcp="$tmp/mcp_list.sh"
    skills="$tmp/skills_list.sh"
    cat > "$mcp" <<'LIST'
#!/usr/bin/env bash
printf '  filesystem  已配置 文件操作\n'
printf '  git         未配置 Git 操作\n'
LIST
    cat > "$skills" <<'LIST'
#!/usr/bin/env bash
printf '  gdb         已安装 [debugging] GDB\n'
printf '  cmake       未安装 [build] CMake\n'
printf '  ninja       未安装 [build] Ninja\n'
printf '\n安装位置:\n'
printf '  /home/example/.agents/skills\n'
LIST
    chmod +x "$mcp" "$skills"

    out=$(MCP_SCRIPT="$mcp" SKILLS_SCRIPT="$skills" timeout 60 bash install.sh status --short 2>&1) || true
    if [[ $out == *"mcp 1/2"* && $out == *"skills 1/3"* ]]; then
        test_pass "status 只按状态列计数 (忽略安装位置段落)"
    else
        test_fail "status 汇总不符: $out"
    fi

    out=$(MCP_SCRIPT="$mcp" SKILLS_SCRIPT="$skills" timeout 60 bash install.sh status --bogus 2>&1) || true
    if [[ $out == *"未知选项: --bogus"* ]]; then
        test_pass "status 拒绝未知选项"
    else
        test_fail "status 未拒绝未知选项: $out"
    fi

    # 安装器 --list 失败时显示 n/a 并返回非零, 不能把 "n/a" 粘在计数后面
    cat > "$tmp/mcp_fail.sh" <<'FAIL'
#!/usr/bin/env bash
printf '  filesystem  已配置 x\n'
exit 1
FAIL
    chmod +x "$tmp/mcp_fail.sh"
    local rc=0
    out=$(MCP_SCRIPT="$tmp/mcp_fail.sh" SKILLS_SCRIPT="$skills" timeout 60 bash install.sh status --short 2>&1) || rc=$?
    if [[ $rc -eq 1 && $out == *"mcp n/a"* && $out != *"/n/a"* ]]; then
        test_pass "status 降级为 n/a 并返回 1"
    else
        test_fail "status 降级行为不符 (rc=$rc, 输出=$out)"
    fi

    rm -rf "$tmp"
}

test_component_id_lists_agree() {
    test_info "测试组件 id 清单一致性"

    local deps_ids tui_ids missing=""
    deps_ids=$(timeout 10 bash -c '
        set -euo pipefail
        source scripts/lib/deps.sh
        for g in "${!COMPONENT_GROUPS[@]}"; do
            printf "%s\n" ${COMPONENT_GROUPS[$g]}
        done | sort -u
    ') || deps_ids=""
    tui_ids=$(timeout 10 bash -c '
        set -euo pipefail
        source scripts/tui_module.sh
        printf "%s\n" "${TUI_IDS[@]}" | sort -u
    ') || tui_ids=""

    if [[ -z $deps_ids || -z $tui_ids ]]; then
        test_fail "组件清单探测为空 (deps=[$deps_ids] tui=[$tui_ids])"
    elif diff <(printf '%s\n' "$deps_ids") <(printf '%s\n' "$tui_ids") >/dev/null; then
        test_pass "deps.sh 组件清单与 tui_module.sh TUI_IDS 未漂移"
    else
        test_fail "deps.sh 与 TUI_IDS 已经不一致"
        diff <(printf '%s\n' "$deps_ids") <(printf '%s\n' "$tui_ids") || true
    fi

    # 新增组件必须同时有安装器 flag, 否则 tools install <id> 会转成无效参数
    local id
    for id in $deps_ids; do
        grep -qE -- "^[[:space:]]*--${id}\)" scripts/install_devtools.sh || missing+=" $id"
    done
    if [[ -z $missing ]]; then
        test_pass "每个组件 id 都映射到 install_devtools.sh 的 flag"
    else
        test_fail "install_devtools.sh 缺少 flag:$missing"
    fi
}

test_quickstart_stages() {
    test_info "测试 quick-start 阶段编排"

    local box s out
    make_tmp -d; box=$TMP_PATH
    mkdir -p "$box/home"
    if ! cp -a "$ROOT_DIR/." "$box/"; then
        test_fail "无法复制仓库到沙箱"
        rm -rf "$box"
        return
    fi
    for s in install_shell install_devtools install_mcp_servers install_skills doctor; do
        printf '#!/usr/bin/env bash\nprintf "STAGE:%s ARGS:[%%s]\\n" "$*"\n' "$s" > "$box/scripts/$s.sh"
        chmod +x "$box/scripts/$s.sh"
    done

    out=$(cd "$box" && HOME="$box/home" timeout 60 bash install.sh quick-start --yes 2>&1) || true

    # 仓库根推导失败会静默改为从 GitHub 克隆, 阶段脚本也就绕开本地改动
    if [[ $out == *"已在仓库内: $box"* ]]; then
        test_pass "quick-start 复用当前仓库, 不重新克隆"
    else
        test_fail "quick-start 走了克隆/复用分支: $(grep -m1 -E '克隆|复用' <<<"$out")"
    fi

    # install_shell.sh 没有 --all 选项
    if [[ $out == *"STAGE:install_shell ARGS:[]"* && $out == *"STAGE:install_devtools ARGS:[--all]"* ]]; then
        test_pass "shell 阶段不加 --all, 工具阶段加 --all"
    else
        test_fail "阶段参数不符: $(grep -c STAGE: <<<"$out") 个阶段被调用"
    fi

    out=$(cd "$box" && HOME="$box/home" timeout 60 bash install.sh quick-start --yes --only shell,doctor 2>&1) || true
    if [[ $out == *"[1/2]"* && $out != *"STAGE:install_devtools"* ]]; then
        test_pass "--only 只跑指定阶段"
    else
        test_fail "--only 行为不符"
    fi

    # install-all 必须传引擎接受的参数 (曾误传 --all 导致必然失败)
    if ! grep -qE 'quickstart\.sh" --all|bootstrap\.sh" --all' install.sh; then
        test_pass "install-all 不再传未支持的 --all"
    else
        test_fail "install-all 仍在传 --all"
    fi

    # 非交互且未给 --yes 时必须拒绝, 否则会无提示地开装
    out=$(cd "$box" && HOME="$box/home" timeout 30 bash install.sh quick-start < /dev/null 2>&1) || true
    if [[ $out == *"非交互环境无法逐阶段确认"* ]]; then
        test_pass "非交互且无 --yes 时拒绝执行"
    else
        test_fail "非交互 quick-start 未被拒绝"
    fi

    # 拼错阶段名不能让 want() 静默跳过全部阶段
    out=$(cd "$box" && HOME="$box/home" timeout 30 bash install.sh quick-start --yes --only nope < /dev/null 2>&1) || true
    if [[ $out == *"未知阶段: nope"* ]]; then
        test_pass "--only 校验阶段名"
    else
        test_fail "--only 未校验阶段名: $out"
    fi

    rm -rf "$box"
}

test_tools_list_version_failure() {
    test_info "测试版本探测失败时的 tools list"

    local tmp_home out rows
    make_tmp -d; tmp_home=$TMP_PATH
    mkdir -p "$tmp_home/.local/bin"
    touch "$tmp_home/.local/bin/zed"   # 判定为已装, 但 PATH 里没有 zed

    out=$(HOME="$tmp_home" PATH=/usr/bin:/bin timeout 20 bash install.sh tools list 2>&1) || true
    rows=$(grep -cE '^  [a-z]+ ' <<<"$out")
    rm -rf "$tmp_home"

    if [[ $rows -eq 15 ]]; then
        test_pass "版本命令失败不影响 tools list 完整输出"
    else
        test_fail "tools list 被版本探测截断 (行数=$rows, 期望 15)"
    fi
}

test_repair_forwards_args() {
    test_info "测试 repair-ghostty 参数转发"

    local box out
    make_tmp -d; box=$TMP_PATH
    if ! cp -a "$ROOT_DIR/." "$box/"; then
        test_fail "无法复制仓库到沙箱"
        rm -rf "$box"
        return
    fi
    cat > "$box/scripts/repair_ghostty.sh" <<'STUB'
#!/usr/bin/env bash
printf 'REPAIR:[%s]\n' "$*"
STUB
    chmod +x "$box/scripts/repair_ghostty.sh"

    out=$(cd "$box" && timeout 20 bash install.sh repair-ghostty --user-only 2>&1) || true
    if [[ $(tail -n1 <<<"$out") == "REPAIR:[--user-only]" ]]; then
        test_pass "repair-ghostty 转发 --user-only"
    else
        test_fail "repair-ghostty 未转发参数: $out"
    fi

    rm -rf "$box"
}

test_ghostty_backup_convention() {
    test_info "测试 Ghostty 修复脚本的备份约定"

    local tmp_home backups
    make_tmp -d; tmp_home=$TMP_PATH
    mkdir -p "$tmp_home/.config/ghostty"
    printf 'term=xterm-256color\n' > "$tmp_home/.config/ghostty/config"

    HOME="$tmp_home" TERM=dumb timeout 20 bash scripts/fix_ghostty_term.sh <<< "y" >/dev/null 2>&1 || true

    backups=$(find "$tmp_home/.config/ghostty" -maxdepth 1 -name 'config.bak.*' | wc -l)
    if [[ $backups -eq 1 ]] \
        && [[ $(grep -c '^term = xterm-256color$' "$tmp_home/.config/ghostty/config") -eq 1 ]] \
        && [[ ! -e "$tmp_home/.config/ghostty/config.tmp" ]]; then
        test_pass "备份用 *.bak.* 且无空格写法被规范化"
    else
        test_fail "Ghostty 备份/写入不符 (backups=$backups)"
    fi

    rm -rf "$tmp_home"
}

# =============================================================================
# 运行所有测试
# =============================================================================

printf "\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  Joe 2.0 CLI 测试套件\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "\n"

test_help
test_version
test_tools_list
test_dependency_resolution
test_backward_compatibility
test_component_validation
test_unknown_command
test_deps_set_e_contract
test_install_plan_uses_deps
test_tools_list_clean_home
test_tui_pty
test_command_adapters
test_tools_update
test_status_summary
test_component_id_lists_agree
test_quickstart_stages
test_tools_list_version_failure
test_repair_forwards_args
test_ghostty_backup_convention

printf "\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "测试结果:\n"
printf "  ${GREEN}通过: %d${RESET}\n" "$TESTS_PASSED"
printf "  ${RED}失败: %d${RESET}\n" "$TESTS_FAILED"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "\n"

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}所有测试通过！${RESET}\n\n"
    exit 0
else
    printf "${RED}有 %d 个测试失败${RESET}\n\n" "$TESTS_FAILED"
    exit 1
fi
