#!/usr/bin/env bash
# Bash installer/runtime regressions: copied repo, temp homes, offline package stubs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASH_BOX=$(mktemp -d)
trap 'rm -rf -- "$BASH_BOX"' EXIT
BASH_REPO="$BASH_BOX/repo with space"
BASH_HOME="$BASH_BOX/home with ' quote"
BASH_BIN="$BASH_BOX/bin"
BASH_LOG="$BASH_BOX/commands.log"
BASH_RUNTIME_LOG="$BASH_BOX/runtime.log"
BASH_TMP="$BASH_BOX/tmp"
mkdir -p "$BASH_REPO/configs/omarchy" "$BASH_HOME" "$BASH_BIN" "$BASH_TMP"
cp -a "$ROOT_DIR/scripts" "$BASH_REPO/scripts"
cp -a "$ROOT_DIR/configs/omarchy/bash" "$BASH_REPO/configs/omarchy/bash"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Whitelisted commands prevent accidental use of host-installed optional tools.
for executable in awk bash cat chmod cmp cp cut dirname env find getent id install ln \
    mkdir mktemp mv readlink rm sha256sum stat tar gzip uname wc python3; do
    ln -s "$(command -v "$executable")" "$BASH_BIN/$executable"
done
for executable in sudo chsh git; do
    cat > "$BASH_BIN/$executable" <<'STUB'
#!/usr/bin/env bash
printf 'FORBIDDEN %s %s\n' "$0" "$*" >> "$BASH_TEST_LOG"
exit 99
STUB
done
cat > "$BASH_BIN/curl" <<'STUB'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$BASH_TEST_LOG"
[[ ${BASH_TEST_RELEASE:-} == yes ]] || exit 99
printf '%s\n' 'https://github.com/starship/starship/releases/tag/v1.2.3'
STUB
chmod +x "$BASH_BIN/"{sudo,chsh,git,curl}

# Replace only helpers in the disposable repo. No system package manager can run.
cat > "$BASH_REPO/scripts/lib_distro.sh" <<'STUB'
PM=apt
pkg_installed() { [[ $1 == bash-completion && -e $BASH_TEST_BIN/.bash-completion-installed ]]; }
pkg_available() { return 1; }
apt_update_once() { printf 'apt-update\n' >> "$BASH_TEST_LOG"; }
install_sys_pkg() {
    printf 'package %s\n' "$*" >> "$BASH_TEST_LOG"
    local tool
    for tool in "$@"; do
        case "$tool" in
            bash-completion) : > "$BASH_TEST_BIN/.bash-completion-installed" ;;
            fzf|zoxide)
                printf '#!/usr/bin/env bash\nexit 0\n' > "$BASH_TEST_BIN/$tool"
                chmod +x "$BASH_TEST_BIN/$tool"
                ;;
        esac
    done
}
STUB
cat > "$BASH_REPO/scripts/lib_github.sh" <<'STUB'
github_mirror_download() {
    printf 'download %s\n' "$1" >> "$BASH_TEST_LOG"
    case "$1" in
        *.sha256) cp "$BASH_TEST_FIXTURE.sha256" "$2" ;;
        *) cp "$BASH_TEST_FIXTURE" "$2" ;;
    esac
}
STUB

run_installer() {
    env HOME="$BASH_HOME" XDG_CONFIG_HOME="$BASH_HOME/.config" PATH="$BASH_BIN" \
        TMPDIR="$BASH_TMP" BASH_TEST_LOG="$BASH_LOG" BASH_TEST_BIN="$BASH_BIN" \
        BASH_TEST_RELEASE="${BASH_TEST_RELEASE:-no}" BASH_TEST_FIXTURE="$BASH_BOX/release.tar.gz" \
        bash "$BASH_REPO/scripts/install_bash.sh" "$@"
}

printf "alias keepme='printf personal'\nexport EXAMPLE='value with spaces'" > "$BASH_HOME/.bashrc"
chmod 640 "$BASH_HOME/.bashrc"
cp "$BASH_HOME/.bashrc" "$BASH_BOX/original"
run_installer --configure-only --dry-run > "$BASH_BOX/out"
cmp -s "$BASH_HOME/.bashrc" "$BASH_BOX/original" || fail 'dry-run changed .bashrc'
[[ ! -e $BASH_HOME/.config && ! -e $BASH_LOG ]] || fail 'dry-run wrote files or ran installers'

