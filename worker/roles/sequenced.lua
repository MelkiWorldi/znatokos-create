-- Sequenced Assembly: multi-stage recipe. Recipe defines stages in .stages = { {machine="press",duration=5}, ... }
local periph = require("core.peripherals")
local logger = require("core.logger")

local M = {}
local cfg = {}

function M.start(c)
  cfg = c or {}
  logger.info("sequenced", "started")
end

function M.onTask(msg, progress)
  local relay = cfg.relay and peripheral.wrap(cfg.relay)
                or periph.wrap(periph.TYPES.redstoneRelay)
  if not relay then progress("error", { msg = "no redstone_relay" }); return end
  local side = cfg.side or "north"
  local recipe = msg.recipe or {}
  local stages = recipe.stages or { { duration = recipe.duration or 10 } }
  local qty = msg.qty or 1

  for iter = 1, qty do
    for i, stage in ipairs(stages) do
      progress("running", { iteration = iter, stage = i, of = #stages })
      relay.setOutput(side, true)
      os.sleep(stage.duration or 5)
      relay.setOutput(side, false)
      os.sleep(0.3)
    end
  end
  progress("done", {})
end

return M
