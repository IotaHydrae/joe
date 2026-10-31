#!/usr/bin/env bash
# Blender 离线回归: 仓库副本、临时 HOME、镜像站点与包管理器 stub。
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOX="$(mktemp -d)"
trap 'rm -rf -- "$BOX"' EXIT
mkdir -p "$BOX/repo" "$BOX/bin" "$BOX/site/release"
cp -a "$ROOT_DIR/install.sh" "$ROOT_DIR/scripts" "$BOX/repo/"
export BLENDER_TEST_BOX="$BOX"
export BLENDER_TEST_ARCH=x86_64
export BLENDER_TEST_TAG=5.2.3
export PATH="$BOX/bin:/usr/bin:/bin"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# 官方源模拟不可达; 清华镜像提供全部文件, 其余主机一律失败。
cat > "$BOX/bin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
out=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    if [[ ${args[i]} == -o ]]; then out="${args[i+1]}"; fi
done
url="${!#}"
printf 'GET|%s\n' "$url" >> "$BLENDER_TEST_BOX/downloads"
case "$url" in
    https://download.blender.org/*) exit 28 ;;
    https://mirrors.tuna.tsinghua.edu.cn/blender/*)
        rel="${url#https://mirrors.tuna.tsinghua.edu.cn/blender}" ;;
    *) exit 22 ;;
esac
src="$BLENDER_TEST_BOX/site$rel"
if [[ "$rel" == */ ]]; then src="${src}index.html"; fi
[[ -f "$src" ]] || exit 22
if [[ -n "$out" ]]; then
    cp -- "$src" "$out"
else
    cat -- "$src"
fi
STUB
cat > "$BOX/bin/uname" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$BLENDER_TEST_ARCH"
STUB
for cmd in sudo apt-get apt-cache dnf pacman zypper; do
    cat > "$BOX/bin/$cmd" <<'STUB'
#!/usr/bin/env bash
printf 'FORBIDDEN|%s|%s\n' "${0##*/}" "$*" >> "$BLENDER_TEST_BOX/forbidden"
exit 99
STUB
done
chmod +x "$BOX/bin/"*
cat > "$BOX/run.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
info() { printf '%s\n' "$*"; }
ok() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die() { printf '%s\n' "$*" >&2; exit 1; }
make_tmp() { local file; file=$(mktemp); printf -v "$1" '%s' "$file"; }
pick_shell_rc() { printf '%s/.bashrc\n' "$HOME"; }
install_sys_pkg() { printf 'FORBIDDEN prerequisite\n' >> "$BLENDER_TEST_BOX/forbidden"; return 99; }
. "$BLENDER_TEST_BOX/repo/scripts/components/blender.sh"
component_blender_install
RUNNER
new_home() {
    export HOME="$BOX/$1 home with ' quote"
    export TMPDIR="$HOME/tmp"
    rm -rf -- "$BOX/site"
    mkdir -p "$HOME/.local/bin" "$TMPDIR" "$BOX/site/release"
    : > "$BOX/downloads"
    rm -f -- "$BOX/forbidden"
}
run_blender() { bash "$BOX/run.sh" > "$BOX/output" 2>&1; }
check_tmp() { [[ -z $(find "$TMPDIR" -mindepth 1 -print -quit) ]] || fail '临时文件未清理'; }

# 生成某个版本目录的安装包、校验文件和索引页。
fixture_site() {
    python3 - "$1" "$2" "$BOX/site" "${BLENDER_TEST_BROKEN:-0}" <<'PY'
import hashlib, io, pathlib, sys, tarfile
tag, arch, site, broken = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3]), sys.argv[4]
release = site / 'release'
major = 'Blender' + tag.rsplit('.', 1)[0]
vdir = release / major
vdir.mkdir(parents=True, exist_ok=True)
name = f'blender-{tag}-linux-{arch}'
script = f'#!/usr/bin/env bash\nprintf "Blender {tag} LTS\\nbuild date: fixture\\n"\n'
if broken == '1':
    script = '#!/usr/bin/env bash\nexit 23\n'
