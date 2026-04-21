-- fct — factory CLI. Shortcut commands.
-- Usage:
--   fct              show status
--   fct update       pull latest code
--   fct reinstall    re-run installer (prompts for role)
--   fct role         print current role
--   fct log          tail log.txt
--   fct peripherals  list attached peripherals with their types
--   fct reset        wipe /factory/data (keeps code) and reboot

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
else
  print("Unknown command: " .. cmd)
  print("Try: status | update | reinstall | role | log | peripherals | reset")
end
