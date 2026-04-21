return {
  id          = "create:brass_ingot",
  displayName = "Brass Ingot",
  type        = "create:mixing",
  machine     = "mixer",
  heat        = "heated",
  inputs = {
    { item = "minecraft:copper_ingot", count = 1 },
    { item = "create:zinc_ingot",      count = 1 },
  },
  outputs = {
    { item = "create:brass_ingot", count = 2 },
  },
  duration = 10,
}
