package.path = "/factory/?.lua;/factory/?/init.lua;" .. package.path

local util    = require("core.util")
local logger  = require("core.logger")
local state   = require("core.state")
local net     = require("core.rednet_proto")
local periph  = require("core.peripherals")
local bus     = require("core.eventbus")

local CONFIG_PATH = "/factory/data/worker.dat"

local config = state.load(CONFIG_PATH, {
  role = nil,
  config = {},
  masterId = nil,
})

-- CLI override (e.g. "monitor_slave")
local args = { ... }
if args[1] then config.role = args[1] end

net.open()
logger.info("worker", "started, id=" .. os.getComputerID() .. " role=" .. tostring(config.role))

-- Role loader
local roleModule = nil
local function loadRole(name)
  if not name then return nil end
  local ok, mod = pcall(require, "worker.roles." .. name)
  if not ok then
    logger.error("worker", "failed to load role " .. name .. ": " .. tostring(mod))
    return nil
  end
  return mod
end

local function saveConfig()
  state.save(CONFIG_PATH, config)
end

local function sendHello()
  local msg = {
    type = "hello",
    worker = os.getComputerID(),
    label = os.getComputerLabel(),
    role = config.role,
    peripherals = periph.scan(),
  }
  if config.masterId then
    net.send(config.masterId, msg)
  else
    net.broadcast(msg)
  end
end

local handlers = {}

function handlers.assign(from, msg)
  config.role = msg.role
  config.config = msg.config or {}
  config.masterId = from
  saveConfig()
  logger.info("worker", "assigned role=" .. config.role .. " by master=" .. from)
  if roleModule and roleModule.stop then roleModule.stop() end
  roleModule = loadRole(config.role)
  if roleModule and roleModule.start then roleModule.start(config.config) end
  net.reply(from, msg, { type = "assign_ok", role = config.role })
end

function handlers.task(from, msg)
  if not roleModule or not roleModule.onTask then
    net.reply(from, msg, { type = "progress", taskId = msg.taskId, stage = "error",
      msg = "no role/onTask" })
    return
  end
  local ok, err = pcall(roleModule.onTask, msg, function(stage, data)
    net.send(from, {
      type = "progress", taskId = msg.taskId, stage = stage, data = data,
    })
  end)
  if not ok then
    net.send(from, { type = "progress", taskId = msg.taskId, stage = "error", msg = tostring(err) })
  end
end

function handlers.ping(from, msg)
  net.reply(from, msg, { type = "pong", worker = os.getComputerID() })
end

function handlers.rescan(from, msg)
  net.reply(from, msg, { type = "peripherals", peripherals = periph.scan() })
end

function handlers.reboot(from, msg)
  logger.info("worker", "reboot requested by master")
  os.reboot()
end

-- Main loops
local function netLoop()
  while true do
    local from, msg = net.receive()
    if type(msg) == "table" and msg.type then
      local h = handlers[msg.type]
      if h then
        local ok, err = pcall(h, from, msg)
        if not ok then logger.error("worker", "handler " .. msg.type .. " error: " .. tostring(err)) end
      elseif roleModule and roleModule.onMessage then
        pcall(roleModule.onMessage, from, msg)
      end
    end
  end
end

local function heartbeatLoop()
  while true do
    sendHello()
    os.sleep(net.HEARTBEAT_INTERVAL)
  end
end

local function roleLoop()
  while true do
    if roleModule and roleModule.tick then
      local ok, err = pcall(roleModule.tick)
      if not ok then logger.error("worker", "role tick error: " .. tostring(err)) end
    end
    os.sleep(1)
  end
end

-- Initial load
if config.role then
  roleModule = loadRole(config.role)
  if roleModule and roleModule.start then
    pcall(roleModule.start, config.config)
  end
end

sendHello()

parallel.waitForAny(netLoop, heartbeatLoop, roleLoop)
