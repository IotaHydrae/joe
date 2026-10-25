#!/usr/bin/env bash
# =============================================================================
# joe devtools — 开发工具套件安装脚本 (跨发行版)
# =============================================================================
# 记录在服务器 (Fedora 44) 上安装过的一组开发工具，供新机器一键复现。
# 支持 apt (Debian/Ubuntu/Mint)、pacman (Arch/CachyOS)、dnf (Fedora/RHEL)、zypper (openSUSE)。
# 已实测: Ubuntu 24.04 / Linux Mint 22.3 (noble) / Arch Linux (CachyOS 基线) / Fedora。
#
# 用法:
#   ./install.sh devtools            # 默认进入 TUI, 不预选; 非交互须指定组件
#   ./install.sh devtools --all      # 显式安装全部开发工具 (不含日常软件)
#   ./install.sh devtools --node     # 安装/切换 Node LTS (nvm 仅在安装时加载)
#   ./install.sh devtools --python   # 只装 pyenv + Python 编译依赖
#   ./install.sh devtools --claude   # 只装 Claude Code
#   ./install.sh devtools --codex    # 只装 Codex CLI
#   ./install.sh devtools --ai       # 同时装 Claude Code 和 Codex
#   ./install.sh devtools --gemini   # 只装 Gemini CLI
#   ./install.sh devtools --opencode # 只装 OpenCode
#   ./install.sh devtools --copilot  # 只装 GitHub Copilot CLI
#   ./install.sh devtools --grok     # 只装 Grok Build
#   ./install.sh devtools --zed      # 只装 Zed 编辑器 + JetBrains Mono
#   ./install.sh devtools --ghostty  # 安装/修复 Ghostty、terminfo、桌面入口、焦点和字体优先级
#   ./install.sh devtools --vscode   # 只装 VS Code 编辑器
#   ./install.sh devtools --brave    # 只装 Brave 浏览器
#   ./install.sh devtools --mimo     # 只装 MiMo Code (小米 AI 编程助手)
#   ./install.sh devtools --chatgpt  # 只装 ChatGPT / Codex 桌面版
#   ./install.sh devtools --ccswitch # 只装 CC Switch (AI CLI 配置切换器)
#   ./install.sh devtools --godot    # 只装 Godot 游戏引擎
#   ./install.sh devtools --wechat   # 只装微信 Linux 原生版
#   ./install.sh devtools --qq       # 只装 Linux QQ
#   ./install.sh devtools --rime     # 只装 Rime 雾凇拼音输入法
#   ./install.sh devtools --tui      # 交互式勾选界面 (TUI)
#   ./install.sh devtools --list     # 列出可安装组件
#   ./install.sh devtools --check    # 只报告本机适配情况 (发行版/包名解析/安装方式), 不做改动
#
# TUI 按键: ↑/↓ 移动, PgUp/PgDn 翻页, Home/End 首尾, 空格 勾选,
#           a 全选, n 全不选, i 仅未装, 回车 开始, q 退出
#
# 结构: 各组件的安装实现位于 scripts/components/<id>.sh, 每个模块暴露
#       component_<id>_install; 本脚本负责参数解析、前置检查与按 COMPONENT_ORDER 派发。
#
# 依赖: git, curl, sudo (非 root 时), bash/zsh
# 说明:
#   - nvm 装到 ~/.nvm; --node 会切换到最新 LTS, 迁移已有全局包
#   - 日常 shell 只使用 ~/.nvm/current/bin, 不加载 nvm.sh 或 nvm 补全
#   - pyenv 装到 ~/.pyenv, Python 版本与 pipx 由用户自行安装
#   - --ghostty 修复用户/系统 terminfo、桌面入口、焦点与 Fixedsys 字体优先级; 系统条目缺失时需要 sudo
#   - 单独修复用 ./install.sh repair-ghostty; --user-only 不写系统 terminfo
#   - 所有需要外网下载的步骤都尊重 https_proxy/http_proxy 环境变量
#   - 系统包名按发行版自动映射 (apt/dnf/pacman/zypper)
#   - brave, chatgpt, wechat, qq, rime 为日常软件, 位于主菜单第 2 项, --all 时默认跳过
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
NODE_LTS="${NODE_LTS:-}"                    # 留空 = 安装时最新 LTS
PROXY_URL="${PROXY_URL:-}"                  # 可选: http://host:7890

