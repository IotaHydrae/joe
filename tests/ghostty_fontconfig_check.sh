#!/usr/bin/env bash
# Ghostty 字体规则回归: 只写临时 HOME, 不访问网络、桌面会话或系统目录。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONT_BOX="$(mktemp -d)"
trap 'rm -rf -- "$FONT_BOX"' EXIT
FONT_REPO="$FONT_BOX/repo with ' quote"
FONT_HOME="$FONT_BOX/home with ' quote"
FONT_CONFIG="$FONT_BOX/config with ' quote"
FONT_BIN="$FONT_BOX/bin"
FONT_LOG="$FONT_BOX/cache.log"
FONT_FORBIDDEN="$FONT_BOX/forbidden.log"
RULE_NAME=99-fixedsys-explicit.conf
mkdir -p "$FONT_REPO/scripts/lib" "$FONT_REPO/.config/fontconfig/conf.d" "$FONT_BIN" "$FONT_HOME" "$FONT_CONFIG"
cp "$ROOT_DIR/install.sh" "$FONT_REPO/install.sh"
cp "$ROOT_DIR/scripts/lib_ghostty.sh" "$FONT_REPO/scripts/lib_ghostty.sh"
cp "$ROOT_DIR/scripts/repair_ghostty.sh" "$FONT_REPO/scripts/repair_ghostty.sh"
cp "$ROOT_DIR/scripts/launch_ghostty.sh" "$FONT_REPO/scripts/launch_ghostty.sh"
cp "$ROOT_DIR/scripts/install_shell.sh" "$FONT_REPO/scripts/install_shell.sh"
cp "$ROOT_DIR/scripts/lib/zsh.sh" "$FONT_REPO/scripts/lib/zsh.sh"
cp -a "$ROOT_DIR/templates" "$FONT_REPO/templates"
ln -s ../lib_ghostty.sh "$FONT_REPO/scripts/lib/ghostty.sh"
cp "$ROOT_DIR/.config/fontconfig/conf.d/$RULE_NAME" "$FONT_REPO/.config/fontconfig/conf.d/$RULE_NAME"
RULE_SOURCE="$FONT_REPO/.config/fontconfig/conf.d/$RULE_NAME"

cat > "$FONT_BIN/fc-cache" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FONT_CACHE_LOG"
STUB
cat > "$FONT_BIN/ghostty" <<'STUB'
#!/usr/bin/env bash
printf 'FAIL: 不应启动 Ghostty 窗口\n' >&2
exit 99
STUB
cat > "$FONT_BIN/infocmp" <<'STUB'
#!/usr/bin/env bash
if [[ ${1:-} == -D ]]; then
    printf '%s\n' "$HOME/.terminfo"
else
    printf 'xterm-ghostty|stub terminfo,\n'
fi
STUB
cat > "$FONT_BIN/gsettings" <<'STUB'
#!/usr/bin/env bash
[[ ${1:-} == list-schemas ]] || exit 99
STUB
cat > "$FONT_BIN/update-desktop-database" <<'STUB'
#!/usr/bin/env bash
[[ $1 == "$XDG_DATA_HOME/applications" ]] || exit 99
STUB
for command in sudo curl tic git chsh; do
    cat > "$FONT_BIN/$command" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$0" >> "$FONT_FORBIDDEN_LOG"
