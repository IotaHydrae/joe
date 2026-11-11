-- Let application titlebars request maximization, just like Omarchy's own
-- titlebar. Filter only the stock blanket suppression while loading defaults.
local M = {}

function M.load_defaults()
  local register = hl.window_rule
  hl.window_rule = function(rule)
    local blanket = rule.suppress_event == "maximize" and rule.match
      and rule.match.class == ".*"
    for key in pairs(rule.match or {}) do
      if key ~= "class" then
        blanket = false
      end
    end
    for key in pairs(rule) do
      if key ~= "match" and key ~= "suppress_event" then
        blanket = false
      end
    end
    if blanket then
      for level = 2, 6 do
        local caller = debug.getinfo(level, "S")
        if not caller then
          break
        end
        if caller.source:match("/default/hypr/windows%.lua$") then
          return
        end
      end
    end
    return register(rule)
  end

  local ok, result = pcall(require, "default.hypr.omarchy")
  hl.window_rule = register
  if not ok then
    error(result, 0)
  end
  return result
end

return M
