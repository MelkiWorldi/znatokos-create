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

function M.open()
  modemSide = findModem()
  if not modemSide then
    error("no modem found — attach Ender Modem or Wireless Modem")
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
