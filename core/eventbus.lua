local M = {}
local subs = {}

function M.on(event, handler)
  subs[event] = subs[event] or {}
  table.insert(subs[event], handler)
end

function M.off(event, handler)
  local list = subs[event]
  if not list then return end
  for i, h in ipairs(list) do
    if h == handler then table.remove(list, i); return end
  end
end

function M.emit(event, ...)
  local list = subs[event]
  if not list then return end
  for _, h in ipairs(list) do
    local ok, err = pcall(h, ...)
    if not ok then
      local logger = package.loaded["core.logger"]
      if logger then logger.warn("eventbus", event .. " handler error: " .. tostring(err)) end
    end
  end
end

return M
