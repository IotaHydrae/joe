# Omarchy configuration archive

[中文](README.md)

These files preserve window fixes for Omarchy floating workspaces and a ChatGPT Desktop scaling fix. They were validated on **Omarchy 4.5.0 / Hyprland 0.56.2 with Lua configuration**. Restore only the parts you need manually: Joe's general configuration import/export and Shell configuration copying do not install these files, and no packages are installed automatically.

A separately installable [Bash preset](bash/README.en.md) provides Starship, fzf, zoxide, and bash-completion. Choose main menu item 1 → Bash, or run `./install.sh shell bash`; this does not apply the desktop configuration below.

| File | Purpose |
|---|---|
| `hypr/native-window-controls.lua` | Allow application titlebars to request maximization by skipping only Omarchy's stock blanket maximize-suppression rule |
| `hypr/input-method-popups.lua` | Preserve existing maximized windows when a small window opens, and exclude Fcitx X11 candidate windows |
| `hypr/maximized-stacking.lua` | Retain each window's maximize/fullscreen choice and expanded background geometry, with independent normal-size restore |
| `hypr/hyprland-snippet.lua` | Show each of the three modules' positions in the main configuration |
| `bin/omarchy-window-picker` | Provide window lists, JSON data, and focus by address; retain a standalone search menu |
| `hypr/window-picker-bindings.lua` | Quickly return to the recent window, cycle while Alt is held, and confirm on release |
| `plugins/user.window-picker/` | Show application icons in the held-Alt window list using Omarchy's themed base components |
| `plugins/lsp.dock/` | Reuse the system Dock visuals while matching Feishu windows with missing Wayland application identities |
| `bin/omarchy-feishu-window-map` | Verify Feishu windows through their PID executable for the Dock compatibility plugin |
| `hypr/cursor-no-warp.lua` | Keep the pointer in place when switching windows, workspaces, and special workspaces |
| `hypr/mint-window-controls.lua` | Mint/Cinnamon-style lock, window, snapping, file-manager, and system-menu shortcuts |
| `hypr/show-desktop.lua` | Show the current ordinary floating workspace's desktop, then restore the windows hidden by this module |
| `shell-taskbar-snippet.json` | Built-in bottom Dock auto-hide settings to merge; not a replacement for the full `shell.json` |
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

## Optional: Alt+Tab window switcher

A quick **Alt+Tab** returns to the previously used window. Hold Alt for more than **150 ms** to show the window list; press **Tab** again to select the next item or **Shift+Tab** for the previous item, then release **Alt** to confirm. Each row shows an application icon, with the application name and window title/workspace information on two lines. Unmatched applications use a generic icon. Windows remain ordered by recent use, with the current window placed last. For a separate application-name/title search, run `omarchy-window-picker` without arguments or holding Alt: that entry retains the original text search menu. Use **Enter** or click an item to confirm, **Esc** to clear an existing query, then **Esc** again to cancel. Cancellation keeps the current window focused.

The separate `user.window-picker` plugin uses `WindowList.qml`, which reuses Omarchy's `OverlayWindow`, `FilterInput`, and other themed base components. Text is rendered as plain text. It does not replace the normal system menu or require additional software dependencies. Icons are resolved from installed desktop entries. When Feishu omits its application identity, the script first verifies that `/proc/<PID>/exe` resolves to `/opt/bytedance/feishu/feishu` before associating its icon; this does not depend on the Dock compatibility helper. From the repository root, back up existing files and install the helper script, Lua bindings module, and whole plugin directory:

```bash
omarchy_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
omarchy_bin_dir="$HOME/.local/bin"
omarchy_hypr_dir="$omarchy_config_dir/hypr"
omarchy_plugin_dir="$omarchy_config_dir/omarchy/plugins/user.window-picker"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
mkdir -p "$omarchy_bin_dir" "$omarchy_hypr_dir" "$(dirname -- "$omarchy_plugin_dir")"
for omarchy_target in "$omarchy_bin_dir/omarchy-window-picker" \
    "$omarchy_hypr_dir/window-picker-bindings.lua" "$omarchy_hypr_dir/bindings.lua"; do
    if [[ -e "$omarchy_target" || -L "$omarchy_target" ]]; then
        cp -a -- "$omarchy_target" "$omarchy_target.bak.$omarchy_backup_stamp"
    fi
done
if [[ -e "$omarchy_plugin_dir" || -L "$omarchy_plugin_dir" ]]; then
    omarchy_plugin_backup="$omarchy_config_dir/omarchy/plugin-backups/user.window-picker.bak.$omarchy_backup_stamp"
    mkdir -p "$(dirname -- "$omarchy_plugin_backup")"
    cp -a -- "$omarchy_plugin_dir" "$omarchy_plugin_backup"
fi
install -m 755 -- configs/omarchy/bin/omarchy-window-picker \
    "$omarchy_bin_dir/omarchy-window-picker"
install -m 644 -- configs/omarchy/hypr/window-picker-bindings.lua \
    "$omarchy_hypr_dir/window-picker-bindings.lua"
mkdir -p "$omarchy_plugin_dir"
cp -a -- configs/omarchy/plugins/user.window-picker/. "$omarchy_plugin_dir/"
omarchy-shell shell rescanPlugins
omarchy plugin list
```

