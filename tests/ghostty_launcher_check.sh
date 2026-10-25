#!/usr/bin/env bash
# 只模拟窗口列表和 Cinnamon 设置; 不连接本机桌面或启动真实 Ghostty。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOCUS_BOX="$(mktemp -d)"
trap 'rm -rf -- "$FOCUS_BOX"' EXIT
FOCUS_HOME="$FOCUS_BOX/home with ' quote"
FOCUS_BIN="$FOCUS_BOX/bin"
mkdir -p "$FOCUS_HOME" "$FOCUS_BIN"
export FOCUS_BOX

cat > "$FOCUS_BIN/wmctrl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FOCUS_BOX/wm.log"
case "$1" in
    -lx)
        printf '%s\n' '0x010 0 ghostty.com.mitchellh.ghostty host old window'
        if [[ -e "$FOCUS_BOX/launched" ]]; then
            printf '%s\n' '0x020 0 other.application host new unrelated window'
            if [[ ${FOCUS_NO_WINDOW:-false} != true ]]; then
                printf '%s\n' '0x030 0 ghostty.com.mitchellh.ghostty host new terminal'
            fi
        fi
        ;;
    -ia) printf '%s\n' "$2" >> "$FOCUS_BOX/activated" ;;
    *) exit 99 ;;
esac
STUB
cat > "$FOCUS_BIN/xprop" <<'STUB'
#!/usr/bin/env bash
# 模拟 WM 拒绝前几次请求, 即使 wmctrl 每次都返回 0。
count=0
[[ ! -f "$FOCUS_BOX/activated" ]] || count=$(wc -l < "$FOCUS_BOX/activated")
if ((count > ${FOCUS_REJECT_BEFORE:-0})); then
    printf '_NET_ACTIVE_WINDOW(WINDOW): window id # 0x30\n'
else
    printf '_NET_ACTIVE_WINDOW(WINDOW): window id # 0x10\n'