tar_path = vdir / f'{name}.tar.xz'
with tarfile.open(tar_path, 'w:xz') as tar:
    for rel, data, mode in (
        ('blender', script.encode(), 0o755),
        ('blender.desktop', b'[Desktop Entry]\nType=Application\nName=Blender\nExec=blender %f\nIcon=blender\n', 0o644),
        ('blender.svg', b'<svg xmlns="http://www.w3.org/2000/svg"/>\n', 0o644),
    ):
        entry = tarfile.TarInfo(f'{name}/{rel}')
        entry.size = len(data)
        entry.mode = mode
        tar.addfile(entry, io.BytesIO(data))
digest = hashlib.sha256(tar_path.read_bytes()).hexdigest()
(vdir / f'blender-{tag}.sha256').write_text(f'{digest}  {name}.tar.xz\n')
files = sorted(p.name for p in vdir.iterdir())
(vdir / 'index.html').write_text('\n'.join(f'<a href="{f}">{f}</a>' for f in files) + '\n')
dirs = sorted(p.name for p in release.iterdir() if p.is_dir())
(release / 'index.html').write_text('\n'.join(f'<a href="{d}/">{d}/</a>' for d in dirs) + '\n')
PY
}
refresh_release_index() {
    {
        for d in "$BOX"/site/release/Blender*/; do
            d=$(basename "$d")
            printf '<a href="%s/">%s/</a>\n' "$d" "$d"
        done
    } > "$BOX/site/release/index.html"
}

# 官方直连失败时回退镜像; 全新安装写入符号链接、桌面菜单项与 PATH。
new_home fresh
fixture_site "$BLENDER_TEST_TAG" x64
run_blender || fail "全新安装失败: $(cat "$BOX/output")"
[[ -L "$HOME/.local/bin/blender" ]] || fail '未创建 blender 符号链接'
[[ $("$HOME/.local/bin/blender" --version | head -1) == "Blender 5.2.3 LTS" ]] || fail '安装版本不符'
grep -q '^GET|https://download.blender.org/release/$' "$BOX/downloads" || fail '未尝试官方源'
grep -q '^GET|.*/Blender5.2/blender-5.2.3-linux-x64.tar.xz$' "$BOX/downloads" || fail '未从镜像下载安装包'
grep -q '^GET|.*/Blender5.2/blender-5.2.3.sha256$' "$BOX/downloads" || fail '未下载校验文件'
[[ -f "$HOME/.local/share/applications/blender.desktop" ]] || fail '未写入桌面菜单项'
grep -q "^Exec=$HOME/.local/bin/blender " "$HOME/.local/share/applications/blender.desktop" \
    || fail '桌面菜单项 Exec 不是稳定绝对路径'
[[ -f "$HOME/.local/share/icons/hicolor/scalable/apps/blender.svg" ]] || fail '未安装图标'
[[ $(grep -c 'export PATH=' "$HOME/.bashrc") -eq 1 ]] || fail 'PATH 配置缺失'
[[ ! -e "$BOX/forbidden" ]] || fail '使用了发行版包管理器'
check_tmp
printf 'PASS: 镜像回退安装、桌面菜单项与 PATH\n'

# 已是最新时不重复下载; 新稳定版出现后显式重跑升级且不重复写 PATH。
new_home upgrade
fixture_site "$BLENDER_TEST_TAG" x64
run_blender || fail '初次安装失败'
: > "$BOX/downloads"
run_blender || fail '重复安装失败'
if grep -q 'tar.xz$' "$BOX/downloads"; then fail '已是最新时仍下载安装包'; fi
export BLENDER_TEST_TAG=5.3.0
fixture_site "$BLENDER_TEST_TAG" x64
refresh_release_index
run_blender || fail '新稳定版无法升级'
[[ $("$HOME/.local/bin/blender" --version | head -1) == "Blender 5.3.0 LTS" ]] || fail '重跑未升级'
[[ $(grep -c 'export PATH=' "$HOME/.bashrc") -eq 1 ]] || fail 'PATH 配置不幂等'
check_tmp
printf 'PASS: 版本检查、显式升级和 PATH 幂等\n'
export BLENDER_TEST_TAG=5.2.3

# 最新大版本目录只有预发布包时回退到最近的稳定版。
new_home alpha
fixture_site 5.3.0 x64
mkdir -p "$BOX/site/release/Blender5.4"
printf '<a href="blender-5.4.0-alpha-linux-x64.tar.xz">x</a>\n' \
    > "$BOX/site/release/Blender5.4/index.html"
