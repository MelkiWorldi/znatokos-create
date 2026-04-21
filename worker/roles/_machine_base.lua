-- Base machine role: pulses a Redstone Relay output for recipe.duration seconds.
-- Specific roles (mixer, press, etc.) can override if they need machine-specific logic.
local periph = require("core.peripherals")
local logger = require("core.logger")

local M = {}

function M.new(name)
  local role = { _name = name }
  local cfg = {}

  function role.start(c)
    cfg = c or {}
    logger.info(name, "started (relay=" .. tostring(cfg.relay) .. " side=" .. tostring(cfg.side) .. ")")
  end

  function role.onTask(msg, progress)
    local relay
    if cfg.relay then relay = peripheral.wrap(cfg.relay)
    else relay = periph.wrap(periph.TYPES.redstoneRelay) end
    if not relay then progress("error", { msg = "no redstone_relay" }); return end

    local side = cfg.side or "north"
    local duration = (msg.recipe and msg.recipe.duration) or 10
    local qty = msg.qty or 1
    local totalTime = duration * qty

    progress("running", { duration = totalTime })
    relay.setOutput(side, true)
    os.sleep(totalTime)
    relay.setOutput(side, false)
    progress("done", {})
  end

  return role
end

return M