fi
STUB
cat > "$FOCUS_BIN/ghostty" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FOCUS_BOX/arguments"
printf 'started\n' > "$FOCUS_BOX/launched"
sleep 0.3
STUB
chmod +x "$FOCUS_BIN"/*

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reset_launch() { rm -f "$FOCUS_BOX/activated" "$FOCUS_BOX/launched" "$FOCUS_BOX/arguments" "$FOCUS_BOX/wm.log"; }
run_launcher() {
    env HOME="$FOCUS_HOME" PATH="$FOCUS_BIN:$PATH" GHOSTTY_BIN="$FOCUS_BIN/ghostty" \
        XDG_SESSION_TYPE="$1" bash "$ROOT_DIR/scripts/launch_ghostty.sh" "${@:2}"
}

(
    cd "$FOCUS_HOME"
    run_launcher x11 --title='a title with spaces' -e printf '%s' "it's fine"
)
for ((attempt = 0; attempt < 30; attempt++)); do
    [[ ! -e "$FOCUS_BOX/activated" ]] || break
    sleep 0.1
done
[[ -f "$FOCUS_BOX/activated" && $(cat "$FOCUS_BOX/activated") == 0x030 ]] || fail "未仅激活新增 Ghostty 窗口"
printf '%s\n' --gtk-single-instance=false "--working-directory=$FOCUS_HOME" \
    '--title=a title with spaces' -e printf '%s' "it's fine" > "$FOCUS_BOX/expected-args"
cmp -s "$FOCUS_BOX/arguments" "$FOCUS_BOX/expected-args" || fail "启动器改变了工作目录或参数边界"
sleep 0.2

reset_launch
FOCUS_REJECT_BEFORE=2 run_launcher x11
for ((attempt = 0; attempt < 30; attempt++)); do
    [[ ! -e "$FOCUS_BOX/activated" ]] || [[ $(wc -l < "$FOCUS_BOX/activated") -lt 3 ]] || break
    sleep 0.1
done
[[ -f "$FOCUS_BOX/activated" && $(wc -l < "$FOCUS_BOX/activated") -eq 3 ]] || fail "激活请求被拒绝后没有重试并确认焦点"
[[ $(sort -u "$FOCUS_BOX/activated") == 0x030 ]] || fail "重试时激活了其他窗口"
sleep 0.3
[[ $(wc -l < "$FOCUS_BOX/activated") -eq 3 ]] || fail "确认焦点后仍继续激活窗口"

reset_launch
run_launcher wayland
[[ -e "$FOCUS_BOX/launched" && ! -e "$FOCUS_BOX/wm.log" ]] || fail "Wayland 使用了 X11 焦点工具"
reset_launch
run_launcher x11 +show-face '--string=ABC'
[[ -e "$FOCUS_BOX/launched" && ! -e "$FOCUS_BOX/wm.log" ]] || fail "字体诊断意外操作窗口焦点"

# 没有 wmctrl 的系统也能正常启动, 不要求额外软件包。
reset_launch
mkdir -p "$FOCUS_BOX/minimal-bin"
ln -s "$(command -v bash)" "$FOCUS_BOX/minimal-bin/bash"
ln -s "$(command -v sleep)" "$FOCUS_BOX/minimal-bin/sleep"
env HOME="$FOCUS_HOME" PATH="$FOCUS_BOX/minimal-bin" GHOSTTY_BIN="$FOCUS_BIN/ghostty" \
    XDG_SESSION_TYPE=x11 bash "$ROOT_DIR/scripts/launch_ghostty.sh"
[[ -e "$FOCUS_BOX/launched" && ! -e "$FOCUS_BOX/wm.log" ]] || fail "缺少 wmctrl 时不能正常启动"

# 即使存在旧窗口, 启动后没有新增 Ghostty 窗口也不能激活旧窗口或其他应用。
reset_launch
FOCUS_NO_WINDOW=true run_launcher x11
sleep 0.3
[[ ! -e "$FOCUS_BOX/activated" ]] || fail "没有新窗口却激活了旧窗口"
# 等待有界观察器结束, 避免下一项测试的状态被上一次观察器消费。
sleep 6

cat > "$FOCUS_BIN/gsettings" <<'STUB'
#!/usr/bin/env bash
case "$1:${2:-}:${3:-}" in
    list-schemas:*) printf '%s\n' org.cinnamon.desktop.keybindings ;;
    get:org.cinnamon.desktop.keybindings:custom-list) cat "$FOCUS_BOX/custom-list" ;;
    get:*custom0/:command) cat "$FOCUS_BOX/shortcut0" ;;
    get:*custom1/:command) printf "'wezterm'\n" ;;
    set:*custom0/:command)
        printf "'%s'\n" "$4" > "$FOCUS_BOX/shortcut0"
        printf '%s\n' "$4" >> "$FOCUS_BOX/settings.log"
        ;;
    set:org.cinnamon.desktop.keybindings:custom-list)
        printf '%s\n' "$4" > "$FOCUS_BOX/custom-list"
        # Cinnamon 只在列表变化时重新加载命令; 单独 set command 不更新回调。
        cp "$FOCUS_BOX/shortcut0" "$FOCUS_BOX/cached-command"
        printf '%s\n' "$4" >> "$FOCUS_BOX/refresh.log"
        ;;
    *) exit 99 ;;
esac
STUB
chmod +x "$FOCUS_BIN/gsettings"
printf "'ghostty'\n" > "$FOCUS_BOX/shortcut0"
printf "'ghostty'\n" > "$FOCUS_BOX/cached-command"
printf "['custom0', 'custom1', '__dummy__']\n" > "$FOCUS_BOX/custom-list"
mkdir -p "$FOCUS_BOX/work"
run_shortcut_repair() {
    env HOME="$FOCUS_HOME" XDG_CONFIG_HOME="$FOCUS_HOME/.config" PATH="$FOCUS_BIN:$PATH" \
        bash -euo pipefail -c '. "$1"; ghostty_install_launcher "$2" "$3"; ghostty_configure_shortcuts "$3"' \
        bash "$ROOT_DIR/scripts/lib_ghostty.sh" "$FOCUS_BIN/ghostty" "$FOCUS_BOX/work"
}
run_shortcut_repair >/dev/null
[[ -x "$FOCUS_HOME/.local/bin/joe-ghostty" ]] || fail "未安装独立启动器"
printf -v expected_command '%q' "$FOCUS_HOME/.local/bin/joe-ghostty"
[[ $(cat "$FOCUS_BOX/settings.log") == "$expected_command" ]] || fail "快捷键命令未安全转义"
[[ $(cat "$FOCUS_BOX/cached-command") == "'$expected_command'" ]] || fail "Cinnamon 内存中的旧命令未刷新"
[[ $(cat "$FOCUS_BOX/custom-list") == "['custom0', 'custom1']" ]] || fail "刷新时改变了真实快捷键列表或顺序"
[[ $(find "$FOCUS_HOME/.config/ghostty" -name 'cinnamon-shortcut-custom0.bak.*' | wc -l) -eq 1 ]] || fail "快捷键迁移缺少备份"
run_shortcut_repair >/dev/null
[[ $(wc -l < "$FOCUS_BOX/settings.log") -eq 1 ]] || fail "重复修复重复修改快捷键"
[[ $(cat "$FOCUS_BOX/custom-list") == "['custom0', 'custom1', '__dummy__']" ]] || fail "已有启动器没有触发 Cinnamon 重载"

# 哨兵可能在首位、末位或是唯一条目; 刷新不能丢失真实快捷键。
refresh_inputs=("['__dummy__', 'custom0', 'custom1']" "['__dummy__']" '@as []' "['custom0']")
refresh_expected=("['custom0', 'custom1']" '[]' "['__dummy__']" "['custom0', '__dummy__']")
for index in "${!refresh_inputs[@]}"; do
    printf '%s\n' "${refresh_inputs[$index]}" > "$FOCUS_BOX/custom-list"
    env PATH="$FOCUS_BIN:$PATH" bash -euo pipefail -c '. "$1"; ghostty_refresh_shortcuts' \
        bash "$ROOT_DIR/scripts/lib_ghostty.sh"
    [[ $(cat "$FOCUS_BOX/custom-list") == "${refresh_expected[$index]}" ]] || fail "快捷键重载未正确处理哨兵位置"
done
reset_launch
env XDG_SESSION_TYPE=wayland PATH="$FOCUS_BIN:$PATH" "$FOCUS_HOME/.local/bin/joe-ghostty" -e printf 'quoted argument'
[[ -e "$FOCUS_BOX/launched" ]] || fail "含空格或单引号路径下的已安装启动器不可执行"

printf 'OK: Ghostty 新窗口焦点/参数/Wayland/诊断命令/快捷键迁移正常\n'