# 选中的组件: id -> 1。
declare -A WANT=()
INSTALL_ALL=false
TUI_MODE=false

# 安装顺序也是依赖顺序: node 必须先于依赖它的 AI CLI。
COMPONENT_ORDER=(node python claude codex gemini opencode copilot grok zed ghostty vscode brave mimo chatgpt ccswitch godot wechat qq rime)

# 日常软件 (不属于开发工具, --all 时跳过; 走主菜单第 2 项或显式 --<id> 参数安装)
DAILY_IDS=(brave chatgpt wechat qq rime)
is_daily_app() {
    local id="$1" d
    for d in "${DAILY_IDS[@]}"; do
        [ "$d" = "$id" ] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# 前置依赖检查
# ---------------------------------------------------------------------------
check_prerequisites() {
    local missing=()

    # 基础工具
    command -v git >/dev/null 2>&1 || missing+=(git)
    command -v curl >/dev/null 2>&1 || missing+=(curl)

    # 如果要安装 Node 相关，检查编译依赖
    if [ -n "${WANT[node]:-}" ] || $INSTALL_ALL; then
        command -v gcc >/dev/null 2>&1 || command -v cc >/dev/null 2>&1 || missing+=(build-essential)
    fi

    # 如果要安装 Python 相关，检查必要依赖
    if [ -n "${WANT[python]:-}" ] || $INSTALL_ALL; then
        command -v python3 >/dev/null 2>&1 || missing+=(python3)
        # pyenv 需要这些包来编译 Python
        if ! pkg_installed libssl-dev 2>/dev/null && ! pkg_installed openssl-devel 2>/dev/null; then
            missing+=(libssl-dev)
        fi
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        warn "缺少必要依赖: ${missing[*]}"
        info "建议先运行: install_sys_pkg ${missing[*]}"
        info "或手动安装: sudo $PM install ${missing[*]}"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# 小工具函数
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*"; }
die()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# 临时文件登记 + 退出清理 (下载中途失败不残留 /tmp/chatgpt.rpm 之类文件)
TMP_FILES=()
cleanup_tmp() {
    if [ ${#TMP_FILES[@]} -gt 0 ]; then
        rm -f -- "${TMP_FILES[@]}"
    fi
}
trap cleanup_tmp EXIT

# make_tmp 变量名 [后缀] — 创建临时文件, 路径写入调用方变量并登记到 TMP_FILES。
# 注意不能用 `f=$(make_tmp ...)` 的命令替换形式: 那样在子 shell 里登记, 父进程的
# TMP_FILES 拿不到, EXIT trap 就清不掉了。
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
# 发行版识别与包名解析 (统一由 lib_distro.sh 提供)
# ---------------------------------------------------------------------------
# 支持 apt (Debian/Ubuntu/Mint) / pacman (Arch/CachyOS) / dnf (Fedora) / zypper (openSUSE)
# 并处理版本差异, 例如 Ubuntu 24.04 的 t64 重命名 (libfuse2 -> libfuse2t64)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _lib in lib_distro.sh lib_github.sh lib_ghostty.sh lib_node.sh; do
    if [ -f "$SCRIPT_DIR/$_lib" ]; then
        # shellcheck disable=SC1090
        . "$SCRIPT_DIR/$_lib"
    else
        die "缺少 $_lib (应与本脚本同目录)"
    fi
done
unset _lib

# 仅在 Node 安装阶段加载 nvm; 不自动启用旧的 default 版本。
load_nvm() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [ -s "$NVM_DIR/nvm.sh" ] || die "未找到 $NVM_DIR/nvm.sh, 请检查 nvm 安装"
    \. "$NVM_DIR/nvm.sh" --no-use
}



# 加载 pyenv 到当前 shell
load_pyenv() {
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    [ -d "$PYENV_ROOT/bin" ] && export PATH="$PYENV_ROOT/bin:$PATH"
    command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init - bash)" 2>/dev/null || true
}

# 选择要写入的 shell 配置文件 (zsh 优先, 都没有时用 .bashrc)
pick_shell_rc() {
    if [ -f "$HOME/.zshrc" ]; then
        printf '%s\n' "$HOME/.zshrc"
    else
        printf '%s\n' "$HOME/.bashrc"
    fi
}

# 写 shell 配置片段 (幂等)
append_shell_cfg() {
    local block="$1"
    local f
    f=$(pick_shell_rc)
    if ! grep -qF "${block%%$'\n'*}" "$f" 2>/dev/null; then
        printf '\n%s\n' "$block" >> "$f"
        info "已追加配置到 $f"
    fi
}

# ---------------------------------------------------------------------------
# AI CLI 共用提示
# ---------------------------------------------------------------------------
print_ai_followup() {
    local cmd="$1" root
    root="$(cd "$SCRIPT_DIR/.." && pwd)"
    printf '下一步: 运行 %s 完成登录。\n' "$cmd"
    printf '让助手使用本机 MCP: 将 %s/templates/AGENTS.md 和 CLAUDE.md 复制到项目根目录。\n' "$root"
}

# ---------------------------------------------------------------------------
# --check: 只报告本机适配情况, 不做任何改动 (跨发行版验证用)
# ---------------------------------------------------------------------------
cmd_check() {
    printf '\n%s\n' "== 发行版 =="
    distro_report

    printf '\n%s\n' "== 系统包解析 =="
    local logical resolved mark
    for logical in vulkan-loader vulkan-tools mesa-vulkan-drivers \
                   jetbrains-mono xdg-terminal-exec fuse2 ncurses-dev \
                   fontconfig unzip; do
        resolved="$(pkg_resolve "$logical" 2>/dev/null || echo "")"
        if [ -z "$resolved" ]; then
            printf '  %-22s %s\n' "$logical" "$(printf '\033[1;33m%-24s\033[0m' '<本发行版无')"
        else
            printf '  %-22s -> %s\n' "$logical" "$resolved"
        fi
    done

    printf '\n%s\n' "== 各组件安装方式 =="
    case "$PM" in
        apt)    printf '  %-12s %s\n' ghostty  "官方仓库(26.04+) / 社区 .deb / snap" ;;
        pacman) printf '  %-12s %s\n' ghostty  "官方 extra 仓库 (pacman -S ghostty)" ;;
        dnf)    printf '  %-12s %s\n' ghostty  "COPR scottames/ghostty" ;;
        zypper) printf '  %-12s %s\n' ghostty  "官方 repo-oss" ;;
    esac
    case "$PM" in
        apt)    printf '  %-12s %s\n' vscode   "微软 apt 源 (packages.microsoft.com)" ;;
        pacman) printf '  %-12s %s\n' vscode   "官方 extra 仓库 (pacman -S code)" ;;
        dnf)    printf '  %-12s %s\n' vscode   "微软 dnf 源" ;;
        zypper) printf '  %-12s %s\n' vscode   "微软 zypper 源" ;;
    esac
    case "$PM" in
        apt)    printf '  %-12s %s\n' chatgpt  "官方 .deb" ;;
        pacman) printf '  %-12s %s\n' chatgpt  "官方 install-arch.sh" ;;
        dnf|zypper) printf '  %-12s %s\n' chatgpt "官方 .rpm" ;;
    esac
    case "$PM" in
        apt)    printf '  %-12s %s\n' ccswitch "官方 .deb" ;;
        pacman) printf '  %-12s %s\n' ccswitch "AppImage + fuse2" ;;
        dnf|zypper) printf '  %-12s %s\n' ccswitch "官方 .rpm" ;;
    esac
    printf '  %-12s %s\n' node   "Node LTS (nvm 仅在安装时使用, 日常只设置 PATH)"
    printf '  %-12s %s\n' python "pyenv (需构建依赖)"
    printf '  %-12s %s\n' claude "官方安装脚本, 失败时回退 npm"
    printf '  %-12s %s\n' codex    "npm 全局安装 (@openai/codex)"
    printf '  %-12s %s\n' gemini   "npm 全局安装 (@google/gemini-cli)"
    printf '  %-12s %s\n' opencode "官方安装脚本, 失败时回退 npm"
    printf '  %-12s %s\n' copilot  "官方安装脚本, 装到 ~/.local, 失败时回退 npm"
    printf '  %-12s %s\n' grok     "官方安装脚本 (https://x.ai/cli/install.sh)"
    printf '  %-12s %s\n' zed      "Zed 官方安装脚本 (发行版无关)"
    printf '  %-12s %s\n' mimo   "MiMo 官方安装脚本 (发行版无关)"
    printf '\n'
}

