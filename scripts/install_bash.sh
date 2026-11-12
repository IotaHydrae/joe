#!/usr/bin/env bash
# Portable four-feature Bash preset derived from Omarchy; no desktop changes.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
PRESET_DIR="$ROOT_DIR/configs/omarchy/bash"
DRY_RUN=false
CONFIGURE_ONLY=false
SET_DEFAULT=false

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

show_help() {
    cat <<'HELP'
用法: ./install.sh shell bash [选项]

安装 Omarchy 风格 Bash: Starship、fzf、zoxide、bash-completion。
保留已有 .bashrc, 添加一个配置入口; Zsh 配置不变。

选项:
    --dry-run         预览操作, 不下载、不安装、不写文件
    --configure-only  只配置已安装工具, 不下载、不提权、不切换默认 Shell
    --set-default     安装后将当前用户的登录 Shell 切换为 Bash (重新登录生效)
    -h, --help        显示帮助

支持 apt (Mint/Ubuntu/Debian)、pacman、dnf、zypper。
默认不更改登录 Shell; 可启动 bash 体验, 或显式使用 --set-default。
HELP
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --configure-only) CONFIGURE_ONLY=true ;;
        --set-default) SET_DEFAULT=true ;;
        -h|--help) show_help; exit 0 ;;
        *) die "未知 Bash 选项: $arg (查看 shell bash --help)" ;;
    esac
done
$CONFIGURE_ONLY && $SET_DEFAULT && die "--configure-only 不能与 --set-default 同时使用"

if $DRY_RUN; then
    if ! $CONFIGURE_ONLY; then
        info '将检查并安装缺失工具: Starship、fzf、zoxide、bash-completion、python3'
        info 'Starship 优先使用系统包; 无对应包时下载官方 Release 并校验 SHA-256'
    fi
    info "将复制 Bash 预设到 ${XDG_CONFIG_HOME:-$HOME/.config}/joe/bash"
    info "将备份并更新 $HOME/.bashrc 的 joe Bash 配置入口, 保留个人配置"
    $SET_DEFAULT && info '将使用 chsh 切换当前用户的登录 Shell 为 Bash'
    exit 0
fi

# Shared package resolution and verified GitHub mirror download helpers.
# shellcheck source=lib/distro.sh
source "$ROOT_DIR/scripts/lib/distro.sh"
# shellcheck source=lib/github.sh
source "$ROOT_DIR/scripts/lib/github.sh"
export PATH="$HOME/.local/bin:$PATH"

install_starship_binary() (
    local release_url version arch asset base tmp_dir staged="" expected actual installed
    command -v curl >/dev/null 2>&1 || install_sys_pkg curl
    command -v tar >/dev/null 2>&1 || install_sys_pkg tar
    command -v gzip >/dev/null 2>&1 || install_sys_pkg gzip
    command -v sha256sum >/dev/null 2>&1 || die 'Starship 二进制安装需要 sha256sum'
    case "$(uname -m)" in
        x86_64|amd64) arch=x86_64 ;;
        aarch64|arm64) arch=aarch64 ;;
        *) die 'Starship 官方二进制仅支持 x86_64/aarch64, 请手动安装 Starship' ;;
    esac
    release_url=$(curl -fsSLI --connect-timeout 15 --max-time 30 -o /dev/null \
        -w '%{url_effective}' https://github.com/starship/starship/releases/latest) \
        || die '无法确定 Starship 最新版本'
    case "$release_url" in
        https://github.com/starship/starship/releases/tag/v*) version="${release_url##*/}" ;;
        *) die 'Starship 发布地址无效' ;;
    esac
    [[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'Starship 发布版本无效'
    asset="starship-${arch}-unknown-linux-musl.tar.gz"
    base="https://github.com/starship/starship/releases/download/$version"
    tmp_dir=$(mktemp -d)
    trap 'rm -rf -- "$tmp_dir"; [[ -z $staged ]] || rm -f -- "$staged"' EXIT
    github_mirror_download "$base/$asset" "$tmp_dir/starship.tar.gz" || die 'Starship 下载失败'
    github_mirror_download "$base/$asset.sha256" "$tmp_dir/starship.sha256" \
        || die '无法获取 Starship SHA-256, 已拒绝安装'
    expected=$(awk 'NR == 1 {print $1}' "$tmp_dir/starship.sha256")
    [[ $expected =~ ^[[:xdigit:]]{64}$ ]] || die 'Starship SHA-256 文件无效, 已拒绝安装'
    actual=$(sha256sum -- "$tmp_dir/starship.tar.gz" | awk '{print $1}')
    [[ $actual == "${expected,,}" ]] || die 'Starship SHA-256 不匹配, 已拒绝安装'
    tar -xzf "$tmp_dir/starship.tar.gz" -C "$tmp_dir" starship
    [[ -f $tmp_dir/starship && ! -L $tmp_dir/starship ]] || die 'Starship 安装包中缺少可执行文件'
    mkdir -p "$HOME/.local/bin"
    [[ ! -e $HOME/.local/bin/starship && ! -L $HOME/.local/bin/starship ]] || die '~/.local/bin/starship 已存在但不可执行, 请先处理该文件'
    staged=$(mktemp "$HOME/.local/bin/.starship.XXXXXX")
    install -m755 -- "$tmp_dir/starship" "$staged"
    installed=$("$staged" --version) || die 'Starship 二进制无法运行, 已取消安装'
    [[ $installed == "starship ${version#v}"* ]] || die 'Starship 二进制版本与发布版本不符'
    mv -fT -- "$staged" "$HOME/.local/bin/starship"
    info "Starship $version 已安装到 ~/.local/bin"
)

if ! $CONFIGURE_ONLY; then
    command -v python3 >/dev/null 2>&1 || install_sys_pkg python3
    command -v fzf >/dev/null 2>&1 || install_sys_pkg fzf
    command -v zoxide >/dev/null 2>&1 || install_sys_pkg zoxide
    if ! pkg_installed bash-completion; then
        install_sys_pkg bash-completion
    fi
    if ! command -v starship >/dev/null 2>&1; then
        [[ $PM != apt ]] || apt_update_once
        if pkg_available starship; then
            install_sys_pkg starship
        else
            install_starship_binary
        fi
    fi
    pkg_installed bash-completion || die '安装后未找到 bash-completion 软件包, 未修改 Bash 配置'
    for tool in python3 starship fzf zoxide; do
        command -v "$tool" >/dev/null 2>&1 || die "安装后未找到 $tool, 未修改 Bash 配置"
    done
fi
command -v python3 >/dev/null 2>&1 || die '--configure-only 需要已安装的 python3'
bash -n "$PRESET_DIR/init.bash"

# Update files atomically, preserve symlinks/permissions and retain the last five backups.
python3 - "$PRESET_DIR" "${XDG_CONFIG_HOME:-$HOME/.config}/joe/bash" "$HOME/.bashrc" <<'PY'
import datetime
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

preset, destination, rc = map(Path, sys.argv[1:])
start = b'# >>> joe Bash preset >>>'
end = b'# <<< joe Bash preset <<<'
block = b'''# >>> joe Bash preset >>>
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/joe/bash/init.bash" ]]; then
    source "${XDG_CONFIG_HOME:-$HOME/.config}/joe/bash/init.bash"
fi
# <<< joe Bash preset <<<
'''


def rc_content(original):
    lines = original.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.rstrip(b'\r\n') == start]
    ends = [i for i, line in enumerate(lines) if line.rstrip(b'\r\n') == end]
    if starts or ends:
        if len(starts) != 1 or len(ends) != 1 or ends[0] < starts[0]:
            raise ValueError('joe Bash 标记不完整或重复, 请先检查 .bashrc; 原文件未修改')
        return b''.join(lines[:starts[0]]) + block + b''.join(lines[ends[0] + 1:])
    return original + (b'\n' if original and not original.endswith(b'\n') else b'') + block


