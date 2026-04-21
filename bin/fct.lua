-- fct — factory CLI. Shortcut commands.
-- Usage:
--   fct               show status
--   fct update        pull latest code
--   fct reinstall     re-run installer (prompts for role)
--   fct role          print current role
--   fct log           tail log.txt
--   fct peripherals   list attached peripherals with their types
--   fct reset         wipe /factory/data (keeps code) and reboot
--   fct setup [role]  interactive role + config wizard (recommended)
--   fct export        copy /factory/data to attached disk (migration)
--   fct import        restore /factory/data from attached disk
--   fct find-master   force rediscovery of master on this worker

local args = { ... }
local cmd = args[1]

local function readRole()
  if not fs.exists("/factory/data/role.dat") then return nil end
  local f = fs.open("/factory/data/role.dat", "r")
  local d = f.readAll(); f.close()
  local ok, t = pcall(textutils.unserialize, d)
  return ok and t and t.role or nil
end

if not cmd or cmd == "status" then
  print("Factory status:")
  print("  label: " .. (os.getComputerLabel() or "-"))
  print("  id:    " .. os.getComputerID())
  print("  role:  " .. (readRole() or "-"))
  print("  up:    " .. math.floor(os.clock()) .. "s")
  local online = rednet.isOpen() and "yes" or "no"
  print("  net:   " .. online)
elseif cmd == "setup" then
  shell.run("/factory/bin/setup.lua", args[2])
elseif cmd == "update" then
  shell.run("/factory/bin/update.lua")
elseif cmd == "reinstall" then
  shell.run("/factory/install.lua")
elseif cmd == "role" then
  print(readRole() or "none")
elseif cmd == "log" then
  if fs.exists("/factory/data/log.txt") then
    shell.run("edit /factory/data/log.txt")
  else print("no log yet") end
elseif cmd == "peripherals" then
  for _, name in ipairs(peripheral.getNames()) do
    print(("  %-20s  %s"):format(peripheral.getType(name) or "?", name))
  end
elseif cmd == "reset" then
  print("Wiping /factory/data ... type YES to confirm:")
  write("> ")
  if read() == "YES" then
    if fs.exists("/factory/data") then fs.delete("/factory/data") end
    print("Wiped. Rebooting.")
    os.sleep(1); os.reboot()
  else print("aborted") end
elseif cmd == "export" then
  local diskPath = nil
  for _, mount in ipairs(fs.list("/")) do
    if mount:sub(1, 4) == "disk" then diskPath = "/" .. mount; break end
  end
  if not diskPath then
    printError("No disk drive attached. Add a Disk Drive next to this computer with a floppy.")
    return
  end
  local src = "/factory/data"
  if not fs.exists(src) then printError("no data to export"); return end
  local dst = diskPath .. "/factory-backup"
  if fs.exists(dst) then fs.delete(dst) end
  fs.copy(src, dst)
  print("Exported to " .. dst)
  print("Contents:")
  for _, f in ipairs(fs.list(dst)) do print("  " .. f) end
elseif cmd == "import" then
  local diskPath = nil
  for _, mount in ipairs(fs.list("/")) do
    if mount:sub(1, 4) == "disk" then diskPath = "/" .. mount; break end
  end
  if not diskPath then printError("no disk attached"); return end
  local src = diskPath .. "/factory-backup"
  if not fs.exists(src) then printError("no /factory-backup on disk"); return end
  print("Importing from " .. src .. " — this will overwrite /factory/data. Type YES:")
  write("> ")
  if read() ~= "YES" then print("aborted"); return end
  if fs.exists("/factory/data") then fs.delete("/factory/data") end
  fs.copy(src, "/factory/data")
  print("Imported. Rebooting.")
  os.sleep(1); os.reboot()
elseif cmd == "find-master" then
  -- Force worker to re-lookup master
  local cfgPath = "/factory/data/worker.dat"
  if not fs.exists(cfgPath) then printError("not a worker"); return end
  local f = fs.open(cfgPath, "r"); local d = f.readAll(); f.close()
  local t = textutils.unserialize(d)
  t.masterId = nil
  f = fs.open(cfgPath, "w"); f.write(textutils.serialize(t)); f.close()
  print("Cleared masterId. Reboot to rediscover.")
else
  print("Unknown command: " .. cmd)
  print("Try: status | setup | update | reinstall | role | log | peripherals")
  print("     reset | export | import | find-master")
end
