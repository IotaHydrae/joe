#!/usr/bin/env bash
# Godot 离线回归: 仓库副本、临时 HOME、官方 release/下载/包管理器 stub。
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOX="$(mktemp -d)"
trap 'rm -rf -- "$BOX"' EXIT
mkdir -p "$BOX/repo" "$BOX/bin" "$BOX/fixtures"
cp -a "$ROOT_DIR/install.sh" "$ROOT_DIR/scripts" "$BOX/repo/"
export GODOT_TEST_BOX="$BOX"
export GODOT_TEST_TAG=4.8.1-stable
export GODOT_TEST_ARCH=x86_64
export PATH="$BOX/bin:/usr/bin:/bin"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
cat > "$BOX/bin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'LATEST|%s\n' "$*" >> "$GODOT_TEST_BOX/downloads"
[[ ${!#} == https://github.com/godotengine/godot-builds/releases/latest ]] || exit 99
[[ ${GODOT_TEST_API_FAIL:-0} == 0 ]] || exit 22
printf 'https://github.com/godotengine/godot-builds/releases/tag/%s' "$GODOT_TEST_TAG"
STUB
cat > "$BOX/bin/uname" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$GODOT_TEST_ARCH"
STUB
for cmd in sudo apt-get apt-cache dnf pacman zypper; do
    cat > "$BOX/bin/$cmd" <<'STUB'
#!/usr/bin/env bash
printf 'FORBIDDEN|%s|%s\n' "${0##*/}" "$*" >> "$GODOT_TEST_BOX/forbidden"
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
install_sys_pkg() { printf 'FORBIDDEN prerequisite\n' >> "$GODOT_TEST_BOX/forbidden"; return 99; }
github_mirror_download() {
    printf 'DOWNLOAD|%s\n' "$1" >> "$GODOT_TEST_BOX/downloads"
    case "$1" in
        "https://github.com/godotengine/godot-builds/releases/download/$GODOT_TEST_TAG/"*.zip)
            cp -- "$GODOT_TEST_BOX/fixtures/package.zip" "$2" ;;
        "https://github.com/godotengine/godot-builds/releases/download/$GODOT_TEST_TAG/SHA512-SUMS.txt")
            [[ ${GODOT_TEST_SUM_FAIL:-0} == 0 ]] || return 22
            cp -- "$GODOT_TEST_BOX/fixtures/SHA512-SUMS.txt" "$2" ;;
        *) return 99 ;;
    esac
}
PM="${GODOT_TEST_PM:-apt}"
. "$GODOT_TEST_BOX/repo/scripts/components/godot.sh"
component_godot_install
RUNNER
new_home() {
    export HOME="$BOX/$1 home with ' quote"
    export TMPDIR="$HOME/tmp"
    mkdir -p "$HOME/.local/bin" "$TMPDIR"
    : > "$BOX/downloads"
    rm -f -- "$BOX/forbidden"
}
fixture() {
    python3 - "$GODOT_TEST_TAG" "$1" "$BOX/fixtures" <<'PY'
import hashlib, os, pathlib, sys, zipfile
version, arch, directory = sys.argv[1:]
root = pathlib.Path(directory)
filename = f'Godot_v{version}_linux.{arch}'
script = f'#!/usr/bin/env bash\nprintf "%s\\n" "{version.replace("-", ".")}.official.fixture"\n'
if os.environ.get('GODOT_TEST_BROKEN') == '1':
    script = '#!/usr/bin/env bash\nexit 23\n'
with zipfile.ZipFile(root / 'package.zip', 'w') as archive:
    archive.writestr(filename, script)
digest = hashlib.sha512((root / 'package.zip').read_bytes()).hexdigest()
(root / 'SHA512-SUMS.txt').write_text(f'{digest}  {filename}.zip\n')
PY
}
run_godot() { bash "$BOX/run.sh" > "$BOX/output" 2>&1; }
check_tmp() { [[ -z $(find "$TMPDIR" -mindepth 1 -print -quit) ]] || fail '临时文件未清理'; }

# 最新版本来自 release fixture, 不依赖测试时线上具体版本; 所有发行版使用同一来源。
for pm in apt dnf pacman zypper; do
    new_home "fresh-$pm"
    fixture x86_64
    GODOT_TEST_PM="$pm" run_godot || fail "全新安装失败 ($pm): $(cat "$BOX/output")"
    [[ $("$HOME/.local/bin/godot" --headless --version) == 4.8.1.stable.* ]] || fail '没有安装最新稳定版'
    [[ ! -e "$BOX/forbidden" ]] || fail '使用了发行版仓库而非官方稳定版'
    grep -q '^DOWNLOAD|.*/SHA512-SUMS.txt$' "$BOX/downloads" || fail '缺少校验文件下载'
    check_tmp
    printf 'PASS: %s 使用官方最新稳定版并校验\n' "$pm"
