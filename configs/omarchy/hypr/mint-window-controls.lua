-- Familiar Cinnamon shortcuts, with window geometry limited to floating
-- workspaces. Work areas include the current bar/dock reservations.
local M = {}
local NORMAL = "user-mint-snap-normal_"

local function tagged(window, wanted)
  for _, tag in ipairs(window.tags or {}) do
    if tag == wanted then return true end
  end
  return false
end

local function supported(window)
  return window and window.mapped and window.workspace and window.workspace.id > 0
    and window.floating and not window.pinned and window.fullscreen_handler == "default"
    and window.title ~= "Fcitx5 Input Window" and tagged(window, "omarchy-floating-workspace")
end

local function rectangle(window)
  return { x = window.at.x, y = window.at.y, width = window.size.x, height = window.size.y }
end

local function saved_rectangle(window)
  for _, tag in ipairs(window.tags or {}) do
    if tag:sub(1, #NORMAL) == NORMAL then
      local x, y, width, height = tag:sub(#NORMAL + 1):match("^(%-?%d+)_(%-?%d+)_(%d+)_(%d+)$")
      if x and tonumber(width) > 0 and tonumber(height) > 0 then
        return { x = tonumber(x), y = tonumber(y), width = tonumber(width), height = tonumber(height) }
      end
    end
  end
end

local function save_rectangle(window, rect)
  for _, tag in ipairs(window.tags or {}) do
    if tag:sub(1, #NORMAL) == NORMAL then
      hl.dispatch(hl.dsp.window.tag({ tag = "-" .. tag, window = window }))
    end
  end
  if rect then
    hl.dispatch(hl.dsp.window.tag({ tag = string.format("+%s%d_%d_%d_%d", NORMAL,
      rect.x, rect.y, rect.width, rect.height), window = window }))
  end
end

local function apply_rectangle(window, rect)
  for _ = 1, 3 do
    hl.dispatch(hl.dsp.window.resize({ x = rect.width, y = rect.height, relative = false, window = window }))
    hl.dispatch(hl.dsp.window.move({ x = rect.x, y = rect.y, relative = false, window = window }))
  end
end

function M.restore()
  local window = hl.get_active_window()
  if not supported(window) then return end
  local normal = saved_rectangle(window)
  require("hypr.maximized-stacking").restore(window)
  if normal then apply_rectangle(window, normal) end
  save_rectangle(window, nil)
end

function M.maximize()
  local window = hl.get_active_window()
  if not supported(window) then return end
  hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = window }))
end

function M.snap(side)
  local window = hl.get_active_window()
  if not supported(window) then return end
  local normal = saved_rectangle(window)
  require("hypr.maximized-stacking").restore(window)
  if not normal then save_rectangle(window, rectangle(window)) end
  local monitor = window.monitor
  if not monitor then return end
  local width, height = monitor.width, monitor.height
  if monitor.transform % 2 == 1 then width, height = height, width end
  width, height = math.floor(width / monitor.scale + 0.5), math.floor(height / monitor.scale + 0.5)
  local reserved = monitor.reserved
  local x = monitor.position.x + reserved.left
  local y = monitor.position.y + reserved.top
  width = width - reserved.left - reserved.right
  height = height - reserved.top - reserved.bottom
  local left_width = math.floor(width / 2)
  if side == "right" then x = x + left_width; width = width - left_width
  else width = left_width end
  local border = hl.get_config("general.border_size") or 0
  local titlebar = 0
  if hl.get_config("plugin.hyprbars.enabled") then
    titlebar = hl.get_config("plugin.hyprbars.bar_height") or 0
  end
  apply_rectangle(window, { x = x + border, y = y + border + titlebar,
    width = math.max(1, width - border * 2), height = math.max(1, height - border * 2 - titlebar) })
  hl.dispatch(hl.dsp.window.bring_to_top({ window = window }))
end

-- SUPER+L previously cycled layouts. SUPER+ALT+L still cycles backward;
-- move the forward cycle to SUPER+CTRL+ALT+L.
o.rebind("SUPER + L", "Lock system", "omarchy system lock")
o.bind("SUPER + CTRL + ALT + L", "Cycle workspace layout", "omarchy-hyprland-workspace-layout-toggle")
o.rebind("CTRL + ALT + DELETE", "System menu", { menu = "system" })
o.bind("ALT + F4", "Close window", hl.dsp.window.close())
o.bind("SUPER + E", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + D", "Show or restore desktop", function() require("hypr.show-desktop").toggle() end)

for key, direction in pairs({ LEFT = "l", RIGHT = "r", UP = "u", DOWN = "d" }) do
  o.bind("SUPER + CTRL + ALT + " .. key, "Focus window " .. direction, hl.dsp.focus({ direction = direction }))
end
o.rebind("SUPER + LEFT", "Snap window left", function() M.snap("left") end)
o.rebind("SUPER + RIGHT", "Snap window right", function() M.snap("right") end)
o.rebind("SUPER + UP", "Maximize window", M.maximize)
o.rebind("SUPER + DOWN", "Restore window", M.restore)
return M
