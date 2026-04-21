-- Interactive role + config wizard.  Writes /factory/data/worker.dat
-- Usage: fct setup [role_name]
-- If role_name is omitted, shows a role picker.

local ROLES = {
  { id = "drill_unload",    label = "Drill unload monitor (mining session stats)" },
  { id = "stock",           label = "Stock ticker bridge" },
  { id = "trains",          label = "Train network monitor" },
  { id = "package_endpoint",label = "Frogport / Postbox monitor" },
  { id = "mixer",           label = "Mechanical Mixer worker" },
  { id = "press",           label = "Mechanical Press worker" },
  { id = "crusher",         label = "Crushing Wheels / Millstone worker" },
  { id = "saw",             label = "Mechanical Saw worker" },
  { id = "spout",           label = "Spout / Item Drain worker" },
  { id = "deployer",        label = "Deployer worker" },
  { id = "mcrafter",        label = "Mechanical Crafter worker" },
  { id = "fan",             label = "Encased Fan worker" },
  { id = "sequenced",       label = "Sequenced Assembly worker" },
  { id = "aero_controller", label = "Aeronautics bearing / burner controller" },
  { id = "cctl_bridge",     label = "CC Total Logistics bridge" },
  { id = "generic",         label = "Generic (redstone pulse)" },
  { id = "monitor_slave",   label = "Monitor slave (extra display)" },
}

local CONFIG_PATH = "/factory/data/worker.dat"

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function clearScreen()
  term.clear(); term.setCursorPos(1, 1)
end

local function header(text)
  term.setTextColor(colors.yellow)
  print("=== " .. text .. " ===")
  term.setTextColor(colors.white)
  print()
end

local function prompt(msg, default)
  if default then write(msg .. " [" .. default .. "] ")
  else write(msg .. " ") end
  local s = read()
  if (s == nil or s == "") and default then return default end
  return s
end

local function promptYes(msg, default)
  local def = default and "Y/n" or "y/N"
  while true do
    write(msg .. " (" .. def .. ") ")
    local s = read():lower()
    if s == "" then return default end
    if s == "y" or s == "yes" then return true end
    if s == "n" or s == "no" then return false end
  end
end

local function promptChoice(msg, options, defaultIdx)
  print(msg)
  for i, opt in ipairs(options) do
    print(("  [%d] %s"):format(i, opt.label or opt))
  end
  while true do
    write("> ")
    local s = read()
    if s == "" and defaultIdx then return options[defaultIdx] end
    local n = tonumber(s)
    if n and options[n] then return options[n] end
    -- also allow typing the id directly
    for _, opt in ipairs(options) do
      if (opt.id or opt) == s then return opt end
    end
    print("invalid, try again")
  end
end

