-- Integration fragments for ~/.config/hypr/hyprland.lua.
-- Replace require("default.hypr.omarchy") at its original position, before
-- personal modules. Do not load Omarchy defaults separately.
require("hypr.native-window-controls").load_defaults()

-- After personal modules, replace require("default.hypr.toggles") below.
-- Its event handlers must be wrapped while they are registered.
require("hypr.input-method-popups").load_toggles()

-- Load the window behavior fix after the toggles.
require("hypr.maximized-stacking")
