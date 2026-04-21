local ui   = require("master.ui.framework")
local mon_ = require("master.monitoring")

local M = {}
local list
local ackAllBtn

function M.build(mon)
  local w, h = mon.getSize()
  list = ui.List{
    x = 1, y = 4, w = w, h = h - 4,
    items = {},
    renderItem = function(a)
      local t = os.date("%H:%M:%S", a.ts)
      local mark = a.acked and " " or "!"
      return ("%s %s [%s] %s"):format(mark, t, a.level:upper(), a.text)
    end,
  }
  ackAllBtn = ui.Button{
    x = 1, y = 2, w = 12, h = 1, label = "Ack All", bg = colors.green,
    onClick = function() for _, a in ipairs(mon_.getAlarms()) do a.acked = true end end,
  }
end

function M.draw(mon)
  ui.write(mon, 1, 3, ("Alarms (%d total)"):format(#mon_.getAlarms()), colors.orange, colors.black)
  ackAllBtn:draw(mon)
  local items = {}
  local all = mon_.getAlarms()
  for i = #all, 1, -1 do items[#items + 1] = all[i] end
  list.items = items
  list:draw(mon)
end

function M.onTouch(x, y)
  if ackAllBtn:hits(x, y) then ackAllBtn.onClick() end
end

return M
