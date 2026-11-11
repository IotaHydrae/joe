# Omarchy 配置存档

[English](README.en.md)

这些配置保存了 Omarchy 浮动工作区的窗口修正和 ChatGPT Desktop 缩放修正。已在 **Omarchy 4.5.0 / Hyprland 0.56.2（Lua 配置）** 验证，供手动按需恢复；Joe 的通用配置导入/导出和 Shell 配置复制不会安装它们，也不会自动安装软件包。

| 文件 | 用途 |
|---|---|
| `hypr/native-window-controls.lua` | 允许软件自带的窗口按钮请求最大化，精确跳过 Omarchy 默认的全局最大化抑制规则 |
| `hypr/input-method-popups.lua` | 普通小窗口打开时保留其它窗口的最大化状态，并排除 Fcitx 的 X11 候选窗口 |
| `hypr/maximized-stacking.lua` | 保留各窗口的最大化/全屏状态和后台大尺寸，独立恢复各自正常尺寸 |
| `hypr/hyprland-snippet.lua` | 上述三个模块在主配置中各自的加载位置 |
| `bin/omarchy-window-picker` | 提供窗口列表、JSON 数据和按地址聚焦，保留独立搜索菜单入口 |
| `hypr/window-picker-bindings.lua` | Alt+Tab 快速切回最近窗口，按住时循环选择、松开 Alt 确认 |
| `plugins/user.window-picker/` | 复用 Omarchy 菜单组件显示按住 Alt 时的延迟窗口列表 |
| `hypr/cursor-no-warp.lua` | 切换窗口、工作区及特殊工作区时保持鼠标位置 |
| `hypr/mint-window-controls.lua` | Mint/Cinnamon 风格的锁屏、窗口、贴边、文件管理器和系统菜单快捷键 |
| `hypr/show-desktop.lua` | 显示当前普通浮动工作区的桌面，再按还原本模块隐藏的窗口 |
| `shell-taskbar-snippet.json` | 内置底部 Dock 自动隐藏设置合并参考，不能替换整份 `shell.json` |
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

## 可选：Alt+Tab 窗口切换器

短按 **Alt+Tab** 会切回最近使用的上一个窗口。按住 Alt 超过 **150 ms** 会显示窗口列表；继续按 **Tab** 选下一项，**Shift+Tab** 选上一项，松开 **Alt** 确认切换。列表按最近使用顺序排列，当前窗口放在后面。该快捷键用于按住 Alt 循环、松开确认。需要按应用名或标题搜索时，单独运行无参数的 `omarchy-window-picker`，无需按住 Alt：在搜索菜单中按 **Enter** 或点击条目选择，**Esc** 先清空已有搜索，再按 **Esc** 取消。取消不改变当前窗口焦点。

切换器使用独立的 `user.window-picker` 插件复用 Omarchy 菜单组件，不替换正常系统菜单，也不需要安装新的软件依赖。从仓库根目录备份并安装脚本、Lua 绑定模块和插件目录：

```bash
omarchy_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
omarchy_bin_dir="$HOME/.local/bin"
omarchy_hypr_dir="$omarchy_config_dir/hypr"
omarchy_plugin_dir="$omarchy_config_dir/omarchy/plugins/user.window-picker"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
mkdir -p "$omarchy_bin_dir" "$omarchy_hypr_dir" "$(dirname -- "$omarchy_plugin_dir")"
for omarchy_target in "$omarchy_bin_dir/omarchy-window-picker" \
    "$omarchy_hypr_dir/window-picker-bindings.lua" "$omarchy_hypr_dir/bindings.lua" \
    "$omarchy_plugin_dir"; do
    if [[ -e "$omarchy_target" || -L "$omarchy_target" ]]; then
        cp -a -- "$omarchy_target" "$omarchy_target.bak.$omarchy_backup_stamp"
    fi
done
install -m 755 -- configs/omarchy/bin/omarchy-window-picker \
    "$omarchy_bin_dir/omarchy-window-picker"
install -m 644 -- configs/omarchy/hypr/window-picker-bindings.lua \
    "$omarchy_hypr_dir/window-picker-bindings.lua"
mkdir -p "$omarchy_plugin_dir"
cp -a -- configs/omarchy/plugins/user.window-picker/. "$omarchy_plugin_dir/"
omarchy-shell shell rescanPlugins
omarchy plugin list
```

