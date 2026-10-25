# Ghostty 终端与字体问题修复

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

# 只想修当前用户、不写系统 terminfo:
./install.sh repair-ghostty --user-only
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

## Fixedsys 字体优先级修复

如果 Ghostty 已设置 `font-family = Fixedsys Excelsior`，但英文和数字仍显示为 Noto，可能是 fontconfig 的中文语言规则调整了字体优先级。这与字体是否安装、终端的 `TERM` 设置是两件事；在普通命令行的非中文环境下检查，也可能无法复现桌面上的结果。

运行已有修复命令即可部署字体规则；`./install.sh tools install ghostty` 也会调用同一修复流程：

```bash
./install.sh repair-ghostty --user-only
```

仓库中的 [99-fixedsys-explicit.conf](../.config/fontconfig/conf.d/99-fixedsys-explicit.conf) 会写入 `${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/99-fixedsys-explicit.conf`。规则只匹配明确包含 `Fixedsys Excelsior` 的字体请求，并以强绑定替换其字体列表：

1. `Fixedsys Excelsior`：英文和数字。
2. `Noto Sans Mono CJK SC`：中文缺字回退。
3. `Noto Color Emoji`：表情和国旗。

替换后的列表不保留通用 `monospace` 标记，避免系统针对中文等宽字体的规则再次把 Noto 插到 Fixedsys 前面。普通 `monospace`、JetBrains Mono 等其他字体请求不会被这条规则匹配。

修复只在内容变化时写入规则，覆盖前备份为 `.bak.<timestamp>`，保留最近 5 份；有 `fc-cache` 时刷新缓存。它不修改 Ghostty 中选择的字体，也不安装字体包。Fixedsys 和两个 Noto 回退字体都需已安装；缺少字体时，规则本身无法提供相应字形。

### 在中文桌面环境验证

先确认系统提供 `zh_CN.UTF-8`，再使用与桌面相同的环境检查：

```bash
locale -a
LC_ALL=zh_CN.UTF-8 fc-match -f '%{family}\n' 'Fixedsys Excelsior'
LC_ALL=zh_CN.UTF-8 fc-match -f '%{family}\n' 'Fixedsys Excelsior:charset=4e2d'
LC_ALL=zh_CN.UTF-8 fc-match -f '%{family}\n' 'Fixedsys Excelsior:charset=1f600'
```

在三个字体都安装的情况下，以上依次应匹配 Fixedsys、Noto Sans Mono CJK SC 和 Noto Color Emoji。还需完全退出并重启 Ghostty，确认实际显示的 `ABC 0123 中文 😀 🇨🇳`；`fc-match` 的结果只能验证 fontconfig 选择，不能代替 Ghostty 自身的加载检查。排查时不要仅使用 `C`、`C.UTF-8` 或与桌面不同的语言环境。

可使用 Ghostty 自身的字体诊断，检查各个码位实际选择的字体：

```bash
LC_ALL=zh_CN.UTF-8 ghostty +show-face --string='ABC 0123 中文 😀 🇨🇳'
```

此命令逐码位检查，国旗等组合字符仍需在窗口中确认最终显示。

## Cinnamon 快捷键打开窗口后没有焦点

如果 Ctrl+Alt+T 的自定义命令直接写成 `ghostty`，Cinnamon 会按普通进程启动它，缺少桌面应用启动上下文；这可能导致新窗口打开后未自动激活。只改成 `gtk-launch` 仍可能无法解决。运行修复命令：

```bash
./install.sh repair-ghostty --user-only
```

修复会安装独立启动器 `~/.local/bin/joe-ghostty`，在 X11 中记录启动前的窗口，最多等待约 5 秒，只对新增的 Ghostty 窗口发送激活请求。它保留调用目录和命令参数，不会激活旧窗口或其他应用。需要系统已有 `wmctrl`；修复命令不安装软件包。Wayland 或缺少 `wmctrl` 时保留 Ghostty 原生焦点行为。

已有 Cinnamon 自定义快捷键直接执行 `ghostty` 或 `gtk-launch com.mitchellh.ghostty` 时，会备份到用户配置目录 `ghostty/cinnamon-shortcut-<id>.bak.<timestamp>` 后迁移到这个启动器，每条保留最近 5 份。其他自定义快捷键不修改。Cinnamon 的 `focus-new-windows = smart` 是正常默认值，修复不修改全局焦点策略。

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
