local logger = require("core.logger")
local periph = require("core.peripherals")

local M = {}
local cfg = {}

function M.start(c)
  cfg = c or {}
  logger.info("generic", "started with relay=" .. tostring(cfg.relay))
end

function M.onTask(msg, progress)
  local relay = cfg.relay and peripheral.wrap(cfg.relay) or periph.wrap(periph.TYPES.redstoneRelay)
  if not relay then
    progress("error", { msg = "no redstone_relay" })
    return
  end
  local side = cfg.side or msg.side or "north"
  local pulseMs = msg.pulseMs or cfg.pulseMs or 200

  relay.setOutput(side, true)
  progress("running", { side = side })
  os.sleep(pulseMs / 1000)
  relay.setOutput(side, false)
  progress("done", {})
end

return M