等待插件列表出现 `user.window-picker`；若尚未出现，稍候重新运行 `omarchy plugin list`。确认已发现后启用：

```bash
omarchy plugin enable user.window-picker
```

在现有 `hypr/bindings.lua` 末尾添加下面一行，仅保留一次，并保留其它个人绑定：

```lua
require("hypr.window-picker-bindings")
```

若仍有旧版直接调用脚本的三行绑定（`local window_picker` 及两条 `o.rebind`），删除那三行后再加载此模块，避免重复绑定。运行 `hyprctl reload` 和 `hyprctl configerrors` 后生效。

脚本仍支持 `omarchy-window-picker --list` 查看窗口列表；`--json` 输出插件使用的窗口数据，`--focus ADDRESS` 聚焦指定窗口地址。直接运行 `omarchy-window-picker` 仍会打开独立搜索菜单。

撤销时从 `bindings.lua` 删除该模块加载及残留旧版三行绑定，运行 `omarchy plugin disable user.window-picker`，再执行 `hyprctl reload` 和 `hyprctl configerrors`。Omarchy 默认的 Alt+Tab / Shift+Alt+Tab 循环切换会恢复。确认没有其它引用后，可删除脚本、Lua 模块及 `~/.config/omarchy/plugins/user.window-picker` 目录。

## 可选：Mint/Cinnamon 快捷键

Super 为 Windows 徽标键。这组设置保留已有 Alt+Tab 切换器及其它个人绑定，仅替换表中冲突的默认快捷键：

| 快捷键 | 动作 |
|---|---|
| Super+L | 锁屏，替换原来的布局切换 |
| Ctrl+Alt+Delete | 打开系统菜单，替换原来的关闭所有窗口 |
| Alt+F4 | 关闭当前窗口 |
| Super+E | 打开现有 Nautilus 文件管理器 |
| Super+D | 显示当前普通 Floating 工作区的桌面，再按还原 |
| Super+左/右 | 当前浮动窗口贴到工作区左半屏/右半屏 |
| Super+上/下 | 最大化/还原当前浮动窗口 |
| Super+Ctrl+Alt+方向键 | 保留原来的方向聚焦操作 |
| Super+Ctrl+Alt+L、Super+Alt+L | 分别向前、向后切换工作区布局 |

方向键窗口操作只处理普通 Floating 工作区中的非固定浮动窗口，忽略输入法候选窗口；Tiling 和 Scrolling 中可使用备用方向聚焦键。贴边和最大化根据显示器当前预留区域计算空间，包括状态栏和其它面板。Super+D 只隐藏当前普通 Floating 工作区的窗口，不处理其它工作区、固定窗口或原本已最小化的窗口；再次按下只还原本模块隐藏且仍由它管理的窗口，并恢复原焦点与窗口状态。

先按前文安装窗口修正。本模块需要本次更新的 `maximized-stacking.lua` 提供独立还原接口；已有旧版本时也要一并更新。然后在仓库根目录执行：

```bash
omarchy_hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
mkdir -p "$omarchy_hypr_dir"
for omarchy_module in maximized-stacking mint-window-controls show-desktop; do
    omarchy_target="$omarchy_hypr_dir/$omarchy_module.lua"
    if [[ -e "$omarchy_target" || -L "$omarchy_target" ]]; then
        cp -a -- "$omarchy_target" "$omarchy_target.bak.$omarchy_backup_stamp"
    fi
    install -m 644 -- "configs/omarchy/hypr/$omarchy_module.lua" "$omarchy_target"
done
cp -a -- "$omarchy_hypr_dir/bindings.lua" \
    "$omarchy_hypr_dir/bindings.lua.bak.$omarchy_backup_stamp"
```

在现有 `hypr/bindings.lua` 末尾只添加一次下面一行，保留现有绑定和 Alt+Tab 模块；`show-desktop` 由它按需加载，不再添加单独的绑定或加载行：

```lua
require("hypr.mint-window-controls")
```

