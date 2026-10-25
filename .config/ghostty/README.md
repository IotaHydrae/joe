# Ghostty 配置说明

这是 Joe 提供的 Ghostty 终端推荐配置。

## 安装

运行 Shell 环境安装时会自动复制到 `~/.config/ghostty/`:

```bash
./install.sh shell
```

如果只想更新 Ghostty 配置：

```bash
cp -i .config/ghostty/config ~/.config/ghostty/config
```

## 配置说明

### 关键设置

```conf
# 终端类型（必须设置）
term = xterm-256color
```

**重要性**：如果缺少这个设置，Ghostty 可能默认使用 `TERM=dumb`，导致：
- 交互式程序无法正常工作
- TUI 界面显示异常
- 按键处理出现问题

### 其他设置

```conf
# 字体
font-family = Fixedsys Excelsior
font-size = 14

# 剪贴板（关闭安全提示）
clipboard-paste-protection = false
clipboard-read = allow

# 分屏快捷键
keybind = ctrl+shift+e=new_split:right
keybind = ctrl+shift+o=new_split:down
keybind = alt+up=goto_split:top
keybind = alt+down=goto_split:bottom
keybind = alt+left=goto_split:left
keybind = alt+right=goto_split:right
```

## 自定义

你可以根据需要修改：

### 字体

```conf
font-family = "JetBrains Mono"
font-size = 12
```

### Shell Integration（可选但推荐）

```conf
shell-integration = true
shell-integration-features = cursor,sudo,title
```

### 主题

```conf
# 使用内置主题
theme = light:Catppuccin Latte,dark:Catppuccin Mocha

# 或自定义颜色
background = 1e1e2e
foreground = cdd6f4
```

### 更多键绑定

```conf
keybind = ctrl+shift+t=new_tab
keybind = ctrl+shift+w=close_surface
keybind = ctrl+tab=next_tab
keybind = ctrl+shift+tab=previous_tab
```

## 故障排除

### 问题：终端行为异常

```bash
# 检查 TERM
echo $TERM
# 应该显示: xterm-256color
```

如果显示 `dumb`，说明配置未生效：

1. 确认配置文件存在：`~/.config/ghostty/config`
2. 检查是否有 `term = xterm-256color` 行
3. 重启 Ghostty

### 问题：配置不生效

Ghostty 可能从其他位置读取配置：

```bash
# 可能的配置位置
~/.config/ghostty/config
~/.ghostty/config
/etc/ghostty/config
```

确保编辑的是正确的文件。

### 问题：设置 Fixedsys 后仍显示 Noto

中文桌面环境下，系统 fontconfig 规则可能把 Noto 排到明确指定的 Fixedsys 前面。运行以下命令，部署用户级 [99-fixedsys-explicit.conf](../fontconfig/conf.d/99-fixedsys-explicit.conf)：

```bash
./install.sh repair-ghostty --user-only
```

仅对明确请求 `Fixedsys Excelsior` 的程序，规则将字体列表替换为 `Fixedsys Excelsior` → `Noto Sans Mono CJK SC` → `Noto Color Emoji`，并移除通用 `monospace` 标记；普通等宽字体请求不受影响。三个字体都需已安装，修复命令不安装字体包。

规则写入 `${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/99-fixedsys-explicit.conf`，内容变化时备份并刷新字体缓存。完全重启 Ghostty 后，在与桌面相同的 `zh_CN.UTF-8` 环境下检查英文、中文、表情和国旗；详见 [Fixedsys 字体修复](../../docs/GHOSTTY_FIX.md#fixedsys-字体优先级修复)。

### 自动修复

```bash
# 使用 Joe 的修复工具
bash scripts/fix_ghostty_term.sh
```

## 参考资源

- [Ghostty 官方文档](https://ghostty.org/docs)
- [配置示例](https://github.com/ghostty-org/ghostty/tree/main/config)
- Joe 故障排除：[docs/GHOSTTY_FIX.md](../../docs/GHOSTTY_FIX.md)

---

**注意**：Joe 的 Shell 安装会备份你现有的 Ghostty 配置（如果存在），备份文件名为 `config.bak.<timestamp>`。
