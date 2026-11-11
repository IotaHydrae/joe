-- Keep each window's maximize/fullscreen choice on floating workspaces.
-- Hyprland gives only one window native fullscreen state at a time. Tags
-- preserve the others' choices and geometry, including across config reloads.
local MODE_TAGS = {
  [1] = "user-remembered-maximized",
  [2] = "user-remembered-fullscreen",
}
local pending_restore = {}
local NORMAL_RECT = "user-max-normal_"
local EXPANDED_RECT = "user-max-expanded_"

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
    and not window.pinned and window.fullscreen_handler == "default"
    and window.title ~= "Fcitx5 Input Window" and tagged(window, "omarchy-floating-workspace")
end

local function remembered_mode(window)
  for mode = 2, 1, -1 do
    if tagged(window, MODE_TAGS[mode]) then
      return mode
    end
  end
  return 0
end

local function remember(window, mode)
  for value, tag in pairs(MODE_TAGS) do
    local enabled = value == mode
    if tagged(window, tag) ~= enabled then
      hl.dispatch(hl.dsp.window.tag({
        tag = (enabled and "+" or "-") .. tag, window = window,
      }))
    end
  end
end

local function rectangle(window)
  return { x = window.at.x, y = window.at.y, width = window.size.x, height = window.size.y }
end

local function read_rectangle(window, prefix)
  for _, tag in ipairs(window.tags or {}) do
    if tag:sub(1, #prefix) == prefix then
      local x, y, width, height = tag:sub(#prefix + 1):match("^(%-?%d+)_(%-?%d+)_(%d+)_(%d+)$")
      if x and tonumber(width) > 0 and tonumber(height) > 0 then
        return { x = tonumber(x), y = tonumber(y), width = tonumber(width), height = tonumber(height) }
      end
    end
  end
end

local function write_rectangle(window, prefix, rect)
  local next_tag = rect and string.format("%s%d_%d_%d_%d", prefix,
    rect.x, rect.y, rect.width, rect.height)
  for _, tag in ipairs(window.tags or {}) do
    if tag:sub(1, #prefix) == prefix and tag ~= next_tag then
      hl.dispatch(hl.dsp.window.tag({ tag = "-" .. tag, window = window }))
    end
  end
  if next_tag and not tagged(window, next_tag) then
    hl.dispatch(hl.dsp.window.tag({ tag = "+" .. next_tag, window = window }))
  end
end

local function apply_rectangle(window, rect)
  if not rect or not window.floating or window.fullscreen ~= 0 then
    return
  end
  -- Fractional scaling can round the position after resizing, or the size
  -- after moving. A bounded second pass settles both logical coordinates.
  for _ = 1, 3 do
    if window.size.x ~= rect.width or window.size.y ~= rect.height then
      hl.dispatch(hl.dsp.window.resize({
        x = rect.width, y = rect.height, relative = false, window = window,
      }))
    end
    if window.at.x ~= rect.x or window.at.y ~= rect.y then
      hl.dispatch(hl.dsp.window.move({
        x = rect.x, y = rect.y, relative = false, window = window,
      }))
    end
  end
end

local function queue_focus(window)
  if not supported(window) then
    return
  end
  local address = window.address
  hl.timer(function()
    local active = hl.get_active_window()
    if not supported(active) or active.address ~= address or pending_restore[address] then
      return
    end

    local mode = remembered_mode(active)
    if active.fullscreen == 0 and mode ~= 0 then
      hl.dispatch(hl.dsp.window.fullscreen({
        mode = mode == 2 and "fullscreen" or "maximized", action = "set", window = active,
      }))
    end
    if active.fullscreen == 0 then
      return
    end

    -- A focused floating window can retain permission to cover maximized
    -- windows. Clear it when returning to either kind of fullscreen state.
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
  -- A newly mapped fullscreen window can replace another before it receives
  -- its floating-workspace tag. Record the replacement at the actual event.
  if window and window.workspace and MODE_TAGS[window.fullscreen] then
    for other_address, request in pairs(pending_restore) do
      if other_address ~= window.address and request.workspace == window.workspace.id then
        request.replaced = true
      end
    end
  end
  if not supported(window) then
    return
  end
  local address = window.address
  if MODE_TAGS[window.fullscreen] then
    pending_restore[address] = nil
    remember(window, window.fullscreen)
    write_rectangle(window, EXPANDED_RECT, rectangle(window))
    queue_focus(window)
  elseif window.fullscreen == 0 and remembered_mode(window) ~= 0 then
    -- Replacement first restores the old window, then maximizes the new one.
    -- Inspect the completed transition to distinguish that from a user restore.
    local request = { workspace = window.workspace.id }
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
      local replaced = request.replaced or false
      for _, other in ipairs(hl.get_workspace_windows(tostring(current.workspace.id))) do
        if other.address ~= address and other.fullscreen ~= 0 then
          replaced = true
          break
        end
      end
      if replaced then
        -- Native replacement restores the old floating size. Preserve that
        -- size once, then keep the background window visually maximized too.
        -- Re-entering native fullscreen later remembers its expanded size,
        -- so the original restore rectangle must survive those focus cycles.
        if not read_rectangle(current, NORMAL_RECT) then
          write_rectangle(current, NORMAL_RECT, rectangle(current))
        end
        apply_rectangle(current, read_rectangle(current, EXPANDED_RECT))
      else
        local normal = read_rectangle(current, NORMAL_RECT)
        remember(current, 0)
        apply_rectangle(current, normal)
        write_rectangle(current, NORMAL_RECT, nil)
        write_rectangle(current, EXPANDED_RECT, nil)
      end
    end, { type = "oneshot", timeout = 1 })
  end
end)

hl.on("window.active", queue_focus)

hl.on("window.open", function(window)
  if not window or not window.workspace or window.title == "Fcitx5 Input Window"
    or not tagged(window, "omarchy-floating-workspace") then
    return
  end
  -- Initial fullscreen/active events precede window.open and the workspace
  -- tag. Read the completed open state so newly launched apps are covered too.
  if supported(window) and MODE_TAGS[window.fullscreen] then
    remember(window, window.fullscreen)
    write_rectangle(window, EXPANDED_RECT, rectangle(window))
  end
  queue_focus(window)
end)

hl.on("window.close", function(window)
  if window then
    pending_restore[window.address] = nil
  end
end)

for _, window in ipairs(hl.get_windows()) do
  if supported(window) and MODE_TAGS[window.fullscreen] then
    remember(window, window.fullscreen)
    write_rectangle(window, EXPANDED_RECT, rectangle(window))
  end
end
queue_focus(hl.get_active_window())

-- Explicit user restores must also work while a different window owns the
-- workspace's native fullscreen state. Clear memory before unsetting it so
-- the replacement detector cannot mistake this request for a focus change.
local M = {}
function M.restore(window)
  if not supported(window) then
    return
  end
  local normal = read_rectangle(window, NORMAL_RECT)
  pending_restore[window.address] = nil
  remember(window, 0)
  write_rectangle(window, NORMAL_RECT, nil)
  write_rectangle(window, EXPANDED_RECT, nil)
  if window.fullscreen ~= 0 then
    hl.dispatch(hl.dsp.window.fullscreen({
      mode = window.fullscreen == 1 and "maximized" or "fullscreen", action = "unset", window = window,
    }))
  end
  apply_rectangle(window, normal)
end
return M
