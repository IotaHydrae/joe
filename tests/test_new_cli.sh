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

# 仓库副本不能落在仓库里, 否则 cp 会递归复制自己 (TMPDIR 指向 checkout 时会踩到)
make_repo_box() {
    make_tmp -d
    case "$TMP_PATH/" in
        "$ROOT_DIR"/*)
            rm -rf "$TMP_PATH"
            TMP_PATH=$(mktemp -d "$(dirname "$ROOT_DIR")/joe-sbx.XXXXXX")
            TEST_TMPS+=("$TMP_PATH")
            ;;
    esac
}

# 断言转换层把参数原样交给底层安装器 (FWD_STUB 打印 "FWD|<args>")
assert_forward() {
    local label="$1" expected="$2"
    shift 2
    local out="" got
    out=$(MCP_SCRIPT="$FWD_STUB" SKILLS_SCRIPT="$FWD_STUB" FONTS_SCRIPT="$FWD_STUB" timeout 10 bash install.sh "$@" 2>&1) || true
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

    if [[ $rows -eq 14 ]]; then
        test_pass "全新环境列出 14 个组件"
    else
        test_fail "tools list 组件行数=$rows (期望 14)"
    fi
}

# 运行 pty 回归脚本; 脚本用退出码 2 表示环境不支持
run_pty_check() {
    local label="$1" script="$2"
    if ! command -v python3 >/dev/null 2>&1; then
        test_info "缺少 python3, 跳过 $label"
        return
    fi

    local rc=0 out=""
    out=$(timeout 90 python3 "$script" 2>&1) || rc=$?
    case $rc in
        0) test_pass "$label" ;;
        2) test_info "无 pty 支持, 跳过 $label" ;;
        *) test_fail "$label 失败 (rc=$rc): $(grep -m1 '^FAIL' <<<"$out")" ;;
    esac
}

test_tui_pty() {
    test_info "测试交互界面 (pty)"

    run_pty_check "TUI 渲染/回车确认/选择回传" tests/tui_pty_check.py
    run_pty_check "主菜单浏览不触发安装" tests/menu_pty_check.py
    run_pty_check "MCP TUI 渲染/选择回传/npx 门禁" tests/mcp_tui_pty_check.py
}

test_command_adapters() {
    test_info "测试 mcp/skills/fonts 语法转换层"

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
    assert_forward "skills categories" "--categories" skills categories
    assert_forward "skills install <id>" "gdb" skills install gdb
    assert_forward "skills install --category" "--category kernel-dev --all" skills install --category kernel-dev --all
    assert_forward "fonts list" "--list" fonts list
    assert_forward "fonts status" "--list" fonts status
    assert_forward "fonts install <id>" "jetbrains-mono" fonts install jetbrains-mono
    assert_forward "fonts install --all/--dry-run" "--dry-run --all" fonts install --dry-run --all

    # 旧语法必须逐字透传 (转换层只认动作词)
    # 交互选择走 MCP TUI; 非交互终端下应拒绝而不是转发给安装器
    local tui_out=""
    tui_out=$(MCP_SCRIPT="$FWD_STUB" timeout 10 bash install.sh mcp tui </dev/null 2>&1) || true
    if [[ $tui_out == *"TUI 需要交互式终端"* && $tui_out != *FWD:* ]]; then
        test_pass "mcp tui 在非交互终端下拒绝"
    else
        test_fail "mcp tui 非交互行为不符: $tui_out"
    fi
    tui_out=$(MCP_SCRIPT="$FWD_STUB" timeout 10 bash install.sh mcp --tui </dev/null 2>&1) || true
    if [[ $tui_out == *"TUI 需要交互式终端"* ]]; then
        test_pass "mcp --tui 也走新 TUI"
    else
        test_fail "mcp --tui 行为不符: $tui_out"
    fi
    # 直接调用安装器的 --tui 同样委托新 TUI (不加载旧 tui_module)
    tui_out=$(timeout 10 bash scripts/install_mcp_servers.sh --tui </dev/null 2>&1) || true
    if [[ $tui_out == *"TUI 需要交互式终端"* ]]; then
        test_pass "安装器 --tui 委托新 TUI"
    else
        test_fail "安装器 --tui 未委托: $tui_out"
    fi

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

    # 指定组件时转成 update-all 的 --only
    out=$(UPDATE_SCRIPT="$stub" timeout 15 bash install.sh tools update node claude 2>&1) || true
    if [[ $out == *"UPD: [--only] [node,claude]"* ]]; then
        test_pass "tools update <组件...> 转成 --only"
    else
        test_fail "按组件更新转发不符: $out"
    fi

    out=$(UPDATE_SCRIPT="$stub" timeout 15 bash install.sh tools update --dry-run node 2>&1) || true
    if [[ $out == *"UPD: [--dry-run] [--only] [node]"* ]]; then
        test_pass "tools update 同时转发选项与 --only"
    else
        test_fail "选项组合转发不符: $out"
    fi

    # 适配层不判断能否更新, 交给 update-all 给出准确的拒绝信息
    out=$(UPDATE_SCRIPT="$stub" timeout 15 bash install.sh tools update zed 2>&1) || true
    if [[ $out == *"UPD: [--only] [zed]"* ]]; then
        test_pass "tools update 不拦截无自更新机制的组件"
    else
        test_fail "zed 转发不符: $out"
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

    local daily_ids
    daily_ids=$(timeout 10 bash -c '
        set -euo pipefail
        source scripts/lib/deps.sh
        printf "%s\n" "${DAILY_IDS[@]}" | sort -u
    ') || daily_ids=""
    local overlap
    overlap=$(comm -12 <(printf '%s\n' "$deps_ids") <(printf '%s\n' "$daily_ids"))
    if [[ -z $overlap ]]; then
        test_pass "日常软件清单与开发工具清单无交集"
    else
        test_fail "日常软件与开发工具有重叠: $overlap"
    fi

    # 新增组件也必须有自己的模块, 否则派发时会 die
    local id missing_module="" all_components
    all_components=$(printf '%s\n%s\n' "$deps_ids" "$daily_ids" | sort -u)
    for id in $all_components; do
        if [ ! -f "scripts/components/$id.sh" ] \
            || ! grep -q "^component_${id}_install()" "scripts/components/$id.sh"; then
            missing_module+=" $id"
        fi
    done
    if [[ -z $missing_module ]]; then
        test_pass "每个组件 id 都有模块并暴露 component_<id>_install"
    else
        test_fail "缺少组件模块或接口:$missing_module"
    fi

    # 派发顺序表包含开发工具与日常软件的所有组件
    local order_ids
    order_ids=$(sed -n 's/^COMPONENT_ORDER=(\(.*\))$/\1/p' scripts/install_devtools.sh |
        tr ' ' '\n' | sort -u)
    if diff <(printf '%s\n' "$all_components") <(printf '%s\n' "$order_ids") >/dev/null; then
        test_pass "COMPONENT_ORDER 覆盖全部开发工具与日常软件"
    else
        test_fail "COMPONENT_ORDER 与预期组件不一致"
        diff <(printf '%s\n' "$all_components") <(printf '%s\n' "$order_ids") || true
    fi

    # 模块之间不应互相调用 (会重新引入隐式依赖)
    if grep -nE 'component_[a-z_]+_install' scripts/components/*.sh |
        grep -vE 'component_[a-z_]*_install\(\)' >/dev/null; then
        test_fail "组件模块之间存在互相调用"
    else
        test_pass "组件模块之间无交叉调用"
    fi
}

test_quickstart_stages() {
    test_info "测试 quick-start 阶段编排"

    local box s out
    make_repo_box; box=$TMP_PATH
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

    if [[ $rows -eq 14 ]]; then
        test_pass "版本命令失败不影响 tools list 完整输出"
    else
        test_fail "tools list 被版本探测截断 (行数=$rows, 期望 14)"
    fi
}

test_repair_forwards_args() {
    test_info "测试 repair-ghostty 参数转发"

    local box out
    make_repo_box; box=$TMP_PATH
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

test_devtools_dispatch() {
    test_info "测试组件派发 (stub 模块)"

    local box out runs id
    make_repo_box; box=$TMP_PATH
    if ! cp -a "$ROOT_DIR/." "$box/"; then
        test_fail "无法复制仓库到沙箱"
        return
    fi
    for id in node python claude codex gemini opencode copilot grok zed ghostty vscode brave mimo chatgpt ccswitch godot wechat qq rime; do
        printf '#!/usr/bin/env bash\ncomponent_%s_install() { echo "RUN:%s"; }\n' "$id" "$id" \
            > "$box/scripts/components/$id.sh"
    done

    out=$(cd "$box" && timeout 60 bash scripts/install_devtools.sh --node --brave 2>&1) || true
    runs=$(grep -E '^RUN:' <<<"$out" | tr '\n' ' ' || true)
    if [[ $runs == "RUN:node RUN:brave " ]]; then
        test_pass "按选择的组件派发 (node, brave)"
    else
        test_fail "派发不符: $runs"
    fi

    out=$(cd "$box" && timeout 60 bash scripts/install_devtools.sh --ai 2>&1) || true
    runs=$(grep -E '^RUN:' <<<"$out" | tr '\n' ' ' || true)
    if [[ $runs == "RUN:claude RUN:codex " ]]; then
        test_pass "--ai 派发 claude + codex"
    else
        test_fail "--ai 派发不符: $runs"
    fi

    out=$(cd "$box" && timeout 90 bash scripts/install_devtools.sh --all 2>&1) || true
    local count
    count=$(grep -cE '^RUN:' <<<"$out" || true)
    if [[ $count -eq 14 ]]; then
        test_pass "--all 派发全部 14 个开发工具模块"
    else
        test_fail "--all 派发数不符: $count"
    fi
    if grep -qE '^RUN:(brave|chatgpt|wechat|qq|rime)$' <<<"$out"; then
        test_fail "--all 包含了日常软件"
    else
        test_pass "--all 未包含日常软件"
    fi

    out=$(cd "$box" && timeout 60 bash scripts/install_devtools.sh --wechat --qq 2>&1) || true
    runs=$(grep -E '^RUN:' <<<"$out" | tr '\n' ' ' || true)
    if [[ $runs == "RUN:wechat RUN:qq " ]]; then
        test_pass "--wechat --qq 按组件顺序派发"
    else
        test_fail "--wechat --qq 派发不符: $runs"
    fi

    # 模块缺失必须显式失败, 不能静默跳过
    rm -f "$box/scripts/components/brave.sh"
    out=$(cd "$box" && timeout 60 bash scripts/install_devtools.sh --brave 2>&1) || true
    if [[ $out == *"缺少组件模块"* ]]; then
        test_pass "缺失模块时显式报错"
    else
        test_fail "缺失模块未报错"
    fi
}

test_update_only() {
    test_info "测试 update-all --only"

    local out rc stub_bin

    rc=0
    out=$(timeout 20 bash scripts/update-all.sh --only bogus </dev/null 2>&1) || rc=$?
    if [[ $rc -eq 2 && $out == *"未知更新项: bogus"* ]]; then
        test_pass "--only 拒绝未知条目"
    else
        test_fail "--only 未知条目行为不符 (rc=$rc): $out"
    fi

    rc=0
    out=$(timeout 20 bash scripts/update-all.sh --only zed </dev/null 2>&1) || rc=$?
    if [[ $rc -eq 2 && $out == *"没有自更新机制"* && $out == *"tools install zed"* ]]; then
        test_pass "无自更新机制的组件给出重装指引"
    else
        test_fail "zed 提示不符 (rc=$rc): $out"
    fi

    rc=0
    out=$(timeout 20 bash scripts/update-all.sh --only system </dev/null 2>&1) || rc=$?
    if [[ $rc -eq 2 && $out == *"--system"* ]]; then
        test_pass "system 必须配合 --system"
    else
        test_fail "system 校验不符 (rc=$rc): $out"
    fi

    # dry-run 不执行任何命令, 可以安全断言筛选结果
    out=$(timeout 30 bash scripts/update-all.sh --only node --dry-run 2>&1) || true
    if [[ $out == *"只更新: node"* && $out == *"nvm"* && $out != *"claude"* ]]; then
        test_pass "--only node 只列出 nvm 一项"
    else
        test_fail "--only node 筛选不符: $out"
    fi

    # 只测试筛选与渲染, 不依赖宿主机是否安装了 Claude Code。
    make_tmp -d; stub_bin=$TMP_PATH
    cat > "$stub_bin/claude" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x "$stub_bin/claude"
    out=$(PATH="$stub_bin:$PATH" timeout 30 bash scripts/update-all.sh --only node,claude --dry-run 2>&1) || true
    if [[ $out == *"nvm"* && $out == *"claude (Claude Code)"* ]]; then
        test_pass "--only node,claude 列出两项"
    else
        test_fail "--only 多条目筛选不符: $out"
    fi

    out=$(timeout 30 bash scripts/update-all.sh --only joe --dry-run 2>&1) || true
    if [[ $out == *"joe (git pull)"* && $out != *"nvm"* ]]; then
        test_pass "--only joe 不波及其它条目"
    else
        test_fail "--only joe 筛选不符: $out"
    fi
}

test_daily_app_packages() {
    test_info "测试微信/QQ 安装包地址与校验"

    local hdr pkg big help out rc
    make_tmp; hdr=$TMP_PATH
    make_tmp; pkg=$TMP_PATH
    make_tmp; big=$TMP_PATH

    if (
        # shellcheck disable=SC1091
        . scripts/components/wechat.sh
        # shellcheck disable=SC1091
        . scripts/components/qq.sh

        url=$(wechat_package_url x86_64 apt)
        [ "$url" = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb" ]
        url=$(wechat_package_url aarch64 zypper)
        [ "$url" = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.rpm" ]
        if wechat_package_url i686 apt >/dev/null; then
            exit 1
        fi
        if wechat_package_url x86_64 pacman >/dev/null; then
            exit 1
        fi

        config='var params= {"x64DownloadUrl":{"deb":"https://qqdl.gtimg.cn/qqfile/test/amd64.deb","rpm":"https://qqdl.gtimg.cn/qqfile/test/x86_64.rpm"},"armDownloadUrl":{"deb":"https://qqdl.gtimg.cn/qqfile/test/arm64.deb","rpm":"https://qqdl.gtimg.cn/qqfile/test/aarch64.rpm","appimage":"https://evil.example/nope.AppImage"}};'
        [ "$(qq_pick_url "$config" x64DownloadUrl deb)" = "https://qqdl.gtimg.cn/qqfile/test/amd64.deb" ]
        [ "$(qq_pick_url "$config" armDownloadUrl rpm)" = "https://qqdl.gtimg.cn/qqfile/test/aarch64.rpm" ]
        [ "$(qq_arch_key aarch64)" = "armDownloadUrl" ]
        [ "$(qq_pkg_kind dnf)" = "rpm" ]
        if qq_pick_url "$config" x64DownloadUrl appimage >/dev/null; then
            exit 1
        fi
        if qq_arch_key i686 >/dev/null; then
            exit 1
        fi
        bad='{"x64DownloadUrl":{"deb":"https://evil.example/a.deb","rpm":"https://qqdl.gtimg.cn/qqfile/test/x86_64.rpm"}}'
        if qq_pick_url "$bad" x64DownloadUrl deb >/dev/null; then
            exit 1
        fi

        printf 'HTTP/1.1 302\r\nX-COS-META-MD5: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\r\n\r\nHTTP/1.1 200\r\nContent-Length: 1048576\r\nX-COS-META-MD5: 3293E535C3BBCDE61D82A8F5B16963F8\r\n' > "$hdr"
        [ "$(read_pkg_md5 "$hdr")" = "3293e535c3bbcde61d82a8f5b16963f8" ]
        printf 'Content-MD5: abcdefghijklmnop\n' > "$hdr"
        if read_pkg_md5 "$hdr" >/dev/null; then
            exit 1
        fi

        dd if=/dev/zero of="$big" bs=1048576 count=1 status=none
        printf '!<arch>\n' | dd of="$big" conv=notrunc status=none
        printf 'Content-Length: 1\r\nContent-Length: 1048576\r\n' > "$hdr"
        pkg_payload_ok "$big" deb "$hdr"
        printf 'Content-Length: 8\n' > "$hdr"
        if pkg_payload_ok "$big" deb "$hdr"; then
            exit 1
        fi
        printf '\355\253\356\333' | dd of="$big" conv=notrunc status=none
        pkg_magic_ok "$big" rpm
        printf '!<arch>\n' > "$pkg"
        printf 'Content-Length: 8\n' > "$hdr"
        if pkg_payload_ok "$pkg" deb "$hdr"; then
            exit 1
        fi
        printf 'not a package' > "$pkg"
        if pkg_magic_ok "$pkg" deb; then
            exit 1
        fi
    ); then
        test_pass "微信/QQ 地址、主机限制和安装包校验符合预期"
    else
        test_fail "微信/QQ 地址或安装包校验不符"
    fi

    help=$(timeout 15 bash install.sh devtools --help 2>&1) || true
    if [[ $help == *"--wechat"* && $help == *"--qq"* && $help == *"依赖"* && $help == *"说明"* ]]; then
        test_pass "devtools --help 包含微信/QQ 且保留依赖与说明"
    else
        test_fail "devtools --help 未包含微信/QQ 或截断了说明"
    fi

    rc=0
    out=$(timeout 20 bash scripts/update-all.sh --only wechat </dev/null 2>&1) || rc=$?
    if [[ $rc -eq 2 && $out == *"没有自更新机制"* && $out == *"tools install wechat"* ]]; then
        test_pass "微信没有自更新机制时给出重装指引"
    else
        test_fail "微信更新提示不符 (rc=$rc): $out"
    fi
}

test_qq_download_signing() {
    test_info "测试 QQ 下载签名与失败处理"

    local box original signed reply label out rc expected
    make_tmp -d; box=$TMP_PATH
    mkdir -p "$box/home" "$box/tmp"
    original="https://qqdl.gtimg.cn/qqfile/test/amd64.deb"
    signed="$original?sign=abcdef0123456789&t=1793105764"
    cat > "$box/runner.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
. "$1/scripts/components/qq.sh"
PM=apt
info() { :; }
ok() { :; }
die() { printf '%s\n' "$*" >&2; exit 1; }
uname() { printf 'x86_64\n'; }
qq_present() { [ -f "$QQ_TEST_BOX/installed" ]; }
make_tmp() { printf -v "$1" '%s/config.js' "$TMPDIR"; }
trap 'rm -f -- "$TMPDIR/config.js"' EXIT
curl() {
    local url="${!#}" output="" data=""
    printf 'curl\n' >> "$QQ_TEST_BOX/request.log"
    printf '%s\n' "$@" >> "$QQ_TEST_BOX/request.log"
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -o) output="$2"; shift ;;
            --data|--data-raw) data="$2"; shift ;;
        esac
        shift
    done
    case "$url" in
        https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js)
            printf '{"x64DownloadUrl":{"deb":"%s"}}\n' "$QQ_TEST_ORIGINAL" > "$output"
            ;;
        https://im.qq.com/http2rpc/gotrpc/noauth/trpc.qqntv2.urlsign.UrlSign/GetSign)
            [ "$data" = "{\"url\":\"$QQ_TEST_ORIGINAL\"}" ] || return 99
            [ "${QQ_TEST_CURL_FAIL:-0}" = 0 ] || return 22
            printf '%s\n' "$QQ_TEST_REPLY"
            ;;
        *) return 99 ;;
    esac
}
install_vendor_package() {
    printf 'package|%s|%s|%s|%s\n' "$@" >> "$QQ_TEST_BOX/package.log"
    [ "$1" = "$QQ_TEST_SIGNED" ] || return 22
    touch "$QQ_TEST_BOX/installed"
}
component_qq_install
RUNNER

    for label in success escaped pretty http_error api_error no_url foreign_host wrong_path unsigned no_sign no_time malformed; do
        expected=1
        case "$label" in
            success) expected=0; reply="{\"retcode\":0,\"data\":{\"url\":\"$signed\"}}" ;;
            escaped) expected=0; reply="{\"retcode\":0,\"data\":{\"url\":\"${signed//\//\\/}\"}}" ;;
            pretty) expected=0; printf -v reply '{\n  "retcode": 0,\n  "data": {\n    "url": "%s"\n  }\n}\n' "$signed" ;;
            http_error) reply='' ;;
            api_error) reply="{\"retcode\":1,\"data\":{\"url\":\"$signed\"}}" ;;
            no_url) reply='{"retcode":0,"data":{}}' ;;
            foreign_host) reply='{"retcode":0,"data":{"url":"https://evil.example/a.deb?sign=abc&t=123"}}' ;;
            wrong_path) reply='{"retcode":0,"data":{"url":"https://qqdl.gtimg.cn/qqfile/other.deb?sign=abc&t=123"}}' ;;
            unsigned) reply="{\"retcode\":0,\"data\":{\"url\":\"$original\"}}" ;;
            no_sign) reply="{\"retcode\":0,\"data\":{\"url\":\"$original?t=123\"}}" ;;
            no_time) reply="{\"retcode\":0,\"data\":{\"url\":\"$original?sign=abc\"}}" ;;
            malformed) reply='<html>unavailable</html>' ;;
        esac
        rm -f -- "$box/installed" "$box/request.log" "$box/package.log"
        rc=0
        out=$(HOME="$box/home" TMPDIR="$box/tmp" QQ_TEST_BOX="$box" \
            QQ_TEST_ORIGINAL="$original" QQ_TEST_SIGNED="$signed" QQ_TEST_REPLY="$reply" \
            QQ_TEST_CURL_FAIL="$([[ $label == http_error ]] && printf 1 || printf 0)" \
            timeout 15 bash "$box/runner.sh" "$ROOT_DIR" 2>&1) || rc=$?
        if [[ $expected -eq 0 ]]; then
            if [[ $rc -eq 0 ]] &&
                    grep -Fxq "package|$signed|deb|no|https://im.qq.com/linuxqq/index.shtml" "$box/package.log" &&
                    grep -Fxq 'Content-Type: application/json' "$box/request.log" &&
                    grep -Fxq 'x-oidb: {"uint32_command":"0x9b8e","uint32_service_type":1}' "$box/request.log"; then
                test_pass "QQ 获取签名后下载 ($label)"
            else
                test_fail "QQ 签名下载失败 ($label, rc=$rc): $out"
            fi
        elif [[ $rc -ne 0 && $out == *"无法获取 Linux QQ 下载签名"* && ! -e "$box/package.log" ]]; then
            test_pass "QQ 签名异常时拒绝下载 ($label)"
        else
            test_fail "QQ 未正确拒绝签名异常 ($label, rc=$rc): $out"
        fi
        if [[ -n $(find "$box/tmp" -mindepth 1 -print -quit) ]]; then
            test_fail "QQ 签名测试遗留临时文件 ($label)"
        fi
    done
}

test_vendor_download_resume() {
    test_info "测试微信/QQ 安装包断点续传"
    local out rc=0
    out=$(timeout 45 bash tests/vendor_download_check.sh 2>&1) || rc=$?
    if [[ $rc -eq 0 ]]; then
        test_pass "自动续传、跨运行缓存、版本识别和完整性校验"
    else
        test_fail "安装包续传回归失败 (rc=$rc): $out"
    fi
}

test_predictable_temp_paths() {
    test_info "测试下载临时路径"

    # 下载/执行的临时文件不能写到固定 /tmp 名称: 多用户机器上可被预置或符号链接劫持
    local hits
    hits=$(grep -nE '/tmp/[A-Za-z0-9._-]+' scripts/components/*.sh scripts/lib_github.sh |
        grep -vE ':[0-9]+:[[:space:]]*#' || true)
    if [[ -z $hits ]]; then
        test_pass "下载临时路径均为随机目录"
    else
        test_fail "存在固定 /tmp 路径: $hits"
    fi

    # 拿不到校验文件时必须拒绝安装, 而不是"跳过校验"继续装
    if grep -q '跳过校验' scripts/lib_github.sh; then
        test_fail "校验缺失时仍会跳过校验"
    else
        test_pass "无法获取校验文件时拒绝安装"
    fi
}

test_fonts_installation() {
    test_info "测试独立字体安装"
    local out rc=0
    out=$(timeout 30 bash tests/fonts_check.sh 2>&1) || rc=$?
    if [[ $rc -eq 0 ]]; then
        test_pass "字体离线安装、备份、幂等和 dry-run"
    else
        test_fail "字体安装回归失败 (rc=$rc): $out"
    fi
}

test_zsh_configuration() {
    test_info "测试离线 zsh 配置优化"
    local out rc=0
    out=$(timeout 45 bash tests/zsh_config_check.sh 2>&1) || rc=$?
    if [[ $rc -eq 0 ]]; then
        test_pass "zsh 配置迁移、按需初始化、幂等和 dry-run"
    elif [[ $rc -eq 2 ]]; then
        test_info "未安装 zsh, 跳过交互配置回归"
    else
        test_fail "zsh 配置回归失败 (rc=$rc): $out"
    fi
}

test_ghostty_fontconfig() {
    test_info "测试 Ghostty Fixedsys 字体优先级修复"
    local out rc=0
    out=$(timeout 30 bash tests/ghostty_fontconfig_check.sh 2>&1) || rc=$?
    if [[ $rc -eq 0 ]]; then
        test_pass "Ghostty 字体规则部署、备份、幂等与中文字体优先级"
    else
        test_fail "Ghostty 字体规则回归失败 (rc=$rc): $out"
    fi
}

test_ghostty_launcher() {
    test_info "测试 Ghostty 新窗口焦点修复"
    local out rc=0
    out=$(timeout 20 bash tests/ghostty_launcher_check.sh 2>&1) || rc=$?
    if [[ $rc -eq 0 ]]; then
        test_pass "Ghostty 新窗口焦点、参数与快捷键迁移"
    else
        test_fail "Ghostty 启动器回归失败 (rc=$rc): $out"
    fi
}

test_rime_installation() {
    test_info "测试 Rime 安装与配置修复"
    local out rc=0
    out=$(timeout 45 bash tests/test_rime.sh 2>&1) || rc=$?
    if [[ $rc -eq 0 ]]; then
        test_pass "Rime 离线部署、数据保留、幂等和失败处理"
    else
        test_fail "Rime 安装回归失败 (rc=$rc): $out"
    fi
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
test_devtools_dispatch
test_update_only
test_daily_app_packages
test_qq_download_signing
test_vendor_download_resume
test_predictable_temp_paths
test_fonts_installation
test_zsh_configuration
test_ghostty_fontconfig
test_ghostty_launcher
test_rime_installation

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
