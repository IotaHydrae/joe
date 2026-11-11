-- Alt+Tab was a searchable menu only. Add MRU quick switching and held cycling.
local M = {}
local session
local alt_down = {}

local function snapshot()
  local active = hl.get_active_window()
  local windows = {}
  for _, window in ipairs(hl.get_windows()) do
    local workspace = window.workspace
    if window.mapped and workspace and (workspace.id > 0 or workspace.name == "special:minimized")
      and window.title ~= "Fcitx5 Input Window" and window.address:match("^0x%x+$") then
      windows[#windows + 1] = window
    end
  end
  table.sort(windows, function(a, b)
    local ac, bc = active and a.address == active.address, active and b.address == active.address
    if ac ~= bc then return not ac end
    local ah, bh = a.focus_history_id, b.focus_history_id
    ah, bh = ah >= 0 and ah or math.huge, bh >= 0 and bh or math.huge
    return ah < bh or (ah == bh and a.address < b.address)
  end)
  local addresses = {}
  for index = 1, math.min(#windows, 500) do
    addresses[index] = '"' .. windows[index].address .. '"'
  end
  return "[" .. table.concat(addresses, ",") .. "]"
end

local function emit(action)
  session.serial = session.serial + 1
  -- Only generated numbers, fixed action names, and validated addresses enter JSON/shell.
  local payload = string.format('{"session":%.0f,"serial":%d,"steps":%d,"action":"%s","addresses":%s}',
    session.id, session.serial, session.steps, action, session.addresses)
  hl.exec_cmd("omarchy-shell shell summon user.window-picker '" .. payload .. "'")
end

function M.step(direction)
  if not session then
    session = { id = math.floor(os.clock() * 1000000), serial = 0,
      steps = direction > 0 and 0 or -2, addresses = snapshot() }
  else
    session.steps = session.steps + direction
  end
  emit("step")
end

function M.finish()
  if not session then return end
  emit("accept")
  session = nil
end

function M.cancel()
  if not session then return end
  emit("cancel")
  session = nil
end

hl.on("config.reloaded", function()
  -- Invalidate even a pending IPC message from the previous configuration.
  session = { id = math.floor(os.clock() * 1000000), serial = 0, steps = 0, addresses = "[]" }
  M.cancel()
end)

o.rebind("ALT + TAB", "Choose next window", function() M.step(1) end)
o.rebind("ALT + SHIFT + TAB", "Choose previous window", function() M.step(-1) end)
o.bind("ALT + ESCAPE", nil, M.cancel)
for _, key in ipairs({ "Alt_L", "Alt_R" }) do
  -- Match keysyms rather than evdev codes: virtual keyboards have their own maps.
  o.bind(key, nil, function() alt_down[key] = true end,
    { transparent = true, ignore_mods = true, non_consuming = true })
  o.bind(key, nil, function()
    alt_down[key] = false
    if not alt_down.Alt_L and not alt_down.Alt_R then M.finish() end
  end, { release = true, transparent = true, ignore_mods = true, non_consuming = true })
end
return M
