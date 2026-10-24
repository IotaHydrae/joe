#!/usr/bin/env bash
# Zsh 优化回归: 只操作 /tmp 仓库副本和临时 HOME, 不安装软件或访问网络。

set -euo pipefail

if ! command -v zsh >/dev/null 2>&1; then
    printf 'SKIP: 未安装 zsh, 无法验证交互配置\n' >&2
    exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_BOX="$(mktemp -d)"
trap 'rm -rf -- "$ZSH_BOX"' EXIT
ZSH_REPO="$ZSH_BOX/repo with space"
ZSH_HOME="$ZSH_BOX/home with ' quote"
ZSH_BIN="$ZSH_BOX/bin"
ZSH_FORBIDDEN="$ZSH_BOX/forbidden.log"
ZSH_LOG="$ZSH_BOX/runtime.log"
mkdir -p "$ZSH_REPO" "$ZSH_BIN" "$ZSH_HOME"
cp "$ROOT_DIR/install.sh" "$ZSH_REPO/install.sh"
cp -a "$ROOT_DIR/scripts" "$ZSH_REPO/scripts"
cp -a "$ROOT_DIR/templates" "$ZSH_REPO/templates"

for command in git curl sudo chsh; do
    cat > "$ZSH_BIN/$command" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$0" >> "$ZSH_FORBIDDEN_LOG"