主配置仍按前文在默认 toggles 后加载 `hypr.maximized-stacking`。运行 `hyprctl reload` 和 `hyprctl configerrors` 应没有错误。锁屏和系统菜单的键位已替换，测试时不要误用原来的布局切换或关闭全部窗口操作。

已用临时窗口验证左右半屏和原尺寸还原、两个最大化窗口独立还原、从最大化贴边、显示桌面及重载后恢复、保留独立最小化窗口、退出真正全屏，以及 Alt+F4 只关闭当前窗口；这些操作中鼠标位置保持不变。锁屏、系统菜单和文件管理器的绑定目标已静态核对。

撤销前，在使用过 Super+D 的各工作区再次按它，还原隐藏窗口；再从 `bindings.lua` 删除 `require("hypr.mint-window-controls")`，运行 `hyprctl reload` 和 `hyprctl configerrors`。默认 Super+L、Ctrl+Alt+Delete 和方向聚焦绑定会恢复。确认没有其它引用后，可删除 `mint-window-controls.lua` 和 `show-desktop.lua`；`maximized-stacking.lua` 若仍用于前文窗口修正，应保留。若安装前已有同名个人快捷键，从备份恢复对应绑定。

## 可选：底部 Dock 自动隐藏

使用 Omarchy 内置 Dock，采用底部自动隐藏的方式：平时让出桌面空间，鼠标移到底部图标栏所在边缘时显示，移开后收起。窗口最大化时仍可从底部唤出；真正全屏时隐藏。固定应用、运行中应用切换、应用网格、右键菜单、拖拽排序和最小化窗口恢复沿用内置行为，顶部状态栏保持原布局。

先备份现有配置，再通过内置命令合并 [`shell-taskbar-snippet.json`](shell-taskbar-snippet.json) 的两个设置：

```bash
omarchy_shell_config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
if [[ -e "$omarchy_shell_config" || -L "$omarchy_shell_config" ]]; then
    cp -a -- "$omarchy_shell_config" "$omarchy_shell_config.bak.$omarchy_backup_stamp"
fi
omarchy dock position bottom
omarchy dock autohide on
```

这些命令保留现有固定应用列表、其它插件和顶部栏设置。不要用片段覆盖整份 `shell.json`，也无需安装自定义 Dock 插件。设置会即时加载；自动隐藏的 Dock 不预留底部窗口工作区。

本机已确认使用内置 `omarchy.dock`、底部位置和自动隐藏设置，底部预留为 **0 个逻辑像素**。

撤销时用 `omarchy dock position <原位置>` 和 `omarchy dock autohide <on|off>` 恢复安装前的两个值；只还原这两个字段，保留后来修改的其它配置。

## 可选：切换时保持鼠标位置

[`hypr/cursor-no-warp.lua`](hypr/cursor-no-warp.lua) 禁用切换焦点时的自动鼠标跳转，并将 `warp_on_change_workspace` 和 `warp_on_toggle_special` 设为 `0`。从仓库根目录安装最小覆盖模块，保留现有外观配置：

```bash
omarchy_hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
mkdir -p "$omarchy_hypr_dir"
for omarchy_target in "$omarchy_hypr_dir/cursor-no-warp.lua" \
    "$omarchy_hypr_dir/looknfeel.lua"; do
    if [[ -e "$omarchy_target" || -L "$omarchy_target" ]]; then
        cp -a -- "$omarchy_target" "$omarchy_target.bak.$omarchy_backup_stamp"
    fi
done
install -m 644 -- configs/omarchy/hypr/cursor-no-warp.lua \
    "$omarchy_hypr_dir/cursor-no-warp.lua"
```

在现有 `hypr/looknfeel.lua` 末尾添加一次：

```lua
require("hypr.cursor-no-warp")
```

若已有相同的内联 `cursor` 设置，将该设置块换成上面的加载语句即可，不要重复添加。运行 `hyprctl reload` 和 `hyprctl configerrors`；无需重开应用或重启系统。检查选择其它窗口、切换工作区及显示/隐藏特殊工作区时，鼠标是否仍停留在原位置。

撤销时删除 `looknfeel.lua` 中的这行加载，然后重载配置。若安装前已有个人鼠标设置，从备份恢复对应设置；确认不再引用后，可删除 `cursor-no-warp.lua`。不要用本片段覆盖整份外观配置。

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