Wait until `user.window-picker` appears in the plugin list. If it has not appeared, wait briefly and run `omarchy plugin list` again. Enable it only after discovery:

```bash
omarchy plugin enable user.window-picker
```

Add this line once at the end of the existing `hypr/bindings.lua`, keeping other personal bindings:

```lua
require("hypr.window-picker-bindings")
```

If the old three direct-script binding lines remain (`local window_picker` and two `o.rebind` calls), remove them before loading this module to avoid duplicate bindings. Run `hyprctl reload` and `hyprctl configerrors` to apply. If a plugin update still shows the cached old list, run `omarchy restart shell` once; applications and the system do not need restarting.

The helper still supports `omarchy-window-picker --list` with its original text format. `--json` outputs the plugin's window data, including `appId`, `initialAppId`, and `desktopId` for icon matching, plus `label` and `detail` for display. `--focus ADDRESS` focuses a specified window address. Running `omarchy-window-picker` without arguments still opens the standalone text search menu.

Visual checks confirmed icons for Brave, Feishu, CC Switch, ChatGPT, and other applications. Switching checks passed quick return, forward/backward selection, Alt-release confirmation, search/Enter, cancellation, and delayed-event handling. Helper checks preserve MRU order, the original text-list format, and plain-text title handling.

To undo, remove the module load and any old three-line direct bindings from `bindings.lua`, run `omarchy plugin disable user.window-picker`, then run `hyprctl reload` and `hyprctl configerrors`. Omarchy's default Alt+Tab / Shift+Alt+Tab cycling will return. Once unreferenced, the script, Lua module, and `~/.config/omarchy/plugins/user.window-picker` directory can be removed.

## Optional: Mint/Cinnamon shortcuts

Super is the Windows logo key. These settings retain the existing Alt+Tab switcher and other personal bindings, replacing only the conflicting default shortcuts shown below:

| Shortcut | Action |
|---|---|
| Super+L | Lock the screen, replacing the former layout cycle |
| Ctrl+Alt+Delete | Open the system menu, replacing close-all-windows |
| Alt+F4 | Close the current window |
| Super+E | Open the existing Nautilus file manager |
| Super+D | Show the current ordinary Floating workspace's desktop; press again to restore |
| Super+Left/Right | Snap the current floating window to the left/right half of the work area |
| Super+Up/Down | Maximize/restore the current floating window |
| Super+Ctrl+Alt+arrow | Retain directional window focus on an alternate shortcut |
| Super+Ctrl+Alt+L, Super+Alt+L | Cycle workspace layouts forward and backward respectively |

Arrow-key window operations handle unpinned floating windows on ordinary Floating workspaces and ignore input-method candidate windows. Use the alternate directional-focus shortcuts in Tiling and Scrolling. Snapping and maximization use the monitor's current reserved work area, including the status bar and other panels. Super+D hides only the current ordinary Floating workspace's windows, excluding other workspaces, pinned windows, and windows already minimized. Pressing it again restores only the windows it hid and still manages, including their previous focus and window states.

Install the window fixes above first. This module requires the updated `maximized-stacking.lua` and its independent restore interface, so update that file even if an older version is already installed. Then run from the repository root:

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

Add this line once at the end of the existing `hypr/bindings.lua`, keeping existing bindings and the Alt+Tab module. It loads `show-desktop` when needed; do not add another binding or load for that module:

```lua
require("hypr.mint-window-controls")
```

The main configuration must still load `hypr.maximized-stacking` after the default toggles, as described above. Run `hyprctl reload` and `hyprctl configerrors`; there should be no errors. The lock and system-menu keys replace former actions, so do not invoke them expecting layout cycling or close-all-windows during testing.

Disposable windows verified left/right snapping and normal-size restoration, independent restoration of two maximized windows, snapping from maximized state, showing/restoring the desktop across a config reload, leaving independently minimized windows hidden, exiting true fullscreen, and Alt+F4 closing only the active window. The pointer stayed fixed during these operations. Lock, system-menu, and file-manager binding targets were checked statically.

To undo, first press Super+D again on each workspace where it hid windows. Remove `require("hypr.mint-window-controls")` from `bindings.lua`, then run `hyprctl reload` and `hyprctl configerrors`. Default Super+L, Ctrl+Alt+Delete, and directional-focus bindings return. Once unreferenced, remove `mint-window-controls.lua` and `show-desktop.lua`. Retain `maximized-stacking.lua` if it still provides the window fixes above. If personal shortcuts existed before installation, restore their corresponding bindings from the backup.

## Optional: auto-hiding bottom Dock

