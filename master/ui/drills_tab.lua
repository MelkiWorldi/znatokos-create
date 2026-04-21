local ui     = require("master.ui.framework")
local drills = require("master.drills")

local M = {}
local leftList, rightList
local selected = nil  -- workerId

local function shortName(k, n)
  local s = k:gsub("^minecraft:", ""):gsub("^create:", "c/")
  if #s > n then s = s:sub(1, n) end
  return s
end

function M.build(mon)
  local w, h = mon.getSize()
  local lw = math.floor(w * 0.35)

  leftList = ui.List{
    x = 1, y = 4, w = lw, h = h - 4,
    items = {},
    renderItem = function(d)
      local mark
      if d.active then mark = "*"
      elseif d.online then mark = "."
      else mark = "!" end  -- offline
      return ("%s %-16s h=%d"):format(mark, (d.name or "?"):sub(1, 16), d.historyCount or 0)
    end,
    onSelect = function(d) selected = d.workerId end,
  }

  rightList = ui.List{
    x = lw + 2, y = 12, w = w - lw - 2, h = h - 12,
    items = {},
    renderItem = function(item) return tostring(item) end,
  }
end

local function drawDetail(mon, x, y, w, h)
  if not selected then
    ui.write(mon, x, y, "(tap a drill on the left)", colors.lightGray, colors.black)
    return
  end
  local current = drills.current(selected)
  local stats = drills.stats(selected) or {}
  local history = drills.history(selected)

  local line = y
  if current then
    ui.write(mon, x, line, "ACTIVE SESSION", colors.lime, colors.black); line = line + 1
    local elapsed = current.elapsedSec or 0
    ui.write(mon, x, line, ("  elapsed: %ds  items: %d"):format(
      math.floor(elapsed), current.total or 0), colors.white, colors.black)
    line = line + 1
    local rate = elapsed > 0 and (current.total or 0) / (elapsed / 60) or 0
    ui.write(mon, x, line, ("  rate:    %.1f/min"):format(rate), colors.white, colors.black)
    line = line + 2
  else
    ui.write(mon, x, line, "No active session", colors.gray, colors.black); line = line + 2
  end

  ui.write(mon, x, line, ("HISTORY (%d sessions)"):format(#history), colors.yellow, colors.black)
  line = line + 1
  ui.write(mon, x, line, ("  sessions: %d"):format(stats.sessions or 0), colors.white, colors.black)
  line = line + 1
  ui.write(mon, x, line, ("  total:    %d items"):format(stats.totalItems or 0), colors.white, colors.black)
  line = line + 1
  ui.write(mon, x, line, ("  avg rate: %.1f/min"):format(stats.avgRatePerMin or 0), colors.white, colors.black)
  line = line + 1
  ui.write(mon, x, line, ("  avg/sess: %.0f items"):format(stats.avgItemsPerSession or 0), colors.white, colors.black)
  line = line + 2
  ui.write(mon, x, line, "TOP ITEMS + RECENT SESSIONS", colors.yellow, colors.black)

  -- Populate rightList with a merged view
  local items = {}
  items[#items + 1] = "--- Top items ---"
  for i, it in ipairs(stats.topItems or {}) do
    if i > 10 then break end
    items[#items + 1] = ("%-30s  %d"):format(shortName(it.name, 30), it.count)
  end
  items[#items + 1] = ""
  items[#items + 1] = "--- Recent sessions ---"
  for i, s in ipairs(history) do
    if i > 20 then break end
    items[#items + 1] = ("#%d  %ds  %d items  %.1f/min"):format(
      i, math.floor(s.durationSec or 0), s.total or 0, s.ratePerMin or 0)
  end
  rightList.items = items
end

function M.draw(mon)
  local w, h = mon.getSize()
  local lw = math.floor(w * 0.35)
  ui.write(mon, 1, 3, "Drills  (* active  . idle  ! offline)", colors.yellow, colors.black)

  local items = drills.list()
  leftList.items = items
  -- Auto-select first drill if none picked yet
  if not selected and items[1] then selected = items[1].workerId end
  leftList:draw(mon)

  drawDetail(mon, lw + 2, 4, w - lw - 2, 8)
  rightList:draw(mon)
end

function M.onTouch(x, y)
  local hit, item = leftList:hits(x, y)
  if hit and item then selected = item.workerId; return end
  rightList:hits(x, y)  -- scroll-only, no-op
end

return M
