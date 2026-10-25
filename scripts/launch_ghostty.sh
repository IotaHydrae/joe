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
            window_id=''
            focus_attempts=0
            for ((attempt = 0; attempt < 50; attempt++)); do
                current_windows=$(wmctrl -lx 2>/dev/null) || exit 0
                if [[ -z $window_id ]]; then
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
                        # 被 wmctrl 列出时窗口可能仍在映射, 快捷键也可能仍持有键盘抓取。
                        sleep 0.15
                    fi
                elif ! awk -v target="$window_id" '$1 == target { found = 1 } END { exit !found }' <<< "$current_windows"; then
                    exit 0
                fi
                if [[ -n $window_id ]]; then
                    wmctrl -ia "$window_id" >/dev/null 2>&1 || true
                    focus_attempts=$((focus_attempts + 1))
                    sleep 0.1
                    if command -v xprop >/dev/null 2>&1; then
                        active_window=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null) || exit 0
                        active_window="${active_window##* }"
                        # wmctrl 返回成功仅表示请求已发送; 确认 WM 实际接受了请求。
                        if [[ $active_window =~ ^0x[0-9a-fA-F]+$ ]] \
                            && ((active_window == window_id)); then
                            exit 0
                        fi
                    elif ((focus_attempts >= 3)); then
                        # 缺少 xprop 时无法确认, 仅作短暂重试, 不持续激活窗口。
                        exit 0
                    fi
                    continue
                fi
                sleep 0.1
            done
        ) </dev/null >/dev/null 2>&1 &
    fi
fi

# 每个新窗口重新加载 GTK 输入法模块, 避免复用安装输入法之前的旧进程。
# Nemo 只改变 cwd, 仍显式传入工作目录。
exec "$GHOSTTY_BIN" --gtk-single-instance=false --working-directory="$(pwd -P)" "$@"
