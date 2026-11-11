# Omarchy configuration archive

[中文](README.md)

These files preserve window fixes for Omarchy floating workspaces and a ChatGPT Desktop scaling fix. They were validated on **Omarchy 4.5.0 / Hyprland 0.56.2 with Lua configuration**. Restore only the parts you need manually: Joe's general configuration import/export and Shell configuration copying do not install these files, and no packages are installed automatically.

| File | Purpose |
|---|---|
| `hypr/input-method-popups.lua` | Prevent an Fcitx X11 candidate window from making Omarchy restore a maximized application |
| `hypr/maximized-stacking.lua` | Fix maximized window stacking and remember each window's maximize choice |
| `hypr/hyprland-snippet.lua` | Load the two modules from the main configuration |
| `hypr/monitors.example.lua` | Hardware-specific example: eDP-1 at 125% and `GDK_SCALE=1` |
| `applications/chatgpt.desktop` | Launch ChatGPT Desktop through native Wayland |

## Restore the window fixes

Run these Bash commands from the repository root. They copy only the two modules, first backing up existing files as `.bak.<timestamp>`:

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

Edit the existing `hyprland.lua` and find:

```lua
require("default.hypr.toggles")
```

Replace it **at that position** with the two lines from [`hypr/hyprland-snippet.lua`](hypr/hyprland-snippet.lua):

```lua
require("hypr.input-method-popups").load_toggles()
require("hypr.maximized-stacking")
```

Keep the rest of `hyprland.lua`. Do not retain the original line and append another copy: the candidate-window fix must intervene while the default toggles register their events. If the modules are already loaded, keep only one load of each. For only the maximize fix, keep `require("default.hypr.toggles")` and load `hypr.maximized-stacking` afterward. For only the candidate-window fix, replace just the toggles line.

Apply and validate:

```bash
hyprctl reload
hyprctl configerrors
```

`configerrors` should report no errors. In a floating workspace, use **Alt+Tab** / **Shift+Alt+Tab** to switch in either direction, and **Super+Alt+F** to maximize or restore (Super is the Windows logo key). Maximize two windows and switch repeatedly: the selected window should return maximized. An explicitly restored window should stay at normal size. With Fcitx, also check that showing a candidate window leaves the application maximized.

A window tag retains its maximize choice across configuration reloads. Hyprland still grants only one native internal maximized state per workspace; the module restores that state when a remembered window regains focus, rather than retaining two internal maximized states simultaneously. The fix handles ordinary Omarchy floating workspaces and preserves the special behavior of pinned windows and input-method candidate windows.

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
