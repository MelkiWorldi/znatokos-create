-- Aeronautics controller: manages propeller bearing / burner / wheel bearing via Redstone Relay.
-- Config:
--   relay       = peripheral name of redstone_relay
--   burnerSide  = side for burner redstone
--   bearingSide = side for propeller/wheel bearing
--   readerSide  = (optional) blockReader peripheral name for NBT readout
local periph = require("core.peripherals")
local logger = require("core.logger")
local net    = require("core.rednet_proto")
local util   = require("core.util")

local M = {}
local cfg = {}
local lastStatus = 0

local function relay()
  return cfg.relay and peripheral.wrap(cfg.relay)
         or periph.wrap(periph.TYPES.redstoneRelay)
end

function M.start(c)
  cfg = c or {}
  logger.info("aero", "started")
end

function M.onMessage(from, msg)
  local r = relay()
  if not r then return end
  if msg.type == "aero_burner" then
    r.setOutput(cfg.burnerSide or "south", msg.on and true or false)
  elseif msg.type == "aero_bearing" then
    r.setOutput(cfg.bearingSide or "north", msg.on and true or false)
  end
end

function M.onTask(msg, progress)
  local r = relay()
  if not r then progress("error", { msg = "no relay" }); return end
  local action = (msg.recipe and msg.recipe.action) or msg.action or "toggle"
  local side = (msg.recipe and msg.recipe.side) or cfg.bearingSide or "north"
  if action == "on" then r.setOutput(side, true)
  elseif action == "off" then r.setOutput(side, false)
  elseif action == "pulse" then
    r.setOutput(side, true); os.sleep(0.5); r.setOutput(side, false)
  end
  progress("done", { action = action, side = side })
end

function M.tick()
  if util.now() - lastStatus < 5 then return end
  lastStatus = util.now()
  if not net.getMaster() then return end
  local readerName = cfg.readerSide or periph.findOne(periph.TYPES.blockReader)
  local data = {}
  if readerName then
    local reader = peripheral.wrap(readerName)
    local ok, blockData = pcall(reader.getBlockData)
    if ok then data.bearingNBT = blockData end
    local ok2, name = pcall(reader.getBlockName)
    if ok2 then data.blockName = name end
  end
  net.sendToMaster({ type = "aero_status", data = data })
end

return M
