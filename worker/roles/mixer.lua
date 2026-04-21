local base   = require("worker.roles._machine_base")
local periph = require("core.peripherals")
local logger = require("core.logger")

local M = base.new("mixer")
local cfg = {}
local baseStart = M.start

function M.start(c)
  cfg = c or {}
  baseStart(c)
  logger.info("mixer", "heat=" .. tostring(cfg.heat) .. " burner=" .. tostring(cfg.burnerRelay))
end

-- Mixer needs heat for some recipes. If recipe.heat != "none", we also want the
-- burner redstone on (configured separately).
function M.onTask(msg, progress)
  local relay = cfg.relay and peripheral.wrap(cfg.relay)
                or periph.wrap(periph.TYPES.redstoneRelay)
  if not relay then progress("error", { msg = "no redstone_relay" }); return end
  local side = cfg.side or "north"
  local heatSide = cfg.burnerSide
  local recipe = msg.recipe or {}
  local needHeat = recipe.heat and recipe.heat ~= "none"
  local totalTime = (recipe.duration or 10) * (msg.qty or 1)

  progress("running", { duration = totalTime, heat = recipe.heat })
  if needHeat and heatSide then relay.setOutput(heatSide, true) end
  relay.setOutput(side, true)
  os.sleep(totalTime)
  relay.setOutput(side, false)
  if needHeat and heatSide then relay.setOutput(heatSide, false) end
  progress("done", {})
end

return M
