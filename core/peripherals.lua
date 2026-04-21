local M = {}

M.TYPES = {
  stockTicker      = "Create_StockTicker",
  station          = "Create_Station",
  speedometer      = "Create_Speedometer",
  stressometer     = "Create_Stressometer",
  rotationSpeed    = "Create_RotationSpeedController",
  sequencedGear    = "Create_SequencedGearshift",
  displayLink      = "Create_Target",
  frogport         = "Create_PackageFrogport",
  postbox          = "Create_PackagePostbox",
  requester        = "Create_RedstoneRequester",
  factoryGauge     = "Create_FactoryGauge",
  chainConveyor    = "Create_ChainConveyor",
  packager         = "Create_Packager",
  trainNetMonitor  = "Create_TrainNetworkMonitor",
  blockReader      = "blockReader",
  chatBox          = "chatBox",
  envDetector      = "environmentDetector",
  inventoryMgr     = "inventoryManager",
  geoScanner       = "geoScanner",
  redstoneRelay    = "redstone_relay",
  redRouter        = "redrouter",
  sourceBlock      = "create_source",
  monitor          = "monitor",
  speaker          = "speaker",
  modem            = "modem",
}

function M.findAll(type_)
  local out = {}
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == type_ then
      out[#out + 1] = name
    end
  end
  return out
end

function M.findOne(type_)
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == type_ then return name end
  end
  return nil
end

function M.wrap(type_)
  local name = M.findOne(type_)
  if not name then return nil end
  return peripheral.wrap(name), name
end

function M.wrapAll(type_)
  local r = {}
  for _, name in ipairs(M.findAll(type_)) do
    r[name] = peripheral.wrap(name)
  end
  return r
end

function M.hasType(type_)
  return M.findOne(type_) ~= nil
end

function M.scan()
  local result = {}
  for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    result[#result + 1] = { name = name, type = t }
  end
  return result
end

return M