done
# 已是最新时不重复下载; 新 release 出现后显式重跑升级且不重复写 PATH。
new_home upgrade
fixture x86_64
run_godot || fail '初次安装失败'
: > "$BOX/downloads"
run_godot || fail '重复安装失败'
if grep -q '^DOWNLOAD|' "$BOX/downloads"; then fail '已是最新时仍下载'; fi
export GODOT_TEST_TAG=4.8.2-stable
fixture x86_64
run_godot || fail '新稳定版无法升级'
[[ $("$HOME/.local/bin/godot" --version) == 4.8.2.stable.* ]] || fail '重跑未升级'
[[ $(grep -c 'export PATH=' "$HOME/.bashrc") -eq 1 ]] || fail 'PATH 配置不幂等'
check_tmp
printf 'PASS: 版本检查、显式升级和 PATH 幂等\n'
# ARM64 选择实际对应的资产名。
new_home arm64
export GODOT_TEST_ARCH=aarch64
fixture arm64
run_godot || fail 'ARM64 安装失败'
grep -q 'Godot_v4.8.2-stable_linux.arm64.zip$' "$BOX/downloads" || fail 'ARM64 资产选择错误'
check_tmp
printf 'PASS: ARM64 官方资产选择\n'
export GODOT_TEST_ARCH=x86_64
# 解析失败、预发布、下载失败、校验不匹配必须保留原安装。
for failure in api prerelease missing_sums malformed_sums bad_checksum broken_binary; do
    new_home "$failure"
    export GODOT_TEST_TAG=4.8.2-stable
    fixture x86_64
    # 旧版 stub 只输出版本, 不调用安装器。
    printf '#!/usr/bin/env bash\nprintf "4.3.stable.official.old\\n"\n' > "$HOME/.local/bin/godot"
    cp "$HOME/.local/bin/godot" "$BOX/original"
    chmod +x "$HOME/.local/bin/godot"
    case "$failure" in
        api) if GODOT_TEST_API_FAIL=1 run_godot; then fail '版本查询失败却报告成功'; fi ;;
        prerelease) if GODOT_TEST_TAG=4.9-beta1 run_godot; then fail '接受了预发布版本'; fi ;;
        missing_sums) if GODOT_TEST_SUM_FAIL=1 run_godot; then fail '缺少校验文件仍安装'; fi ;;
        malformed_sums)
            printf 'broken checksum\n' > "$BOX/fixtures/SHA512-SUMS.txt"
            if run_godot; then fail '校验格式错误仍安装'; fi ;;
        bad_checksum)
            printf '%0128d  Godot_v%s_linux.x86_64.zip\n' 0 "$GODOT_TEST_TAG" > "$BOX/fixtures/SHA512-SUMS.txt"
            if run_godot; then fail 'SHA-512 不匹配仍安装'; fi ;;
        broken_binary)
            GODOT_TEST_BROKEN=1 fixture x86_64
            if run_godot; then fail '新版本无法运行仍安装'; fi ;;
    esac
    cmp -s -- "$BOX/original" "$HOME/.local/bin/godot" || fail '失败后覆盖了旧 Godot'
    check_tmp
    printf 'PASS: %s 失败时保留原安装并清理\n' "$failure"
done
# owning adapter 必须让显式 install godot 到达安装器, 即使已安装。
new_home adapter
printf '#!/usr/bin/env bash\nprintf "4.3.stable.official.old\\n"\n' > "$BOX/bin/godot"
chmod +x "$BOX/bin/godot"
printf '#!/usr/bin/env bash\nprintf "FWD|%%s\\n" "$*"\n' > "$BOX/installer.sh"
chmod +x "$BOX/installer.sh"
HOME="$HOME" DEVTOOLS_SCRIPT="$BOX/installer.sh" bash "$BOX/repo/install.sh" tools install godot > "$BOX/output" 2>&1 \
    || fail 'tools install godot 失败'
grep -Fxq 'FWD|--godot' "$BOX/output" || fail '已安装 Godot 被命令层提前跳过'
printf 'PASS: tools install godot 对已安装版本仍转发\n'
DEVTOOLS_SCRIPT="$BOX/installer.sh" bash "$BOX/repo/install.sh" tools install --all > "$BOX/output" 2>&1 \
    || fail '--all 派发失败'
if grep '^FWD|' "$BOX/output" | grep -q -- '--godot'; then fail '--all 意外升级了已安装的 Godot'; fi
printf 'PASS: --all 保留已安装 Godot 的跳过行为\n'
