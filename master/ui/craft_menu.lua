local ui        = require("master.ui.framework")
local recipes   = require("master.recipes")
local stock     = require("master.stock")
local util      = require("core.util")

local M = {}
local list
local qtyButtons = {}
local requestedQty = 1
local selected = nil
local requestBtn

local QTY_OPTIONS = { 1, 16, 32, 64, 128, 256 }

local scheduler  -- injected to avoid circular

function M.setScheduler(s) scheduler = s end

function M.build(mon)
  local w, h = mon.getSize()
  list = ui.List{
    x = 1, y = 4, w = math.floor(w * 0.55), h = h - 5,
    items = recipes.list(),
    renderItem = function(r)
      local out = r.outputs and r.outputs[1] or {}
      local have = stock.getCount((out.item or "") .. "|nil")
      return ("%-28s  have:%-6d  x%d"):format(r.id, have, out.count or 1)
    end,
    onSelect = function(r) selected = r end,
  }
  qtyButtons = {}
  local bx = math.floor(w * 0.55) + 2
  local by = 4
  for i, q in ipairs(QTY_OPTIONS) do
    qtyButtons[#qtyButtons + 1] = ui.Button{
      x = bx, y = by, w = 10, h = 1, label = "x" .. q,
      bg = (q == requestedQty) and colors.blue or colors.gray,
      onClick = function()
        requestedQty = q
        for j, btn in ipairs(qtyButtons) do
          btn.bg = (QTY_OPTIONS[j] == requestedQty) and colors.blue or colors.gray
        end
      end,
    }
    by = by + 1
  end
  requestBtn = ui.Button{
    x = bx, y = by + 1, w = 14, h = 2, label = "REQUEST", bg = colors.green,
    onClick = function()
      if selected and scheduler then
        scheduler.submit(selected.id, requestedQty, { source = "gui" })
      end
    end,
  }
end

function M.draw(mon)
  local w, h = mon.getSize()
  ui.write(mon, 1, 3, "Craft menu — tap recipe, qty, REQUEST", colors.yellow, colors.black)
  list.items = recipes.list()
  list:draw(mon)
  for _, b in ipairs(qtyButtons) do b:draw(mon) end
  requestBtn:draw(mon)
  if selected then
    ui.write(mon, 1, h, "Selected: " .. selected.id .. "  qty=" .. requestedQty,
      colors.white, colors.black)
  end
end

function M.onTouch(x, y)
  local hit, item = list:hits(x, y)
  if hit and item then selected = item; return end
  for _, b in ipairs(qtyButtons) do if b:hits(x, y) then b.onClick(); return end end
  if requestBtn:hits(x, y) then requestBtn.onClick() end
end

return M
