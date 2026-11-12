# Omarchy-style Bash preset: Starship, bash-completion, fzf and zoxide.
# Sourced by ~/.bashrc; do not enable strict options in the caller's shell.
[[ $- == *i* ]] || return 0
[[ ${JOE_BASH_INIT_LOADED:-} == 1 ]] && return 0
JOE_BASH_INIT_LOADED=1

_joe_bash_init() {
    local config_dir="${BASH_SOURCE[0]%/*}" script generated

    # The verified Starship fallback installs here on distributions without a package.
    if [[ :$PATH: != *:"$HOME/.local/bin":* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi

    shopt -s histappend
    HISTCONTROL=ignoreboth
    HISTSIZE=32768
    HISTFILESIZE="$HISTSIZE"

    if [[ ! ${BASH_COMPLETION_VERSINFO+x} ]] \
        && ! declare -F _init_completion >/dev/null \
        && ! declare -F _comp_initialize >/dev/null; then
        for script in /usr/share/bash-completion/bash_completion /etc/bash_completion; do
            if [[ -r $script ]]; then
                # shellcheck disable=SC1090
                source "$script"
                break
            fi
        done
    fi

    [[ ! -r $config_dir/inputrc ]] || bind -f "$config_dir/inputrc"

    if command -v fzf >/dev/null 2>&1 && ! declare -F fzf-file-widget >/dev/null; then
        script=""
        for script in /usr/share/fzf/key-bindings.bash /usr/share/doc/fzf/examples/key-bindings.bash; do
            if [[ -r $script ]]; then
                # Omarchy loads only key bindings to keep shell startup fast.
                # shellcheck disable=SC1090
                source "$script"
                break
            fi
        done
        if [[ ! -r $script ]] && generated=$(fzf --bash 2>/dev/null); then
            # fzf emits its own Bash integration; older distro versions lack --bash.
            eval "$generated"
        fi
    fi

    if [[ ${TERM:-} != dumb ]] && command -v starship >/dev/null 2>&1; then
        # Select this preset explicitly without overwriting ~/.config/starship.toml.
        export STARSHIP_CONFIG="$config_dir/starship.toml"
        if ! declare -F starship_precmd >/dev/null; then
            if generated=$(starship init bash --print-full-init); then
                eval "$generated"
            fi
        fi
    fi

    # Keep this hook last, as recommended by zoxide. Preserve the ordinary cd command.
    if command -v zoxide >/dev/null 2>&1 && ! declare -F __zoxide_hook >/dev/null; then
        if generated=$(zoxide init bash); then
            eval "$generated"
        fi
    fi
}

_joe_bash_init
unset -f _joe_bash_init
