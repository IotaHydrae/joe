# Omarchy 配置存档

[English](README.en.md)

这些配置保存了 Omarchy 浮动工作区的窗口修正和 ChatGPT Desktop 缩放修正。已在 **Omarchy 4.5.0 / Hyprland 0.56.2（Lua 配置）** 验证，供手动按需恢复；Joe 的通用配置导入/导出和 Shell 配置复制不会安装它们，也不会自动安装软件包。

| 文件 | 用途 |
|---|---|
| `hypr/native-window-controls.lua` | 允许软件自带的窗口按钮请求最大化，精确跳过 Omarchy 默认的全局最大化抑制规则 |
| `hypr/input-method-popups.lua` | 普通小窗口打开时保留其它窗口的最大化状态，并排除 Fcitx 的 X11 候选窗口 |
| `hypr/maximized-stacking.lua` | 保留各窗口的最大化/全屏状态和后台大尺寸，独立恢复各自正常尺寸 |
| `hypr/hyprland-snippet.lua` | 上述三个模块在主配置中各自的加载位置 |
| `bin/omarchy-window-picker` | 复用 Omarchy 菜单，按应用名或标题搜索、点击选择已有窗口 |
| `hypr/window-picker-bindings.lua` | 将 Alt+Tab / Shift+Alt+Tab 改为窗口选择列表 |
| `hypr/monitors.example.lua` | 本机 eDP-1 的 125% 缩放与 `GDK_SCALE=1` 示例，需按硬件调整 |
| `applications/chatgpt.desktop` | 使用原生 Wayland 启动 ChatGPT Desktop |

## 恢复窗口修正

在仓库根目录执行以下 Bash 命令，仅复制三个模块；已有同名文件先备份为 `.bak.<时间戳>`：

```bash
omarchy_hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
mkdir -p "$omarchy_hypr_dir"
for omarchy_module in native-window-controls input-method-popups maximized-stacking; do
    omarchy_target="$omarchy_hypr_dir/$omarchy_module.lua"
    if [[ -e "$omarchy_target" || -L "$omarchy_target" ]]; then
        cp -a -- "$omarchy_target" "$omarchy_target.bak.$omarchy_backup_stamp"
    fi
    install -m 644 -- "configs/omarchy/hypr/$omarchy_module.lua" "$omarchy_target"
done
cp -a -- "$omarchy_hypr_dir/hyprland.lua" \
    "$omarchy_hypr_dir/hyprland.lua.bak.$omarchy_backup_stamp"
```

随后按 [`hypr/hyprland-snippet.lua`](hypr/hyprland-snippet.lua) 编辑现有的 `hyprland.lua`，保留其余内容。两处替换各留在原来的位置：

1. 在个人模块之前，将 `require("default.hypr.omarchy")` 替换为：

   ```lua
   require("hypr.native-window-controls").load_defaults()
   ```

2. 在个人模块之后，将 `require("default.hypr.toggles")` 替换为下面两行：

   ```lua
   require("hypr.input-method-popups").load_toggles()
   require("hypr.maximized-stacking")
   ```

不要覆盖整份 `hyprland.lua`，也不要保留被替换的原语句再追加一份。两个包装模块必须在默认配置注册对应规则或事件时介入；已加载的模块各保留一次即可。只需要窗口状态记忆时，可保留原来的两个默认加载语句，仅在 toggles 之后加载 `hypr.maximized-stacking`。新建普通小窗口时保留已有窗口最大化状态的修正位于 `input-method-popups`，与输入法候选窗口修正一起加载；自带最大化按钮修正可单独安装。

应用并检查：

```bash
hyprctl reload
hyprctl configerrors
```

`configerrors` 应没有错误。窗口切换和新窗口打开行为的修正重载后立即生效，不需要重开应用或重启系统。默认最大化抑制属于静态窗口规则；此前已打开的软件需要关闭并重新打开一次，其自带最大化按钮才能采用新规则，无需重启系统。

浮动工作区中切换多个窗口，用 **Super+Alt+F** 最大化或还原，用 **Super+F** 进入或退出真正全屏（Super 为 Windows 徽标键）。下面的可选窗口选择器提供可搜索的切换列表；未安装时保留默认 Alt+Tab / Shift+Alt+Tab 循环切换。分别将多个窗口设为最大化或全屏，再反复切换，确认切回时恢复各自的状态；主动还原某个窗口后，该窗口应恢复自己的正常位置和尺寸，其它已最大化/全屏的窗口仍保持大尺寸。也可启动一个初始全屏的应用，并在切走、切回和配置重载后检查其全屏状态。打开一个普通小窗口，确认它能覆盖在已有最大化窗口上；切回后者时应仍为最大化，而不是被新窗口的打开动作取消。使用 Fcitx 时检查输入候选框出现后，当前窗口仍保持最大化。

