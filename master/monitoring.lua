local logger = require("core.logger")
local util   = require("core.util")
local bus    = require("core.eventbus")
local reg    = require("master.registry")

local M = {}

-- Aggregated telemetry from worker status messages
local telemetry = {}  -- [workerId] = { stress = {used, capacity}, fluids = [...], ts }
local alarms = {}     -- list of { id, level, text, ts, acked }
local nextAlarmId = 1

local function raise(level, text)
  local a = { id = nextAlarmId, level = level, text = text, ts = util.now(), acked = false }
  nextAlarmId = nextAlarmId + 1
  alarms[#alarms + 1] = a
  -- Keep only last 100
  while #alarms > 100 do table.remove(alarms, 1) end
  logger.warn("alarm", "[" .. level .. "] " .. text)
  bus.emit("alarm_raised", a)
end

function M.getAlarms() return alarms end

function M.ack(id)
  for _, a in ipairs(alarms) do if a.id == id then a.acked = true end end
end

function M.getTelemetry() return telemetry end

function M.onStatus(from, msg)
  telemetry[from] = {
    stress = msg.stress, fluids = msg.fluids, invs = msg.invs,
    ts = util.now(),
  }
  if msg.stress and msg.stress.capacity and msg.stress.used then
    local pct = msg.stress.capacity > 0 and msg.stress.used / msg.stress.capacity or 0
    if pct >= 0.9 then
      raise("crit", ("stress %d%% on worker #%d"):format(math.floor(pct * 100), from))
    elseif pct >= 0.7 then
      raise("warn", ("stress %d%% on worker #%d"):format(math.floor(pct * 100), from))
    end
  end
  for _, f in ipairs(msg.fluids or {}) do
    if f.capacity and f.capacity > 0 then
      local pct = (f.amount or 0) / f.capacity
      if pct < 0.1 then
        raise("warn", ("low fluid %s on worker #%d (%d%%)"):format(f.name or "?", from, math.floor(pct * 100)))
      elseif pct > 0.95 then
        raise("warn", ("fluid %s near full on worker #%d"):format(f.name or "?", from))
      end
    end
  end
end

function M.onAlarm(from, msg)
  raise(msg.level or "warn", ("[#%d] %s"):format(from, msg.text or ""))
end

-- Worker offline alarms
bus.on("worker_offline", function(w)
  raise("warn", ("worker #%d (%s) offline"):format(w.id, w.role or "?"))
end)

return M
