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
--   monitor      = peripheral name of monitor (optional, auto-detect if omitted)
--   showLocal    = set to false to disable local monitor render (default true)

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
  history = {},       -- last N finished sessions (for local monitor)
}
local LOCAL_HISTORY_LIMIT = 10

local function wrapBuffer()
  if not cfg.buffer then return nil end
  return peripheral.wrap(cfg.buffer)
end

local function wrapMonitor()
  if cfg.showLocal == false then return nil end
  local name = cfg.monitor or periph.findOne("monitor")
  return name and peripheral.wrap(name) or nil
end

local function fmtDuration(sec)
  sec = math.floor(sec)
  if sec < 60 then return sec .. "s" end
  local m = math.floor(sec / 60); local s = sec - m * 60
  return string.format("%dm%02ds", m, s)
end

local function shortItem(k)
  local s = k:gsub("^minecraft:", ""):gsub("^create:", "c/")
  return s
end

local function renderMonitorImpl()
  local m = wrapMonitor()
  if not m then
    logger.warn("drill", "renderMonitor: no monitor (cfg.monitor=" .. tostring(cfg.monitor) .. ", showLocal=" .. tostring(cfg.showLocal) .. ")")
    return
  end
  m.setTextScale(0.5)
  m.setBackgroundColor(colors.black); m.clear()
  local w, h = m.getSize()

  -- Config sanity check first — if misconfigured, show that loudly.
  if not cfg.buffer or not peripheral.wrap(cfg.buffer) then
    m.setCursorPos(1, 1); m.setTextColor(colors.red)
    m.write("DRILL NOT CONFIGURED")
    m.setCursorPos(1, 3); m.setTextColor(colors.white)
    m.write("Buffer: " .. tostring(cfg.buffer or "<unset>"))
    m.setCursorPos(1, 5); m.setTextColor(colors.yellow)
    m.write("Run on this computer:")
    m.setCursorPos(1, 6); m.setTextColor(colors.lime)
    m.write("  fct setup drill_unload")
    return
  end

  -- Header
  m.setCursorPos(1, 1); m.setTextColor(colors.yellow)
  m.write((cfg.drillName or ("Drill #" .. os.getComputerID())):sub(1, w))

  -- Status line
  m.setCursorPos(1, 2); m.setTextColor(colors.lightGray)
  if state.session then
    local elapsed = util.now() - state.session.startedAt
    local rate = elapsed > 0 and state.session.total / (elapsed / 60) or 0
    m.setTextColor(colors.lime)
    m.write(("ACTIVE %s   %d items   %.1f/min"):format(
      fmtDuration(elapsed), state.session.total, rate))
  else
    m.setTextColor(colors.gray)
    m.write("idle")
  end

  -- Top items of current or latest session
  local sess = state.session or state.history[1]
  m.setCursorPos(1, 4); m.setTextColor(colors.white)
  m.write(state.session and "Current haul:" or "Last session:")
  if sess and sess.totals then
    local list = {}
    for k, v in pairs(sess.totals) do list[#list + 1] = { k = k, v = v } end
    table.sort(list, function(a, b) return a.v > b.v end)
    local y = 5
    for i, it in ipairs(list) do
      if y > h - 4 or i > 12 then break end
      m.setCursorPos(1, y); m.setTextColor(colors.white)
      m.write(shortItem(it.k):sub(1, w - 9))
      m.setCursorPos(math.max(1, w - 7), y); m.setTextColor(colors.lightBlue)
      m.write(tostring(it.v))
      y = y + 1
    end
  end

  -- History summary (last 3)
  m.setCursorPos(1, h - 3); m.setTextColor(colors.yellow)
  m.write(("History (%d):"):format(#state.history))
  for i = 1, math.min(3, #state.history) do
    local s = state.history[i]
    m.setCursorPos(1, h - 3 + i); m.setTextColor(colors.lightGray)
    m.write(("#%d  %s  %d  %.1f/min"):format(
      i, fmtDuration(s.durationSec or 0), s.total or 0, s.ratePerMin or 0):sub(1, w))
  end
end

local function renderMonitor()
  local ok, err = pcall(renderMonitorImpl)
  if not ok then logger.error("drill", "render error: " .. tostring(err)) end
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
  net.sendToMaster({
    type = "drill_session_start",
    session = sess,
  })
  logger.info("drill", "session start (" .. sess.trigger .. ") -> master=" .. tostring(net.getMaster()))
end

local function pushDelta(sess, delta, added)
  net.sendToMaster({
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
  net.sendToMaster({
    type = "drill_session_end",
    session = sess,
  })
  logger.info("drill", ("session end: %d items in %ds (%.1f/min)"):format(
    sess.total, math.floor(sess.durationSec), sess.ratePerMin))
  table.insert(state.history, 1, sess)
  while #state.history > LOCAL_HISTORY_LIMIT do table.remove(state.history) end
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
  state.history = {}
  logger.info("drill", "started buffer=" .. tostring(cfg.buffer) .. " mode=" .. cfg.mode)
  if not cfg.buffer then
    logger.error("drill", "NO BUFFER CONFIGURED — run `fct setup drill_unload` on this computer")
  elseif not peripheral.wrap(cfg.buffer) then
    logger.error("drill", "buffer '" .. cfg.buffer .. "' is not attached / not reachable")
  end
  renderMonitor()
end

function M.tick()
  local curr = snapshot()
  if not curr then
    state._noSnapCount = (state._noSnapCount or 0) + 1
    if state._noSnapCount % 15 == 1 then
      logger.warn("drill", "snapshot() returned nil — buffer '" .. tostring(cfg.buffer) .. "' not reachable or not an inventory")
    end
    return
  end
  local prev = state.lastSnapshot or {}
  local delta, added = diff(prev, curr)
  state.lastSnapshot = curr

  local now = util.now()
  local rsOn = (cfg.mode ~= "auto") and redstoneActive()

  -- Diagnostic heartbeat: every 15s confirm snapshot size and last delta
  if now - (state._lastDiag or 0) >= 15 then
    state._lastDiag = now
    local count = 0; for _ in pairs(curr) do count = count + 1 end
    local totalItems = 0
    for _, v in pairs(curr) do totalItems = totalItems + v end
    logger.info("drill", ("diag: types=%d items=%d added=%d rs=%s sess=%s"):format(
      count, totalItems, added, tostring(rsOn), state.session and "YES" or "no"))
  end

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

  -- Local monitor redraw: every tick while active, every ~5s when idle
  if state.session or (now - (state._lastRender or 0) >= 5) then
    state._lastRender = now
    renderMonitor()
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
