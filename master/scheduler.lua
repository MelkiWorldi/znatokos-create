local logger  = require("core.logger")
local state   = require("core.state")
local util    = require("core.util")
local bus     = require("core.eventbus")
local net     = require("core.rednet_proto")
local reg     = require("master.registry")
local recipes = require("master.recipes")
local stock   = require("master.stock")

-- Task lifecycle: queued -> assigned -> running -> done|error
-- Task: { id, recipeId, qty, status, workerId?, createdAt, startedAt?, finishedAt?, error?, source }

local M = {}
local PATH = "/factory/data/queue.dat"

local tasks = state.load(PATH, {})
local nextId = 1
for _, t in pairs(tasks) do if t.id >= nextId then nextId = t.id + 1 end end

local TASK_TIMEOUT_PAD = 30  -- extra seconds beyond recipe duration

local function save() state.save(PATH, tasks) end

function M.list() return tasks end

function M.get(id) return tasks[id] end

function M.submit(recipeId, qty, opts)
  opts = opts or {}
  local recipe = recipes.get(recipeId)
  if not recipe then return nil, "unknown recipe" end
  local id = nextId; nextId = nextId + 1
  local task = {
    id = id, recipeId = recipeId, qty = qty or 1,
    status = "queued", createdAt = util.now(),
    source = opts.source or "unknown",
  }
  tasks[id] = task
  save()
  logger.info("sched", ("task #%d queued: %s x%d"):format(id, recipeId, task.qty))
  bus.emit("task_queued", task)
  return task
end

local function sendTask(task, worker, recipe)
  task.workerId = worker.id
  task.status = "assigned"
  task.startedAt = util.now()
  task.timeoutAt = util.now() + (recipe.duration or 10) + TASK_TIMEOUT_PAD
  save()
  net.send(worker.id, {
    type = "task", taskId = task.id, recipe = recipe, qty = task.qty,
  })
  logger.info("sched", ("task #%d -> worker #%d"):format(task.id, worker.id))
end

local function findIdleWorker(role)
  local candidates = reg.byRole(role)
  -- Check which aren't already running a task
  for _, w in ipairs(candidates) do
    if reg.isOnline(w.id) then
      local busy = false
      for _, t in pairs(tasks) do
        if (t.status == "assigned" or t.status == "running") and t.workerId == w.id then
          busy = true; break
        end
      end
      if not busy then return w end
    end
  end
  return nil
end

function M.tick()
  local now = util.now()
  for id, task in pairs(tasks) do
    -- Timeouts
    if (task.status == "assigned" or task.status == "running") and task.timeoutAt and now > task.timeoutAt then
      task.status = "error"; task.error = "timeout"; task.finishedAt = now
      logger.warn("sched", "task #" .. id .. " timed out")
      bus.emit("task_error", task); save()
    end
    -- Dispatch queued
    if task.status == "queued" then
      local recipe = recipes.get(task.recipeId)
      if not recipe then
        task.status = "error"; task.error = "recipe gone"; save()
      else
        local role = recipe.machine or recipes.roleFor(recipe.type) or "generic"
        local worker = findIdleWorker(role)
        if worker then sendTask(task, worker, recipe) end
      end
    end
    -- Cleanup old completed
    if (task.status == "done" or task.status == "error") and task.finishedAt and now - task.finishedAt > 300 then
      tasks[id] = nil
    end
  end
end

function M.onMessage(from, msg)
  if msg.type ~= "progress" then return end
  local task = tasks[msg.taskId]
  if not task then return end
  if msg.stage == "running" then
    task.status = "running"
    bus.emit("task_running", task)
  elseif msg.stage == "done" then
    task.status = "done"; task.finishedAt = util.now()
    logger.info("sched", "task #" .. task.id .. " done")
    bus.emit("task_done", task)
  elseif msg.stage == "error" then
    task.status = "error"; task.error = msg.msg or "unknown"; task.finishedAt = util.now()
    logger.warn("sched", "task #" .. task.id .. " error: " .. tostring(task.error))
    bus.emit("task_error", task)
  end
  save()
end

return M
