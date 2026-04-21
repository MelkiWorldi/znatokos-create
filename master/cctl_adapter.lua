-- Optional adapter for Create: CC Total Logistics.
-- On Create 6.0.8+ its author does not recommend using CCTL. This adapter is
-- a fallback for environments where CCTL is present and the native Stock Ticker
-- integration is not working. It delegates by finding a CCTL peripheral and
-- calling requestItem / listItems.
local logger = require("core.logger")

local M = {}

local function findCCTL()
  for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t and t:find("total_logistics") then return peripheral.wrap(name), name end
  end
  return nil
end

function M.available()
  return findCCTL() ~= nil
end

function M.listItems()
  local p = findCCTL()
  if not p then return nil end
  if p.listItems then return p.listItems() end
  if p.list then return p.list() end
  return nil
end

function M.requestItem(name, count, address)
  local p = findCCTL()
  if not p then return false, "no cctl" end
  if p.requestItem then
    return pcall(p.requestItem, name, count, address)
  end
  if p.request then
    return pcall(p.request, { name = name, count = count }, address)
  end
  return false, "no compatible method"
end

return M
