-- factory bootstrap: dispatch to master/worker based on /factory/data/role.dat
package.path = "/factory/?.lua;/factory/?/init.lua;" .. package.path

-- Register short aliases so `update` and `fct` work from the shell.
if shell and shell.setAlias then
  if fs.exists("/factory/bin/update.lua") then
    shell.setAlias("update", "/factory/bin/update.lua")
  end
  if fs.exists("/factory/bin/fct.lua") then
    shell.setAlias("fct", "/factory/bin/fct.lua")
  end
end

local function readRole()
  if not fs.exists("/factory/data/role.dat") then return nil end
  local f = fs.open("/factory/data/role.dat", "r")
  local data = f.readAll(); f.close()
  local ok, t = pcall(textutils.unserialize, data)
  if ok and t then return t.role end
  return nil
end

local role = readRole()
if not role then
  printError("No role configured. Run /factory/install.lua first.")
  return
end

if role == "master" then
  shell.run("/factory/master/main.lua")
elseif role == "monitor_slave" then
  shell.run("/factory/worker/main.lua monitor_slave")
else
  shell.run("/factory/worker/main.lua")
end
