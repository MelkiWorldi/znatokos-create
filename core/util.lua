local M = {}

function M.deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = M.deepcopy(v) end
  return r
end

function M.merge(a, b)
  local r = M.deepcopy(a)
  for k, v in pairs(b) do r[k] = v end
  return r
end

function M.itemKey(item)
  local nbt = item.nbt or ""
  return (item.name or item.id) .. "|" .. tostring(nbt)
end

function M.fluidKey(fluid)
  return fluid.name or fluid.id
end

function M.sleep(s) os.sleep(s) end

function M.now() return os.epoch("utc") / 1000 end

function M.keys(t)
  local r = {}
  for k in pairs(t) do r[#r + 1] = k end
  return r
end

function M.count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function M.find(list, pred)
  for i, v in ipairs(list) do
    if pred(v, i) then return v, i end
  end
  return nil
end

function M.contains(list, value)
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

function M.uuid()
  return string.format("%x-%x", os.epoch("utc"), math.random(0, 0xffffff))
end

function M.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function M.pad(s, n)
  s = tostring(s)
  if #s >= n then return s:sub(1, n) end
  return s .. string.rep(" ", n - #s)
end

return M