run_installer --configure-only > "$BASH_BOX/out"
backup=$(find "$BASH_HOME" -name '.bashrc.bak.*' -print -quit)
[[ -n $backup ]] && cmp -s "$backup" "$BASH_BOX/original" || fail 'original .bashrc not backed up'
[[ $(stat -c '%a' "$BASH_HOME/.bashrc") == 640 ]] || fail '.bashrc permissions changed'
[[ $(head -n2 "$BASH_HOME/.bashrc") == "$(cat "$BASH_BOX/original")" ]] || fail 'personal config was changed'
cp "$BASH_HOME/.bashrc" "$BASH_BOX/configured"
run_installer --configure-only > "$BASH_BOX/out"
cmp -s "$BASH_HOME/.bashrc" "$BASH_BOX/configured" || fail 'repeat configuration is not idempotent'
[[ $(find "$BASH_HOME" -name '.bashrc.bak.*' | wc -l) -eq 1 ]] || fail 'unchanged install added backup'
[[ ! -e $BASH_LOG ]] || fail 'configure-only ran package/download/privileged command'

rc=0
run_installer --configure-only --set-default > "$BASH_BOX/out" 2> "$BASH_BOX/err" || rc=$?
[[ $rc -ne 0 && ! -e $BASH_LOG ]] || fail 'configure-only allowed default-shell change'
rc=0
run_installer --unknown > "$BASH_BOX/out" 2> "$BASH_BOX/err" || rc=$?
[[ $rc -ne 0 ]] || fail 'unknown option was accepted'

# Preserve symlinks and keep only five backups, including same-second collisions.
BASH_HOME="$BASH_BOX/symlink-home"
mkdir -p "$BASH_HOME/linked"
printf "alias linked='printf preserved'\n" > "$BASH_HOME/linked/bashrc"
ln -s linked/bashrc "$BASH_HOME/.bashrc"
run_installer --configure-only > "$BASH_BOX/out"
[[ -L $BASH_HOME/.bashrc ]] || fail 'configuration replaced .bashrc symlink'
for version in 1 2 3 4 5 6 7; do
    printf '\n# personal change %s\n' "$version" >> "$BASH_HOME/.bashrc"
    # An outdated managed block forces a real update without deleting personal edits.
    python3 - "$BASH_HOME/.bashrc" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(p.read_text().replace('    source ', '    builtin source '))
PY
    run_installer --configure-only > "$BASH_BOX/out"
done
[[ $(find "$BASH_HOME" -name '.bashrc.bak.*' | wc -l) -eq 5 ]] || fail 'did not retain five backups'
[[ $(grep -c '^# >>> joe Bash preset >>>$' "$BASH_HOME/.bashrc") -eq 1 ]] || fail 'duplicate source block'
grep -q "alias linked=" "$BASH_HOME/.bashrc" || fail 'symlink target lost personal config'

# Invalid managed markers and syntax fail before preset assets are copied.
BASH_HOME="$BASH_BOX/invalid-home"
mkdir -p "$BASH_HOME"
printf '# >>> joe Bash preset >>>\n' > "$BASH_HOME/.bashrc"
cp "$BASH_HOME/.bashrc" "$BASH_BOX/invalid-original"
rc=0
run_installer --configure-only > "$BASH_BOX/out" 2> "$BASH_BOX/err" || rc=$?
[[ $rc -ne 0 && ! -e $BASH_HOME/.config ]] || fail 'invalid block was partly installed'
cmp -s "$BASH_HOME/.bashrc" "$BASH_BOX/invalid-original" || fail 'invalid block was rewritten'
printf 'if\n' > "$BASH_HOME/.bashrc"
rc=0
run_installer --configure-only > "$BASH_BOX/out" 2> "$BASH_BOX/err" || rc=$?
[[ $rc -ne 0 && ! -e $BASH_HOME/.config ]] || fail 'invalid user syntax was partly installed'