exit 99
STUB
done
chmod +x "$FONT_BIN"/*

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

run_font_rule() {
    env HOME="$FONT_HOME" XDG_CONFIG_HOME="$FONT_CONFIG" PATH="$FONT_BIN:$PATH" \
        FONT_CACHE_LOG="$FONT_LOG" FONT_FORBIDDEN_LOG="$FONT_FORBIDDEN" \
        bash -euo pipefail -c '. "$1"; ghostty_install_fontconfig' bash \
        "$FONT_REPO/scripts/lib/ghostty.sh"
}

count_backups() {
    find "$FONT_CONFIG/fontconfig/conf.d" -maxdepth 1 -name "$RULE_NAME.bak.*" | wc -l
}

# 自定义 XDG 路径不落到默认 ~/.config; 部署不能覆盖其他字体规则。
RULE_DEST="$FONT_CONFIG/fontconfig/conf.d/$RULE_NAME"
mkdir -p "$(dirname "$RULE_DEST")"
printf '<fontconfig><!-- personal rule --></fontconfig>\n' > "$(dirname "$RULE_DEST")/50-personal.conf"
run_font_rule
cmp -s "$RULE_SOURCE" "$RULE_DEST" || fail "规则未部署到自定义 XDG_CONFIG_HOME"
[[ $(stat -c '%a' "$RULE_DEST") == 644 ]] || fail "字体规则权限错误"
[[ $(cat "$(dirname "$RULE_DEST")/50-personal.conf") == '<fontconfig><!-- personal rule --></fontconfig>' ]] || fail "其他字体规则被覆盖"
[[ ! -e "$FONT_HOME/.config" ]] || fail "自定义 XDG_CONFIG_HOME 时写入默认配置目录"
[[ $(cat "$FONT_LOG") == -f ]] || fail "规则部署后未刷新字体缓存"

# 相同规则不重复写入、备份或刷新缓存。
run_font_rule
[[ $(count_backups) -eq 0 && $(wc -l < "$FONT_LOG") -eq 1 ]] || fail "重复部署未保持幂等"

# 同秒覆盖仍保留旧内容, 不复用备份名, 总计保留最近五份。
for version in 1 2 3 4 5 6 7; do
    printf 'old font rule %s\n' "$version" > "$RULE_DEST"
    run_font_rule
done
[[ $(count_backups) -eq 5 ]] || fail "字体规则备份未保留五份"
cmp -s "$RULE_SOURCE" "$RULE_DEST" || fail "覆盖后字体规则内容不符"
while IFS= read -r backup; do
    [[ $(cat "$backup") == 'old font rule '* ]] || fail "备份未保存旧内容"
done < <(find "$(dirname "$RULE_DEST")" -maxdepth 1 -name "$RULE_NAME.bak.*")
[[ $(wc -l < "$FONT_LOG") -eq 8 ]] || fail "字体规则变化后未刷新缓存"
[[ -z $(find "$FONT_CONFIG" -name '*.tmp.*' -print -quit) ]] || fail "留下字体规则临时文件"

# 符号链接保持不变; 更新链接目标并备份, 而不是拆掉用户链接。
FONT_CONFIG="$FONT_BOX/symlink config"
mkdir -p "$FONT_CONFIG/fontconfig/conf.d" "$FONT_BOX/linked rules"
RULE_DEST="$FONT_CONFIG/fontconfig/conf.d/$RULE_NAME"
RULE_TARGET="$FONT_BOX/linked rules/explicit.conf"
printf 'old linked rule\n' > "$RULE_TARGET"
ln -s "$RULE_TARGET" "$RULE_DEST"
run_font_rule
[[ -L $RULE_DEST && $(readlink "$RULE_DEST") == "$RULE_TARGET" ]] || fail "用户字体规则符号链接被替换"
cmp -s "$RULE_SOURCE" "$RULE_TARGET" || fail "字体规则链接目标未更新"
[[ $(find "$(dirname "$RULE_TARGET")" -name 'explicit.conf.bak.*' | wc -l) -eq 1 ]] || fail "链接目标缺少备份"

# 缺少资源时必须在创建目标目录、刷新缓存前失败。
FONT_CONFIG="$FONT_BOX/missing asset config"
cache_before="$(wc -l < "$FONT_LOG")"
mv "$RULE_SOURCE" "$FONT_BOX/saved-rule.conf"
if run_font_rule; then
    fail "缺少规则资源仍报告成功"
fi
[[ ! -e "$FONT_CONFIG" && $(wc -l < "$FONT_LOG") -eq $cache_before ]] || fail "缺少规则仍写文件或刷新缓存"
mv "$FONT_BOX/saved-rule.conf" "$RULE_SOURCE"

# 目标为目录时必须拒绝, 不能把临时文件移进目录后误报成功。
FONT_CONFIG="$FONT_BOX/directory target config"
mkdir -p "$FONT_CONFIG/fontconfig/conf.d/$RULE_NAME"
cache_before="$(wc -l < "$FONT_LOG")"
if run_font_rule; then
    fail "字体规则目标为目录时仍报告成功"
fi
[[ -z $(find "$FONT_CONFIG" -type f -print -quit) ]] || fail "目录目标留下了临时规则"
[[ $(wc -l < "$FONT_LOG") -eq $cache_before ]] || fail "目录目标仍刷新缓存"

# 未设置 XDG_CONFIG_HOME 时使用默认用户配置目录。
FONT_HOME="$FONT_BOX/default config home"
mkdir -p "$FONT_HOME"
env -u XDG_CONFIG_HOME HOME="$FONT_HOME" PATH="$FONT_BIN:$PATH" \
    FONT_CACHE_LOG="$FONT_LOG" FONT_FORBIDDEN_LOG="$FONT_FORBIDDEN" \
    bash -euo pipefail -c '. "$1"; ghostty_install_fontconfig' bash \
    "$FONT_REPO/scripts/lib_ghostty.sh"
cmp -s "$RULE_SOURCE" "$FONT_HOME/.config/fontconfig/conf.d/$RULE_NAME" || fail "未使用默认用户配置目录"

# Shell 安装的预览会经过 .config 分支, 但不能部署规则或刷新缓存。
FONT_HOME="$FONT_BOX/dry-run home"
FONT_CONFIG="$FONT_HOME/.config"
mkdir -p "$FONT_HOME"
cache_before="$(wc -l < "$FONT_LOG")"
env HOME="$FONT_HOME" XDG_CONFIG_HOME="$FONT_CONFIG" PATH="$FONT_BIN:$PATH" \
    FONT_CACHE_LOG="$FONT_LOG" FONT_FORBIDDEN_LOG="$FONT_FORBIDDEN" \
    SHELL_SCRIPT="$FONT_REPO/scripts/install_shell.sh" \
    bash "$FONT_REPO/install.sh" shell --dry-run --no-fonts --no-p10k --no-fastfetch --no-ghostty-ime \
    > "$FONT_BOX/shell-dry-run.log" 2>&1
[[ ! -e "$FONT_CONFIG" && $(wc -l < "$FONT_LOG") -eq $cache_before ]] || fail "Shell dry-run 部署规则或刷新缓存"

# 完整用户级修复必须调用字体修复; 所有桌面/terminfo 命令均为 stub。
FONT_HOME="$FONT_BOX/repair home with ' quote"
FONT_CONFIG="$FONT_HOME/.config"
mkdir -p "$FONT_HOME"
run_repair() {
    env HOME="$FONT_HOME" XDG_CONFIG_HOME="$FONT_CONFIG" XDG_DATA_HOME="$FONT_HOME/.local/share" \
        XDG_DATA_DIRS="$FONT_BOX/empty-data" XDG_CURRENT_DESKTOP='' PATH="$FONT_BIN:$PATH" \
        FONT_CACHE_LOG="$FONT_LOG" FONT_FORBIDDEN_LOG="$FONT_FORBIDDEN" \
        bash "$FONT_REPO/install.sh" repair-ghostty --user-only
}
run_repair >/dev/null 2>&1
cmp -s "$RULE_SOURCE" "$FONT_CONFIG/fontconfig/conf.d/$RULE_NAME" || fail "repair-ghostty 未部署字体规则"
[[ -x "$FONT_HOME/.local/bin/joe-ghostty" ]] || fail "用户级修复未完成桌面启动器"
cache_before="$(wc -l < "$FONT_LOG")"
run_repair >/dev/null 2>&1
[[ $(wc -l < "$FONT_LOG") -eq $cache_before ]] || fail "完整修复重复刷新未变化的字体规则"
[[ ! -e "$FONT_FORBIDDEN" ]] || fail "用户级修复执行了系统或网络命令"

# 检查真实 fontconfig 替换语义, 模拟先运行的中文 monospace 优先规则。
if command -v fc-pattern >/dev/null 2>&1; then
    cat > "$FONT_BOX/semantic.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="lang" compare="contains"><string>zh</string></test>
    <test name="family"><string>monospace</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Noto Sans Mono CJK SC</string></edit>
  </match>
  <include>$RULE_SOURCE</include>
</fontconfig>
EOF
    pattern_family() {
        env HOME="$FONT_HOME" LC_ALL=C FONTCONFIG_FILE="$FONT_BOX/semantic.conf" FONTCONFIG_PATH="$FONT_BOX" \
            fc-pattern -c -f '%{family}' "$1"
    }
    [[ $(pattern_family 'Fixedsys Excelsior,monospace:lang=zh-cn') == 'Fixedsys Excelsior,Noto Sans Mono CJK SC,Noto Color Emoji' ]] || fail "中文规则抢占 Fixedsys 或保留了通用 monospace"
    [[ $(pattern_family 'JetBrains Mono:lang=zh-cn') == 'JetBrains Mono' ]] || fail "Fixedsys 规则影响了其他字体"
    [[ $(pattern_family 'monospace:lang=zh-cn') == 'Noto Sans Mono CJK SC,monospace' ]] || fail "Fixedsys 规则改变了通用等宽字体"
else
    printf 'SKIP: 未安装 fc-pattern, 跳过字体匹配语义检查\n'
fi

printf 'OK: Ghostty 字体规则部署/备份/幂等/符号链接/中文匹配正常\n'
