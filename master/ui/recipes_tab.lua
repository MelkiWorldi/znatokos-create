local ui      = require("master.ui.framework")
local recipes = require("master.recipes")

local M = {}
local list
local reloadBtn

function M.build(mon)
  local w, h = mon.getSize()
  list = ui.List{
    x = 1, y = 4, w = w, h = h - 4,
    items = recipes.list(),
    renderItem = function(r)
      local outs = r.outputs and r.outputs[1] or {}
      return ("%-30s  %-25s  x%d"):format(r.id, r.type or "?", outs.count or 1)
    end,
  }
  reloadBtn = ui.Button{
    x = 1, y = 2, w = 12, h = 1, label = "Reload", bg = colors.blue,
    onClick = function() recipes.loadAll(); list.items = recipes.list() end,
  }
end

function M.draw(mon)
  ui.write(mon, 1, 3, ("Recipes (%d)"):format(#recipes.list()), colors.yellow, colors.black)
  reloadBtn:draw(mon)
  list.items = recipes.list()
  list:draw(mon)
end

function M.onTouch(x, y)
  if reloadBtn:hits(x, y) then reloadBtn.onClick(); return end
end

return M
