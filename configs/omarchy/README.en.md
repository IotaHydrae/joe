# Omarchy configuration archive

[中文](README.md)

These files preserve window fixes for Omarchy floating workspaces and a ChatGPT Desktop scaling fix. They were validated on **Omarchy 4.5.0 / Hyprland 0.56.2 with Lua configuration**. Restore only the parts you need manually: Joe's general configuration import/export and Shell configuration copying do not install these files, and no packages are installed automatically.

| File | Purpose |
|---|---|
| `hypr/native-window-controls.lua` | Allow application titlebars to request maximization by skipping only Omarchy's stock blanket maximize-suppression rule |
| `hypr/input-method-popups.lua` | Preserve existing maximized windows when a small window opens, and exclude Fcitx X11 candidate windows |
| `hypr/maximized-stacking.lua` | Retain each window's maximize/fullscreen choice and expanded background geometry, with independent normal-size restore |
| `hypr/hyprland-snippet.lua` | Show each of the three modules' positions in the main configuration |
| `bin/omarchy-window-picker` | Reuse Omarchy's menu to search existing windows by application name or title, then click to select |
| `hypr/window-picker-bindings.lua` | Replace Alt+Tab / Shift+Alt+Tab cycling with the window list |
| `hypr/cursor-no-warp.lua` | Keep the pointer in place when switching windows, workspaces, and special workspaces |
| `hypr/monitors.example.lua` | Hardware-specific example: eDP-1 at 125% and `GDK_SCALE=1` |
| `applications/chatgpt.desktop` | Launch ChatGPT Desktop through native Wayland |

## Restore the window fixes

Run these Bash commands from the repository root. They copy only the three modules, first backing up existing files as `.bak.<timestamp>`:

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

Edit the existing `hyprland.lua` using [`hypr/hyprland-snippet.lua`](hypr/hyprland-snippet.lua), keeping the rest of the file. Make both replacements at their original positions:

1. Before the personal modules, replace `require("default.hypr.omarchy")` with:

   ```lua
   require("hypr.native-window-controls").load_defaults()
   ```

2. After the personal modules, replace `require("default.hypr.toggles")` with these two lines:

   ```lua
   require("hypr.input-method-popups").load_toggles()
   require("hypr.maximized-stacking")
   ```

Do not replace the whole `hyprland.lua` or retain a replaced line and append another copy. The two wrappers must intervene while the default configuration registers the relevant rules or events. Keep only one load of each module. For only window-state memory, retain both original default loads and load `hypr.maximized-stacking` after the toggles. Preserving existing maximized windows when an ordinary small window opens is handled by `input-method-popups`, together with the input-method candidate fix. The native-button fix can be installed separately.

Apply and validate:

```bash
hyprctl reload
hyprctl configerrors
```

`configerrors` should report no errors. The window-switching and new-window fixes take effect as soon as the configuration reloads, without reopening applications or restarting the system. Maximize suppression is a static window rule: close and reopen applications that were already running once to apply the native-button fix. No system restart is needed.

Switch between several windows in a floating workspace, using **Super+Alt+F** to maximize or restore, and **Super+F** to enter or leave true fullscreen (Super is the Windows logo key). The optional picker below provides a searchable window list; without it, the default Alt+Tab / Shift+Alt+Tab cycling remains available. Set several windows to maximize or fullscreen and switch repeatedly: each selected window should return to its own state. An explicitly restored window should return to its own normal position and size, while other maximized/fullscreen windows keep their expanded geometry. Also launch an application in fullscreen and check its state after switching away and back, and after reloading the configuration. Open an ordinary small window and check that it can appear above an existing maximized window; switching back should find the latter still maximized, with no restore caused by opening the new window. With Fcitx, check that showing a candidate window leaves the application maximized.

Window tags retain each window's maximization (internal mode 1) or true-fullscreen (internal mode 2) choice, together with its independent normal and expanded rectangles, across configuration reloads. When another window takes the foreground native state, the background window keeps its expanded geometry. Explicitly restoring a window restores only that window's own normal position and size and clears its metadata, leaving the other windows expanded.

Hyprland still grants only the foreground window a native internal maximized/fullscreen state per workspace. Background windows retain their appearance through geometry and tags, then regain their native state when focused. This does not give several windows simultaneous native internal states or guarantee that every application's client hints remain maximized/fullscreen. The fix handles ordinary Omarchy floating workspaces without an application-name filter, preserves pinned windows, input-method candidate windows, and other layouts' fullscreen handlers, and records startup fullscreen.

