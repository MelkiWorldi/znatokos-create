-- Drill sessions aggregator. Keeps last 50 sessions per drill worker and
-- exposes aggregate stats for UI.
local logger = require("core.logger")
local state  = require("core.state")
local util   = require("core.util")
local bus    = require("core.eventbus")
local reg    = require("master.registry")

local M = {}

local HISTORY_PATH = "/factory/data/drills.dat"
local HISTORY_LIMIT = 50  -- per drill

local data = state.load(HISTORY_PATH, {
  drills = {},   -- [workerId] = { name, active?, current?, history = {...} }
})

local function ensureDrill(workerId, name)
  if not data.drills[workerId] then
    data.drills[workerId] = { name = name or ("Drill #" .. workerId), history = {} }
  elseif name then
    data.drills[workerId].name = name
  end
  return data.drills[workerId]
end

local function save() state.save(HISTORY_PATH, data) end

function M.list()
  -- Merge drills with sessions + any registered drill_unload workers that
  -- haven't reported a session yet, so the tab is useful before the first run.
  local r = {}
  local seen = {}
  for id, d in pairs(data.drills) do
    r[#r + 1] = { workerId = id, name = d.name, active = d.active,
                  current = d.current, historyCount = #d.history,
                  online = reg.isOnline(id) }
    seen[id] = true
  end
  for _, w in ipairs(reg.byRole("drill_unload")) do
    if not seen[w.id] then
      local drillName = (w.config and w.config.drillName) or w.label or ("Drill #" .. w.id)
      r[#r + 1] = { workerId = w.id, name = drillName, active = false,
                    current = nil, historyCount = 0, online = reg.isOnline(w.id) }
    end
  end
  table.sort(r, function(a, b) return a.workerId < b.workerId end)
  return r
end

function M.history(workerId)
  local d = data.drills[workerId]
  return d and d.history or {}
end

function M.current(workerId)
  local d = data.drills[workerId]
  return d and d.current or nil
end

function M.onMessage(from, msg)
  if msg.type == "drill_session_start" then
    local d = ensureDrill(from, msg.session.drillName)
    d.active = true
    d.current = msg.session
    save()
    bus.emit("drill_update", from)
  elseif msg.type == "drill_session_delta" then
    local d = ensureDrill(from)
    if d.current and d.current.id == msg.sessionId then
      d.current.totals = msg.totals
      d.current.total = msg.total
      d.current.elapsedSec = msg.elapsedSec
      -- We don't save on every delta to reduce disk churn
    end
    bus.emit("drill_update", from)
  elseif msg.type == "drill_session_end" then
    local d = ensureDrill(from, msg.session.drillName)
    d.active = false
    d.current = nil
    table.insert(d.history, 1, msg.session)
    while #d.history > HISTORY_LIMIT do table.remove(d.history) end
    save()
    logger.info("drills", ("drill #%d session ended: %d items in %ds"):format(
      from, msg.session.total, math.floor(msg.session.durationSec)))
    bus.emit("drill_update", from)
    bus.emit("drill_session_ended", from, msg.session)
  end
end

-- Aggregate stats for a drill
function M.stats(workerId)
  local d = data.drills[workerId]
  if not d then return nil end
  local totalItems, totalDuration, count = 0, 0, #d.history
  local topItems = {}  -- [name] = count
  for _, s in ipairs(d.history) do
    totalItems = totalItems + (s.total or 0)
    totalDuration = totalDuration + (s.durationSec or 0)
    for k, v in pairs(s.totals or {}) do
      topItems[k] = (topItems[k] or 0) + v
    end
  end
  local sorted = {}
  for k, v in pairs(topItems) do sorted[#sorted + 1] = { name = k, count = v } end
  table.sort(sorted, function(a, b) return a.count > b.count end)
  return {
    sessions = count,
    totalItems = totalItems,
    totalDurationSec = totalDuration,
    avgItemsPerSession = count > 0 and totalItems / count or 0,
    avgRatePerMin = totalDuration > 0 and totalItems / (totalDuration / 60) or 0,
    topItems = sorted,  -- full sorted list, UI slices
  }
end

return M
