-- Drill unload monitor. Watches a buffer inventory (Vault/Chest/Barrel) during
-- mining contraption unload, detects session start/end, streams deltas and
-- final totals to master.
--
-- Config:
--   buffer       = peripheral name of the receiving inventory (required)
--   mode         = "redstone" | "auto" | "both"   (default "both")
--   relay        = peripheral name of redstone_relay (for redstone mode)
--   relaySide    = side on relay reading the trigger ("north" default)
--   idleTimeout  = seconds of no new items before auto-closing session (default 10)
--   drillName    = human label shown in UI ("Drill #1" default)

local periph = require("core.peripherals")
local logger = require("core.logger")
local net    = require("core.rednet_proto")
local util   = require("core.util")

local M = {}
local cfg = {}

local POLL_INTERVAL = 1  -- seconds between inventory polls

local state = {
  session = nil,      -- active session table, or nil
  lastSnapshot = nil, -- previous {itemKey -> count}
  lastItemAt = 0,     -- time of last delta>0
}

local function wrapBuffer()
  if not cfg.buffer then return nil end
  return peripheral.wrap(cfg.buffer)
end

local function wrapRelay()
  return cfg.relay and peripheral.wrap(cfg.relay)
         or periph.wrap(periph.TYPES.redstoneRelay)
end

local function snapshot()
  local buf = wrapBuffer()
  if not buf or not buf.list then return nil end
  local ok, items = pcall(buf.list)
  if not ok or not items then return nil end
  local snap = {}
  for _, item in pairs(items) do
    local key = item.name or "?"
    snap[key] = (snap[key] or 0) + (item.count or 0)
  end
  return snap
end

local function diff(prev, curr)
  local delta = {}
  local added = 0
  for k, v in pairs(curr) do
    local d = v - (prev[k] or 0)
    if d > 0 then delta[k] = d; added = added + d end
  end
  return delta, added
end

local function newSession(reason)
  return {
    id        = util.uuid(),
    drillName = cfg.drillName or ("Drill@" .. os.getComputerID()),
    startedAt = util.now(),
    endedAt   = nil,
    trigger   = reason,
    totals    = {},   -- [itemKey] = count
    total     = 0,
    durationSec = 0,
  }
end

local function pushStart(sess)
  if not cfg.masterId then return end
  net.send(cfg.masterId, {
    type = "drill_session_start",
    session = sess,
  })
  logger.info("drill", "session start (" .. sess.trigger .. ")")
end

local function pushDelta(sess, delta, added)
  if not cfg.masterId then return end
  net.send(cfg.masterId, {
    type = "drill_session_delta",
    sessionId = sess.id,
    delta = delta, added = added,
    totals = sess.totals, total = sess.total,
    elapsedSec = util.now() - sess.startedAt,
  })
end

local function pushEnd(sess)
  sess.endedAt = util.now()
  sess.durationSec = sess.endedAt - sess.startedAt
  if sess.durationSec > 0 then
    sess.ratePerMin = sess.total / (sess.durationSec / 60)
  else
    sess.ratePerMin = 0
  end
  if cfg.masterId then
    net.send(cfg.masterId, {
      type = "drill_session_end",
      session = sess,
    })
  end
  logger.info("drill", ("session end: %d items in %ds (%.1f/min)"):format(
    sess.total, math.floor(sess.durationSec), sess.ratePerMin))
end

local function redstoneActive()
  local r = wrapRelay(); if not r then return false end
  local ok, v = pcall(r.getInput, cfg.relaySide or "north")
  return ok and v or false
end

function M.start(c)
  cfg = c or {}
  cfg.mode = cfg.mode or "both"
  cfg.idleTimeout = cfg.idleTimeout or 10
  state.lastSnapshot = snapshot() or {}
  state.session = nil
  logger.info("drill", "started buffer=" .. tostring(cfg.buffer) .. " mode=" .. cfg.mode)
end

function M.tick()
  local curr = snapshot()
  if not curr then return end
  local prev = state.lastSnapshot or {}
  local delta, added = diff(prev, curr)
  state.lastSnapshot = curr

  local now = util.now()
  local rsOn = (cfg.mode ~= "auto") and redstoneActive()

  -- Start conditions
  if not state.session then
    local starts = false
    local reason = nil
    if cfg.mode ~= "auto" and rsOn then starts = true; reason = "redstone" end
    if cfg.mode ~= "redstone" and added > 0 then starts = true; reason = reason or "auto" end
    if starts then
      state.session = newSession(reason)
      state.lastItemAt = now
      pushStart(state.session)
    end
  end

  if state.session then
    if added > 0 then
      for k, v in pairs(delta) do
        state.session.totals[k] = (state.session.totals[k] or 0) + v
      end
      state.session.total = state.session.total + added
      state.lastItemAt = now
      pushDelta(state.session, delta, added)
    end
    -- End conditions
    local shouldEnd = false
    if cfg.mode == "redstone" then
      if not rsOn then shouldEnd = true end
    elseif cfg.mode == "auto" then
      if now - state.lastItemAt > cfg.idleTimeout then shouldEnd = true end
    else  -- both: end when redstone off AND idle
      local idleDone = now - state.lastItemAt > cfg.idleTimeout
      if (cfg.mode == "both") and not rsOn and idleDone then shouldEnd = true end
    end
    if shouldEnd then
      pushEnd(state.session)
      state.session = nil
    end
  end
end

function M.onMessage(from, msg)
  if msg.type == "drill_status_request" then
    cfg.masterId = from
    net.reply(from, msg, {
      type = "drill_status",
      active = state.session ~= nil,
      session = state.session,
      buffer = cfg.buffer,
      mode = cfg.mode,
      drillName = cfg.drillName,
    })
  elseif msg.type == "drill_force_end" then
    if state.session then pushEnd(state.session); state.session = nil end
    net.reply(from, msg, { type = "drill_force_end_ok" })
  end
end

function M.onTask(msg, progress)
  progress("error", { msg = "drill_unload has no tasks" })
end

return M