Use Omarchy's built-in Dock at the bottom with auto-hide enabled. It leaves desktop space free until the pointer reaches the bottom edge beneath its icon strip, then hides after the pointer leaves. It remains available from that edge when windows are maximized and stays hidden during true fullscreen. Pinned applications, running-app switching, the application grid, context menus, drag reordering, and minimized-window restoration keep their built-in behavior. The top status bar retains its layout.

Back up the existing configuration, then use the built-in commands to merge the two settings from [`shell-taskbar-snippet.json`](shell-taskbar-snippet.json):

```bash
omarchy_shell_config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
if [[ -e "$omarchy_shell_config" || -L "$omarchy_shell_config" ]]; then
    cp -a -- "$omarchy_shell_config" "$omarchy_shell_config.bak.$omarchy_backup_stamp"
fi
omarchy dock position bottom
omarchy dock autohide on
```

These commands retain existing Dock pins, other plugins, and top-bar settings. Do not replace the full `shell.json` with the fragment. Auto-hide itself needs no custom plugin; install the next section's compatibility plugin only to recognize Feishu windows with empty application identities. Settings reload immediately, and an auto-hiding Dock reserves no bottom window work area.

Bottom auto-hide was confirmed to reserve **0 logical pixels** of bottom window work area. The Feishu compatibility plugin below uses the same settings.

To undo, use `omarchy dock position <previous-position>` and `omarchy dock autohide <on|off>` to restore the previous two values. Restore only those fields, preserving other configuration changes made later.

## Optional: Feishu Dock compatibility

Some native Wayland Feishu windows report no application identity and are filtered out by the system Dock. The `--class=bytedance-feishu` launch argument did not fix that behavior on this machine. This fix uses a `lsp.dock` user copy to retain the Dock's appearance and operations while adding identity matching for those Feishu windows. Its entry reuses the system `DockWindow`, application grid, and Dock model components without modifying files under `/usr/share/omarchy`.

The helper reads Hyprland's client list and identifies Feishu only when the application identity is empty and `/proc/<PID>/exe` resolves to `/opt/bytedance/feishu/feishu`. The plugin cross-checks window address and PID instead of matching window titles. The installed Feishu desktop entry must be `bytedance-feishu.desktop`. This fix retains existing bottom auto-hide, pinned applications, and other plugins; it does not automatically pin Feishu.

Back up and install from the repository root:

```bash
omarchy_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
omarchy_bin_dir="$HOME/.local/bin"
omarchy_plugin_dir="$omarchy_config_dir/omarchy/plugins/lsp.dock"
omarchy_shell_config="$omarchy_config_dir/omarchy/shell.json"
omarchy_backup_stamp=$(date +%Y%m%d%H%M%S%N)
mkdir -p "$omarchy_bin_dir" "$(dirname -- "$omarchy_plugin_dir")"
for omarchy_target in "$omarchy_bin_dir/omarchy-feishu-window-map" \
    "$omarchy_shell_config"; do
    if [[ -e "$omarchy_target" || -L "$omarchy_target" ]]; then
        cp -a -- "$omarchy_target" "$omarchy_target.bak.$omarchy_backup_stamp"
    fi
done
if [[ -e "$omarchy_plugin_dir" || -L "$omarchy_plugin_dir" ]]; then
    omarchy_plugin_backup="$omarchy_config_dir/omarchy/plugin-backups/lsp.dock.bak.$omarchy_backup_stamp"
    mkdir -p "$(dirname -- "$omarchy_plugin_backup")"
    cp -a -- "$omarchy_plugin_dir" "$omarchy_plugin_backup"
fi
install -m 755 -- configs/omarchy/bin/omarchy-feishu-window-map \
    "$omarchy_bin_dir/omarchy-feishu-window-map"
mkdir -p "$omarchy_plugin_dir"
cp -a -- configs/omarchy/plugins/lsp.dock/. "$omarchy_plugin_dir/"
omarchy plugin validate "$omarchy_plugin_dir"
omarchy-shell shell rescanPlugins
omarchy plugin list
```

Wait until `lsp.dock` is discovered, then enable it:

```bash
omarchy plugin enable lsp.dock
```

The manifest's `clonedFrom: "omarchy.dock"` tells Omarchy to switch from the original Dock to the user copy. Do not enable both Docks simultaneously or overwrite the full `shell.json`. If the old component remains cached, run `omarchy restart shell` once; Feishu and the system do not need restarting. After upgrading Omarchy, confirm this entry still works with the system Dock components.

Live checks confirmed that running Feishu appears in the Dock model, activation focuses its existing window, and activation restores it after minimizing. The pointer stayed fixed and exactly one Dock surface remained loaded. Helper and model checks cover unrelated processes, spoofed titles, address/PID mismatches, and invalid input. Run `omarchy-shell user.feishu-dock status` to inspect identity matching.

To undo, run these commands while retaining existing Dock position, auto-hide, and pins:

```bash
omarchy plugin disable lsp.dock
omarchy plugin enable omarchy.dock
```

Once the system Dock is in use, remove the user `lsp.dock` directory and `~/.local/bin/omarchy-feishu-window-map` if desired. Run `omarchy restart shell` once if an old component remains visible.

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
