#!/usr/bin/env bash
# =============================================================================
# joe — 开发环境配置工具
# =============================================================================
# 命令路由器: ./install.sh <域> <动作> [选项] [参数...]
# 无参数或 --tui 进入主菜单

set -euo pipefail

VERSION="2.0.0"

usage() {
    cat <<'EOF'
用法: ./install.sh [<域> <动作> [选项] [参数...]]

无参数进入主菜单。

基础选项 (必须放在最前面, 后面不要跟域):
    -h, --help      显示此帮助
    --version       显示版本信息

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
主命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  shell              安装 zsh + Oh My Zsh + Powerlevel10k
      --dry-run          预览操作
      --no-fonts         跳过字体安装
      --no-config        跳过 .config 复制
      --no-p10k          跳过 powerlevel10k
      --no-fastfetch     跳过 fastfetch
      --no-default-plugins  不启用默认 OMZ 插件
      --clean-backups    清理旧备份 (保留最近 5 个)

  fonts              字体安装 (Fixedsys Excelsior / JetBrains Mono)
      <无参数>           进入字体编号菜单
      list, status       列出字体及安装状态
      install <字体...>  单独安装字体 (--all / --dry-run)

  tools              开发工具管理
      <无参数>           进入 TUI 选择界面
      list               列出所有工具及安装状态
      install <组件...>  安装指定工具
      update [组件...]   统一更新; 指定组件时只更新这些 (--dry-run/--quiet/--system)
      check              检查系统兼容性

  mcp                MCP 服务器管理
      <无参数>           进入 TUI 选择界面
      list               列出所有服务及状态
      install <服务...>  安装指定服务
      update [服务...]   重跑安装器刷新配置

  skills             代理技能管理
      <无参数>           进入技能组 / 分类选择
      list               列出技能及安装状态
      categories         列出分类及技能数量
      install <技能...>  安装指定技能 (可配 --category / --all)

  config             配置文件管理
      list               查看配置映射
      export             导出配置到仓库
      import             从仓库恢复配置
      diff               对比配置差异

  doctor             环境检查
      [--json]           JSON 格式输出

  status             显示所有组件安装状态
      [--short]          单行输出 (tools 14/14 | mcp 0/7 | skills 150/150)

  update             更新工具链、AI CLI 与 joe 仓库

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
快捷命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  quick-start        一键部署 shell/工具/MCP/技能/体检
      --yes                非交互全部安装 (适合脚本/CI)
      --only|--skip <阶段>  选择阶段: shell,devtools,mcp,skills,doctor

  install-all        安装所有组件（需确认）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
示例
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ./install.sh                          # 主菜单
  ./install.sh shell                    # 安装 shell 环境
  ./install.sh fonts                    # 字体安装菜单
  ./install.sh fonts install jetbrains-mono  # 单独安装 JetBrains Mono
  ./install.sh tools                    # 进入工具选择 TUI
  ./install.sh tools list               # 列出所有工具
  ./install.sh tools install node       # 安装 Node.js
  ./install.sh tools install claude codex   # 安装多个工具
  ./install.sh tools install --ai       # 安装 AI 工具组
  ./install.sh mcp install memory git   # 安装 MCP 服务
  ./install.sh doctor                   # 环境检查
  ./install.sh status                   # 查看状态

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
向后兼容 (旧命令)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  devtools [选项]    = tools [选项]
  mcp [旧参数]       兼容旧格式
  configs <动作>     = config <动作>
  repair-ghostty     = scripts/repair_ghostty.sh (--user-only 不写系统 terminfo)
  bootstrap          = quick-start

EOF
}


die() {
    printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2
    exit 1
}

info() {
    printf '\033[0;34m[INFO]\033[0m %s\n' "$*"
}

