#!/usr/bin/env bash
# 修复已有 Ghostty 的 terminfo、桌面入口和 Cinnamon/Nemo 工作目录。
# 用法: ./install.sh repair-ghostty [--user-only]
# 默认补齐系统 terminfo (缺失时通过 sudo 写入), 支持 sudo minicom。
# --user-only 只修复当前用户, 不使用 sudo, 不保证 sudo 下的终端程序可用。
# 不安装软件包, 不改 Ghostty 主题、字体或快捷键配置。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_ONLY=false
case "${1:-}" in
    -h|--help)
        awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
        exit 0
        ;;
    '') ;;
    --user-only) USER_ONLY=true; shift ;;
    *) printf '未知选项: %s\n' "$1" >&2; exit 1 ;;
esac
[ "$#" -eq 0 ] || { printf '不接受额外参数\n' >&2; exit 1; }

# shellcheck source=lib_ghostty.sh
. "$SCRIPT_DIR/lib_ghostty.sh"
repair_ghostty "$USER_ONLY"
