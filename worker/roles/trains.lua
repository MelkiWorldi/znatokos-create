local periph = require("core.peripherals")
local logger = require("core.logger")
local net    = require("core.rednet_proto")
local util   = require("core.util")

local M = {}
local cfg = {}
local lastPush = 0
local PUSH_INTERVAL = 5

local function collect()
  local out = { stations = {}, trains = {}, schedules = {} }
  -- Train Network Monitor (from Create: Additional Logistics) - global view
  local monName = cfg.monitor or periph.findOne(periph.TYPES.trainNetMonitor)
  if monName then
    local m = peripheral.wrap(monName)
    if m.listStations then
      local ok, res = pcall(m.listStations); if ok then out.stations = res end
    end
    if m.getTrains then
      local ok, res = pcall(m.getTrains); if ok then out.trains = res end
    end
    if m.getSchedules then
      local ok, res = pcall(m.getSchedules); if ok then out.schedules = res end
    end
  end
  -- Fallback/augmentation: wrap all local stations
  for _, stName in ipairs(periph.findAll(periph.TYPES.station)) do
    local st = peripheral.wrap(stName)
    local rec = { peripheral = stName }
    for _, method in ipairs({ "getStationName", "getTrainName", "isTrainPresent", "isTrainImminent", "hasSchedule" }) do
      if st[method] then
        local ok, res = pcall(st[method])
        if ok then rec[method] = res end
      end
    end
    out.stations[#out.stations + 1] = rec
  end
  return out
end

function M.start(c)
  cfg = c or {}
  logger.info("trains", "started monitor=" .. tostring(cfg.monitor))
end

function M.tick()
  if util.now() - lastPush < PUSH_INTERVAL then return end
  lastPush = util.now()
  if not net.getMaster() then return end
  local data = collect()
  net.sendToMaster({
    type = "trains_update",
    stations = data.stations, trains = data.trains, schedules = data.schedules,
  })
end

function M.onMessage(from, msg)
  if msg.type == "trains_poll" then
    lastPush = 0
    M.tick()
  elseif msg.type == "set_schedule" then
    local stName = msg.station or periph.findOne(periph.TYPES.station)
    if not stName then
      net.reply(from, msg, { type = "schedule_set", ok = false, err = "no station" }); return
    end
    local st = peripheral.wrap(stName)
    local ok, err = pcall(st.setSchedule, msg.schedule)
    net.reply(from, msg, { type = "schedule_set", ok = ok, err = ok and nil or tostring(err) })
  end
end

return M
