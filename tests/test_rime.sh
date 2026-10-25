#!/usr/bin/env bash
# Rime 离线回归: 仅使用 /tmp 仓库副本、临时 HOME 和命令 stub。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RIME_BOX="$(mktemp -d)"
trap 'rm -rf -- "$RIME_BOX"' EXIT
RIME_REPO="$RIME_BOX/repo with ' quote"
RIME_BIN="$RIME_BOX/bin"
RIME_LOG="$RIME_BOX/commands.log"
RIME_FORBIDDEN="$RIME_BOX/forbidden.log"
RIME_FIXTURE="$RIME_BOX/fixture"
mkdir -p "$RIME_REPO" "$RIME_BIN" "$RIME_FIXTURE"
cp -a "$ROOT_DIR/scripts" "$RIME_REPO/scripts"
printf 'schema_list:\n  - schema: rime_ice\n' > "$RIME_FIXTURE/default.yaml"
printf 'schema:\n  schema_id: rime_ice\n' > "$RIME_FIXTURE/rime_ice.schema.yaml"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

# 所有可能访问桌面、网络或软件包管理器的命令都必须经过 stub。
cat > "$RIME_BIN/rime_deployer" <<'STUB'
#!/usr/bin/env bash
printf 'rime_deployer' >> "$RIME_TEST_LOG"
printf '|%s' "$@" >> "$RIME_TEST_LOG"
printf '\n' >> "$RIME_TEST_LOG"
if [[ ${RIME_TEST_DEPLOY_FAIL:-0} == 1 ]]; then
    printf 'STUB_COMPILE_FAILURE\n' >&2
    exit 31
fi
[[ ${1:-} == --build && -n ${2:-} ]] || exit 99
[[ ${RIME_TEST_DEPLOY_EMPTY:-0} == 0 ]] || exit 0
mkdir -p "$2/build"
printf 'compiled schema\n' > "$2/build/rime_ice.schema.yaml"
printf 'compiled table\n' > "$2/build/rime_ice.table.bin"
printf 'compiled prism\n' > "$2/build/rime_ice.prism.bin"
STUB
cat > "$RIME_BIN/im-config" <<'STUB'
#!/usr/bin/env bash
printf 'im-config|%s\n' "$*" >> "$RIME_TEST_LOG"
[[ $* == '-n fcitx5' ]] || exit 99
printf '# im-config test\nrun_im fcitx5\n' > "$HOME/.xinputrc"
STUB
cat > "$RIME_BIN/id" <<'STUB'
#!/usr/bin/env bash
if [[ $* == -u ]]; then
    printf '1000\n'
else
    /usr/bin/id "$@"
fi
STUB
cat > "$RIME_BIN/sudo" <<'STUB'
#!/usr/bin/env bash
printf 'sudo' >> "$RIME_TEST_LOG"
printf '|%s' "$@" >> "$RIME_TEST_LOG"
printf '\n' >> "$RIME_TEST_LOG"
STUB
cat > "$RIME_BIN/git" <<'STUB'
#!/usr/bin/env bash
printf 'git' >> "$RIME_TEST_LOG"
printf '|%s' "$@" >> "$RIME_TEST_LOG"
printf '\n' >> "$RIME_TEST_LOG"
[[ ${RIME_TEST_CLONE_FAIL:-0} == 0 ]] || exit 32
destination="${!#}"
mkdir -p "$destination"
cp -a "$RIME_TEST_FIXTURE/." "$destination/"
STUB
for command in curl wget apt-get apt dnf pacman zypper pkill killall; do
    cat > "$RIME_BIN/$command" <<'STUB'
#!/usr/bin/env bash
printf 'FORBIDDEN|%s|%s\n' "${0##*/}" "$*" >> "$RIME_TEST_LOG"
printf '%s|%s\n' "${0##*/}" "$*" >> "$RIME_TEST_FORBIDDEN"
exit 99
STUB
done
cat > "$RIME_BIN/pgrep" <<'STUB'
#!/usr/bin/env bash
printf 'pgrep|%s\n' "$*" >> "$RIME_TEST_LOG"
name="${!#}"
[[ ${RIME_TEST_SESSION:-0} == 1 && -f "$RIME_TEST_STATE/$name" ]] || exit 1
printf '12345\n'
STUB
cat > "$RIME_BIN/fcitx5-remote" <<'STUB'
#!/usr/bin/env bash
printf 'fcitx5-remote|%s\n' "$*" >> "$RIME_TEST_LOG"
if [[ ${1:-} == -e ]]; then
    rm -f -- "$RIME_TEST_STATE/fcitx5"
