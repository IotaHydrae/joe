#!/usr/bin/env bash
# 字体命令路由; 清单和安装逻辑由字体库与安装器维护。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONTS_SCRIPT="${FONTS_SCRIPT:-$SCRIPT_DIR/../install_fonts.sh}"

forward() {
    if [[ ! -f $FONTS_SCRIPT ]]; then
        printf '错误: 找不到字体安装器: %s\n' "$FONTS_SCRIPT" >&2
        exit 1
    fi
    exec bash "$FONTS_SCRIPT" "$@"
}

ACTION="${1:-}"
case "$ACTION" in
    '')
        if [[ ! -t 0 || ! -t 1 ]]; then
            printf '字体菜单需要交互式终端; 请用: fonts list 或 fonts install <字体...>\n' >&2
            exit 1
        fi
        exec bash "$SCRIPT_DIR/../ui/menu_main.sh" fonts
        ;;
    list|status) shift; forward --list "$@" ;;
    install) shift; forward "$@" ;;
    -h|--help) forward --help ;;
    *)
        printf '错误: 未知字体动作: %s (查看 fonts --help)\n' "$ACTION" >&2
        exit 1
        ;;
esac
