-- Omarchy's floating-workspace handler treats an X11 input-method popup as a
-- newly opened application and unmaximizes the window being typed into.
-- Skip only that handler for Fcitx's candidate window; retain ordinary window
-- handling and restore the event-registration API immediately after loading.
local M = {}

function M.load_toggles()
  local subscribe = hl.on

  hl.on = function(event, callback)
    if event == "window.open"
      and debug.getinfo(callback, "S").source:match("/default/hypr/workspace%-modes%.lua$") then
      return subscribe(event, function(window, ...)
        if window and window.xwayland and window.title == "Fcitx5 Input Window" then
          return
        end
        return callback(window, ...)
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
