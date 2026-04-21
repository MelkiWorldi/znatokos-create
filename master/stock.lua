local logger = require("core.logger")
local util   = require("core.util")
local bus    = require("core.eventbus")
local net    = require("core.rednet_proto")
local reg    = require("master.registry")

-- Aggregates Stock Ticker contents from stock-role workers.
local M = {}

-- cache[itemKey] = { name, count, displayName, tags, nbt, via = { [tickerId] = count } }
local cache = {}
local tickerMeta = {}  -- [workerId] = { address, lastUpdate }
local TTL = 10  -- seconds

function M.getAll() return cache end

function M.getCount(itemKey)
  local e = cache[itemKey]
  return e and e.count or 0
end

function M.findByName(name)
  local r = {}
  for k, e in pairs(cache) do
    if e.name == name then r[#r + 1] = e end
  end
  return r
end

function M.ingestStock(workerId, payload)
  -- payload = { ticker = { address = "...", items = {{name, count, nbt?, displayName?, tags?}, ...} } }
  tickerMeta[workerId] = {
    address = payload.address,
    lastUpdate = util.now(),
  }
  -- Remove previous contribution from this ticker, then re-add
  for k, e in pairs(cache) do
    if e.via and e.via[workerId] then
      e.count = e.count - e.via[workerId]
      e.via[workerId] = nil
      if e.count <= 0 then cache[k] = nil end
    end
  end
  for _, item in ipairs(payload.items or {}) do
    local key = util.itemKey(item)
    local e = cache[key] or {
      name = item.name, nbt = item.nbt, count = 0,
      displayName = item.displayName, tags = item.tags, via = {},
    }
    e.count = e.count + (item.count or 0)
    e.via[workerId] = item.count or 0
    if item.displayName then e.displayName = item.displayName end
    if item.tags then e.tags = item.tags end
    cache[key] = e
  end
  bus.emit("stock_updated", workerId, payload)
end

function M.request(itemName, count, address)
  -- Find a stock worker (any will do — they're all on same logistics net)
  local workers = reg.byRole("stock")
  if #workers == 0 then
    logger.warn("stock", "no stock worker available")
    return false, "no stock worker"
  end
  local w = workers[1]
  local reqId = util.uuid()
  net.send(w.id, {
    type = "stock_request",
    reqId = reqId,
    address = address,
    filter = { name = itemName, _requestCount = count },
  })
  return true, reqId
end

function M.tick()
  local now = util.now()
  for workerId, meta in pairs(tickerMeta) do
    if now - meta.lastUpdate > TTL and reg.isOnline(workerId) then
      net.send(workerId, { type = "stock_poll" })
    end
  end
end

function M.onMessage(from, msg)
  if msg.type == "stock_update" then
    M.ingestStock(from, msg.payload or {})
  end
end

return M