exit 99
STUB
done
chmod +x "$ZSH_BIN"/*

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

run_shell() {
    env -u ZDOTDIR HOME="$ZSH_HOME" XDG_CACHE_HOME="$ZSH_HOME/.cache" \
        XDG_CONFIG_HOME="$ZSH_HOME/.config" PATH="$ZSH_BIN:$PATH" \
        ZSH="$ZSH_HOME/.oh-my-zsh" ZSH_CUSTOM="$ZSH_HOME/.oh-my-zsh/custom" \
        NVM_DIR="$ZSH_HOME/.nvm" PYENV_ROOT="$ZSH_HOME/.pyenv" \
        ZSH_FORBIDDEN_LOG="$ZSH_FORBIDDEN" \
        SHELL_SCRIPT="$ZSH_REPO/scripts/install_shell.sh" \
        bash "$ZSH_REPO/install.sh" shell --configure-only "$@"
}

run_zsh() {
    env -u ZDOTDIR HOME="$ZSH_HOME" XDG_CACHE_HOME="$ZSH_HOME/.cache" \
        XDG_CONFIG_HOME="$ZSH_HOME/.config" PATH="$ZSH_BIN:$PATH" \
        ZSH="$ZSH_HOME/.oh-my-zsh" ZSH_CUSTOM="$ZSH_HOME/.oh-my-zsh/custom" \
        HISTFILE="$ZSH_HOME/.zsh_history" ZSH_COMPDUMP="$ZSH_HOME/.zcompdump" \
        NVM_DIR="$ZSH_HOME/.nvm" PYENV_ROOT="$ZSH_HOME/.pyenv" \
        ZSH_TEST_LOG="$ZSH_LOG" DISABLE_AUTO_UPDATE=true TERM=xterm-256color \
        zsh "$@"
}

cat > "$ZSH_HOME/.zshrc" <<'RC'
# Enable Powerlevel10k instant prompt.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git sudo custom zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh
source ~/.zsh-autosuggestions/zsh-autosuggestions.zsh
source "$HOME/.zsh-autosuggestions/zsh-autosuggestions.zsh"
source ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source "$HOME/.powerlevel10k/powerlevel10k.zsh-theme"
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
# >>> joe Node runtime >>>
export PATH="$HOME/.nvm/current/bin:$PATH"
# <<< joe Node runtime <<<
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
eval "$(pyenv virtualenv-init -)"
alias keepme='printf personal'
alias localpath='export PATH="$HOME/.local/bin:$PATH"'
export http_proxy=http://127.0.0.1:7890
export PATH="$HOME/custom tools:$PATH"
export PICO_SDK_PATH="$HOME/pico-sdk"
[[ -n ${ZSH_TEST_LOG:-} ]] && print -r -- custom >> "$ZSH_TEST_LOG"
RC
cp "$ZSH_HOME/.zshrc" "$ZSH_BOX/original"
chmod 640 "$ZSH_HOME/.zshrc"

# 配置预览不能改写用户文件或执行软件安装命令。
run_shell --dry-run > "$ZSH_BOX/out"
cmp -s "$ZSH_HOME/.zshrc" "$ZSH_BOX/original" || fail "dry-run 改写了 zshrc"
[[ $(find "$ZSH_HOME" -name '*.bak.*' | wc -l) -eq 0 ]] || fail "dry-run 创建了备份"
[[ ! -e $ZSH_FORBIDDEN ]] || fail "configure-only 调用了下载/提权命令"

run_shell > "$ZSH_BOX/out"
[[ $(stat -c '%a' "$ZSH_HOME/.zshrc") == 640 ]] || fail "迁移没有保留原文件权限"
backup="$(find "$ZSH_HOME" -name '.zshrc.bak.*' -print -quit)"
[[ -n $backup ]] && cmp -s "$backup" "$ZSH_BOX/original" || fail "修改前未完整备份原 zshrc"
for line in "alias keepme='printf personal'" \
    'alias localpath='\''export PATH="$HOME/.local/bin:$PATH"'\''' \
    'export http_proxy=http://127.0.0.1:7890' \
    'export PATH="$HOME/custom tools:$PATH"' \
    'export PICO_SDK_PATH="$HOME/pico-sdk"'; do
    grep -qxF "$line" "$ZSH_HOME/.zshrc" || fail "迁移丢失了自定义配置: $line"
done
grep -q '^# >>> joe user configuration >>>' "$ZSH_HOME/.zshrc" || fail "缺少保留用户配置的区域"
cp "$ZSH_HOME/.zshrc" "$ZSH_BOX/optimized"
run_shell > "$ZSH_BOX/out"
cmp -s "$ZSH_HOME/.zshrc" "$ZSH_BOX/optimized" || fail "重复迁移不幂等"
[[ $(find "$ZSH_HOME" -name '.zshrc.bak.*' | wc -l) -eq 1 ]] || fail "重复迁移创建了多余备份"

# 切换现有选项形成真实配置变更, 检查同秒备份碰撞和保留数量。
for version in 1 2 3 4 5 6 7; do
    if ((version % 2)); then
        run_shell --no-p10k > "$ZSH_BOX/out"
    else
        run_shell > "$ZSH_BOX/out"
    fi
done
[[ $(find "$ZSH_HOME" -name '.zshrc.bak.*' | wc -l) -eq 5 ]] || fail "zshrc 备份未保留最近 5 份"
run_shell > "$ZSH_BOX/out"

if command -v zsh >/dev/null 2>&1; then
    # 模拟已装组件, 用源文件记录加载顺序, 不调用宿主机的真实插件。
    mkdir -p "$ZSH_HOME/.oh-my-zsh/plugins/"{git,sudo,custom} \
        "$ZSH_HOME/.powerlevel10k" "$ZSH_HOME/.fzf/shell" \
        "$ZSH_HOME/.zsh-autosuggestions" "$ZSH_HOME/.zsh-syntax-highlighting" \
        "$ZSH_HOME/.nvm/current/bin" "$ZSH_HOME/.pyenv/bin" "$ZSH_HOME/.pyenv/shims"
    printf 'print -r -- omz >> "$ZSH_TEST_LOG"\n' > "$ZSH_HOME/.oh-my-zsh/oh-my-zsh.sh"
    printf 'print -r -- p10k >> "$ZSH_TEST_LOG"\n' > "$ZSH_HOME/.powerlevel10k/powerlevel10k.zsh-theme"
    printf 'print -r -- p10k-config >> "$ZSH_TEST_LOG"\n' > "$ZSH_HOME/.p10k.zsh"
    printf 'print -r -- fzf-completion >> "$ZSH_TEST_LOG"\n' > "$ZSH_HOME/.fzf/shell/completion.zsh"
    printf 'print -r -- fzf-bindings >> "$ZSH_TEST_LOG"\n' > "$ZSH_HOME/.fzf/shell/key-bindings.zsh"
    printf 'print -r -- old-fzf-wrapper >> "$ZSH_TEST_LOG"\n' > "$ZSH_HOME/.fzf.zsh"
    printf 'print -r -- autosuggestions >> "$ZSH_TEST_LOG"\n' > "$ZSH_HOME/.zsh-autosuggestions/zsh-autosuggestions.zsh"
    printf 'print -r -- highlighting >> "$ZSH_TEST_LOG"\n' > "$ZSH_HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    cat > "$ZSH_HOME/.nvm/nvm.sh" <<'NVM'
print -r -- nvm-init >> "$ZSH_TEST_LOG"
nvm() { print -r -- "nvm:$*" >> "$ZSH_TEST_LOG"; }
NVM
    cat > "$ZSH_HOME/.pyenv/bin/pyenv" <<'PYENV'
#!/usr/bin/env bash
printf 'pyenv:%s\n' "$*" >> "$ZSH_TEST_LOG"
if [[ ${1:-} == init ]]; then
    printf 'pyenv() { command pyenv "$@"; }\n'
fi
PYENV
    chmod +x "$ZSH_HOME/.pyenv/bin/pyenv"
    run_zsh -i -c 'print -r -- JOE_ZSH_OK' > "$ZSH_BOX/runtime.out" 2> "$ZSH_BOX/runtime.err"
    [[ ! -s "$ZSH_BOX/runtime.err" ]] || fail "优化后的启动产生错误: $(cat "$ZSH_BOX/runtime.err")"
    [[ $(cat "$ZSH_LOG") == $'omz\np10k\np10k-config\nfzf-completion\nfzf-bindings\ncustom\nautosuggestions\nhighlighting' ]] || fail "组件重复加载、顺序错误或启动时加载了 nvm/pyenv: $(cat "$ZSH_LOG")"
    grep -qx JOE_ZSH_OK "$ZSH_BOX/runtime.out" || fail "交互式 shell 启动失败"
    : > "$ZSH_LOG"
    run_zsh -i -c 'nvm --version; nvm --version; pyenv --version' > "$ZSH_BOX/runtime.out" 2> "$ZSH_BOX/runtime.err"
    [[ $(grep -c '^nvm-init$' "$ZSH_LOG") -eq 1 ]] || fail "nvm 按需初始化未只执行一次"
    grep -q '^pyenv:init ' "$ZSH_LOG" || fail "pyenv 未按需初始化"
    grep -q '^pyenv:--version$' "$ZSH_LOG" || fail "pyenv 初始化后未派发请求"
    [[ ! -s "$ZSH_BOX/runtime.err" ]] || fail "按需初始化产生错误: $(cat "$ZSH_BOX/runtime.err")"
else
    printf 'SKIP: 未安装 zsh, 跳过交互运行时检查\n'
fi

# 更新符号链接的目标, 同时保留链接本身。
ZSH_HOME="$ZSH_BOX/symlink-home"
mkdir -p "$ZSH_HOME/linked"
printf "alias linked='printf linked'\n" > "$ZSH_HOME/linked/zshrc"
ln -s linked/zshrc "$ZSH_HOME/.zshrc"
run_shell > "$ZSH_BOX/out"
[[ -L "$ZSH_HOME/.zshrc" ]] || fail "迁移破坏了 zshrc 符号链接"
grep -q "alias linked=" "$ZSH_HOME/linked/zshrc" || fail "迁移未保留链接目标的用户配置"

# 新环境缺少所有可选组件时也应能干净启动。
ZSH_HOME="$ZSH_BOX/bare-home"
mkdir -p "$ZSH_HOME"
run_shell --no-p10k --no-default-plugins > "$ZSH_BOX/out"
grep -qx 'plugins=(git)' "$ZSH_HOME/.zshrc" || fail "--no-default-plugins 未保留最小插件配置"
grep -qx 'JOE_ZSH_USE_P10K=0' "$ZSH_HOME/.zshrc" || fail "--no-p10k 未关闭主题初始化"
[[ ! -e $ZSH_FORBIDDEN ]] || fail "configure-only 调用了下载/提权命令"
if command -v zsh >/dev/null 2>&1; then
    mkdir -p "$ZSH_HOME/.cache"
    printf 'print -r -- instant-cache >> "$ZSH_TEST_LOG"\n' > \
        "$ZSH_HOME/.cache/p10k-instant-prompt-$(id -un).zsh"
    : > "$ZSH_LOG"
    run_zsh -i -c 'print -r -- JOE_BARE_OK' > "$ZSH_BOX/runtime.out" 2> "$ZSH_BOX/runtime.err"
    [[ ! -s "$ZSH_BOX/runtime.err" ]] || fail "可选组件缺失时启动报错: $(cat "$ZSH_BOX/runtime.err")"
    grep -qx JOE_BARE_OK "$ZSH_BOX/runtime.out" || fail "可选组件缺失时无法启动"
    [[ ! -s "$ZSH_LOG" ]] || fail "--no-p10k 仍加载了 instant prompt 缓存"
fi

# 不能通过执行用户的动态插件表达式来迁移配置。
ZSH_HOME="$ZSH_BOX/dynamic-home"
mkdir -p "$ZSH_HOME"
printf 'plugins=($(touch "$HOME/SHOULD_NOT_EXIST"))\n' > "$ZSH_HOME/.zshrc"
cp "$ZSH_HOME/.zshrc" "$ZSH_BOX/dynamic-original"
rc=0
run_shell > "$ZSH_BOX/out" 2> "$ZSH_BOX/err" || rc=$?
[[ $rc -ne 0 ]] || fail "动态插件配置未安全拒绝迁移"
cmp -s "$ZSH_HOME/.zshrc" "$ZSH_BOX/dynamic-original" || fail "拒绝迁移后仍改写了用户配置"
[[ ! -e "$ZSH_HOME/SHOULD_NOT_EXIST" ]] || fail "迁移执行了旧配置中的命令"

if command -v zsh >/dev/null 2>&1; then
    ZSH_HOME="$ZSH_BOX/invalid-template-home"
    mkdir -p "$ZSH_HOME"
    cp "$ZSH_REPO/templates/zshrc.zsh" "$ZSH_BOX/good-template"
    printf '\nif\n' >> "$ZSH_REPO/templates/zshrc.zsh"
    rc=0
    run_shell > "$ZSH_BOX/out" 2> "$ZSH_BOX/err" || rc=$?
    [[ $rc -ne 0 && ! -e "$ZSH_HOME/.zshrc" ]] || fail "语法检查失败仍写入了无效配置"
    cp "$ZSH_BOX/good-template" "$ZSH_REPO/templates/zshrc.zsh"
fi

printf 'OK: zsh 迁移/加载顺序/按需初始化/备份/幂等/dry-run 正常\n'