else
    printf '2\n'
fi
STUB
cat > "$RIME_BIN/gdbus" <<'STUB'
#!/usr/bin/env bash
printf 'gdbus|%s\n' "$*" >> "$RIME_TEST_LOG"
[[ $* == *org.fcitx.Fcitx.InputMethod.Exit* ]] || exit 99
rm -f -- "$RIME_TEST_STATE/fcitx"
printf '()\n'
STUB
cat > "$RIME_BIN/fcitx5" <<'STUB'
#!/usr/bin/env bash
printf 'fcitx5|%s\n' "$*" >> "$RIME_TEST_LOG"
[[ $* == -rd ]] || exit 99
touch "$RIME_TEST_STATE/fcitx5"
STUB
chmod +x "$RIME_BIN"/*

cat > "$RIME_BOX/runner.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
info() { printf '%s\n' "$*"; }
ok() { printf 'SUCCESS|%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die() { printf '%s\n' "$*" >&2; exit 1; }
TMP_FILES=()
cleanup_tmp() {
    if [[ ${#TMP_FILES[@]} -gt 0 ]]; then
        rm -rf -- "${TMP_FILES[@]}"
    fi
}
trap cleanup_tmp EXIT
make_tmp() {
    local __var="$1" __tmp
    __tmp="$(mktemp)"
    TMP_FILES+=("$__tmp")
    printf -v "$__var" '%s' "$__tmp"
}
SCRIPT_DIR="$RIME_TEST_REPO/scripts"
PM=apt
# 在所有宿主机上覆盖旧版 remote 的可用性, 只测试受控的 DBus Exit 路径。
command() {
    if [[ ${RIME_TEST_SESSION:-0} == 1 && $* == '-v fcitx-remote' ]]; then
        return 1
    fi
    if [[ ${RIME_TEST_MISSING_DEPLOY:-0} == 1 && $* == '-v rime_deployer' ]]; then
        return 1
    fi
    builtin command "$@"
}
case "$1" in
    component)
        . "$SCRIPT_DIR/components/rime.sh"
        component_rime_install
        ;;
    repair)
        . "$SCRIPT_DIR/lib/rime.sh"
        rime_repair_user_config
        ;;
    *) exit 99 ;;
esac
RUNNER

new_home() {
    RIME_HOME="$RIME_BOX/$1 home with ' quote"
    RIME_DATA="$RIME_HOME/.local/share/fcitx5/rime"
    RIME_CONFIG="$RIME_HOME/.config/fcitx5"
    mkdir -p "$RIME_HOME" "$RIME_HOME/tmp"
    RIME_STATE="$RIME_HOME/session-state"
    mkdir -p "$RIME_STATE"
    : > "$RIME_LOG"
}

seed_data() {
    mkdir -p "$RIME_DATA"
    cp -a "$RIME_FIXTURE/." "$RIME_DATA/"
    printf 'personal dictionary\n' > "$RIME_DATA/personal.userdb.txt"
}

run_rime() {
    env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
        HOME="$RIME_HOME" XDG_CONFIG_HOME="$RIME_HOME/.config" \
        XDG_DATA_HOME="$RIME_HOME/.local/share" TMPDIR="$RIME_HOME/tmp" \
        PATH="$RIME_BIN:$PATH" RIME_TEST_LOG="$RIME_LOG" \
        RIME_TEST_FORBIDDEN="$RIME_FORBIDDEN" \
        DISPLAY="${SESSION_DISPLAY:-}" RIME_TEST_SESSION="${SESSION_TEST:-0}" RIME_TEST_STATE="$RIME_STATE" \
        RIME_TEST_FIXTURE="$RIME_FIXTURE" RIME_TEST_REPO="$RIME_REPO" \
        RIME_TEST_DEPLOY_FAIL="${DEPLOY_FAIL:-0}" RIME_TEST_CLONE_FAIL="${CLONE_FAIL:-0}" \
        RIME_TEST_DEPLOY_EMPTY="${DEPLOY_EMPTY:-0}" RIME_TEST_MISSING_DEPLOY="${MISSING_DEPLOY:-0}" \
        bash "$RIME_BOX/runner.sh" "$@"
}

# 已安装的用户重跑仍修复配置, 不覆盖其他输入法、快捷键和个人词库。
new_home existing
seed_data
mkdir -p "$RIME_CONFIG" "$RIME_HOME/.config/environment.d" "$RIME_HOME/.local/share/rime"
printf 'other Rime frontend data\n' > "$RIME_HOME/.local/share/rime/keep.txt"
cat > "$RIME_CONFIG/profile" <<'PROFILE'
[Groups/0]
Name=Personal
Default Layout=us
DefaultIM=pinyin
CustomField=keep me

[Groups/0/Items/0]
Name=keyboard-us

[Groups/0/Items/3]
Name=pinyin

[Groups/1]
Name=Other
Default Layout=de
DefaultIM=keyboard-de

[Groups/1/Items/0]
Name=keyboard-de

[GroupOrder]
0=Personal
1=Other
PROFILE
cat > "$RIME_CONFIG/config" <<'CONFIG'
[Hotkey]
EnumerateWithTriggerKeys=True

[Hotkey/TriggerKeys]
0=Control+space
3=Super+space

[Behavior]
ShareInputState=All
CONFIG
cat > "$RIME_HOME/.config/environment.d/im.conf" <<'ENV'
# personal environment
MY_PERSONAL_VARIABLE=keep_me
GTK_IM_MODULE=fcitx
QT_IM_MODULE=ibus
XMODIFIERS=@im=ibus
ENV
printf 'run_im fcitx\n' > "$RIME_HOME/.xinputrc"
cp "$RIME_CONFIG/profile" "$RIME_BOX/original-profile"
run_rime component > "$RIME_BOX/existing.out" 2>&1 || fail "已安装环境修复失败: $(cat "$RIME_BOX/existing.out")"
[[ $(cat "$RIME_DATA/personal.userdb.txt") == 'personal dictionary' ]] || fail "个人词库被覆盖"
[[ $(cat "$RIME_HOME/.local/share/rime/keep.txt") == 'other Rime frontend data' ]] || fail "其他 Rime 前端目录被覆盖"
[[ ! -e "$RIME_HOME/.local/share/rime/rime" ]] || fail "在已有目录内错误创建了 Rime 链接"
for text in 'Name=Personal' 'CustomField=keep me' 'Name=pinyin' 'Name=Other' 'Name=keyboard-de' '1=Other' 'DefaultIM=rime'; do
    grep -qxF "$text" "$RIME_CONFIG/profile" || fail "配置迁移丢失字段: $text"
done
grep -q '^Name=rime$' "$RIME_CONFIG/profile" || fail "输入法组未加入 Rime"
for text in '0=Control+space' '3=Super+space' 'ShareInputState=All'; do
    grep -qxF "$text" "$RIME_CONFIG/config" || fail "快捷键配置丢失字段: $text"
done
python3 - "$RIME_CONFIG/config" <<'PY'
import configparser, sys
config = configparser.ConfigParser(interpolation=None, strict=True)
config.read(sys.argv[1])
keys = list(config['Hotkey/TriggerKeys'].values())
assert keys.count('Alt+Shift_L') == 1, keys
assert keys.count('Shift+Alt_L') == 1, keys
PY
for text in 'MY_PERSONAL_VARIABLE=keep_me' 'GTK_IM_MODULE=fcitx5' 'QT_IM_MODULE=fcitx' 'XMODIFIERS=@im=fcitx'; do
    grep -qxF "$text" "$RIME_HOME/.config/environment.d/im.conf" || fail "环境变量合并不正确: $text"
done
grep -qx 'run_im fcitx5' "$RIME_HOME/.xinputrc" || fail "未选择 Fcitx 5 登录会话"
backup="$(find "$RIME_HOME" -name '.xinputrc.bak.*' -print -quit)"
[[ -n $backup && $(cat "$backup") == 'run_im fcitx' ]] || fail "旧登录配置未备份"
backup="$(find "$RIME_CONFIG" -name 'profile.bak.*' -print -quit)"
[[ -n $backup ]] && cmp -s "$backup" "$RIME_BOX/original-profile" || fail "原输入法列表未完整备份"
for asset in schema.yaml table.bin prism.bin; do
    [[ -s "$RIME_DATA/build/rime_ice.$asset" ]] || fail "没有生成编译产物: $asset"
done
grep -q '^rime_deployer|--build|' "$RIME_LOG" || fail "重跑安装跳过了词库部署"
grep -q 'librime-plugin-lua' "$RIME_LOG" || fail "apt 依赖缺少雾凇 Lua 插件"
grep -q 'fcitx5-frontend-gtk4' "$RIME_LOG" || fail "apt 依赖缺少 Ghostty GTK4 前端"
if grep -q '^git|' "$RIME_LOG"; then
    fail "已有完整词库仍尝试下载或替换"
fi

# 重复修复不追加配置、不产生重复备份。
cp "$RIME_CONFIG/profile" "$RIME_BOX/repaired-profile"
cp "$RIME_CONFIG/config" "$RIME_BOX/repaired-config"
cp "$RIME_HOME/.config/environment.d/im.conf" "$RIME_BOX/repaired-env"
backups_before="$(find "$RIME_HOME" -name '*.bak.*' | wc -l)"
run_rime repair > "$RIME_BOX/repeat.out" 2>&1 || fail "重复修复失败: $(cat "$RIME_BOX/repeat.out")"
cmp -s "$RIME_CONFIG/profile" "$RIME_BOX/repaired-profile" || fail "重复修复改变输入法列表"
cmp -s "$RIME_CONFIG/config" "$RIME_BOX/repaired-config" || fail "重复修复追加重复快捷键"
cmp -s "$RIME_HOME/.config/environment.d/im.conf" "$RIME_BOX/repaired-env" || fail "重复修复改变环境变量"
[[ $(find "$RIME_HOME" -name '*.bak.*' | wc -l) -eq $backups_before ]] || fail "重复修复为未变化配置创建备份"

# 同秒连续修改登录配置时, 不覆盖备份且只保留最近五份。
for version in 1 2 3 4 5 6 7; do
    printf '# old login %s\nrun_im fcitx\n' "$version" > "$RIME_HOME/.xinputrc"
    run_rime repair > "$RIME_BOX/backup.out" 2>&1 || fail "登录配置备份失败: $(cat "$RIME_BOX/backup.out")"
done
[[ $(find "$RIME_HOME" -maxdepth 1 -name '.xinputrc.bak.*' | wc -l) -eq 5 ]] || fail "登录配置备份未保留最近五份"
while IFS= read -r backup; do
    grep -q '^# old login [3-7]$' "$backup" || fail "同秒备份内容丢失或清理顺序错误"
done < <(find "$RIME_HOME" -maxdepth 1 -name '.xinputrc.bak.*')

# 用户的配置符号链接保留, 修改其目标。
new_home linked
seed_data
mkdir -p "$RIME_CONFIG" "$RIME_HOME/linked" "$RIME_HOME/.config/environment.d"
printf '[Behavior]\nShareInputState=All\n' > "$RIME_HOME/linked/config"
ln -s "$RIME_HOME/linked/config" "$RIME_CONFIG/config"
printf 'PERSONAL=preserved\nGTK_IM_MODULE=fcitx\n' > "$RIME_HOME/linked/im.conf"
ln -s "$RIME_HOME/linked/im.conf" "$RIME_HOME/.config/environment.d/im.conf"
run_rime repair > "$RIME_BOX/linked.out" 2>&1 || fail "链接配置修复失败: $(cat "$RIME_BOX/linked.out")"
[[ -L "$RIME_CONFIG/config" && -L "$RIME_HOME/.config/environment.d/im.conf" ]] || fail "用户配置符号链接被拆掉"
grep -qx 'ShareInputState=All' "$RIME_HOME/linked/config" || fail "链接目标的个人配置丢失"
grep -qx 'GTK_IM_MODULE=fcitx5' "$RIME_HOME/linked/im.conf" || fail "环境变量链接目标未更新"
[[ $(find "$RIME_HOME/linked" -name '*.bak.*' | wc -l) -eq 2 ]] || fail "链接目标未备份"

# 编译失败须保留错误、返回失败, 并保留源词库。
new_home deploy-failure
seed_data
DEPLOY_FAIL=1
if run_rime component > "$RIME_BOX/deploy-failure.out" 2>&1; then
    fail "词库编译失败仍报告安装成功"
fi
unset DEPLOY_FAIL
grep -q 'STUB_COMPILE_FAILURE' "$RIME_BOX/deploy-failure.out" || fail "编译错误被隐藏"
[[ $(cat "$RIME_DATA/personal.userdb.txt") == 'personal dictionary' ]] || fail "编译失败丢失个人词库"
if grep -q '^SUCCESS|' "$RIME_BOX/deploy-failure.out"; then
    fail "编译失败仍显示安装成功消息"
fi

# 缺少部署工具或编译器未生成词典时, 不能认定已安装。
new_home missing-deployer
seed_data
MISSING_DEPLOY=1
if run_rime repair > "$RIME_BOX/missing-deployer.out" 2>&1; then
    fail "缺少词库部署工具仍报告成功"
fi
unset MISSING_DEPLOY
new_home empty-build
seed_data
DEPLOY_EMPTY=1
if run_rime repair > "$RIME_BOX/empty-build.out" 2>&1; then
    fail "编译器未生成词库仍报告成功"
fi
unset DEPLOY_EMPTY

# 不完整的旧数据目录必须原样保留, 由用户决定如何处理。
new_home incomplete
mkdir -p "$RIME_DATA"
printf 'valuable local data\n' > "$RIME_DATA/personal.userdb.txt"
if run_rime component > "$RIME_BOX/incomplete.out" 2>&1; then
    fail "不完整的旧词库被静默替换"
fi
[[ $(cat "$RIME_DATA/personal.userdb.txt") == 'valuable local data' ]] || fail "不完整目录中的个人数据丢失"
[[ $(find "$RIME_DATA" -type f | wc -l) -eq 1 ]] || fail "不完整目录被修改"
if grep -q '^git|' "$RIME_LOG"; then
    fail "不完整旧目录仍被拉取覆盖"
fi

# 下载失败不能留下半个安装; 新安装则从随机暂存目录部署。
new_home clone-failure
CLONE_FAIL=1
if run_rime component > "$RIME_BOX/clone-failure.out" 2>&1; then
    fail "词库下载失败仍报告安装成功"
fi
unset CLONE_FAIL
[[ ! -e "$RIME_DATA" ]] || fail "下载失败留下半个词库目录"
[[ -z $(find "$RIME_HOME/tmp" -mindepth 1 -print -quit) ]] || fail "下载失败留下临时文件"

new_home fresh
run_rime component > "$RIME_BOX/fresh.out" 2>&1 || fail "首次离线安装失败: $(cat "$RIME_BOX/fresh.out")"
[[ -s "$RIME_DATA/build/rime_ice.table.bin" ]] || fail "首次安装没有部署词库"
grep -q '^git|' "$RIME_LOG" || fail "首次安装未获取词库"
if grep '^git|' "$RIME_LOG" | grep -qF "|$RIME_DATA"; then
    fail "直接向最终用户目录克隆词库"
fi
[[ -z $(find "$RIME_HOME/tmp" -mindepth 1 -print -quit) ]] || fail "安装完成后留下临时文件"

# 模拟双后台的当前桌面会话: 精确按用户停止旧 daemon, 编译后重启 Fcitx 5。
new_home session
seed_data
touch "$RIME_STATE/fcitx" "$RIME_STATE/fcitx5"
SESSION_TEST=1
SESSION_DISPLAY=:987
run_rime repair > "$RIME_BOX/session.out" 2>&1 || fail "模拟双后台会话修复失败: $(cat "$RIME_BOX/session.out")"
unset SESSION_TEST SESSION_DISPLAY
[[ ! -e "$RIME_STATE/fcitx" && -e "$RIME_STATE/fcitx5" ]] || fail "旧 daemon 未停止或 Fcitx 5 未启动"
python3 - "$RIME_LOG" <<'PY'
from pathlib import Path
import sys
lines = Path(sys.argv[1]).read_text().splitlines()
stop5 = next(i for i, line in enumerate(lines) if line == 'fcitx5-remote|-e')
stop4 = next(i for i, line in enumerate(lines) if line.startswith('gdbus|') and 'org.fcitx.Fcitx.InputMethod.Exit' in line)
deploy = next(i for i, line in enumerate(lines) if line.startswith('rime_deployer|--build|'))
start5 = next(i for i, line in enumerate(lines) if line == 'fcitx5|-rd')
assert stop5 < stop4 < deploy < start5, lines
for line in lines:
    if line.startswith('pgrep|'):
        assert '-u 1000' in line and '-x fcitx' in line, line
PY
if [[ -e "$RIME_FORBIDDEN" ]]; then
    fail "测试调用了未授权的系统/网络命令: $(cat "$RIME_FORBIDDEN")"
fi
printf 'Rime offline regression OK\n'
