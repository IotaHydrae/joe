#!/usr/bin/env bash
# joe — 统一菜单入口; 安装器与维护脚本位于 scripts/。

set -euo pipefail

usage() {
    cat <<'EOF'
用法: ./install.sh [命令] [参数...]

无参数进入主菜单, 输入编号选择操作; 回车不执行操作, q 退出。
开发工具、MCP 和 skills 的安装菜单默认不勾选任何项目。
skills 先选择技能组; low-level-dev-skills 再按分类进入勾选列表。
非交互调用须显式指定命令, 安装项须按需指定或明确使用 --all。

命令:
    shell           zsh / Oh My Zsh / Powerlevel10k 环境
    devtools        开发工具安装器 (支持 --tui / --list / --all)
    mcp             MCP 安装器 (支持 --tui / --list / --all)
    skills          skills 安装器 (支持 --category / --categories)
    doctor          环境体检
    update          更新已安装的工具
    repair-ghostty  修复 Ghostty terminfo 与桌面入口
    configs         配置备份/恢复 (list / export / import / diff)
    bootstrap       串行运行开发工具、MCP、skills 和体检
    menu, --tui     打开主菜单
    -h, --help      显示帮助

示例:
    ./install.sh shell --dry-run
    ./install.sh devtools --node
    ./install.sh mcp memory git
    ./install.sh skills --category kernel-dev --tui
    ./install.sh doctor --json
    ./install.sh update --dry-run
    ./install.sh configs export --check
    ./install.sh bootstrap --only mcp,skills

子命令帮助: ./install.sh <命令> --help
兼容原 Shell 参数: --dry-run/-n, --no-fonts, --no-config, --no-p10k,
--no-fastfetch, --no-default-plugins, --no-ghostty-ime, --clean-backups, --update/-u。
一行安装仍克隆到 ~/.joe (可设置 JOE_INSTALL_DIR), 随后进入菜单。
EOF
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

# 在准备仓库前检查命令, --help 与无效参数均不触发克隆。
case "${1:-menu}" in
    -h|--help) usage; exit 0 ;;
    shell|devtools|mcp|skills|doctor|update|repair-ghostty|configs|bootstrap|menu|--tui) ;;
    -n|--dry-run|--no-fonts|--no-config|--no-p10k|--no-fastfetch|--no-default-plugins|--no-ghostty-ime|--clean-backups|-u|--update) ;;
    *) die "未知命令: $1 (查看 --help)" ;;
esac

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

script_for() {
    case "$1" in
        shell) printf '%s/install_shell.sh\n' "$SCRIPTS_DIR" ;;
        devtools) printf '%s/install_devtools.sh\n' "$SCRIPTS_DIR" ;;
        mcp) printf '%s/install_mcp_servers.sh\n' "$SCRIPTS_DIR" ;;
        skills) printf '%s/install_skills.sh\n' "$SCRIPTS_DIR" ;;
        doctor) printf '%s/doctor.sh\n' "$SCRIPTS_DIR" ;;
        update) printf '%s/update-all.sh\n' "$SCRIPTS_DIR" ;;
        repair-ghostty) printf '%s/repair_ghostty.sh\n' "$SCRIPTS_DIR" ;;
        configs) printf '%s/sync-configs.sh\n' "$SCRIPTS_DIR" ;;
        bootstrap) printf '%s/bootstrap.sh\n' "$SCRIPTS_DIR" ;;
        *) return 1 ;;
    esac
}

run_action() {
    local command="$1" script status
    shift
    script="$(script_for "$command")"
    if [ ! -f "$script" ]; then
        printf '[ERROR] 脚本不存在: %s\n' "$script" >&2
        return 1
    fi
    if bash "$script" "$@"; then
        printf '\n操作完成, 返回菜单。\n'
    else
        status=$?
        printf '\n[ERROR] 操作失败 (退出码 %d), 可重新选择操作。\n' "$status" >&2
    fi
}

configs_menu() {
    local choice
    while true; do
        printf '\n── 配置备份与恢复 ──\n'
        printf '  1) 查看配置映射\n  2) 预览导出脱敏结果\n  3) 导出本机配置到仓库\n'
        printf '  4) 从仓库恢复配置 (备份现有文件)\n  5) 对比配置\n  b) 返回主菜单\n'
        printf '选择操作 [1-5/b]: '
        IFS= read -r choice || return 0
        case "$choice" in
            1) run_action configs list ;;
            2) run_action configs export --check ;;
            3) run_action configs export ;;
            4) run_action configs import ;;
            5) run_action configs diff ;;
            b|B|q|Q) return 0 ;;
            '') continue ;;
            *) printf '请输入有效编号或 b。\n' ;;
        esac
    done
}

main_menu() {
    [ -t 0 ] && [ -t 1 ] || die "菜单需要交互式终端; 请指定命令 (查看 --help)"
    local choice
    while true; do
        printf '\n── joe 开发环境 ──\n'
        printf '  1) Shell 环境 (zsh / Oh My Zsh / Powerlevel10k)\n'
        printf '  2) 开发工具 (按需勾选)\n  3) MCP 服务器 (按需勾选)\n'
        printf '  4) skills (技能组 / 分类子菜单)\n  5) 环境体检\n'
        printf '  6) 更新已安装工具\n  7) Ghostty 兼容修复\n'
        printf '  8) 配置备份与恢复\n  9) 全流程部署 (各阶段按需勾选)\n'
        printf '  q) 退出\n选择操作 [1-9/q]: '
        IFS= read -r choice || return 0
        case "$choice" in
            1) run_action shell ;;
            2) run_action devtools --tui ;;
            3) run_action mcp --tui ;;
            4) run_action skills --tui ;;
            5) run_action doctor ;;
            6) run_action update ;;
            7) run_action repair-ghostty ;;
            8) configs_menu ;;
            9) run_action bootstrap ;;
            q|Q|0) return 0 ;;
            '') continue ;;
            *) printf '请输入有效编号或 q。\n' ;;
        esac
    done
}

case "${1:-menu}" in
    menu|--tui)
        [ "$#" -le 1 ] || die "主菜单不接受额外参数"
        main_menu ;;
    -n|--dry-run|--no-fonts|--no-config|--no-p10k|--no-fastfetch|--no-default-plugins|--no-ghostty-ime|--clean-backups|-u|--update)
        exec bash "$SCRIPTS_DIR/install_shell.sh" "$@" ;;
    *)
        script="$(script_for "$1")"
        shift
        [ -f "$script" ] || die "脚本不存在: $script"
        exec bash "$script" "$@" ;;
esac
