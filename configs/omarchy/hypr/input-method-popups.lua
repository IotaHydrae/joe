-- Keep the normal floating-workspace open handling, without restoring other
-- maximized windows just because a new small window opens. Input-method
-- candidate windows must not trigger that application-open handling at all.
local M = {}

local function on_open(callback, window, ...)
  if window and window.xwayland and window.title == "Fcitx5 Input Window" then
    return
  end
  if not window or window.fullscreen ~= 0 or not window.workspace then
    return callback(window, ...)
  end

  -- Restrict the override to this one stock callback. Its other work still
  -- claims and arranges the new window normally. Hyprland already allows a
  -- floating window above an existing maximized window without restoring it.
  local fullscreen = hl.dsp.window.fullscreen
  hl.dsp.window.fullscreen = function(spec)
    local other = spec and spec.window
    if spec and spec.mode == "maximized" and spec.action == "unset"
      and other and other.address ~= window.address and other.workspace
      and other.workspace.id == window.workspace.id then
      return function() end
    end
    return fullscreen(spec)
  end

  local result = table.pack(pcall(callback, window, ...))
  hl.dsp.window.fullscreen = fullscreen
  if not result[1] then
    error(result[2], 0)
  end
  return table.unpack(result, 2, result.n)
end

function M.load_toggles()
  local subscribe = hl.on

  hl.on = function(event, callback)
    if event == "window.open"
      and debug.getinfo(callback, "S").source:match("/default/hypr/workspace%-modes%.lua$") then
      return subscribe(event, function(window, ...)
        return on_open(callback, window, ...)
      end)
    end
    return subscribe(event, callback)
  end

  local ok, result = pcall(require, "default.hypr.toggles")
  hl.on = subscribe
  if not ok then
    error(result, 0)
  end
  return result
end

return M
