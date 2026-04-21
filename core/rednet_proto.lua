local logger = require("core.logger")
local util   = require("core.util")

local M = {}
M.PROTOCOL = "factory-v1"
M.HEARTBEAT_INTERVAL = 10
M.MISSED_PONG_LIMIT = 3

local modemSide = nil

local function findModem()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      local m = peripheral.wrap(name)
      if m.isWireless and m.isWireless() then
        return name
      end
    end
  end
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then return name end
  end
  return nil
end

-- Wait until any modem is attached. If onWaiting is given, it is called with
-- a short status string so the caller can update a monitor / screen.
local function awaitModem(onWaiting)
  local announced = false
  while true do
    local name = findModem()
    if name then return name end
    if not announced and onWaiting then
      onWaiting("Waiting for modem (Ender / Wireless) — attach one to this computer")
      announced = true
    end
    -- Either an event arrives (peripheral attached) or we retry after 2s.
    parallel.waitForAny(
      function() os.pullEvent("peripheral") end,
      function() os.sleep(2) end
    )
  end
end

function M.open(onWaiting)
  modemSide = findModem()
  if not modemSide then
    modemSide = awaitModem(onWaiting)
  end
  if not rednet.isOpen(modemSide) then rednet.open(modemSide) end
  rednet.host(M.PROTOCOL, tostring(os.getComputerID()))
  logger.info("rednet", "opened on " .. modemSide)
  return modemSide
end

-- Register this computer under a well-known label (e.g. "master") in addition
-- to its numeric ID. Used for master rediscovery after migration.
function M.hostAs(label)
  rednet.host(M.PROTOCOL, label)
end

-- Look up a computer by well-known label. Returns the first matching ID.
function M.lookup(label, timeout)
  local id = rednet.lookup(M.PROTOCOL, label)
  return id
end

function M.send(to, msg)
  return rednet.send(to, msg, M.PROTOCOL)
end

function M.broadcast(msg)
  return rednet.broadcast(msg, M.PROTOCOL)
end

-- Cached master ID for worker roles that need to push to master without
-- tracking it themselves (set by worker/main.lua on each (re)discovery).
local cachedMasterId = nil
function M.setMaster(id) cachedMasterId = id end
function M.getMaster() return cachedMasterId end
function M.sendToMaster(msg)
  local id = cachedMasterId
  if id then return rednet.send(id, msg, M.PROTOCOL) end
  return rednet.broadcast(msg, M.PROTOCOL)
end

function M.receive(timeout)
  local id, msg = rednet.receive(M.PROTOCOL, timeout)
  return id, msg
end

function M.request(to, msg, timeout)
  local reqId = util.uuid()
  msg._reqId = reqId
  M.send(to, msg)
  local deadline = util.now() + (timeout or 5)
  while util.now() < deadline do
    local id, reply = rednet.receive(M.PROTOCOL, deadline - util.now())
    if id == to and type(reply) == "table" and reply._reqId == reqId then
      return reply
    end
  end
  return nil
end

function M.reply(to, original, msg)
  msg._reqId = original._reqId
  M.send(to, msg)
end

return M
