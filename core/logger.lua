local M = {}

local LOG_PATH = "/factory/data/log.txt"
local MAX_SIZE = 64 * 1024
local level_rank = { debug = 1, info = 2, warn = 3, error = 4 }
local min_level = "info"

local function rotate()
  if not fs.exists(LOG_PATH) then return end
  if fs.getSize(LOG_PATH) < MAX_SIZE then return end
  local old = LOG_PATH .. ".1"
  if fs.exists(old) then fs.delete(old) end
  fs.move(LOG_PATH, old)
end

local function ensureDir()
  local dir = fs.getDir(LOG_PATH)
  if not fs.exists(dir) then fs.makeDir(dir) end
end

local function write(level, tag, msg)
  if level_rank[level] < level_rank[min_level] then return end
  ensureDir()
  rotate()
  local f = fs.open(LOG_PATH, "a")
  if not f then return end
  local t = textutils.formatTime(os.time(), true)
  f.writeLine(("[%s] %s %s: %s"):format(t, level:upper(), tag, msg))
  f.close()
  if level == "error" or level == "warn" then
    print(("[%s] %s: %s"):format(level:upper(), tag, msg))
  end
end

function M.setLevel(l) min_level = l end
function M.debug(tag, msg) write("debug", tag, tostring(msg)) end
function M.info(tag, msg)  write("info",  tag, tostring(msg)) end
function M.warn(tag, msg)  write("warn",  tag, tostring(msg)) end
function M.error(tag, msg) write("error", tag, tostring(msg)) end

return M
