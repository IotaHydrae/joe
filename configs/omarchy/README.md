# Omarchy 配置存档

[English](README.en.md)

这些配置保存了 Omarchy 浮动工作区的窗口修正和 ChatGPT Desktop 缩放修正。已在 **Omarchy 4.5.0 / Hyprland 0.56.2（Lua 配置）** 验证，供手动按需恢复；Joe 的通用配置导入/导出和 Shell 配置复制不会安装它们，也不会自动安装软件包。

| 文件 | 用途 |
|---|---|
| `hypr/input-method-popups.lua` | 避免 Fcitx 的 X11 候选窗口触发 Omarchy 取消应用最大化 |
| `hypr/maximized-stacking.lua` | 修正最大化窗口的前后层级，并记忆各窗口的最大化选择 |
| `hypr/hyprland-snippet.lua` | 上述两个模块在主配置中的加载方式 |
| `hypr/monitors.example.lua` | 本机 eDP-1 的 125% 缩放与 `GDK_SCALE=1` 示例，需按硬件调整 |
| `applications/chatgpt.desktop` | 使用原生 Wayland 启动 ChatGPT Desktop |

## 恢复窗口修正

在仓库根目录执行以下 Bash 命令，仅复制两个模块；已有同名文件先备份为 `.bak.<时间戳>`：

```bash
omarchy_hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
mkdir -p "$omarchy_hypr_dir"
for omarchy_module in input-method-popups maximized-stacking; do
    omarchy_target="$omarchy_hypr_dir/$omarchy_module.lua"
    if [[ -e "$omarchy_target" || -L "$omarchy_target" ]]; then
        cp -a -- "$omarchy_target" "$omarchy_target.bak.$omarchy_backup_stamp"
    fi
    install -m 644 -- "configs/omarchy/hypr/$omarchy_module.lua" "$omarchy_target"
done
cp -a -- "$omarchy_hypr_dir/hyprland.lua" \
    "$omarchy_hypr_dir/hyprland.lua.bak.$omarchy_backup_stamp"
```

随后编辑现有的 `hyprland.lua`，找到：

```lua
require("default.hypr.toggles")
```

在这个位置用 [`hypr/hyprland-snippet.lua`](hypr/hyprland-snippet.lua) 中的两行替换它：

```lua
require("hypr.input-method-popups").load_toggles()
require("hypr.maximized-stacking")
```

不要覆盖整份 `hyprland.lua`，也不要保留旧语句再追加一份；候选窗口修正需要在默认 toggles 注册事件时介入。若已加载这两个模块，各保留一次即可。只需要最大化修正时，保留原来的 `require("default.hypr.toggles")`，在其后加载 `hypr.maximized-stacking`；只需要候选窗口修正时，仅替换 toggles 语句。

应用并检查：

```bash
hyprctl reload
hyprctl configerrors
```

`configerrors` 应没有错误。浮动工作区中用 **Alt+Tab** / **Shift+Alt+Tab** 双向切换，用 **Super+Alt+F** 最大化或还原（Super 为 Windows 徽标键）。分别最大化两个窗口，再反复切换，确认切回时恢复最大化；主动还原后应保持普通大小。使用 Fcitx 时也可检查输入候选框出现后，当前窗口仍保持最大化。

最大化选择通过窗口 tag 保存，可跨配置重载保留。Hyprland 在同一工作区仍只给一个窗口原生内部最大化状态，模块会在重新聚焦时恢复该窗口的最大化，而不是同时保留两个内部最大化状态。修正只处理 Omarchy 的普通浮动工作区，保留固定窗口和输入法候选窗口的特殊行为。

## 恢复 ChatGPT 缩放修正

需要已安装 `/usr/bin/chatgpt`。在仓库根目录执行：

```bash
test -x /usr/bin/chatgpt
omarchy_apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
mkdir -p "$omarchy_apps_dir"
if [[ -e "$omarchy_apps_dir/chatgpt.desktop" || -L "$omarchy_apps_dir/chatgpt.desktop" ]]; then
    cp -a -- "$omarchy_apps_dir/chatgpt.desktop" \
        "$omarchy_apps_dir/chatgpt.desktop.bak.$omarchy_backup_stamp"
fi
install -m 644 -- configs/omarchy/applications/chatgpt.desktop "$omarchy_apps_dir/chatgpt.desktop"
update-desktop-database "$omarchy_apps_dir"
```

该用户级入口使用 `--ozone-platform=wayland`，适用于此前通过 XWayland 显示过大的界面。完全退出 ChatGPT 后，从应用启动器重新打开，新的启动参数才会生效。

## 可选：显示器缩放

[`hypr/monitors.example.lua`](hypr/monitors.example.lua) 是硬件相关的示例。先备份现有 `monitors.lua`，再按实际输出名称和期望缩放值合并需要的设置；已有相同输出或 `GDK_SCALE` 设置时修改原设置。不要用示例覆盖整份 `monitors.lua`。完成后同样运行 `hyprctl reload` 和 `hyprctl configerrors`；环境变量变化需要重新启动对应应用。

此存档不包含 SSH 密钥、认证信息、Rime 学习词库或生成缓存。
