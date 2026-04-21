package.path = "/factory/?.lua;/factory/?/init.lua;" .. package.path

local util    = require("core.util")
local logger  = require("core.logger")
local bus     = require("core.eventbus")
local net     = require("core.rednet_proto")
local periph  = require("core.peripherals")

local registry   = require("master.registry")
local recipes    = require("master.recipes")
local stock      = require("master.stock")
local scheduler  = require("master.scheduler")
local parstock   = require("master.parstock")
local trains     = require("master.trains")
local monitoring = require("master.monitoring")
local drills     = require("master.drills")

local ui          = require("master.ui.framework")
local dashboard   = require("master.ui.dashboard")
local craft_menu  = require("master.ui.craft_menu")
local workers_tab = require("master.ui.workers_tab")
local trains_tab  = require("master.ui.trains_tab")
local alarms_tab  = require("master.ui.alarms_tab")
local recipes_tab = require("master.ui.recipes_tab")
local drills_tab  = require("master.ui.drills_tab")

-- Wire scheduler into parstock and craft_menu (avoid circular requires)
parstock.setScheduler(scheduler)
craft_menu.setScheduler(scheduler)

-- Wait for monitor first so we can render a friendly "attach a modem" hint.
local function awaitMonitor()
  while true do
    local m = periph.wrap(periph.TYPES.monitor)
    if m then return m end
    print("Waiting for Advanced Monitor... (attach one to this computer)")
    parallel.waitForAny(
      function() os.pullEvent("peripheral") end,
      function() os.sleep(2) end
    )
  end
end

local mon = awaitMonitor()
mon.setTextScale(0.5)
mon.setBackgroundColor(colors.black); mon.clear()

local function hint(text)
  mon.setBackgroundColor(colors.black); mon.clear()
  mon.setCursorPos(1, 1); mon.setTextColor(colors.yellow)
  mon.write("Factory master")
  mon.setCursorPos(1, 3); mon.setTextColor(colors.white)
  for line in (text or ""):gmatch("[^\n]+") do
    local _, y = mon.getCursorPos()
    mon.write(line); mon.setCursorPos(1, y + 1)
  end
end

-- Open rednet, waiting for modem if needed.
net.open(hint)
net.hostAs("master")
recipes.loadAll()

local tabs = ui.Tabs{
  mon = mon,
  tabs = {
    { name = "Dashboard", draw = function(m) dashboard.draw(m) end,
      onTouch = function(x, y) dashboard.onTouch(x, y) end },
    { name = "Craft",     draw = function(m) craft_menu.draw(m) end,
      onTouch = function(x, y) craft_menu.onTouch(x, y) end },
    { name = "Workers",   draw = function(m) workers_tab.draw(m) end,
      onTouch = function(x, y) workers_tab.onTouch(x, y) end },
    { name = "Recipes",   draw = function(m) recipes_tab.draw(m) end,
      onTouch = function(x, y) recipes_tab.onTouch(x, y) end },
    { name = "Trains",    draw = function(m) trains_tab.draw(m) end,
      onTouch = function(x, y) trains_tab.onTouch(x, y) end },
    { name = "Drills",    draw = function(m) drills_tab.draw(m) end,
      onTouch = function(x, y) drills_tab.onTouch(x, y) end },
    { name = "Alarms",    draw = function(m) alarms_tab.draw(m) end,
      onTouch = function(x, y) alarms_tab.onTouch(x, y) end },
  },
}

dashboard.build(mon); craft_menu.build(mon); workers_tab.build(mon)
recipes_tab.build(mon); trains_tab.build(mon); alarms_tab.build(mon)
drills_tab.build(mon)
tabs:redraw()

-- Redraw on event
local function scheduleRedraw()
  os.queueEvent("ui_redraw")
end
bus.on("worker_seen",     scheduleRedraw)
bus.on("worker_assigned", scheduleRedraw)
bus.on("stock_updated",   scheduleRedraw)
bus.on("recipes_reloaded",scheduleRedraw)
bus.on("task_queued",     scheduleRedraw)
bus.on("task_done",       scheduleRedraw)
bus.on("task_error",      scheduleRedraw)
bus.on("alarm_raised",    scheduleRedraw)
bus.on("worker_offline",  scheduleRedraw)
bus.on("drill_update",    scheduleRedraw)
bus.on("drill_session_ended", scheduleRedraw)

-- Heartbeat loop
local function heartbeatLoop()
  while true do
    os.sleep(net.HEARTBEAT_INTERVAL)
    for id, w in pairs(registry.list()) do
      if w.approved then
        net.send(id, { type = "ping" })
        -- Each worker sends hello periodically; we use that as proof of life.
        if util.now() - (w.last_seen or 0) > net.HEARTBEAT_INTERVAL * 1.5 then
          registry.markMissed(id)
        end
      end
    end
  end
end

-- Rednet listener
local function netLoop()
  while true do
    local from, msg = net.receive()
    if type(msg) == "table" and msg.type then
      if msg.type == "hello" then
        registry.upsertHello(from, msg)
      elseif msg.type == "pong" then
        registry.markPong(from)
      elseif msg.type == "progress" then
        scheduler.onMessage(from, msg)
      elseif msg.type == "stock_update" then
        stock.onMessage(from, msg)
      elseif msg.type == "trains_update" then
        trains.onMessage(from, msg)
      elseif msg.type == "status" then
        monitoring.onStatus(from, msg)
      elseif msg.type == "alarm" then
        monitoring.onAlarm(from, msg)
      elseif msg.type == "drill_session_start"
          or msg.type == "drill_session_delta"
          or msg.type == "drill_session_end" then
        logger.info("main", "drill msg from #" .. from .. ": " .. msg.type)
        drills.onMessage(from, msg)
      end
    end
  end
end

-- Tick loop for master-side modules
local function tickLoop()
  while true do
    local ok, err = pcall(function()
      scheduler.tick()
      parstock.tick()
      stock.tick()
      trains.tick()
    end)
    if not ok then logger.error("main", "tick error: " .. tostring(err)) end
    os.sleep(1)
  end
end

-- UI loop
local function uiLoop()
  while true do
    local ev = { os.pullEvent() }
    if ev[1] == "monitor_touch" then
      tabs:onTouch(ev[3], ev[4])
      tabs:redraw()
    elseif ev[1] == "ui_redraw" then
      tabs:redraw()
    elseif ev[1] == "timer" then
      tabs:redraw()
    end
  end
end

-- Periodic redraw even without events
local function redrawLoop()
  while true do
    os.sleep(2)
    scheduleRedraw()
  end
end

logger.info("main", "master online id=" .. os.getComputerID())

parallel.waitForAny(netLoop, tickLoop, uiLoop, heartbeatLoop, redrawLoop)
