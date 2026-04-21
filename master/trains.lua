local logger = require("core.logger")
local util   = require("core.util")
local net    = require("core.rednet_proto")
local reg    = require("master.registry")

local M = {}

-- Aggregated data from trains-role workers
-- cache = { stations = {...}, trains = {...}, schedules = {...}, lastUpdate }
local cache = { stations = {}, trains = {}, schedules = {}, lastUpdate = 0 }

function M.get() return cache end

function M.onMessage(from, msg)
  if msg.type == "trains_update" then
    cache.stations = msg.stations or cache.stations
    cache.trains   = msg.trains   or cache.trains
    cache.schedules = msg.schedules or cache.schedules
    cache.lastUpdate = util.now()
  end
end

local lastPoll = 0
function M.tick()
  if util.now() - lastPoll < 5 then return end
  lastPoll = util.now()
  for _, w in ipairs(reg.byRole("trains")) do
    if reg.isOnline(w.id) then
      net.send(w.id, { type = "trains_poll" })
    end
  end
end

function M.setSchedule(stationWorkerId, schedule)
  net.send(stationWorkerId, { type = "set_schedule", schedule = schedule })
end

return M
