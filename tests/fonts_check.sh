#!/usr/bin/env bash
# 字体安装回归: 所有文件写入临时 HOME, fontconfig 与网络/提权命令均为 stub。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONT_BOX="$(mktemp -d)"
trap 'rm -rf -- "$FONT_BOX"' EXIT
FONT_REPO="$FONT_BOX/repo with space"
FONT_HOME="$FONT_BOX/home with ' quote"
FONT_BIN="$FONT_BOX/bin"
FONT_LOG="$FONT_BOX/cache.log"
mkdir -p "$FONT_REPO/scripts/commands" "$FONT_REPO/scripts/lib" "$FONT_BIN" "$FONT_HOME"
cp "$ROOT_DIR/install.sh" "$FONT_REPO/install.sh"
cp "$ROOT_DIR/scripts/install_fonts.sh" "$FONT_REPO/scripts/install_fonts.sh"
cp "$ROOT_DIR/scripts/commands/fonts.sh" "$FONT_REPO/scripts/commands/fonts.sh"
cp "$ROOT_DIR/scripts/lib/fonts.sh" "$FONT_REPO/scripts/lib/fonts.sh"
cp -a "$ROOT_DIR/fonts" "$FONT_REPO/fonts"

cat > "$FONT_BIN/fc-cache" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FONT_CACHE_LOG"
STUB
cat > "$FONT_BIN/fc-list" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${FONT_TEST_FAMILY:-}"
STUB
for command in curl sudo; do
    cat > "$FONT_BIN/$command" <<'STUB'
