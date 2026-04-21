# znatokos-create

CC:Tweaked factory controller for Create 6.0 + addons on Minecraft 1.21.1.

Manages the full Create 6.0 logistics stack (Stock Ticker, Frogport, Requester,
Factory Gauge, Chain Conveyor) and orchestrates machine workers (mixer, press,
crusher, spout, deployer, mechanical crafter, fan, sequenced assembly, trains,
Aeronautics controllers) over a rednet network with a master + workers topology.

## Install

On each computer:

```
wget https://raw.githubusercontent.com/MelkiWorldi/znatokos-create/main/install.lua install
install
```

Pick a role (`master`, `worker`, `monitor_slave`) and reboot. On the master,
open the **Workers** tab and assign roles to newly-registered workers.

## Requirements

- Minecraft 1.21.1 + Create 6.0.8+
- CC:Tweaked (native Redstone Relay)
- Advanced Peripherals (Block Reader, Chat Box)
- Ender / Wireless Modem on every computer
- Advanced Monitor for the master

Optional: CC:C Bridge (Source Block, RedRouter), Create: Additional Logistics
(Train Network Monitor), Create: Factory Logistics, Create: CC Total Logistics.

## Recipes

Drop Lua files into `recipes/` and hit **Reload** on the Recipes tab. See
`recipes/_template.lua`.

## Layout

```
core/        eventbus, logger, state, rednet_proto, peripherals, util
master/      scheduler, parstock, registry, recipes, stock, trains, monitoring
master/ui/   dashboard, craft_menu, workers_tab, recipes_tab, trains_tab, alarms_tab
worker/      main + roles/{mixer,press,crusher,saw,spout,deployer,mcrafter,
             fan,sequenced,stock,trains,package_endpoint,cctl_bridge,
             aero_controller,monitor_slave,generic}
recipes/     user-defined Lua recipe files
```
