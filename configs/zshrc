# Joe zsh configuration. Personal commands are preserved in the user block.
# Optional machine-specific overrides can also live in ~/.zshrc.local.

JOE_ZSH_USE_P10K=1
if (( JOE_ZSH_USE_P10K )) && [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Keep command lookup fast without initializing version managers at startup.
typeset -U path PATH
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
typeset -a _joe_bins=()
for _joe_bin in "$HOME/.local/bin" "$NVM_DIR/current/bin" \
    "$PYENV_ROOT/shims" "$PYENV_ROOT/bin" "$HOME/.grok/bin" \
    "$HOME/.mimocode/bin" "$HOME/.cargo/bin" "$HOME/.fzf/bin"; do
    [[ ! -d $_joe_bin ]] || _joe_bins+=("$_joe_bin")
done
path=("${_joe_bins[@]}" "${path[@]}")
unset _joe_bin _joe_bins

# Updates are explicit: ./install.sh shell --update.
zstyle ':omz:update' mode disabled
plugins=(git sudo extract z history dirhistory)
typeset -U plugins
typeset -a _joe_plugins=()
for _joe_plugin in "${plugins[@]}"; do
    case "$_joe_plugin" in
        zsh-autosuggestions|zsh-syntax-highlighting|nvm|pyenv) continue ;;
    esac
    if [[ -d "$ZSH/plugins/$_joe_plugin" || \
        -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/$_joe_plugin" ]]; then
        _joe_plugins+=("$_joe_plugin")
    fi
done
plugins=("${_joe_plugins[@]}")
unset _joe_plugin _joe_plugins

ZSH_THEME="robbyrussell"
if (( JOE_ZSH_USE_P10K )) && [[ -r "$HOME/.powerlevel10k/powerlevel10k.zsh-theme" ]]; then
    ZSH_THEME=""
fi
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
else
    autoload -Uz compinit
    compinit
fi
if (( JOE_ZSH_USE_P10K )) && [[ -r "$HOME/.powerlevel10k/powerlevel10k.zsh-theme" ]]; then
    source "$HOME/.powerlevel10k/powerlevel10k.zsh-theme"
    [[ ! -r "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"
fi

# Share useful history across terminals and avoid duplicate entries.
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_SPACE HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS HIST_FIND_NO_DUPS HIST_REDUCE_BLANKS HIST_VERIFY
unsetopt INC_APPEND_HISTORY INC_APPEND_HISTORY_TIME
KEYTIMEOUT=10
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select

# Initialize shell integration only when a version-manager command is requested.
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    nvm() {
        unfunction nvm
        source "$NVM_DIR/nvm.sh" --no-use || return $?
        nvm "$@"
    }
fi
if (( $+commands[pyenv] )); then
    pyenv() {
        unfunction pyenv
        source <(command pyenv init - zsh) || return $?
        if [[ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]]; then
            source <(command pyenv virtualenv-init -) || return $?
        fi
        pyenv "$@"
    }
fi

# Source installed widgets directly, without running the fzf installer.
for _joe_fzf_dir in "$HOME/.fzf/shell" /usr/share/fzf/shell /usr/share/doc/fzf/examples; do
    if [[ -r "$_joe_fzf_dir/completion.zsh" && -r "$_joe_fzf_dir/key-bindings.zsh" ]]; then
        source "$_joe_fzf_dir/completion.zsh"
        source "$_joe_fzf_dir/key-bindings.zsh"
        break
    fi
done
unset _joe_fzf_dir

# >>> joe user configuration >>>
# <<< joe user configuration <<<

[[ ! -r "$HOME/.zshrc.local" ]] || source "$HOME/.zshrc.local"

# Widgets and custom bindings must be ready before syntax highlighting loads.
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=200
for _joe_source in "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "$ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "$HOME/.zsh-autosuggestions/zsh-autosuggestions.zsh"; do
    if [[ -r $_joe_source ]]; then
        source "$_joe_source"
        break
    fi
done
for _joe_source in "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
    "$ZSH/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
    "$HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
    if [[ -r $_joe_source ]]; then
        source "$_joe_source"
        break
    fi
done
unset _joe_source
