# Ghostty 终端按键问题修复

## 问题描述

在 Ghostty 终端中，主菜单按 `q` + 回车无法退出，但在其他终端（如 Tabby）中正常。

## 诊断结果

**根本原因**: Ghostty 将 `TERM` 环境变量设置为 `dumb`，导致终端功能受限。

```bash
$ echo $TERM
dumb    # ← 这是问题所在
```

`TERM=dumb` 表示终端没有特殊功能，很多交互式程序会有问题。

## 解决方案

### 方案 1：修复 Ghostty 配置（推荐）

在 `~/.config/ghostty/config` 中添加：

```conf
# 设置正确的终端类型
term = xterm-256color

# 或使用 Ghostty 专用 terminfo
# term = xterm-ghostty
```

**操作步骤**:

```bash
# 1. 编辑配置
echo "term = xterm-256color" >> ~/.config/ghostty/config

# 2. 重启 Ghostty

# 3. 验证
echo $TERM  # 应该显示 xterm-256color
```

### 方案 2：修复 terminfo（如果方案 1 不工作）

Ghostty 自带专用 terminfo，确保已安装：

```bash
# 运行 joe 的 Ghostty 修复工具
./install.sh repair-ghostty

# 或使用新命令
./install.sh tools install ghostty --repair
```

### 方案 3：临时修复（测试用）

在启动 shell 时设置正确的 TERM：

```bash
# 在 ~/.zshrc 或 ~/.bashrc 中添加
if [ "$TERM" = "dumb" ] && [ -n "$GHOSTTY_RESOURCES_DIR" ]; then
    export TERM=xterm-256color
fi
```

### 方案 4：Shell 级别修复（最兼容）

如果上述方案都不行，修改 install.sh 的菜单逻辑，使其在 dumb 终端也能工作：

```bash
# install.sh 中的 main_menu_legacy 函数
main_menu_legacy() {
    # 检测 dumb 终端并警告
    if [ "$TERM" = "dumb" ]; then
        printf '\033[1;33m警告:\033[0m 检测到 TERM=dumb，可能影响交互体验\n'
        printf '建议在 ~/.config/ghostty/config 中添加: term = xterm-256color\n\n'
    fi
    
    # ... 原有代码
}
```

## 验证修复

```bash
# 1. 检查 TERM
echo $TERM
# 应该输出: xterm-256color 或 xterm-ghostty

# 2. 测试菜单
./install.sh
# 按 q + 回车应该能正常退出

# 3. 测试 stty
stty -a | grep icanon
# 应该能看到输出
```

## 为什么会出现 TERM=dumb？

可能的原因：

1. **Ghostty 配置缺失**: 没有明确设置 `term` 参数
2. **SSH 会话**: 通过 SSH 连接时可能降级为 dumb
3. **Subshell**: 某些情况下子 shell 继承了错误的 TERM
4. **GTK 环境**: GTK 应用在某些桌面环境下的兼容性问题

## 推荐配置

完整的 Ghostty 配置示例：

```conf
# ~/.config/ghostty/config

# 终端类型（必须）
term = xterm-256color

# 字体
font-family = Fixedsys Excelsior
font-size = 14

# 剪贴板
clipboard-paste-protection = false
clipboard-read = allow

# Shell integration（可选但推荐）
shell-integration = true
shell-integration-features = cursor,sudo,title

# 键绑定
keybind = ctrl+shift+e=new_split:right
keybind = ctrl+shift+o=new_split:down
keybind = alt+up=goto_split:top
keybind = alt+down=goto_split:bottom
keybind = alt+left=goto_split:left
keybind = alt+right=goto_split:right
```

## 其他终端对比

| 终端 | 默认 TERM | 是否需要修复 |
|------|-----------|--------------|
| Ghostty (默认) | dumb | ✗ 需要配置 |
| Ghostty (配置后) | xterm-256color | ✓ 正常 |
| Tabby | xterm-256color | ✓ 正常 |
| Alacritty | alacritty | ✓ 正常 |
| Kitty | xterm-kitty | ✓ 正常 |
| GNOME Terminal | xterm-256color | ✓ 正常 |

## 相关资源

- [Ghostty 官方文档](https://ghostty.org/docs)
- [Ghostty GitHub Issues](https://github.com/ghostty-org/ghostty/issues)
- 搜索关键词: "ghostty TERM dumb"

## 快速修复脚本

```bash
#!/usr/bin/env bash
# 一键修复 Ghostty TERM 问题

CONFIG="$HOME/.config/ghostty/config"

if [ -f "$CONFIG" ]; then
    if grep -q "^term = " "$CONFIG"; then
        echo "✓ 配置已存在 term 设置"
        grep "^term = " "$CONFIG"
    else
        echo "添加 term = xterm-256color 到配置"
        echo "" >> "$CONFIG"
        echo "# Terminal type" >> "$CONFIG"
        echo "term = xterm-256color" >> "$CONFIG"
        echo "✓ 已添加，请重启 Ghostty"
    fi
else
    echo "✗ Ghostty 配置文件不存在: $CONFIG"
fi
```

---

**更新日期**: 2025-10-20  
**影响版本**: Joe 2.0.0  
**Ghostty 版本**: 1.3.1
