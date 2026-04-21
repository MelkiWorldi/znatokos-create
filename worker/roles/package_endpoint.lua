-- Monitors a Frogport/Postbox: reports package queue to master.
local periph = require("core.peripherals")
local logger = require("core.logger")
local net    = require("core.rednet_proto")
local util   = require("core.util")

local M = {}
local cfg = {}
local lastPush = 0

local function wrap()
  local name = cfg.endpoint
              or periph.findOne(periph.TYPES.frogport)
              or periph.findOne(periph.TYPES.postbox)
  return name and peripheral.wrap(name) or nil, name
end

function M.start(c) cfg = c or {}; logger.info("package", "started") end

function M.tick()
  if util.now() - lastPush < 5 then return end
  lastPush = util.now()
  if not net.getMaster() then return end
  local p = wrap()
  if not p then return end
  local packages = {}
  if p.listPackages then
    local ok, res = pcall(p.listPackages); if ok then packages = res end
  end
  net.sendToMaster({
    type = "package_update",
    address = cfg.address,
    packages = packages,
  })
end

function M.onMessage(from, msg)
  if msg.type == "package_poll" then
    lastPush = 0; M.tick()
  elseif msg.type == "set_address_filter" then
    local p = wrap()
    if p and p.setAddressFilter then
      pcall(p.setAddressFilter, msg.filter)
    end
  end
end

return M