# Simulate Mint: fzf/zoxide packages and verified upstream Starship fallback.
BASH_HOME="$BASH_BOX/package-home"
mkdir -p "$BASH_HOME" "$BASH_BOX/release"
cat > "$BASH_BOX/release/starship" <<'STUB'
#!/usr/bin/env bash
printf 'starship 1.2.3\n'
STUB
chmod +x "$BASH_BOX/release/starship"
tar -czf "$BASH_BOX/release.tar.gz" -C "$BASH_BOX/release" starship
sha256sum "$BASH_BOX/release.tar.gz" > "$BASH_BOX/release.tar.gz.sha256"
BASH_TEST_RELEASE=yes
run_installer > "$BASH_BOX/out"
[[ -x $BASH_HOME/.local/bin/starship && -f $BASH_HOME/.bashrc ]] || fail 'normal installation failed'
grep -qx 'package fzf' "$BASH_LOG" || fail 'missing fzf was not installed'
grep -qx 'package zoxide' "$BASH_LOG" || fail 'missing zoxide was not installed'
grep -qx 'package bash-completion' "$BASH_LOG" || fail 'completion package was not installed'
! grep -q 'FORBIDDEN' "$BASH_LOG" || fail 'installer changed default shell without flag'

BASH_HOME="$BASH_BOX/checksum-home"
mkdir -p "$BASH_HOME"
printf '%064d\n' 0 > "$BASH_BOX/release.tar.gz.sha256"
rc=0
run_installer > "$BASH_BOX/out" 2> "$BASH_BOX/err" || rc=$?
[[ $rc -ne 0 && ! -e $BASH_HOME/.bashrc && ! -e $BASH_HOME/.local/bin/starship ]] \
    || fail 'checksum mismatch did not stop installation'
[[ $(find "$BASH_TMP" -mindepth 1 | wc -l) -eq 0 ]] || fail 'failed download left temporary files'

# Runtime fixture: exercise cross-distro source order without loading host integrations.
BASH_HOME="$BASH_BOX/runtime-home"
mkdir -p "$BASH_HOME" "$BASH_BOX/runtime" "$BASH_BOX/integrations"
cp -a "$BASH_REPO/configs/omarchy/bash/." "$BASH_BOX/runtime/"
python3 - "$BASH_BOX/runtime/init.bash" "$BASH_BOX/integrations" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
directory = sys.argv[2]
content = p.read_text()
for old, new in (
    ('/usr/share/bash-completion/bash_completion', 'completion'),
    ('/etc/bash_completion', 'completion-fallback'),
    ('/usr/share/fzf/key-bindings.bash', 'fzf-arch'),
    ('/usr/share/doc/fzf/examples/key-bindings.bash', 'fzf-mint'),
):
    content = content.replace(old, directory + '/' + new)
p.write_text(content)
PY
cat > "$BASH_BOX/integrations/completion" <<'STUB'
printf 'completion\n' >> "$BASH_RUNTIME_LOG"
BASH_COMPLETION_VERSINFO=(2 18)
STUB
cat > "$BASH_BOX/integrations/fzf-mint" <<'STUB'
printf 'fzf-mint\n' >> "$BASH_RUNTIME_LOG"
fzf-file-widget() { :; }
STUB
cat > "$BASH_BIN/starship" <<'STUB'
#!/usr/bin/env bash
cat <<'INIT'
printf 'starship\n' >> "$BASH_RUNTIME_LOG"
starship_precmd() { :; }
INIT
STUB
cat > "$BASH_BIN/zoxide" <<'STUB'
#!/usr/bin/env bash
cat <<'INIT'
printf 'zoxide\n' >> "$BASH_RUNTIME_LOG"
__zoxide_hook() { :; }
z() { :; }
zi() { :; }
INIT
STUB
chmod +x "$BASH_BIN/starship" "$BASH_BIN/zoxide"
run_runtime() {
    env -u JOE_BASH_INIT_LOADED HOME="$BASH_HOME" PATH="$BASH_BIN" TERM=xterm-256color \
        BASH_RUNTIME_LOG="$BASH_RUNTIME_LOG" BASH_RUNTIME_PRESET="$BASH_BOX/runtime/init.bash" \
        STARSHIP_CONFIG=/old/config bash --noprofile --norc "$@" 2> "$BASH_BOX/runtime.err"
}
run_runtime -e -c 'source "$BASH_RUNTIME_PRESET"; [[ ! ${JOE_BASH_INIT_LOADED+x} ]]' \
    || fail 'non-interactive source initialized tools'
