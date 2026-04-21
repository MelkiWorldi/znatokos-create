local state  = require("core.state")
local logger = require("core.logger")
local util   = require("core.util")
local bus    = require("core.eventbus")

local M = {}
local PATH = "/factory/data/registry.dat"

local workers = state.load(PATH, {})  -- [id] = { id, label, role, peripherals, config, last_seen, missed_pings, approved }

function M.list() return workers end

function M.get(id) return workers[id] end

function M.byRole(role)
  local r = {}
  for _, w in pairs(workers) do
    if w.role == role and w.approved then r[#r + 1] = w end
  end
  return r
end

function M.upsertHello(id, msg)
  local w = workers[id] or { id = id, approved = false, missed_pings = 0 }
  w.label       = msg.label
  w.peripherals = msg.peripherals or w.peripherals
  if not w.role then w.role = msg.role end
  w.last_seen   = util.now()
  w.missed_pings = 0
  workers[id] = w
  M.save()
  bus.emit("worker_seen", w)
  return w
end

function M.assign(id, role, config)
  local w = workers[id] or { id = id, approved = false, missed_pings = 0 }
  w.role     = role
  w.config   = config or {}
  w.approved = true
  workers[id] = w
  M.save()
  bus.emit("worker_assigned", w)
  return w
end

function M.remove(id)
  workers[id] = nil
  M.save()
  bus.emit("worker_removed", id)
end

function M.markPong(id)
  local w = workers[id]
  if not w then return end
  w.last_seen = util.now()
  w.missed_pings = 0
end

function M.markMissed(id)
  local w = workers[id]
  if not w then return end
  w.missed_pings = (w.missed_pings or 0) + 1
  if w.missed_pings == 3 then
    bus.emit("worker_offline", w)
    logger.warn("registry", "worker " .. id .. " offline")
  end
end

function M.isOnline(id)
  local w = workers[id]
  return w and (w.missed_pings or 0) < 3
end

function M.save() state.save(PATH, workers) end

return M
