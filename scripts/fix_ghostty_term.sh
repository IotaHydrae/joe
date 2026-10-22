#!/usr/bin/env bash
# =============================================================================
# 修复 Ghostty TERM=dumb 问题
# =============================================================================

set -euo pipefail

CONFIG="$HOME/.config/ghostty/config"

info() { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*"; }
die() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Ghostty TERM 修复工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# 检查当前 TERM
echo "1. 当前终端类型: ${TERM:-<未设置>}"
if [ "${TERM:-}" != "dumb" ]; then
    ok "TERM 正常，无需修复"
    echo
    echo "如果您在其他 Ghostty 窗口遇到问题，请在那个窗口运行此脚本。"
    exit 0
fi

warn "检测到 TERM=dumb，这会导致交互问题"
echo

# 检查配置文件
echo "2. 检查 Ghostty 配置"
if [ ! -f "$CONFIG" ]; then
    info "配置文件不存在，创建: $CONFIG"
    mkdir -p "$(dirname "$CONFIG")"
    touch "$CONFIG"
fi

# 备份配置: 与仓库约定一致 (*.bak.<timestamp>) 且只保留最近 5 个
backup_config() {
    local backup old
    backup="$CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "$CONFIG" "$backup"
    info "已备份配置到: $backup"
    while IFS= read -r old; do
        rm -f -- "$old"
    done < <(find "$(dirname "$CONFIG")" -maxdepth 1 -type f \
        -name "$(basename "$CONFIG").bak.*" -printf '%T@ %p\n' |
        sort -rn | tail -n +6 | cut -d' ' -f2-)
}

# 检查是否已有 term 设置
echo "3. 修复配置"
if grep -qE '^term[[:space:]]*=' "$CONFIG"; then
    current_term=$(grep -m1 -E '^term[[:space:]]*=' "$CONFIG" | cut -d= -f2- | tr -d ' ')
    warn "已存在 term 设置: $current_term"

    if ! read -p "是否覆盖为 xterm-256color? [y/N] " -r answer; then
        die "非交互环境无法确认; 请手动编辑 $CONFIG"
    fi
    if [[ $answer =~ ^[Yy]$ ]]; then
        backup_config
        # term=xterm-256color 这种不带空格的写法也要覆盖; 不用 -i.tmp 以免留下 .tmp
        sed -i 's/^term[[:space:]]*=.*/term = xterm-256color/' "$CONFIG"
        ok "已更新 term 设置"
    else
        info "跳过修改"
        exit 0
    fi
else
    # 添加新设置
    backup_config
    {
        echo ""
        echo "# Terminal type (fixed by joe)"
        echo "term = xterm-256color"
    } >> "$CONFIG"
    ok "已添加 term = xterm-256color"
fi

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  修复完成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
warn "请执行以下步骤："
echo "  1. 关闭此 Ghostty 窗口"
echo "  2. 重新打开 Ghostty"
echo "  3. 运行: echo \$TERM"
echo "     应该显示: xterm-256color"
echo "  4. 测试 joe 菜单: ./install.sh"
echo
info "如果仍有问题，查看详细文档: docs/GHOSTTY_FIX.md"
