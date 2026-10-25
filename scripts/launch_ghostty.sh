#!/usr/bin/env bash
# 已安装的启动器会在本脚本前写入 Ghostty 的实际路径, 不依赖仓库运行。
set -euo pipefail

GHOSTTY_BIN="${GHOSTTY_BIN:-ghostty}"

# X11 的部分桌面不会激活快捷键打开的新窗口。只跟踪本次新增窗口,
# 不激活已有窗口; Wayland 和缺少 wmctrl 时保留 Ghostty 的原生行为。
focus_window=true
for arg in "$@"; do
    case "$arg" in
        +*|-h|--help|--version) focus_window=false ;;
        -e) break ;;
    esac
done
if $focus_window && [[ ${XDG_SESSION_TYPE:-} == x11 \
    || ( -z ${XDG_SESSION_TYPE:-} && -n ${DISPLAY:-} ) ]] \
    && command -v wmctrl >/dev/null 2>&1; then
    if previous_windows=$(wmctrl -lx 2>/dev/null | awk '{print $1}'); then
        (
            for ((attempt = 0; attempt < 50; attempt++)); do
                current_windows=$(wmctrl -lx 2>/dev/null) || exit 0
                window_id=$(awk -v previous="$previous_windows" '
                    BEGIN {
                        count = split(previous, rows, "\n")
                        for (i = 1; i <= count; i++) {
                            seen[rows[i]] = 1
                        }
                    }
                    !seen[$1] && tolower($3) ~ /[.]com[.]mitchellh[.]ghostty$/ {
                        print $1
                        exit
                    }
                ' <<< "$current_windows")
                if [[ -n $window_id ]]; then
                    wmctrl -ia "$window_id" >/dev/null 2>&1 || true
                    exit 0
                fi
                sleep 0.1
            done
        ) </dev/null >/dev/null 2>&1 &
    fi
fi

# Nemo 只改变 cwd, 单实例 Ghostty 必须显式收到该目录。
exec "$GHOSTTY_BIN" --gtk-single-instance=true --working-directory="$(pwd -P)" "$@"