local function scanPeripherals()
  local r = {}
  for _, name in ipairs(peripheral.getNames()) do
    r[#r + 1] = { name = name, type = peripheral.getType(name) or "?" }
  end
  table.sort(r, function(a, b) return a.name < b.name end)
  return r
end

local function pickPeripheral(msg, filterFn)
  local all = scanPeripherals()
  local choices = {}
  for _, p in ipairs(all) do
    if not filterFn or filterFn(p) then
      choices[#choices + 1] = {
        id = p.name,
        label = ("%s  (%s)"):format(p.name, p.type),
      }
    end
  end
  if #choices == 0 then
    print("  no peripherals matching found")
    return nil
  end
  local choice = promptChoice(msg, choices)
  return choice.id
end

local SIDES = { "north", "south", "east", "west", "up", "down", "top", "bottom", "left", "right", "front", "back" }

local function pickSide(default)
  print("Which side reads the signal?")
  print("  (" .. table.concat(SIDES, ", ") .. ")")
  while true do
    local s = prompt(">", default or "top")
    for _, v in ipairs(SIDES) do if s == v then return s end end
    print("invalid side, try again")
  end
end

-- ── Role wizards ─────────────────────────────────────────────────────────────

local wizards = {}

-- Machines that just toggle a Redstone Relay
local function machineWizard(name)
  return function()
    local cfg = {}
    print("Configuring " .. name .. ".")
    print()
    cfg.relay = pickPeripheral("Which Redstone Relay controls the " .. name .. "?",
      function(p) return p.type == "redstone_relay" end)
    if not cfg.relay then
      print("No redstone relay attached — " .. name .. " won't be able to toggle the machine.")
      print("Add one via Wired Modem and run setup again.")
    else
      cfg.side = pickSide("north")
    end
    return cfg
  end
end

function wizards.drill_unload()
  local cfg = { mode = "both", idleTimeout = 15 }
  print("Drill unload monitor tracks mining contraption output.")
  print()

  -- buffer inventory
  cfg.buffer = pickPeripheral(
    "Which inventory is the drill unload buffer? (barrel / vault / chest)",
    function(p)
      return p.type ~= "modem" and p.type ~= "monitor" and p.type ~= "speaker"
         and p.type ~= "redstone_relay" and p.type ~= "chatBox"
    end)

  -- redstone trigger?
  local useRelay = promptYes("Use a redstone trigger (e.g. signal when train arrives)?", false)
  if useRelay then
    cfg.relay = pickPeripheral("Which Redstone Relay?",
      function(p) return p.type == "redstone_relay" end)
    if cfg.relay then cfg.relaySide = pickSide("top") end
  end

  -- mode
  local modes = {
    { id = "both",     label = "Both: start on redstone OR first items; end on redstone low AND idle (recommended)" },
    { id = "auto",     label = "Auto: detect by incoming items only (no redstone needed)" },
    { id = "redstone", label = "Redstone: start/stop strictly by the signal" },
  }
  if not cfg.relay then
    cfg.mode = "auto"
    print("(no relay configured -> mode set to auto)")
  else
    cfg.mode = promptChoice("Trigger mode:", modes, 1).id
  end

  -- idle timeout
  local to = prompt("Idle timeout in seconds (stop session after N seconds with no new items)?", "15")
  cfg.idleTimeout = tonumber(to) or 15

  -- name
  cfg.drillName = prompt("Drill display name?", "Drill #" .. os.getComputerID())

  -- local monitor?
  local hasMon = false
  for _, p in ipairs(scanPeripherals()) do
    if p.type == "monitor" then hasMon = true; break end
  end
  if hasMon then
    if promptYes("A monitor is attached — show drill stats on it?", true) then
      cfg.monitor = pickPeripheral("Which monitor?",
        function(p) return p.type == "monitor" end)
    else
      cfg.showLocal = false
    end
  end
  return cfg
end

function wizards.stock()
  local cfg = {}
  cfg.ticker = pickPeripheral("Which Stock Ticker peripheral? (skip if only one)",
    function(p) return p.type:find("StockTicker") or p.type == "Create_StockTicker" end)
  cfg.address = prompt("Default delivery address (packager/frogport address tag)?",
    "stock")
  return cfg
end

function wizards.trains()
  local cfg = {}
  cfg.monitor = pickPeripheral("Which Train Network Monitor? (optional, skip if none)",
    function(p) return p.type:find("TrainNetworkMonitor") end)
  return cfg
end

function wizards.package_endpoint()
  local cfg = {}
  cfg.endpoint = pickPeripheral("Which Frogport / Postbox?",
    function(p) return p.type:find("Frogport") or p.type:find("Postbox") end)
  cfg.address = prompt("Address for this endpoint?", "local")
  return cfg
end

function wizards.aero_controller()
  local cfg = {}
  cfg.relay = pickPeripheral("Which Redstone Relay controls burners/bearings?",
    function(p) return p.type == "redstone_relay" end)
  cfg.burnerSide = pickSide("south")
  cfg.bearingSide = pickSide("north")
  return cfg
end

function wizards.monitor_slave()
  local cfg = {}
  cfg.monitor = pickPeripheral("Which monitor to display on?",
    function(p) return p.type == "monitor" end)
  return cfg
end

function wizards.generic() return machineWizard("generic relay")() end

wizards.mixer    = machineWizard("mixer")
wizards.press    = machineWizard("press")
wizards.crusher  = machineWizard("crusher")
wizards.saw      = machineWizard("saw")
wizards.spout    = machineWizard("spout")
wizards.deployer = machineWizard("deployer")
wizards.mcrafter = machineWizard("mechanical crafter")
wizards.fan      = machineWizard("fan")
wizards.sequenced = machineWizard("sequenced assembly")
wizards.cctl_bridge = function() return {} end

-- ── Entry ────────────────────────────────────────────────────────────────────

local arg = (...)

clearScreen()
header("Factory setup")

-- Pick role
local role
if arg then
  for _, r in ipairs(ROLES) do if r.id == arg then role = r end end
  if not role then print("Unknown role: " .. arg); print() end
end
if not role then
  role = promptChoice("Pick a role:", ROLES)
end
print()

-- Run wizard
local wizard = wizards[role.id]
local cfg = wizard and wizard() or {}
print()

-- Show summary
header("Review")
print("Role:   " .. role.id)
print("Config:")
local preview = textutils.serialize(cfg):gsub("\n", "\n  ")
print("  " .. preview)
print()

if not promptYes("Save and reboot?", true) then
  print("Aborted. Nothing saved.")
  return
end

-- Load existing, preserve masterId
local existing = {}
if fs.exists(CONFIG_PATH) then
  local f = fs.open(CONFIG_PATH, "r"); local d = f.readAll(); f.close()
  local ok, t = pcall(textutils.unserialize, d); if ok and t then existing = t end
end

local out = {
  role = role.id,
  config = cfg,
  masterId = existing.masterId,
}
if not fs.exists("/factory/data") then fs.makeDir("/factory/data") end
local f = fs.open(CONFIG_PATH, "w")
f.write(textutils.serialize(out)); f.close()

print("Saved. Rebooting in 2s...")
os.sleep(2)
os.reboot()
