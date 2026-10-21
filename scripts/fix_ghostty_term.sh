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
echo "1. 当前终端类型: $TERM"
if [ "$TERM" != "dumb" ]; then
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

# 备份配置
BACKUP="$CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG" "$BACKUP"
info "已备份配置到: $BACKUP"
echo

# 检查是否已有 term 设置
echo "3. 修复配置"
if grep -q "^term = " "$CONFIG"; then
    current_term=$(grep "^term = " "$CONFIG" | head -1 | cut -d= -f2 | tr -d ' ')
    warn "已存在 term 设置: $current_term"

    read -p "是否覆盖为 xterm-256color? [y/N] " -r answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        # 替换现有设置
        sed -i.tmp 's/^term = .*/term = xterm-256color/' "$CONFIG"
        ok "已更新 term 设置"
    else
        info "跳过修改"
        exit 0
    fi
else
    # 添加新设置
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