#!/usr/bin/env bash
printf 'FAIL: 字体安装不应下载或提权\n' >&2
exit 99
STUB
done
chmod +x "$FONT_BIN"/*

run_fonts() {
    env HOME="$FONT_HOME" PATH="$FONT_BIN:$PATH" FONT_CACHE_LOG="$FONT_LOG" \
        FONTS_SCRIPT="$FONT_REPO/scripts/install_fonts.sh" \
        FONT_TEST_FAMILY="${FONT_TEST_FAMILY:-}" \
        bash "$FONT_REPO/install.sh" fonts "$@"
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

count_backups() {
    find "$FONT_HOME/.local/share/fonts" -type f -name '*.bak.*' | wc -l
}

# list / status / dry-run 都不能创建字体目录或运行缓存刷新。
listing="$(run_fonts list)"
[[ $listing == *"Fixedsys Excelsior"* && $listing == *"JetBrains Mono"* ]] || fail "字体清单缺少名称"
run_fonts status >/dev/null
run_fonts install --dry-run --all >/dev/null
[[ ! -e "$FONT_HOME/.local" && ! -e "$FONT_LOG" ]] || fail "只读操作或 dry-run 写入了字体/缓存"
listing="$(FONT_TEST_FAMILY='JetBrains Mono' run_fonts list)"
[[ $listing =~ jetbrains-mono[[:space:]]+已安装 ]] || fail "未识别系统已安装的 JetBrains Mono"
listing="$(FONT_TEST_FAMILY='JetBrains Mono,JetBrains Mono NL' run_fonts list)"
[[ $listing =~ jetbrains-mono[[:space:]]+已安装 ]] || fail "未识别逗号分隔的字体家族"
listing="$(FONT_TEST_FAMILY='JetBrains Mono NL' run_fonts list)"
[[ $listing =~ jetbrains-mono[[:space:]]+未安装 ]] || fail "错误地把 JetBrains Mono NL 当作 JetBrains Mono"

rc=0
run_fonts install fsex302 unknown-font >"$FONT_BOX/out" 2>"$FONT_BOX/err" || rc=$?
[[ $rc -eq 1 && -s "$FONT_BOX/err" ]] || fail "未知字体未在 stderr 报错并退出 1"
[[ ! -e "$FONT_HOME/.local" && ! -e "$FONT_LOG" ]] || fail "未知字体仍触发写入"
rc=0
run_fonts install >"$FONT_BOX/out" 2>"$FONT_BOX/err" || rc=$?
[[ $rc -eq 1 && -s "$FONT_BOX/err" ]] || fail "未指定字体的 install 未拒绝执行"
[[ ! -e "$FONT_HOME/.local" && ! -e "$FONT_LOG" ]] || fail "空安装请求仍触发写入"

# 从仓库外运行, 首次安装与完整字形/许可证复制。
(
    cd "$FONT_BOX"
    run_fonts install --all >/dev/null
)
FONT_DEST="$FONT_HOME/.local/share/fonts"
cmp -s "$FONT_REPO/fonts/FSEX302.ttf" "$FONT_DEST/FSEX302.ttf" || fail "FSEX302 安装内容错误"
for style in Regular Bold Italic BoldItalic; do
    file="jetbrains-mono/JetBrainsMono-$style.ttf"
    cmp -s "$FONT_REPO/fonts/$file" "$FONT_DEST/$file" || fail "JetBrains Mono 缺少 $style"
done
cmp -s "$FONT_REPO/fonts/jetbrains-mono/OFL.txt" "$FONT_DEST/jetbrains-mono/OFL.txt" || fail "JetBrains Mono 未保留许可证"
[[ -s "$FONT_LOG" ]] || fail "首次安装未刷新字体缓存"
listing="$(run_fonts list)"
[[ $listing == *"已安装"* ]] || fail "字体安装后状态未更新"
[[ ! -e "$FONT_HOME/.zshrc" && ! -e "$FONT_HOME/.oh-my-zsh" ]] || fail "字体安装修改了 Shell 环境"

# 重复安装不创建备份或再次刷新缓存。
cache_before="$(wc -l < "$FONT_LOG")"
run_fonts install fsex302 jetbrains-mono >/dev/null
[[ $(count_backups) -eq 0 ]] || fail "相同字体重复安装产生备份"
[[ $(wc -l < "$FONT_LOG") -eq $cache_before ]] || fail "字体未变化仍重复刷新缓存"

# 覆盖前备份, 同秒多次覆盖也不得重用备份名; 仅保留最后 5 份。
for version in 1 2 3 4 5 6 7; do
    printf 'old font version %s\n' "$version" > "$FONT_DEST/FSEX302.ttf"
    run_fonts install fsex302 >/dev/null
done
[[ $(count_backups) -eq 5 ]] || fail "字体备份未保留 5 份或同秒覆盖了备份"
cmp -s "$FONT_REPO/fonts/FSEX302.ttf" "$FONT_DEST/FSEX302.ttf" || fail "覆盖字体后内容不符"
find "$FONT_DEST" -type f -name 'FSEX302.ttf.bak.*' | while IFS= read -r backup; do
    [[ $(cat "$backup") == "old font version "* ]] || fail "备份未保存旧字体内容"
done

# 全量安装必须先验证所有源文件, 避免资源不完整时只安装一半。
FONT_HOME="$FONT_BOX/missing-source-home"
mkdir -p "$FONT_HOME"
mv "$FONT_REPO/fonts/jetbrains-mono/JetBrainsMono-BoldItalic.ttf" "$FONT_BOX/missing.ttf"
cache_before="$(wc -l < "$FONT_LOG")"
rc=0
run_fonts install --all >"$FONT_BOX/out" 2>"$FONT_BOX/err" || rc=$?
[[ $rc -ne 0 && -s "$FONT_BOX/err" ]] || fail "源字体缺失未报告错误"
[[ ! -e "$FONT_HOME/.local" ]] || fail "源字体缺失仍进行了部分安装"
[[ $(wc -l < "$FONT_LOG") -eq $cache_before ]] || fail "源字体缺失仍刷新了缓存"

printf 'OK: 字体清单/离线安装/备份/幂等/dry-run 正常\n'
