return {
  id          = "create:andesite_alloy",
  displayName = "Andesite Alloy",
  type        = "create:mixing",
  machine     = "mixer",
  heat        = "none",
  inputs = {
    { item = "minecraft:andesite", count = 1 },
    { item = "minecraft:iron_nugget", count = 1 },
  },
  outputs = {
    { item = "create:andesite_alloy", count = 1 },
  },
  duration = 8,
}
