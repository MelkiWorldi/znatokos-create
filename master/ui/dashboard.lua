local ui       = require("master.ui.framework")
local reg      = require("master.registry")
local stock    = require("master.stock")
local mon_     = require("master.monitoring")
local sched    = require("master.scheduler")

local M = {}

function M.build(mon) end

local function aggStress()
  local used, cap = 0, 0
  for _, t in pairs(mon_.getTelemetry()) do
    if t.stress then
      used = used + (t.stress.used or 0)
      cap  = cap  + (t.stress.capacity or 0)
    end
  end
  return used, cap
end

function M.draw(mon)
  local w, h = mon.getSize()

  -- Top: stress
  local used, cap = aggStress()
  local pct = cap > 0 and used / cap or 0
  ui.write(mon, 1, 3, ("Stress: %d / %d  (%d%%)"):format(
    math.floor(used), math.floor(cap), math.floor(pct * 100)),
    pct >= 0.9 and colors.red or (pct >= 0.7 and colors.yellow or colors.lime),
    colors.black)
  ui.hbar(mon, 1, 4, w, pct,
    pct >= 0.9 and colors.red or (pct >= 0.7 and colors.yellow or colors.green),
    colors.gray)

  -- Workers count
  local online, total = 0, 0
  for _, wrk in pairs(reg.list()) do
    total = total + 1
    if reg.isOnline(wrk.id) then online = online + 1 end
  end
  ui.write(mon, 1, 6, ("Workers: %d/%d online"):format(online, total),
    online == total and colors.lime or colors.yellow, colors.black)

  -- Stock unique items
  local uniq = 0
  for _ in pairs(stock.getAll()) do uniq = uniq + 1 end
  ui.write(mon, 1, 7, ("Stock: %d unique items"):format(uniq), colors.white, colors.black)

  -- Active tasks
  local queued, running, errors = 0, 0, 0
  for _, t in pairs(sched.list()) do
    if t.status == "queued" then queued = queued + 1
    elseif t.status == "assigned" or t.status == "running" then running = running + 1
    elseif t.status == "error" then errors = errors + 1 end
  end
  ui.write(mon, 1, 8, ("Tasks: %d queued / %d running / %d errors"):format(queued, running, errors),
    errors > 0 and colors.red or colors.white, colors.black)

  -- Recent alarms (last 5)
  ui.write(mon, 1, 10, "Recent alarms:", colors.orange, colors.black)
  local alarms = mon_.getAlarms()
  local shown = math.min(5, #alarms)
  for i = 0, shown - 1 do
    local a = alarms[#alarms - i]
    if not a then break end
    local color = a.level == "crit" and colors.red or colors.yellow
    local line = ("[%s] %s"):format(a.level:upper(), a.text)
    if #line > w then line = line:sub(1, w) end
    ui.write(mon, 1, 11 + i, line, color, colors.black)
  end
end

function M.onTouch(x, y) end

return M
