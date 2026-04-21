-- Monitor slave: just displays master-pushed status on an attached monitor.
local periph = require("core.peripherals")
local logger = require("core.logger")

local M = {}
local cfg = {}
local lastPayload = { text = "waiting for master..." }

local function getMonitor()
  return cfg.monitor and peripheral.wrap(cfg.monitor) or periph.wrap(periph.TYPES.monitor)
end

local function redraw()
  local m = getMonitor(); if not m then return end
  m.setBackgroundColor(colors.black); m.clear(); m.setCursorPos(1, 1)
  m.setTextColor(colors.white)
  if type(lastPayload.text) == "string" then
    for line in lastPayload.text:gmatch("[^\n]+") do
      local x, y = m.getCursorPos()
      m.write(line)
      m.setCursorPos(1, y + 1)
    end
  end
end

function M.start(c)
  cfg = c or {}
  logger.info("monitor_slave", "started")
  redraw()
end

function M.onMessage(from, msg)
  if msg.type == "display" then
    lastPayload = { text = msg.text }
    redraw()
  end
end

function M.tick() end

return M