# 检测命令类型和参数
detect_command() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
        --version) printf "joe v%s\n" "$VERSION"; exit 0 ;;
        '') COMMAND="menu" ;;
        shell|fonts|tools|mcp|skills|config|doctor|status|update) COMMAND="$1" ;;

        # 快捷命令
        quick-start|install-all) COMMAND="$1" ;;

        # 向后兼容
        devtools) COMMAND="tools"; LEGACY_DEVTOOLS=true ;;
        configs) COMMAND="config" ;;
        menu|--tui) COMMAND="menu" ;;
        repair-ghostty) COMMAND="repair"; REPAIR_TARGET="ghostty" ;;
        bootstrap) COMMAND="quick-start" ;;  # 映射到新命令

        # 旧 Shell 参数（向后兼容）: 参数本身就是选项, 不能 shift 掉
        -n|--dry-run|--no-fonts|--no-config|--no-p10k|--no-fastfetch|--no-default-plugins|--no-ghostty-ime|--clean-backups|-u)
            COMMAND="shell"
            COMMAND_ARGS=("$@")
            return 0
            ;;

        *) die "未知命令: $1 (查看 --help)" ;;
    esac

    shift || true
    COMMAND_ARGS=("$@")

    # 旧 devtools 参数: --list 映射为 list 动作, 其余选项映射为 install 动作
    if [ "$LEGACY_DEVTOOLS" = true ] && [ $# -gt 0 ]; then
        case "$1" in
            --list) COMMAND_ARGS=(list) ;;
            -h|--help)
                # 帮助由旧脚本从文件头注释渲染 (含「依赖」「说明」两节)
                exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/install_devtools.sh" --help
                ;;
            --tui) ;;
            *) COMMAND_ARGS=(install "$@") ;;
        esac
    fi
}

# 在准备仓库前检查命令
COMMAND=""
COMMAND_ARGS=()
REPAIR_TARGET=""
LEGACY_DEVTOOLS=false

detect_command "$@"

ROOT_DIR=""
if [ -f "${BASH_SOURCE[0]:-}" ]; then
    ROOT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
else
    # curl | bash 的 stdin 是脚本流; 菜单和子安装器必须从控制终端读取按键。
    # 没有控制终端时, 显式子命令仍可用于脚本/CI。
    if [ -t 1 ] && { true </dev/tty; } 2>/dev/null; then
        INTERACTIVE_STDIN=true
    else
        INTERACTIVE_STDIN=false
    fi
    case "${1:-menu}" in
        menu|--tui) $INTERACTIVE_STDIN || die "菜单需要交互式终端; 请指定命令 (查看 --help)" ;;
    esac
    JOE_INSTALL_DIR="${JOE_INSTALL_DIR:-$HOME/.joe}"
    if [ ! -d "$JOE_INSTALL_DIR/.git" ]; then
        [ ! -e "$JOE_INSTALL_DIR" ] || die "$JOE_INSTALL_DIR 已存在且不是 joe Git 仓库, 请设置 JOE_INSTALL_DIR"
        command -v git >/dev/null 2>&1 || die "一行安装需要 git"
        printf '克隆 joe 到 %s...\n' "$JOE_INSTALL_DIR"
        git clone --depth=1 https://github.com/IotaHydrae/joe.git "$JOE_INSTALL_DIR"
    fi
    [ -f "$JOE_INSTALL_DIR/install.sh" ] || die "仓库缺少 install.sh: $JOE_INSTALL_DIR"
    if $INTERACTIVE_STDIN; then
        exec bash "$JOE_INSTALL_DIR/install.sh" "$@" </dev/tty
    fi
    exec bash "$JOE_INSTALL_DIR/install.sh" "$@"
fi


SCRIPTS_DIR="$ROOT_DIR/scripts"
COMMANDS_DIR="$SCRIPTS_DIR/commands"
UI_DIR="$SCRIPTS_DIR/ui"

# 加载库函数
load_libs() {
    local lib_dir="$SCRIPTS_DIR/lib"
    for lib in distro.sh github.sh ghostty.sh node.sh deps.sh; do
        if [ -f "$lib_dir/$lib" ]; then
            # shellcheck disable=SC1090
            . "$lib_dir/$lib"
        fi
    done
}

