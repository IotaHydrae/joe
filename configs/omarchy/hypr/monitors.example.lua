-- Optional settings for this laptop, not a replacement for monitors.lua.
-- Check the output name with `hyprctl monitors all` before merging.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.25 })

-- Replace the existing GDK_SCALE setting in monitors.lua with this value.
-- Newly launched GTK/XWayland apps inherit this scale.
hl.env("GDK_SCALE", "1")