[[ ! -e $BASH_RUNTIME_LOG ]] || fail 'non-interactive source ran integrations'
run_runtime -i -c 'before=$-; source "$BASH_RUNTIME_PRESET"; source "$BASH_RUNTIME_PRESET"; [[ $- == "$before" && $(type -t cd) == builtin ]]; [[ $STARSHIP_CONFIG == "${BASH_RUNTIME_PRESET%/*}/starship.toml" ]]; declare -F z zi >/dev/null' \
    || fail 'interactive preset failed or changed shell options/cd'
[[ $(cat "$BASH_RUNTIME_LOG") == $'completion\nfzf-mint\nstarship\nzoxide' ]] \
    || fail "runtime order or idempotency failed: $(cat "$BASH_RUNTIME_LOG")"

# Prefer Arch location when both are available; pre-existing hooks are not initialized again.
cp "$BASH_BOX/integrations/fzf-mint" "$BASH_BOX/integrations/fzf-arch"
sed -i s/fzf-mint/fzf-arch/ "$BASH_BOX/integrations/fzf-arch"
: > "$BASH_RUNTIME_LOG"
run_runtime -i -c 'source "$BASH_RUNTIME_PRESET"' || fail 'Arch runtime failed'
[[ $(cat "$BASH_RUNTIME_LOG") == $'completion\nfzf-arch\nstarship\nzoxide' ]] || fail 'Arch fzf path not preferred'
: > "$BASH_RUNTIME_LOG"
run_runtime -i -c 'starship_precmd() { :; }; __zoxide_hook() { :; }; fzf-file-widget() { :; }; source "$BASH_RUNTIME_PRESET"' \
    || fail 'pre-existing hooks failed'
[[ $(cat "$BASH_RUNTIME_LOG") == completion ]] || fail 'pre-existing integrations initialized twice'

# New fzf can generate integration when distro script files are absent.
rm "$BASH_BOX/integrations/"fzf-{arch,mint}
cat > "$BASH_BIN/fzf" <<'STUB'
#!/usr/bin/env bash
cat <<'INIT'
printf 'fzf-generated\n' >> "$BASH_RUNTIME_LOG"
fzf-file-widget() { :; }
INIT
STUB
chmod +x "$BASH_BIN/fzf"
: > "$BASH_RUNTIME_LOG"
run_runtime -i -c 'source "$BASH_RUNTIME_PRESET"' || fail 'new fzf integration fallback failed'
[[ $(cat "$BASH_RUNTIME_LOG") == $'completion\nfzf-generated\nstarship\nzoxide' ]] || fail 'new fzf fallback order failed'

# Old fzf without integration files/--bash and all optional tools missing must stay quiet.
cat > "$BASH_BIN/fzf" <<'STUB'
#!/usr/bin/env bash
printf 'unknown option --bash\n' >&2
exit 2
STUB
chmod +x "$BASH_BIN/fzf"
run_runtime -i -c 'source "$BASH_RUNTIME_PRESET"; printf OLD_FZF_OK' > "$BASH_BOX/runtime.out" \
    || fail 'old fzf broke shell startup'
grep -q OLD_FZF_OK "$BASH_BOX/runtime.out" || fail 'old fzf stopped shell startup'
! grep -q 'unknown option' "$BASH_BOX/runtime.err" || fail 'old fzf printed startup errors'
rm "$BASH_BIN/"{starship,zoxide,fzf}
run_runtime -i -c 'source "$BASH_RUNTIME_PRESET"; printf MISSING_TOOLS_OK' > "$BASH_BOX/runtime.out" \
    || fail 'missing optional tools broke startup'
grep -q MISSING_TOOLS_OK "$BASH_BOX/runtime.out" || fail 'missing tools stopped shell startup'

printf 'Bash 配置与离线安装回归通过\n'
