local periph = require("core.peripherals")
local logger = require("core.logger")
local net    = require("core.rednet_proto")
local util   = require("core.util")

local M = {}
local cfg = {}
local lastPoll = 0
local POLL_INTERVAL = 5

local function wrapTicker()
  local name = cfg.ticker or periph.findOne(periph.TYPES.stockTicker)
  if not name then return nil end
  return peripheral.wrap(name), name
end

local function collect()
  local t, name = wrapTicker()
  if not t then return nil, "no stock ticker" end
  local ok, items = pcall(t.stock, true)
  if not ok then
    -- fallback: some API versions use list()
    ok, items = pcall(t.list)
    if not ok then return nil, tostring(items) end
  end
  return {
    ticker = name,
    address = cfg.address,
    items = items or {},
  }
end

local function pushUpdate()
  if not net.getMaster() then return end
  local payload, err = collect()
  if not payload then
    logger.warn("stock", "collect failed: " .. tostring(err))
    return
  end
  net.sendToMaster({ type = "stock_update", payload = payload })
end

function M.start(c)
  cfg = c or {}
  logger.info("stock", "started")
end

function M.tick()
  if util.now() - lastPoll >= POLL_INTERVAL then
    lastPoll = util.now()
    pushUpdate()
  end
end

function M.onMessage(from, msg)
  if msg.type == "stock_poll" then
    pushUpdate()
  elseif msg.type == "stock_request" then
    local t = wrapTicker()
    if not t then
      net.reply(from, msg, { type = "stock_request_result", ok = false, err = "no ticker" })
      return
    end
    local ok, res = pcall(t.requestFiltered, msg.address, msg.filter)
    net.reply(from, msg, { type = "stock_request_result", ok = ok, result = res })
  end
end

function M.onTask(msg, progress)
  if msg.subtype == "stock_request" then
    local t = wrapTicker()
    if not t then progress("error", { msg = "no ticker" }); return end
    local ok, res = pcall(t.requestFiltered, msg.address, msg.filter)
    progress(ok and "done" or "error", { result = res })
  else
    progress("error", { msg = "unknown subtype" })
  end
end

return M