def backup_and_replace(requested, content, validate=False):
    target = requested.resolve()
    if target.exists() and target.read_bytes() == content:
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    handle, temp_name = tempfile.mkstemp(prefix='.' + target.name + '.', dir=target.parent)
    temp = Path(temp_name)
    try:
        with os.fdopen(handle, 'wb') as output:
            output.write(content)
        if target.exists():
            shutil.copystat(target, temp)
        else:
            temp.chmod(0o644)
        if validate:
            subprocess.run(['bash', '-n', str(temp)], check=True)
        if target.exists():
            stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
            index = 0
            while True:
                saved = requested.with_name(requested.name + '.bak.' + stamp + ('.' + str(index) if index else ''))
                try:
                    saved_fd = os.open(saved, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                    with os.fdopen(saved_fd, 'wb') as output, target.open('rb') as source:
                        shutil.copyfileobj(source, output)
                    shutil.copystat(target, saved)
                    break
                except FileExistsError:
                    index += 1
            print('[INFO] 已备份: ' + str(saved))
        os.replace(temp, target)
        pattern = re.compile(re.escape(requested.name) + r'\.bak\.(\d{14})(?:\.(\d+))?$')
        backups = []
        for candidate in requested.parent.iterdir():
            match = pattern.fullmatch(candidate.name)
            if match and candidate.is_file() and not candidate.is_symlink():
                backups.append((match.group(1), int(match.group(2) or 0), candidate))
        for _, _, candidate in sorted(backups, reverse=True)[5:]:
            candidate.unlink()
    finally:
        temp.unlink(missing_ok=True)


try:
    original = rc.read_bytes() if rc.exists() else b''
    updated = rc_content(original)
    # Validate the combined user configuration before copying any preset assets.
    with tempfile.TemporaryDirectory() as temporary:
        candidate = Path(temporary) / 'bashrc'
        candidate.write_bytes(updated)
        subprocess.run(['bash', '-n', str(candidate)], check=True)
    for name in ('init.bash', 'inputrc', 'starship.toml'):
        backup_and_replace(destination / name, (preset / name).read_bytes())
    backup_and_replace(rc, updated, validate=True)
except (OSError, ValueError, subprocess.CalledProcessError) as error:
    print('[FAIL] Bash 配置失败: ' + str(error), file=sys.stderr)
    sys.exit(1)
PY

if $SET_DEFAULT; then
    bash_path=$(command -v bash)
    current_shell=$(getent passwd "$(id -un)" | cut -d: -f7)
    if [[ $current_shell != "$bash_path" && $(readlink -f "$current_shell") != "$(readlink -f "$bash_path")" ]]; then
        info '将登录 Shell 切换为 Bash...'
        sudo chsh -s "$bash_path" "$(id -un)"
    fi
fi
info 'Bash 配置已就绪。打开新的 Bash 会话生效; 当前 Shell 未重载。'
