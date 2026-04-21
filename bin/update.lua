-- Re-downloads the latest install.lua from GitHub and runs it in update mode.
-- Usage: /factory/bin/update.lua        (or the `update` shell alias)

local URL = "https://raw.githubusercontent.com/MelkiWorldi/znatokos-create/main/install.lua"

local req, err = http.get(URL)
if not req then
  printError("Could not fetch installer: " .. tostring(err))
  return
end
local data = req.readAll(); req.close()

local path = "/factory/install.lua"
if fs.exists(path) then fs.delete(path) end
local f = fs.open(path, "w"); f.write(data); f.close()

shell.run(path, "update")
