local logger = require("core.logger")
local bus    = require("core.eventbus")

local M = {}
local DIR = "/factory/recipes"
local registry = {}  -- [id] = recipe

local VALID_TYPES = {
  ["create:mixing"] = true, ["create:compacting"] = true,
  ["create:pressing"] = true, ["create:crushing"] = true,
  ["create:milling"] = true, ["create:cutting"] = true,
  ["create:filling"] = true, ["create:emptying"] = true,
  ["create:splashing"] = true, ["create:haunting"] = true,
  ["create:smoking"] = true, ["create:fan_blasting"] = true,
  ["create:deploying"] = true, ["create:item_application"] = true,
  ["create:mechanical_crafting"] = true, ["create:sequenced_assembly"] = true,
  ["createaddition:rolling"] = true, ["createaddition:charging"] = true,
  ["sliceanddice:slicing"] = true, ["farmersdelight:cooking"] = true,
  ["create_factory_logistics:fluid_packaging"] = true,
  ["minecraft:crafting_shaped"] = true, ["minecraft:crafting_shapeless"] = true,
}

local TYPE_TO_ROLE = {
  ["create:mixing"] = "mixer", ["create:compacting"] = "press",
  ["create:pressing"] = "press", ["create:crushing"] = "crusher",
  ["create:milling"] = "crusher", ["create:cutting"] = "saw",
  ["create:filling"] = "spout", ["create:emptying"] = "spout",
  ["create:splashing"] = "fan", ["create:haunting"] = "fan",
  ["create:smoking"] = "fan", ["create:fan_blasting"] = "fan",
  ["create:deploying"] = "deployer", ["create:item_application"] = "deployer",
  ["create:mechanical_crafting"] = "mcrafter",
  ["create:sequenced_assembly"] = "sequenced",
  ["createaddition:rolling"] = "press", ["createaddition:charging"] = "generic",
  ["sliceanddice:slicing"] = "saw", ["farmersdelight:cooking"] = "mixer",
  ["create_factory_logistics:fluid_packaging"] = "spout",
  ["minecraft:crafting_shaped"] = "mcrafter",
  ["minecraft:crafting_shapeless"] = "mcrafter",
}

function M.roleFor(type_) return TYPE_TO_ROLE[type_] end

local function validate(recipe, source)
  if type(recipe) ~= "table" then return false, "not a table" end
  if not recipe.id then return false, "missing id" end
  if recipe.delegate == "cctl" then return true end  -- minimal shape for CCTL delegates
  if not recipe.type then return false, "missing type" end
  if not VALID_TYPES[recipe.type] then return false, "unknown type " .. recipe.type end
  if not recipe.outputs or #recipe.outputs == 0 then return false, "no outputs" end
  recipe.inputs = recipe.inputs or {}
  recipe.fluidInputs = recipe.fluidInputs or {}
  recipe.duration = recipe.duration or 10
  recipe.machine = recipe.machine or TYPE_TO_ROLE[recipe.type] or "generic"
  recipe._source = source
  return true
end

function M.load(path)
  local ok, chunk = pcall(loadfile, path)
  if not ok or not chunk then
    logger.error("recipes", "loadfile failed: " .. path)
    return nil
  end
  local ok2, recipe = pcall(chunk)
  if not ok2 then
    logger.error("recipes", "exec failed: " .. path .. ": " .. tostring(recipe))
    return nil
  end
  local vOk, err = validate(recipe, path)
  if not vOk then
    logger.error("recipes", "invalid: " .. path .. ": " .. err)
    return nil
  end
  return recipe
end

function M.loadAll()
  registry = {}
  if not fs.exists(DIR) then fs.makeDir(DIR); return end
  for _, file in ipairs(fs.list(DIR)) do
    if file:sub(-4) == ".lua" and file:sub(1, 1) ~= "_" then
      local r = M.load(DIR .. "/" .. file)
      if r then registry[r.id] = r end
    end
  end
  logger.info("recipes", "loaded " .. #M.list() .. " recipes")
  bus.emit("recipes_reloaded")
end

function M.list()
  local r = {}
  for _, v in pairs(registry) do r[#r + 1] = v end
  table.sort(r, function(a, b) return a.id < b.id end)
  return r
end

function M.get(id) return registry[id] end

function M.findByOutput(itemName)
  for _, r in pairs(registry) do
    for _, o in ipairs(r.outputs or {}) do
      if o.item == itemName then return r end
    end
  end
  return nil
end

return M
