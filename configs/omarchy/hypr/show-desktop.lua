-- Super+D hides this workspace's windows, then restores only that group.
-- Window tags keep the restore information through a Hyprland config reload.
local M = {}
local DESKTOP = "special:user-desktop"
local PREFIX = "user-desktop-"
local META = PREFIX .. "state_"
local SAVED = PREFIX .. "saved-"
local busy = false

local function tagged(window, wanted)
  for _, tag in ipairs(window.tags or {}) do
    if tag == wanted then
      return true
    end
  end
  return false
end

local function max_tag(tag)
  return tag == "user-remembered-maximized" or tag == "user-remembered-fullscreen"
    or tag:sub(1, 16) == "user-max-normal_"
    or tag:sub(1, 18) == "user-max-expanded_"
end

local function set_tag(window, tag, enabled)
  hl.dispatch(hl.dsp.window.tag({ tag = (enabled and "+" or "-") .. tag, window = window }))
end

local function clear_metadata(window)
  for _, tag in ipairs(window.tags or {}) do
    if tag:sub(1, #PREFIX) == PREFIX then
      set_tag(window, tag, false)
    end
  end
end

local function on_desktop(window)
  return window.workspace and window.workspace.name == DESKTOP
end

local function read_state(window)
  for _, tag in ipairs(window.tags or {}) do
    if tag:sub(1, #META) == META then
      local workspace, focused, order, mode, x, y, width, height = tag:sub(#META + 1):match(
        "^(%d+)_([01])_(%d+)_([012])_(%-?%d+)_(%-?%d+)_(%d+)_(%d+)$")
      if workspace and tonumber(workspace) > 0 and tonumber(width) > 0 and tonumber(height) > 0 then
        return {
          window = window, workspace = tonumber(workspace), focused = focused == "1",
          order = tonumber(order), mode = tonumber(mode), x = tonumber(x), y = tonumber(y),
          width = tonumber(width), height = tonumber(height),
        }
      end
    end
  end
end

local function save_state(window, active)
  clear_metadata(window)
  local state = {
    window = window, workspace = window.workspace.id,
    focused = active and active.address == window.address or false,
    order = math.max(0, window.focus_history_id or 999999),
    mode = window.fullscreen or 0, x = window.at.x, y = window.at.y,
    width = window.size.x, height = window.size.y,
  }
  set_tag(window, string.format("%s%d_%d_%d_%d_%d_%d_%d_%d", META, state.workspace,
    state.focused and 1 or 0, state.order, state.mode,
    state.x, state.y, state.width, state.height), true)
  for _, tag in ipairs(window.tags or {}) do
    if max_tag(tag) then
      set_tag(window, SAVED .. tag, true)
    end
  end
  return state
end

local function restore_max_tags(window)
  local saved = {}
  for _, tag in ipairs(window.tags or {}) do
    if tag:sub(1, #SAVED) == SAVED then
      saved[tag:sub(#SAVED + 1)] = true
    end
  end
  -- Workspace moves can emit a fullscreen-unset event. Repair the previous
  -- stacking module's tags before giving any restored window focus.
  for _, tag in ipairs(window.tags or {}) do
    if max_tag(tag) and not saved[tag] then
      set_tag(window, tag, false)
    end
  end
  for tag in pairs(saved) do
    set_tag(window, tag, true)
  end
end

local function apply_rectangle(state)
  local window = state.window
  if not window.floating or window.fullscreen ~= 0 then
    return
  end
  -- A fractional monitor scale may round a resize or move; settle both.
  for _ = 1, 3 do
    if window.size.x ~= state.width or window.size.y ~= state.height then
      hl.dispatch(hl.dsp.window.resize({
        x = state.width, y = state.height, relative = false, window = window,
      }))
    end
    if window.at.x ~= state.x or window.at.y ~= state.y then
      hl.dispatch(hl.dsp.window.move({
        x = state.x, y = state.y, relative = false, window = window,
      }))
    end
  end
end

local function restore(workspace, states)
  table.sort(states, function(a, b)
    if a.order == b.order then
      return a.window.address < b.window.address
    end
    return a.order > b.order
  end)
  local focus, original_focus
  for _, state in ipairs(states) do
    local window = state.window
    -- Clear native mode while still hidden, where the stacking module does
    -- not interpret this as the user choosing to restore a visible window.
    if window.fullscreen ~= 0 then
      hl.dispatch(hl.dsp.window.fullscreen({
        mode = window.fullscreen == 2 and "fullscreen" or "maximized",
        action = "unset", window = window,
      }))
    end
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(workspace), follow = false, window = window }))
    if window.workspace and window.workspace.id == workspace then
      -- A native fullscreen window still has its compositor restore rectangle.
      -- Keep that geometry underneath when setting its native mode again.
      if state.mode == 0 then
        apply_rectangle(state)
      end
      restore_max_tags(window)
      if state.mode ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({
          mode = state.mode == 2 and "fullscreen" or "maximized", action = "set", window = window,
        }))
      end
      clear_metadata(window)
      if state.focused then
        focus = window
        original_focus = true
      elseif not original_focus then
        focus = window
      end
    end
  end
  hl.dispatch(hl.dsp.focus({ workspace = tostring(workspace) }))
  if focus then
    hl.dispatch(hl.dsp.focus({ window = focus }))
  end
end

local function toggle()
  local workspace = hl.get_active_workspace()
  if not workspace or workspace.id < 1 then
    return
  end
  local hidden = {}
  for _, window in ipairs(hl.get_windows()) do
    local state = read_state(window)
    if state then
      if not on_desktop(window) then
        -- A user moved this window independently: give up ownership of it.
        clear_metadata(window)
      elseif window.mapped and state.workspace == workspace.id then
        table.insert(hidden, state)
      end
    end
  end
  if #hidden > 0 then
    restore(workspace.id, hidden)
    return
  end

  local visible = hl.get_workspace_windows(tostring(workspace.id))
  local floating_workspace = false
  for _, window in ipairs(visible) do
    if tagged(window, "omarchy-floating-workspace") then
      floating_workspace = true
      break
    end
  end
  if not floating_workspace then
    return
  end
  local active, states = hl.get_active_window(), {}
  for _, window in ipairs(visible) do
    if window.mapped and window.workspace and window.workspace.id == workspace.id
      and not window.pinned and window.title ~= "Fcitx5 Input Window" then
      table.insert(states, save_state(window, active))
    end
  end
  -- Snapshot every window before moving any: native fullscreen replacement
  -- can change another window's state during the first workspace move.
  for _, state in ipairs(states) do
    local window = state.window
    hl.dispatch(hl.dsp.window.move({ workspace = DESKTOP, follow = false, window = window }))
    if not on_desktop(window) then
      clear_metadata(window)
    end
  end
  if #states > 0 then
    -- Keep new launches on the visible workspace instead of the hidden one.
    hl.dispatch(hl.dsp.focus({ workspace = tostring(workspace.id) }))
  end
end

function M.toggle()
  if busy then
    return
  end
  busy = true
  local ok, message = pcall(toggle)
  busy = false
  if not ok then
    error(message)
  end
end

return M
