#!/usr/bin/env bash
# 日常运行只使用固定 Node 路径; nvm 仅在显式安装/切换版本时加载。

load_node() {
    local bin="${NVM_DIR:-$HOME/.nvm}/current/bin"
    if [ -x "$bin/node" ]; then
        case "$PATH" in
            "$bin"|"$bin":*) ;;
            *) export PATH="$bin:$PATH" ;;
        esac
    fi
}

# 把旧的 nvm 自动加载片段迁移成 PATH, 保留其余配置及符号链接。
configure_node_shell() (
    set -euo pipefail
    local rc="$1" nvm_dir="$2" syntax_rc="$1" tmp backup old index=0 mode=644
    if [ -L "$rc" ]; then
        rc="$(readlink -f "$rc")" || return 1
    fi
    mkdir -p -- "$(dirname "$rc")" || return 1
    tmp="$(mktemp "$rc.tmp.XXXXXX")" || return 1
    trap '[ ! -e "$tmp" ] || unlink -- "$tmp"' EXIT
    if [ -f "$rc" ]; then
        mode="$(stat -c '%a' "$rc")" || return 1
        awk '
            /^# >>> joe Node runtime >>>$/ { managed=1; next }
            /^# <<< joe Node runtime <<<$/ { managed=0; next }
            managed { next }
            /^[[:space:]]*export[[:space:]]+NVM_DIR=/ { next }
            /^[[:space:]]*(\[|source[[:space:]]|\.[[:space:]]|\\\.[[:space:]])/ &&
                /\$\{?NVM_DIR\}?\/(nvm\.sh|bash_completion)/ { next }
            { lines[++n]=$0 }
            END {
                if (managed) { print "Node 配置块缺少结束标记" > "/dev/stderr"; exit 1 }
                while (n && lines[n] ~ /^[[:space:]]*$/) n--
                for (i=1; i<=n; i++) print lines[i]
            }
        ' "$rc" > "$tmp" || return 1
    fi
    {
        printf '\n# >>> joe Node runtime >>>\n'
        if [ "$nvm_dir" = "$HOME/.nvm" ]; then
            printf '%s\n' 'export PATH="$HOME/.nvm/current/bin:$PATH"'
        else
            printf 'export PATH=%q:"$PATH"\n' "$nvm_dir/current/bin"
        fi
        printf '# <<< joe Node runtime <<<\n'
    } >> "$tmp" || return 1
    case "$syntax_rc" in
        */.zshrc) if command -v zsh >/dev/null 2>&1; then zsh -n "$tmp" || return 1; fi ;;
        *) bash -n "$tmp" || return 1 ;;
    esac
    if [ -f "$rc" ] && cmp -s -- "$tmp" "$rc"; then
        return 0
    fi
    chmod "$mode" "$tmp" || return 1
    if [ -f "$rc" ]; then
        backup="$rc.bak.$(date +%Y%m%d%H%M%S)"
        while [ -e "$backup" ]; do
            index=$((index + 1))
            backup="$rc.bak.$(date +%Y%m%d%H%M%S).$index"
        done
        cp -p -- "$rc" "$backup" || return 1
    fi
    mv -f -- "$tmp" "$rc" || return 1
    while IFS= read -r old; do
        unlink -- "$old" || return 1
    done < <(find "$(dirname "$rc")" -maxdepth 1 -type f \
        -name "$(basename "$rc").bak.[0-9]*" -printf '%T@ %p\n' \
        | sort -rn | tail -n +6 | cut -d' ' -f2-)
)
