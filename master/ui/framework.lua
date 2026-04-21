-- Minimal touch-UI framework for CC:Tweaked monitors
local M = {}

local Button = {}
Button.__index = Button

function M.Button(opts)
  local b = setmetatable({}, Button)
  b.x, b.y, b.w, b.h = opts.x, opts.y, opts.w or 10, opts.h or 1
  b.label = opts.label or ""
  b.bg = opts.bg or colors.gray
  b.fg = opts.fg or colors.white
  b.onClick = opts.onClick
  b.enabled = opts.enabled ~= false
  return b
end

function Button:draw(mon)
  mon.setBackgroundColor(self.enabled and self.bg or colors.lightGray)
  mon.setTextColor(self.fg)
  for dy = 0, self.h - 1 do
    mon.setCursorPos(self.x, self.y + dy)
    mon.write(string.rep(" ", self.w))
  end
  local text = self.label
  if #text > self.w then text = text:sub(1, self.w) end
  local tx = self.x + math.floor((self.w - #text) / 2)
  local ty = self.y + math.floor(self.h / 2)
  mon.setCursorPos(tx, ty)
  mon.write(text)
end

function Button:hits(x, y)
  return x >= self.x and x < self.x + self.w
     and y >= self.y and y < self.y + self.h
end

local List = {}
List.__index = List

function M.List(opts)
  local l = setmetatable({}, List)
  l.x, l.y, l.w, l.h = opts.x, opts.y, opts.w, opts.h
  l.items = opts.items or {}
  l.scroll = 0
  l.renderItem = opts.renderItem or function(item) return tostring(item) end
  l.onSelect = opts.onSelect
  return l
end

function List:draw(mon)
  mon.setBackgroundColor(colors.black)
  mon.setTextColor(colors.white)
  for i = 0, self.h - 1 do
    mon.setCursorPos(self.x, self.y + i)
    mon.write(string.rep(" ", self.w))
    local item = self.items[i + 1 + self.scroll]
    if item then
      mon.setCursorPos(self.x, self.y + i)
      local line = self.renderItem(item)
      if #line > self.w then line = line:sub(1, self.w) end
      mon.write(line)
    end
  end
end

function List:hits(x, y)
  if x < self.x or x >= self.x + self.w then return false, nil end
  if y < self.y or y >= self.y + self.h then return false, nil end
  local idx = y - self.y + 1 + self.scroll
  return true, self.items[idx]
end

function List:scrollBy(delta)
  self.scroll = math.max(0, math.min(#self.items - self.h, self.scroll + delta))
end

-- Tabs container
local Tabs = {}
Tabs.__index = Tabs

function M.Tabs(opts)
  local t = setmetatable({}, Tabs)
  t.tabs = opts.tabs or {}  -- { {name, draw, onTouch, onTick}, ... }
  t.active = 1
  t.mon = opts.mon
  t.buttons = {}
  t:rebuildButtons()
  return t
end

function Tabs:rebuildButtons()
  self.buttons = {}
  local w, _ = self.mon.getSize()
  local totalW = 0
  for _, t in ipairs(self.tabs) do totalW = totalW + #t.name + 2 end
  local spacing = math.max(1, math.floor((w - totalW) / (#self.tabs + 1)))
  local x = 1 + spacing
  for i, t in ipairs(self.tabs) do
    local bw = #t.name + 2
    self.buttons[#self.buttons + 1] = M.Button{
      x = x, y = 1, w = bw, h = 1, label = t.name,
      bg = (i == self.active) and colors.blue or colors.gray,
      onClick = function() self.active = i; self:rebuildButtons(); self:redraw() end,
    }
    x = x + bw + spacing
  end
end

function Tabs:redraw()
  self.mon.setBackgroundColor(colors.black)
  self.mon.clear()
  for _, b in ipairs(self.buttons) do b:draw(self.mon) end
  local tab = self.tabs[self.active]
  if tab and tab.draw then tab.draw(self.mon) end
end

function Tabs:onTouch(x, y)
  for _, b in ipairs(self.buttons) do
    if b:hits(x, y) and b.onClick then b.onClick(); return end
  end
  local tab = self.tabs[self.active]
  if tab and tab.onTouch then tab.onTouch(x, y) end
end

function Tabs:tick()
  local tab = self.tabs[self.active]
  if tab and tab.onTick then tab.onTick() end
end

-- Helpers
function M.clear(mon, bg)
  mon.setBackgroundColor(bg or colors.black)
  mon.clear()
  mon.setCursorPos(1, 1)
end

function M.write(mon, x, y, text, fg, bg)
  mon.setCursorPos(x, y)
  if fg then mon.setTextColor(fg) end
  if bg then mon.setBackgroundColor(bg) end
  mon.write(text)
end

function M.hbar(mon, x, y, w, pct, fg, bg)
  local filled = math.floor(w * math.max(0, math.min(1, pct)) + 0.5)
  mon.setCursorPos(x, y)
  mon.setBackgroundColor(fg or colors.green)
  mon.write(string.rep(" ", filled))
  mon.setBackgroundColor(bg or colors.gray)
  mon.write(string.rep(" ", w - filled))
end

return M