Latest validation with Feishu, CC Switch, ChatGPT, and Chromium passed 22 checks across two setups: all windows maximized, and mixed maximization/fullscreen. Repeated focus changes, configuration reloads, and restoring windows individually left every other window's rectangle and state tags unchanged. Five additional checks covered application-originated Wayland maximize/restore requests, a small window covering two expanded windows, explicitly restoring an obscured inactive native-maximized window, normal-size restoration after refocusing, and replacement/restore races within the same event-loop turn.

## Optional: Alt+Tab window list

The picker reuses Omarchy's built-in menu and requires no additional dependencies. Both **Alt+Tab** and **Shift+Alt+Tab** open a searchable, clickable window list, replacing forward/backward cycling. Windows are ordered by recent use, with the current window placed last. Type an application name or window title to filter, then click an item or press **Enter** to confirm. **Esc** first clears an existing query; press **Esc** again to cancel. Cancellation keeps the current window focused. This is an explicit selection list: releasing Alt does not confirm a choice.

From the repository root, back up existing files and install the script and separate bindings fragment:

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

Add this line once at the end of the existing `hypr/bindings.lua`, keeping other personal bindings:

```lua
require("hypr.window-picker-bindings")
```

If the three picker-binding lines from this archive are already present directly, replace them with the module load above rather than retaining both. Run `hyprctl reload` and `hyprctl configerrors`. Actual menu checks confirmed that canceling preserves focus and maximization, searching `cc-switch` and confirming selects it, and searching `Chatgpt` and confirming selects it and restores maximization.

To undo, remove this module load (or the three directly added picker-binding lines) from `bindings.lua` and reload. Omarchy's default Alt+Tab / Shift+Alt+Tab cycling will return. Once no other references remain, the picker script and bindings fragment can be removed.

## Optional: keep the pointer in place

[`hypr/cursor-no-warp.lua`](hypr/cursor-no-warp.lua) disables automatic pointer warps on focus changes and sets `warp_on_change_workspace` and `warp_on_toggle_special` to `0`. Install this minimal override from the repository root while preserving existing appearance settings:

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

Add this line once at the end of the existing `hypr/looknfeel.lua`:

```lua
require("hypr.cursor-no-warp")
```

If the same inline `cursor` settings are already present, replace that block with this module load instead of adding duplicates. Run `hyprctl reload` and `hyprctl configerrors`; no application or system restart is needed. Check that selecting another window, changing workspaces, and showing/hiding a special workspace leave the pointer where it was placed.

To undo, remove this module load from `looknfeel.lua` and reload. If personal cursor settings existed before installation, restore those settings from the backup. Once unreferenced, `cursor-no-warp.lua` can be removed. Do not replace the whole appearance configuration with this fragment.

## Undo the window fixes

In the existing `hyprland.lua`, change `require("hypr.native-window-controls").load_defaults()` back to `require("default.hypr.omarchy")`, change `require("hypr.input-method-popups").load_toggles()` back to `require("default.hypr.toggles")`, and remove `require("hypr.maximized-stacking")`. To undo only one fix, change just its corresponding load. Run `hyprctl reload` and `hyprctl configerrors`. After undoing the native-button fix, reopen affected applications to restore the default static rule. Once unreferenced, remove the relevant user modules or restore the needed files from their installation backups.

## Restore the ChatGPT scaling fix

This requires an installed `/usr/bin/chatgpt`. From the repository root:

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

The user launcher passes `--ozone-platform=wayland`, addressing the oversized interface previously seen through XWayland. Fully quit ChatGPT and reopen it from the application launcher to apply the new launch arguments.

## Optional: monitor scaling

[`hypr/monitors.example.lua`](hypr/monitors.example.lua) is hardware-specific. Back up the existing `monitors.lua`, then merge the settings you need with the correct output name and desired scale. Update existing rules for the same output or `GDK_SCALE` rather than duplicating them. Do not replace the entire `monitors.lua` with this example. Run `hyprctl reload` and `hyprctl configerrors` afterward; environment changes require restarting the affected applications.

This archive contains no SSH keys, authentication data, learned Rime dictionaries, or generated caches.
