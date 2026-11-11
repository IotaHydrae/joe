-- Integration fragment for ~/.config/hypr/hyprland.lua, after personal modules.
-- Replace require("default.hypr.toggles") with the wrapper below; do not load
-- the default toggles separately, because their event handlers must be wrapped.
require("hypr.input-method-popups").load_toggles()

-- Load the window behavior fix after the toggles.
require("hypr.maximized-stacking")