# ---------------------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------------------
# 打印文件头部注释块 (去掉 # 前缀); 按注释边界截取, 不依赖硬编码行号,
# 以后增删注释不会再把「依赖」「说明」两节截掉
usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

# 加载 TUI 模块 (--tui 与 --list 共用); 成功时可直接调用其函数
load_tui_module() {
    if [ ! -f "$SCRIPT_DIR/tui_module.sh" ]; then
        return 1
    fi
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/tui_module.sh"
}

# --list: 列出可安装组件及当前安装状态
list_components() {
    local id status
    if ! load_tui_module; then
        die "未找到 tui_module.sh, 无法列出组件"
    fi
    printf '可安装组件:\n'
    for id in "${TUI_IDS[@]}"; do
        if tui_component_installed "$id"; then
            status="已安装"
        else
            status="未安装"
        fi
        printf '  %-9s %-4s %s\n' "$id" "$status" "$(tui_component_name "$id")"
    done
}

HAS_ARGS=false
[ "$#" -gt 0 ] && HAS_ARGS=true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --node|--python|--claude|--codex|--gemini|--opencode|--copilot|--grok|--zed|--ghostty|--vscode|--brave|--mimo|--chatgpt|--ccswitch|--godot|--wechat|--qq|--rime)
            WANT[${1#--}]=1; shift ;;
        --ai)       WANT[claude]=1; WANT[codex]=1; shift ;;
        --all)      INSTALL_ALL=true; shift ;;
        --tui)      TUI_MODE=true; shift ;;
        --list)     list_components; exit 0 ;;
        --check)    cmd_check; exit 0 ;;
        -h|--help)  usage; exit 0 ;;
        *)
            printf '未知选项: %s\n\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# 无参数只进入交互选择, 非交互调用须显式指定组件。
