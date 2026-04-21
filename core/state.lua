local M = {}

local function ensureDir(path)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
end

function M.load(path, default)
  if not fs.exists(path) then return default end
  local f = fs.open(path, "r")
  if not f then return default end
  local data = f.readAll()
  f.close()
  local ok, value = pcall(textutils.unserialize, data)
  if not ok or value == nil then return default end
  return value
end

function M.save(path, value)
  ensureDir(path)
  local tmp = path .. ".tmp"
  local f = fs.open(tmp, "w")
  if not f then return false end
  f.write(textutils.serialize(value))
  f.close()
  if fs.exists(path) then fs.delete(path) end
  fs.move(tmp, path)
  return true
end

return M
