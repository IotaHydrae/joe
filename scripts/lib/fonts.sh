#!/usr/bin/env bash
# 字体菜单、状态和安装器共用的清单; 字体资产始终相对仓库定位。

FONT_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/fonts"
FONT_INSTALL_DIR="$HOME/.local/share/fonts"
FONT_IDS=(fsex302 jetbrains-mono)
declare -A FONT_NAMES=(
    [fsex302]="Fixedsys Excelsior (FSEX302)"
    [jetbrains-mono]="JetBrains Mono"
)
declare -A FONT_FAMILIES=(
    [fsex302]="Fixedsys Excelsior"
    [jetbrains-mono]="JetBrains Mono"
)
declare -A FONT_FILES=(
    [fsex302]="FSEX302.ttf"
    [jetbrains-mono]="jetbrains-mono/JetBrainsMono-Regular.ttf jetbrains-mono/JetBrainsMono-Bold.ttf jetbrains-mono/JetBrainsMono-Italic.ttf jetbrains-mono/JetBrainsMono-BoldItalic.ttf jetbrains-mono/OFL.txt"
)

font_is_installed() {
    local id="$1" file family listing missing=false
    local -a families=()
    [[ -n ${FONT_NAMES[$id]:-} ]] || return 1
    for file in ${FONT_FILES[$id]}; do
        [[ $file == *.ttf ]] || continue
        if [[ ! -s "$FONT_INSTALL_DIR/$file" ]]; then
            missing=true
        fi
    done
    $missing || return 0

    # fc-match 会返回替代字体; 这里只接受 fc-list 中实际存在的字体家族。
    command -v fc-list >/dev/null 2>&1 || return 1
    if ! listing=$(fc-list --format '%{family}\n' 2>/dev/null); then
        return 1
    fi
    while IFS=, read -r -a families; do
        for family in "${families[@]}"; do
            [[ $family == "${FONT_FAMILIES[$id]}" ]] && return 0
        done
    done <<< "$listing"
    return 1
}
