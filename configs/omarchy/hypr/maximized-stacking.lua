-- Keep independent maximize choices on Omarchy floating workspaces. Hyprland
-- gives only one window native maximization at a time; remember the others and
-- restore their native maximization when they regain focus. A window tag keeps
-- this choice across config reloads without changing application protocols.
local MAXIMIZED_TAG = "user-remembered-maximized"
local opening = {}
local pending_restore = {}

local function tagged(window, tag)
  for _, value in ipairs(window.tags or {}) do
    if value == tag then
      return true
    end
  end
  return false
end

local function supported(window)
  return window and window.mapped and window.workspace and window.workspace.id >= 1
    and window.floating and not window.pinned and window.fullscreen_handler == "default"
    and window.title ~= "Fcitx5 Input Window" and tagged(window, "omarchy-floating-workspace")
end

local function remember(window, maximized)
  if tagged(window, MAXIMIZED_TAG) ~= maximized then
    hl.dispatch(hl.dsp.window.tag({
      tag = (maximized and "+" or "-") .. MAXIMIZED_TAG, window = window,
    }))
  end
end

local function queue_focus(window)
  if not supported(window) then
    return
  end
  local address = window.address
  hl.timer(function()
    local active = hl.get_active_window()
    if not supported(active) or active.address ~= address or active.fullscreen == 2
      or pending_restore[address] then
      return
    end

    if active.fullscreen == 0 and tagged(active, MAXIMIZED_TAG) then
      hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = active }))
    end
    if active.fullscreen ~= 1 then
      return
    end

    -- A focused floating window can retain permission to cover maximized
    -- windows. Clear that permission when returning to a maximized window.
    local windows = hl.get_workspace_windows(tostring(active.workspace.id))
    for index = #windows, 1, -1 do
      local other = windows[index]
      if other.address ~= address and other.floating and other.fullscreen == 0
        and other.allowed_over_fullscreen and not other.pinned
        and other.title ~= "Fcitx5 Input Window" then
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = other }))
      end
    end
  end, { type = "oneshot", timeout = 2 })
end

hl.on("window.fullscreen", function(window)
  if not supported(window) then
    return
  end
  local address = window.address
  if window.fullscreen == 1 then
    pending_restore[address] = nil
    remember(window, true)
    queue_focus(window)
  elseif window.fullscreen == 0 and tagged(window, MAXIMIZED_TAG) then
    -- Replacement first restores the old window, then maximizes the new one.
    -- Inspect the completed transition to distinguish that from a user restore.
    local request = {}
    pending_restore[address] = request
    hl.timer(function()
      if pending_restore[address] ~= request then
        return
      end
      pending_restore[address] = nil
      local current = hl.get_window("address:" .. address)
      if not supported(current) or current.fullscreen ~= 0 then
        return
      end
      local replaced = opening[current.workspace.id] ~= nil
      for _, other in ipairs(hl.get_workspace_windows(tostring(current.workspace.id))) do
        if other.address ~= address and other.fullscreen == 1 then
          replaced = true
          break
        end
      end
      remember(current, replaced)
    end, { type = "oneshot", timeout = 1 })
  end
end)

hl.on("window.active", queue_focus)

hl.on("window.open", function(window)
  if not window or not window.workspace or window.title == "Fcitx5 Input Window"
    or not tagged(window, "omarchy-floating-workspace") then
    return
  end
  -- Omarchy also restores an existing maximized window when an app opens.
  -- Keep its remembered choice; the new app can still appear in front normally.
  local workspace = window.workspace.id
  local request = {}
  opening[workspace] = request
  hl.timer(function()
    if opening[workspace] == request then
      opening[workspace] = nil
    end
  end, { type = "oneshot", timeout = 5 })
end)

hl.on("window.close", function(window)
  if window then
    pending_restore[window.address] = nil
  end
end)

for _, window in ipairs(hl.get_windows()) do
  if supported(window) and window.fullscreen == 1 then
    remember(window, true)
  end
end
queue_focus(hl.get_active_window())