if [ "$HAS_ARGS" = "false" ]; then
    if [ -t 1 ] && [ -t 0 ]; then
        TUI_MODE=true
    else
        die "当前不是交互式终端, 请指定组件选项或使用 --all (查看 --help)"
    fi
fi

if $TUI_MODE && $INSTALL_ALL; then
    die "--all 不能与 --tui 同时使用"
fi

# ---------------------------------------------------------------------------
# 代理设置 (可选)
# ---------------------------------------------------------------------------
if [ -n "$PROXY_URL" ]; then
    export https_proxy="$PROXY_URL" http_proxy="$PROXY_URL"
    info "使用代理: $PROXY_URL"
fi

# ---------------------------------------------------------------------------
# TUI 交互选择 (--tui)
# ---------------------------------------------------------------------------
if $TUI_MODE; then
    if ! load_tui_module; then
        die "未找到 tui_module.sh"
    fi
    if ! tui_available; then
        die "当前不是交互式终端, 请指定组件选项或使用 --all (查看 --help)"
    fi
    info "启动 TUI 选择界面 (已安装组件自动跳过)..."
    run_tui
    if [ -z "$TUI_SELECTED" ]; then
        info "TUI 未选择任何组件 (或退出), 跳过安装"
        exit 0
    fi
    INSTALL_ALL=false
    WANT=()
    for comp in $TUI_SELECTED; do
        WANT[$comp]=1
    done
    info "已选择:${TUI_SELECTED}"
fi

# 前置检查放在选择之后, 只检查用户选中的组件。
info "=== 开发工具安装器 ==="
distro_report
printf '\n'
if ! check_prerequisites; then
    warn "前置检查发现问题，但继续执行（部分安装可能失败）"
    sleep 2
fi

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
info "joe devtools 安装开始 $(date) [包管理器: $PM]"

# 每个 id 对应 scripts/components/<id>.sh 里的 component_<id>_install
COMPONENT_DIR="$SCRIPT_DIR/components"
load_component() {
    local id="$1" file
    file="$COMPONENT_DIR/$id.sh"
    [ -f "$file" ] || die "缺少组件模块: $file"
    # shellcheck disable=SC1090
    . "$file"
}

for _id in "${COMPONENT_ORDER[@]}"; do
    if [ -n "${WANT[$_id]:-}" ] || ( $INSTALL_ALL && ! is_daily_app "$_id" ); then
        load_component "$_id"
        "component_${_id}_install"
    fi
done
unset _id

ok "全部完成! 新开终端后生效 (或 source ~/.zshrc)"