模块通过窗口 tag 分别保存最大化（内部 mode 1）或真正全屏（内部 mode 2）的选择，以及各窗口独立的正常矩形和展开矩形，可跨配置重载保留。另一个窗口接管前台最大化/全屏时，后台窗口继续保持展开后的大尺寸；主动还原只恢复目标窗口自己的正常位置和尺寸，并清除它的记忆，不会把其它窗口一起缩小。

Hyprland 在同一工作区仍只给前台窗口原生内部最大化/全屏状态；后台窗口通过几何尺寸和 tag 保留外观，重新聚焦时再恢复原生状态。这不表示多个窗口同时持有原生内部状态或所有应用客户端提示都保持为最大化/全屏。修正适用于 Omarchy 的普通浮动工作区，不按应用名称区分，保留固定窗口、输入法候选窗口及其他布局全屏处理器的特殊行为，并补记初始全屏打开。

最新验证使用飞书、CC Switch、ChatGPT 和 Chromium，在全部最大化及最大化/全屏混合两组场景中通过 22 项检查：多轮聚焦、配置重载和逐一还原时，其它窗口的矩形与状态 tag 均不变。另通过 5 项针对性检查，覆盖应用自身的 Wayland 最大化/还原请求、小窗口同时覆盖两个展开窗口、显式还原被遮挡且未激活的原生最大化窗口、重新聚焦后恢复原尺寸，以及同一事件循环中的替换/还原竞态。

## 可选：Alt+Tab 窗口选择列表

选择器复用 Omarchy 自带菜单，不需要新增依赖。**Alt+Tab** 和 **Shift+Alt+Tab** 都会打开可搜索、可点击的窗口列表，替换原来的前后循环切换。列表按最近使用顺序排列，当前窗口放在后面；输入应用名或窗口标题即可筛选，点击条目或按 **Enter** 确认。按 **Esc** 会先清空已有搜索，再按 **Esc** 取消；取消不改变窗口焦点。这是显式选择列表，松开 Alt 不会自动确认。

在仓库根目录执行，先备份已有同名文件，再安装脚本和独立绑定片段：

```bash
omarchy_bin_dir="$HOME/.local/bin"
omarchy_hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
mkdir -p "$omarchy_bin_dir" "$omarchy_hypr_dir"
for omarchy_target in "$omarchy_bin_dir/omarchy-window-picker" \
    "$omarchy_hypr_dir/window-picker-bindings.lua" "$omarchy_hypr_dir/bindings.lua"; do
    if [[ -e "$omarchy_target" || -L "$omarchy_target" ]]; then
        cp -a -- "$omarchy_target" "$omarchy_target.bak.$omarchy_backup_stamp"
    fi
done
install -m 755 -- configs/omarchy/bin/omarchy-window-picker \
    "$omarchy_bin_dir/omarchy-window-picker"
install -m 644 -- configs/omarchy/hypr/window-picker-bindings.lua \
    "$omarchy_hypr_dir/window-picker-bindings.lua"
```

在现有 `hypr/bindings.lua` 末尾添加下面一行，仅保留一次，并保留其它个人绑定：

```lua
require("hypr.window-picker-bindings")
```

若已有本存档的三行窗口选择器绑定，改为上面的模块加载即可，不要同时保留两份。运行 `hyprctl reload` 和 `hyprctl configerrors` 后生效。已实际验证取消菜单保持原焦点和最大化状态、搜索 `cc-switch` 后确认切换、搜索 `Chatgpt` 后确认切换并恢复最大化。

撤销时从 `bindings.lua` 删除这行加载（或直接添加的三行选择器绑定），再重载配置，Omarchy 默认的 Alt+Tab / Shift+Alt+Tab 循环切换就会恢复。确认没有其它引用后，可删除选择器脚本和绑定片段。

## 撤销窗口修正

在现有 `hyprland.lua` 中，将 `require("hypr.native-window-controls").load_defaults()` 改回 `require("default.hypr.omarchy")`，将 `require("hypr.input-method-popups").load_toggles()` 改回 `require("default.hypr.toggles")`，删除 `require("hypr.maximized-stacking")`。仅撤销部分修正时，只改对应加载语句。运行 `hyprctl reload` 和 `hyprctl configerrors`；若撤销了自带最大化按钮修正，重开相关软件后会重新采用默认静态规则。确认不再引用后，可删除对应用户模块，或从安装前的备份恢复所需文件。

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
