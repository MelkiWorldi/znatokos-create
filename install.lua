-- Factory installer for CC:Tweaked
--
-- One-liner install (no re-typing, runs immediately):
--   wget run https://raw.githubusercontent.com/MelkiWorldi/znatokos-create/main/install.lua
--
-- Non-interactive:
--   wget run <url> master
--   wget run <url> worker
--   wget run <url> monitor_slave
--   wget run <url> update         (re-download all files for current role)

local BASE_URL = "https://raw.githubusercontent.com/MelkiWorldi/znatokos-create/main"

local FILES = {
  common = {
    "startup.lua",
  },
  core = {
    "core/util.lua", "core/eventbus.lua", "core/logger.lua",
    "core/state.lua", "core/rednet_proto.lua", "core/peripherals.lua",
  },
  master = {
    "master/main.lua", "master/scheduler.lua", "master/parstock.lua",
    "master/registry.lua", "master/recipes.lua", "master/stock.lua",
    "master/trains.lua", "master/monitoring.lua", "master/cctl_adapter.lua",
    "master/drills.lua",
    "master/ui/framework.lua", "master/ui/dashboard.lua",
    "master/ui/craft_menu.lua", "master/ui/workers_tab.lua",
    "master/ui/trains_tab.lua", "master/ui/alarms_tab.lua",
    "master/ui/recipes_tab.lua", "master/ui/drills_tab.lua",
  },
  worker = {
    "worker/main.lua",
    "worker/roles/_machine_base.lua",
    "worker/roles/generic.lua", "worker/roles/mixer.lua",
    "worker/roles/press.lua", "worker/roles/crusher.lua",
    "worker/roles/saw.lua", "worker/roles/spout.lua",
    "worker/roles/deployer.lua", "worker/roles/mcrafter.lua",
    "worker/roles/fan.lua", "worker/roles/sequenced.lua",
    "worker/roles/stock.lua", "worker/roles/trains.lua",
    "worker/roles/package_endpoint.lua", "worker/roles/cctl_bridge.lua",
    "worker/roles/aero_controller.lua", "worker/roles/drill_unload.lua",
    "worker/roles/monitor_slave.lua",
  },
  recipes = {
    "recipes/_template.lua", "recipes/brass.lua", "recipes/andesite_alloy.lua",
  },
  bin = {
    "bin/update.lua", "bin/fct.lua", "bin/setup.lua",
  },
}

local function hasPeripheralType(t)
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == t then return true end
  end
  return false
end

local function hasModem()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then return true end
  end
  return false
end

local function detectDefaultRole()
  -- Advanced Monitor present → master is a good default
  if hasPeripheralType("monitor") then return "master" end
  return "worker"
end

local function download(relPath)
  local url = BASE_URL .. "/" .. relPath
  local path = "/factory/" .. relPath
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local req, err = http.get(url)
  if not req then return false, tostring(err) end
  local data = req.readAll(); req.close()
  if fs.exists(path) then fs.delete(path) end
  local f = fs.open(path, "w")
  f.write(data); f.close()
  return true
end

local function progressBar(i, n)
  local w = 30
  local filled = math.floor(w * i / n + 0.5)
  return "[" .. string.rep("=", filled) .. string.rep(" ", w - filled) ..
    "] " .. i .. "/" .. n
end

local function downloadSet(sets, label)
  local total = 0
  for k, enabled in pairs(sets) do
    if enabled then total = total + #FILES[k] end
  end
  local i, ok = 0, 0
  term.clear(); term.setCursorPos(1, 1)
  print("=== Factory " .. label .. " ===")
  print()
  for k, enabled in pairs(sets) do
    if enabled then
      for _, rel in ipairs(FILES[k]) do
        i = i + 1
        term.setCursorPos(1, 4)
        term.clearLine()
        write(progressBar(i, total))
        term.setCursorPos(1, 5)
        term.clearLine()
        write("  " .. rel:sub(1, 50))
        local dOk, dErr = download(rel)
        if dOk then ok = ok + 1
        else
          term.setCursorPos(1, 6)
          printError("\n  FAIL " .. rel .. ": " .. dErr)
        end
      end
    end
  end
  print()
  print(("Downloaded %d/%d files"):format(ok, total))
  return ok == total
end

local function writeStartup(role)
  local f = fs.open("/startup.lua", "w")
  f.writeLine('-- factory bootstrap (auto-generated)')
  f.writeLine('shell.run("/factory/startup.lua")')
  f.close()
end

local function writeRoleConfig(role)
  if not fs.exists("/factory/data") then fs.makeDir("/factory/data") end
  local f = fs.open("/factory/data/role.dat", "w")
  f.write(textutils.serialize({ role = role, installed = os.epoch("utc") }))
  f.close()
end

local function currentRole()
  if not fs.exists("/factory/data/role.dat") then return nil end
  local f = fs.open("/factory/data/role.dat", "r")
  local data = f.readAll(); f.close()
  local ok, t = pcall(textutils.unserialize, data)
  return ok and t and t.role or nil
end

local function pickRole()
  local default = detectDefaultRole()
  print("Detected: " .. (hasPeripheralType("monitor") and "monitor attached" or "no monitor"))
  print("          " .. (hasModem() and "modem attached" or "NO MODEM — install one"))
  print()
  print("Select role  (press Enter for " .. default .. "):")
  print("  [1] master        [2] worker        [3] monitor_slave")
  write("> ")
  local s = read()
  if s == "" or s == nil then return default end
  if s == "1" or s == "master" then return "master" end
  if s == "2" or s == "worker" then return "worker" end
  if s == "3" or s == "monitor_slave" then return "monitor_slave" end
  return default
end

local function setLabel(role)
  if os.getComputerLabel() then return end
  os.setComputerLabel(("factory-%s-%d"):format(role, os.getComputerID()))
end

local function sets(role)
  local s = { common = true, core = true, bin = true }
  if role == "master" then s.master = true; s.recipes = true
  else s.worker = true end
  return s
end

-- ── Entry ────────────────────────────────────────────────────────────────────

local arg = (...)

-- Update mode: re-download all files for current role, keep role + data
if arg == "update" then
  local role = currentRole()
  if not role then
    printError("No installation found. Run installer without args first.")
    return
  end
  if not downloadSet(sets(role), "update: " .. role) then return end
  print("Updated. Rebooting in 2s..."); os.sleep(2); os.reboot()
end

-- Fresh install. If arg is a role, skip prompt.
local role = arg
if role ~= "master" and role ~= "worker" and role ~= "monitor_slave" then
  role = pickRole()
end

if not hasModem() then
  print()
  printError("WARNING: no modem detected.")
  printError("Attach a Wireless or Ender Modem before the computer can join the network.")
  print()
end

if not downloadSet(sets(role), "install: " .. role) then
  printError("Install failed. Check internet / BASE_URL.")
  return
end

writeRoleConfig(role)
writeStartup(role)
setLabel(role)

print("Install complete. Label: " .. (os.getComputerLabel() or "?"))
print()

if role == "worker" then
  write("Run the role setup wizard now? (Y/n) ")
  local s = read():lower()
  if s == "" or s == "y" or s == "yes" then
    shell.run("/factory/bin/setup.lua")
    return
  end
  print()
  print("You can run it later with:  fct setup")
end

print("Rebooting in 3s...")
os.sleep(3)
os.reboot()
