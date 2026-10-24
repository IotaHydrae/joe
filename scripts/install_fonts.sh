#!/usr/bin/env bash
# 独立字体安装器: 仅复制仓库字体到用户目录, 不运行 Shell 安装或联网下载。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/fonts.sh"

usage() {
    cat <<'EOF'
用法: ./install.sh fonts [动作]

动作:
    <无参数>                  打开字体安装编号菜单
    list, status              列出字体及安装状态
    install <字体...>         安装指定字体到 ~/.local/share/fonts
        --all                     安装全部字体
        --dry-run                 只预览, 不复制文件或更新字体缓存
    -h, --help                显示帮助

字体随仓库提供, 无须联网或 sudo; 安装后在终端/编辑器中选择字体。
已有文件相同时跳过, 修改前备份为 .bak.<timestamp>, 每个文件保留最近 5 份。

可用字体:
EOF
    local id
    for id in "${FONT_IDS[@]}"; do
        printf '    %-18s %s\n' "$id" "${FONT_NAMES[$id]}"
    done
    printf '\n示例: ./install.sh fonts install jetbrains-mono\n'
    printf '      ./install.sh fonts install --dry-run --all\n'
}

die() {
    printf '错误: %s\n' "$*" >&2
    exit 1
}

list_fonts() {
    local id status
    printf '可用字体:\n'
    for id in "${FONT_IDS[@]}"; do
        status="未安装"
        if font_is_installed "$id"; then
            status="已安装"
        fi
        printf '  %-18s %s %s\n' "$id" "$status" "${FONT_NAMES[$id]}"
    done
}

copy_font_file() {
    local source="$1" dest="$2" backup base old index=0
    if [[ -f $dest ]] && cmp -s -- "$source" "$dest"; then
        return 0
    fi
    [[ ! -d $dest ]] || die "目标路径是目录: $dest"
    mkdir -p -- "$(dirname "$dest")"
    if [[ -e $dest || -L $dest ]]; then
        base="$dest.bak.$(date +%Y%m%d%H%M%S)"
        backup="$base"
        while [[ -e $backup || -L $backup ]]; do
            index=$((index + 1))
            backup="$base.$index"
        done
        cp -a -- "$dest" "$backup"
        printf '已备份: %s\n' "$backup"
    fi
    cp --remove-destination -- "$source" "$dest"
    chmod 644 -- "$dest"
    FONTS_CHANGED=true
    # 按时间戳和碰撞序号保留最近 5 份, 不依赖原字体文件的修改时间。
    while IFS= read -r old; do
        rm -f -- "$old"
    done < <(find "$(dirname "$dest")" -maxdepth 1 \
        -name "$(basename "$dest").bak.[0-9]*" -print | sort -rV | tail -n +6)
}

DRY_RUN=false
LIST_MODE=false
FONTS_CHANGED=false
REQUESTED=()
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        --list) LIST_MODE=true ;;
        --dry-run) DRY_RUN=true ;;
        --all) REQUESTED+=("${FONT_IDS[@]}") ;;
        -*) die "未知选项: $arg" ;;
        *) REQUESTED+=("$arg") ;;
    esac
done

if $LIST_MODE; then
    [[ ${#REQUESTED[@]} -eq 0 ]] || die "--list 不能与安装项一起使用"
    list_fonts
    exit 0
fi
if [[ ${#REQUESTED[@]} -eq 0 ]]; then
    usage >&2
    die "未指定字体, 请指定字体名或使用 --all"
fi

declare -A SEEN=()
SELECTED=()
for id in "${REQUESTED[@]}"; do
    [[ -n ${FONT_NAMES[$id]:-} ]] || die "未知字体: $id"
    [[ -z ${SEEN[$id]:-} ]] || continue
    SEEN[$id]=1
    SELECTED+=("$id")
done

# 先校验全部来源, 避免缺少资产时只安装了一部分字体。
for id in "${SELECTED[@]}"; do
    for file in ${FONT_FILES[$id]}; do
        [[ -s "$FONT_SOURCE_DIR/$file" ]] || die "字体文件缺失或为空: $FONT_SOURCE_DIR/$file"
    done
done

for id in "${SELECTED[@]}"; do
    if $DRY_RUN; then
        printf '[预览] 安装 %s -> %s\n' "${FONT_NAMES[$id]}" "$FONT_INSTALL_DIR"
        continue
    fi
    printf '安装字体: %s\n' "${FONT_NAMES[$id]}"
    for file in ${FONT_FILES[$id]}; do
        copy_font_file "$FONT_SOURCE_DIR/$file" "$FONT_INSTALL_DIR/$file"
    done
done

if $FONTS_CHANGED; then
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$FONT_INSTALL_DIR"
    else
        printf '未找到 fc-cache, 字体文件已复制; 安装 fontconfig 后运行 fc-cache -f。\n'
    fi
fi
if ! $DRY_RUN; then
    printf '字体安装完成, 请在终端或编辑器中选择字体。\n'
fi
