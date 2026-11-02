#!/usr/bin/env bash
# =============================================================================
# joe lib/agents — 探测已安装的 AI 代理 CLI
# =============================================================================
# _has_bin <name>: 依次检查 PATH、~/.local/bin、MiMo/Grok 官方安装目录、
# 以及 nvm 的 node 版本目录。非交互 shell 下 PATH 往往不含这些路径,
# 仅用 command -v 会误判。
# =============================================================================

_has_bin() {
    local name="$1"
    command -v "$name" >/dev/null 2>&1 && return 0
    [ -x "$HOME/.local/bin/$name" ] && return 0
    [ -x "$HOME/.mimocode/bin/$name" ] && return 0   # MiMo Code 官方安装路径
    [ -x "$HOME/.grok/bin/$name" ] && return 0       # Grok Build 官方安装路径
    local f
    for f in "$HOME"/.nvm/versions/node/*/bin/"$name"; do
        [ -x "$f" ] && return 0
    done
    return 1
}
