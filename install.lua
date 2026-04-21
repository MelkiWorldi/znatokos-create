-- Factory installer for CC:Tweaked
-- Usage: pastebin get <ID> install  (or wget <URL> install)
-- Then:  install

local BASE_URL = "https://raw.githubusercontent.com/MelkiWorldi/znatokos-create/main"

local FILES = {
  core = {
    "core/util.lua", "core/eventbus.lua", "core/logger.lua",
    "core/state.lua", "core/rednet_proto.lua", "core/peripherals.lua",
  },
  master = {
    "master/main.lua", "master/scheduler.lua", "master/parstock.lua",
    "master/registry.lua", "master/recipes.lua", "master/stock.lua",
    "master/trains.lua", "master/monitoring.lua", "master/cctl_adapter.lua",
    "master/ui/framework.lua", "master/ui/dashboard.lua",
    "master/ui/craft_menu.lua", "master/ui/workers_tab.lua",
    "master/ui/trains_tab.lua", "master/ui/alarms_tab.lua",
    "master/ui/recipes_tab.lua",
  },
  worker = {
    "worker/main.lua",
    "worker/roles/generic.lua", "worker/roles/mixer.lua",
    "worker/roles/press.lua", "worker/roles/crusher.lua",
    "worker/roles/saw.lua", "worker/roles/spout.lua",
    "worker/roles/deployer.lua", "worker/roles/mcrafter.lua",
    "worker/roles/fan.lua", "worker/roles/sequenced.lua",
    "worker/roles/stock.lua", "worker/roles/trains.lua",
    "worker/roles/package_endpoint.lua", "worker/roles/cctl_bridge.lua",
    "worker/roles/aero_controller.lua", "worker/roles/monitor_slave.lua",
  },
  recipes = {
    "recipes/_template.lua", "recipes/brass.lua", "recipes/andesite_alloy.lua",
  },
}

local function download(relPath)
  local url = BASE_URL .. "/" .. relPath
  local path = "/factory/" .. relPath
  print("  " .. relPath)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local req, err = http.get(url)
  if not req then
    printError("FAIL " .. relPath .. ": " .. tostring(err))
    return false
  end
  local data = req.readAll(); req.close()
  if fs.exists(path) then fs.delete(path) end
  local f = fs.open(path, "w")
  f.write(data); f.close()
  return true
end

local function ask(msg, options)
  print(msg)
  for i, o in ipairs(options) do print("  " .. i .. ") " .. o) end
  while true do
    write("> ")
    local n = tonumber(read())
    if n and options[n] then return options[n] end
    print("invalid")
  end
end

local function writeStartup(role)
  local f = fs.open("/startup.lua", "w")
  f.writeLine('-- factory startup')
  f.writeLine('package.path = "/factory/?.lua;/factory/?/init.lua;" .. package.path')
  if role == "master" then
    f.writeLine('shell.run("/factory/master/main.lua")')
  elseif role == "monitor_slave" then
    f.writeLine('shell.run("/factory/worker/main.lua monitor_slave")')
  else
    f.writeLine('shell.run("/factory/worker/main.lua")')
  end
  f.close()
end

local function writeRoleConfig(role)
  if not fs.exists("/factory/data") then fs.makeDir("/factory/data") end
  local f = fs.open("/factory/data/role.dat", "w")
  f.write(textutils.serialize({ role = role, installed = os.epoch("utc") }))
  f.close()
end

print("=== Factory Installer ===")
local role = ask("Select role:", { "master", "worker", "monitor_slave" })
print("Installing " .. role .. "...")

local sets = { core = true }
if role == "master" then sets.master = true; sets.recipes = true end
if role == "worker" or role == "monitor_slave" then sets.worker = true end

local total, ok = 0, 0
for setName, enabled in pairs(sets) do
  if enabled then
    for _, rel in ipairs(FILES[setName]) do
      total = total + 1
      if download(rel) then ok = ok + 1 end
    end
  end
end

print(("Downloaded %d/%d files"):format(ok, total))
if ok < total then
  printError("Some downloads failed. Check BASE_URL and internet.")
  return
end

writeRoleConfig(role)
writeStartup(role)

print("Install complete. Rebooting in 3s...")
os.sleep(3)
os.reboot()
