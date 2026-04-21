-- Template recipe. Copy and rename to enable. Files starting with _ are ignored.
return {
  id           = "example_id",
  displayName  = "Example",
  type         = "create:mixing",     -- see registry in master/recipes.lua
  machine      = "mixer",              -- worker role
  heat         = "none",               -- none | heated | superheated
  inputs       = {
    { item = "minecraft:dirt", count = 1 },
  },
  fluidInputs  = {},                   -- { { fluid = "minecraft:water", amount = 250 } }
  outputs      = {
    { item = "minecraft:grass_block", count = 1 },
  },
  duration     = 10,                   -- seconds (used as timeout)
  -- orderVia  = "native",              -- "native" | "cctl"
  -- prepare   = function(ctx) end,
}
