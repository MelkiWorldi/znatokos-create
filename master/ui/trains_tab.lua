local ui     = require("master.ui.framework")
local trains = require("master.trains")

local M = {}
local list

function M.build(mon)
  local w, h = mon.getSize()
  list = ui.List{
    x = 1, y = 4, w = w, h = h - 4,
    items = {},
    renderItem = function(s)
      if s.kind == "station" then
        local name = s.getStationName or s.name or "?"
        local train = s.getTrainName or s.isTrainPresent and "YES" or "-"
        return ("STATION %-20s  train:%s"):format(name:sub(1,20), tostring(train))
      elseif s.kind == "train" then
        return ("TRAIN %-20s  at:%s"):format(tostring(s.name or "?"), tostring(s.station or "?"))
      end
      return tostring(s)
    end,
  }
end

local function buildItems()
  local data = trains.get()
  local items = {}
  for _, st in ipairs(data.stations or {}) do
    st.kind = "station"; items[#items + 1] = st
  end
  for _, tr in ipairs(data.trains or {}) do
    tr.kind = "train"; items[#items + 1] = tr
  end
  return items
end

function M.draw(mon)
  local data = trains.get()
  ui.write(mon, 1, 3, ("Trains (%d stations, %d trains)"):format(
    #(data.stations or {}), #(data.trains or {})), colors.yellow, colors.black)
  list.items = buildItems()
  list:draw(mon)
end

function M.onTouch(x, y) end

return M