# 命令路由
route_command() {
    case "$COMMAND" in
        menu)
            # 主菜单实现在 scripts/ui/menu_main.sh, 菜单项一律回到本路由执行
            [ -t 0 ] && [ -t 1 ] || die "菜单需要交互式终端; 请指定命令 (查看 --help)"
            [ -f "$UI_DIR/menu_main.sh" ] || die "缺少主菜单实现: $UI_DIR/menu_main.sh"
            exec bash "$UI_DIR/menu_main.sh"
            ;;

        shell)
            # Shell 环境安装
            local script="$SCRIPTS_DIR/install_shell.sh"
            [ -f "$script" ] || die "脚本不存在: $script"
            exec bash "$script" "${COMMAND_ARGS[@]}"
            ;;

        tools)
            # 开发工具管理
            if [ -f "$COMMANDS_DIR/tools.sh" ]; then
                bash "$COMMANDS_DIR/tools.sh" "${COMMAND_ARGS[@]}"
            else
                # 回退到旧脚本
                exec bash "$SCRIPTS_DIR/install_devtools.sh" "${COMMAND_ARGS[@]}"
            fi
            ;;

        fonts)
            exec bash "$COMMANDS_DIR/fonts.sh" "${COMMAND_ARGS[@]}"
            ;;

        mcp)
            # MCP 服务器管理
            if [ -f "$COMMANDS_DIR/mcp.sh" ]; then
                bash "$COMMANDS_DIR/mcp.sh" "${COMMAND_ARGS[@]}"
            else
                exec bash "$SCRIPTS_DIR/install_mcp_servers.sh" "${COMMAND_ARGS[@]}"
            fi
            ;;

        skills)
            # Skills 管理
            if [ -f "$COMMANDS_DIR/skills.sh" ]; then
                bash "$COMMANDS_DIR/skills.sh" "${COMMAND_ARGS[@]}"
            else
                exec bash "$SCRIPTS_DIR/install_skills.sh" "${COMMAND_ARGS[@]}"
            fi
            ;;

        config)
            # 配置管理
            exec bash "$SCRIPTS_DIR/sync-configs.sh" "${COMMAND_ARGS[@]}"
            ;;

        doctor)
            # 环境检查
            exec bash "$SCRIPTS_DIR/doctor.sh" "${COMMAND_ARGS[@]}"
            ;;

        status)
            # 显示所有组件状态
            if [ -f "$COMMANDS_DIR/status.sh" ]; then
                bash "$COMMANDS_DIR/status.sh" "${COMMAND_ARGS[@]}"
            else
                info "未找到 status 实现, 请使用以下命令查看："
                printf "  ./install.sh tools list\n"
                printf "  ./install.sh mcp list\n"
                printf "  ./install.sh doctor\n"
            fi
            ;;

        update)
            # 更新工具
            exec bash "$SCRIPTS_DIR/update-all.sh" "${COMMAND_ARGS[@]}"
            ;;

        repair)
            # 修复特定组件
            case "$REPAIR_TARGET" in
                ghostty)
                    exec bash "$SCRIPTS_DIR/repair_ghostty.sh" "${COMMAND_ARGS[@]}"
                    ;;
                *)
                    die "未知的修复目标: $REPAIR_TARGET"
                    ;;
            esac
            ;;

        quick-start)
            # 新手引导/一键部署 (旧名 bootstrap, 仍映射到这里)
            [ -f "$COMMANDS_DIR/quickstart.sh" ] || die "缺少 quick-start 实现: $COMMANDS_DIR/quickstart.sh"
            exec bash "$COMMANDS_DIR/quickstart.sh" "${COMMAND_ARGS[@]}"
            ;;

        install-all)
            # 全部安装（带确认）; 读不到输入 (非交互) 时按取消处理
            printf '\033[1;33m警告:\033[0m 将安装所有组件（shell/工具/MCP/技能），这可能需要较长时间。\n'
            confirm=""
            if ! read -p "确认继续？[y/N] " -r confirm; then
                info "已取消 (未读取到确认输入); 非交互环境请直接使用 ./install.sh quick-start --yes"
                exit 0
            fi
            if [[ $confirm =~ ^[Yy]$ ]]; then
                exec bash "$COMMANDS_DIR/quickstart.sh" --yes
            fi
            info "已取消"
            ;;

        *)
            die "未实现的命令: $COMMAND"
            ;;
    esac
}


# 主入口
load_libs
route_command