refresh_release_index
run_blender || fail '预发布目录导致安装失败'
[[ $("$HOME/.local/bin/blender" --version | head -1) == "Blender 5.3.0 LTS" ]] \
    || fail '未回退到最近的稳定版'
check_tmp
printf 'PASS: 预发布目录回退到稳定版\n'

# ARM64 选择实际对应的资产名。
new_home arm64
export BLENDER_TEST_ARCH=aarch64
fixture_site "$BLENDER_TEST_TAG" arm64
run_blender || fail 'ARM64 安装失败'
grep -q 'blender-5.2.3-linux-arm64.tar.xz$' "$BOX/downloads" || fail 'ARM64 资产选择错误'
[[ $("$HOME/.local/bin/blender" --version | head -1) == "Blender 5.2.3 LTS" ]] || fail 'ARM64 版本不符'
check_tmp
export BLENDER_TEST_ARCH=x86_64
printf 'PASS: ARM64 官方资产选择\n'

# 解析失败、缺校验、校验不匹配、新版本无法运行必须保留原安装。
for failure in listing missing_sums malformed_sums bad_checksum broken_binary; do
    new_home "$failure"
    fixture_site "$BLENDER_TEST_TAG" x64
    printf '#!/usr/bin/env bash\nprintf "Blender 4.2.0 LTS\\n"\n' > "$HOME/.local/bin/blender"
    chmod +x "$HOME/.local/bin/blender"
    cp "$HOME/.local/bin/blender" "$BOX/original"
    case "$failure" in
        listing)
            mv "$BOX/site" "$BOX/site.off"
            if run_blender; then fail '版本查询失败却报告成功'; fi
            mv "$BOX/site.off" "$BOX/site" ;;
        missing_sums)
            rm -f "$BOX/site/release/Blender5.2/blender-5.2.3.sha256"
            if run_blender; then fail '缺少校验文件仍安装'; fi ;;
        malformed_sums)
            printf 'broken checksum\n' > "$BOX/site/release/Blender5.2/blender-5.2.3.sha256"
            if run_blender; then fail '校验格式错误仍安装'; fi ;;
        bad_checksum)
            printf '%064d  blender-5.2.3-linux-x64.tar.xz\n' 0 \
                > "$BOX/site/release/Blender5.2/blender-5.2.3.sha256"
            if run_blender; then fail 'SHA-256 不匹配仍安装'; fi ;;
        broken_binary)
            BLENDER_TEST_BROKEN=1 fixture_site "$BLENDER_TEST_TAG" x64
            if run_blender; then fail '新版本无法运行仍安装'; fi ;;
    esac
    cmp -s -- "$BOX/original" "$HOME/.local/bin/blender" || fail '失败后覆盖了旧 Blender'
    check_tmp
    printf 'PASS: %s 失败时保留原安装并清理\n' "$failure"
done

# owning adapter 必须让显式 install blender 到达安装器, 即使已安装。
new_home adapter
printf '#!/usr/bin/env bash\nprintf "Blender 4.2.0 LTS\\n"\n' > "$BOX/bin/blender"
chmod +x "$BOX/bin/blender"
printf '#!/usr/bin/env bash\nprintf "FWD|%%s\\n" "$*"\n' > "$BOX/installer.sh"
chmod +x "$BOX/installer.sh"
HOME="$HOME" DEVTOOLS_SCRIPT="$BOX/installer.sh" bash "$BOX/repo/install.sh" tools install blender > "$BOX/output" 2>&1 \
    || fail 'tools install blender 失败'
grep -Fxq 'FWD|--blender' "$BOX/output" || fail '已安装 Blender 被命令层提前跳过'
printf 'PASS: tools install blender 对已安装版本仍转发\n'
DEVTOOLS_SCRIPT="$BOX/installer.sh" bash "$BOX/repo/install.sh" tools install --all > "$BOX/output" 2>&1 \
    || fail '--all 派发失败'
if grep '^FWD|' "$BOX/output" | grep -q -- '--blender'; then fail '--all 意外升级了已安装的 Blender'; fi
printf 'PASS: --all 保留已安装 Blender 的跳过行为\n'
