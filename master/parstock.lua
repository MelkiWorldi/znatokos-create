local logger    = require("core.logger")
local state     = require("core.state")
local util      = require("core.util")
local recipes   = require("master.recipes")
local stock     = require("master.stock")

local M = {}
local PATH = "/factory/data/parstock.dat"
local TICK_INTERVAL = 5

local rules = state.load(PATH, {})  -- [itemName] = { min, max, address? }
local scheduler
local lastTick = 0

function M.setScheduler(s) scheduler = s end

function M.list() return rules end

function M.set(itemName, min, max, address)
  rules[itemName] = { min = min, max = max, address = address }
  state.save(PATH, rules)
end

function M.remove(itemName)
  rules[itemName] = nil
  state.save(PATH, rules)
end

local function hasActiveTaskFor(recipeId)
  if not scheduler then return false end
  for _, t in pairs(scheduler.list()) do
    if t.recipeId == recipeId and (t.status == "queued" or t.status == "assigned" or t.status == "running") then
      return true
    end
  end
  return false
end

function M.tick()
  if util.now() - lastTick < TICK_INTERVAL then return end
  lastTick = util.now()
  if not scheduler then return end
  for itemName, rule in pairs(rules) do
    local have = 0
    for k, e in pairs(stock.getAll()) do
      if e.name == itemName then have = have + e.count end
    end
    if have < rule.min then
      local recipe = recipes.findByOutput(itemName)
      if recipe and not hasActiveTaskFor(recipe.id) then
        local outCount = (recipe.outputs[1] and recipe.outputs[1].count) or 1
        local needQty = math.ceil((rule.max - have) / outCount)
        scheduler.submit(recipe.id, needQty, { source = "parstock" })
        logger.info("parstock", ("trigger %s: have %d < %d, queued %s x%d"):format(
          itemName, have, rule.min, recipe.id, needQty))
      end
    end
  end
end

return M
