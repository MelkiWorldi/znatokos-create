-- Worker role: proxies to a local CCTL peripheral
local logger = require("core.logger")
local net    = require("core.rednet_proto")

local M = {}
local cfg = {}

local function findCCTL()
  for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t and t:find("total_logistics") then return peripheral.wrap(name), name end
  end
  return nil
end

function M.start(c) cfg = c or {}; logger.info("cctl_bridge", "started") end

function M.onTask(msg, progress)
  local p = findCCTL()
  if not p then progress("error", { msg = "no cctl peripheral" }); return end
  local r = msg.recipe or {}
  local out = r.outputs and r.outputs[1] or {}
  local name = out.item
  local count = (out.count or 1) * (msg.qty or 1)
  if not name then progress("error", { msg = "no output" }); return end
  progress("running", { name = name, count = count })
  local ok, res = pcall(function()
    if p.requestItem then return p.requestItem(name, count) end
    if p.request then return p.request({ name = name, count = count }) end
    error("no method")
  end)
  progress(ok and "done" or "error", { result = res })
end

return M
