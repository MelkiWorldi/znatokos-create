local ui       = require("master.ui.framework")
local registry = require("master.registry")
local net      = require("core.rednet_proto")
local util     = require("core.util")

local M = {}

local ROLES = {
  "generic", "mixer", "press", "crusher", "saw", "spout", "deployer",
  "mcrafter", "fan", "sequenced", "stock", "trains", "package_endpoint",
  "cctl_bridge", "aero_controller", "monitor_slave",
}

local selected = nil
local list = nil
local roleButtons = {}

function M.build(mon)
  local w, h = mon.getSize()

  list = ui.List{
    x = 1, y = 3, w = math.floor(w * 0.5), h = h - 4,
    items = {},
    renderItem = function(wrk)
      local status = registry.isOnline(wrk.id) and "ON " or "OFF"
      return ("%s #%d %s -> %s"):format(status, wrk.id, wrk.label or "", wrk.role or "?")
    end,
    onSelect = function(wrk) selected = wrk end,
  }

  roleButtons = {}
  local rx = math.floor(w * 0.5) + 2
  local ry = 3
  for i, role in ipairs(ROLES) do
    roleButtons[#roleButtons + 1] = ui.Button{
      x = rx, y = ry, w = 18, h = 1, label = role, bg = colors.gray,
      onClick = function()
        if not selected then return end
        net.send(selected.id, { type = "assign", role = role, config = {} })
        registry.assign(selected.id, role, {})
      end,
    }
    ry = ry + 1
    if ry > h - 1 then ry = 3; rx = rx + 20 end
  end
end

function M.draw(mon)
  local w, h = mon.getSize()
  ui.write(mon, 1, 2, "Workers (tap to select, then role):", colors.yellow, colors.black)

  local items = {}
  for _, w in pairs(registry.list()) do items[#items + 1] = w end
  table.sort(items, function(a, b) return a.id < b.id end)
  list.items = items
  list:draw(mon)

  for _, b in ipairs(roleButtons) do b:draw(mon) end

  if selected then
    ui.write(mon, 1, h, "Selected: #" .. selected.id .. " role=" .. (selected.role or "none"),
      colors.white, colors.black)
  end
end

function M.onTouch(x, y)
  local hit, item = list:hits(x, y)
  if hit and item then selected = item; return end
  for _, b in ipairs(roleButtons) do
    if b:hits(x, y) and b.onClick then b.onClick(); return end
  end
end

return M
