# znatokos-create

CC:Tweaked factory controller for Create 6.0 + addons on Minecraft 1.21.1.

Manages the full Create 6.0 logistics stack (Stock Ticker, Frogport, Requester,
Factory Gauge, Chain Conveyor) and orchestrates machine workers (mixer, press,
crusher, spout, deployer, mechanical crafter, fan, sequenced assembly, trains,
Aeronautics controllers) over a rednet network with a master + workers topology.

## Install (one command)

```
wget run https://raw.githubusercontent.com/MelkiWorldi/znatokos-create/main/install.lua
```

Auto-detects the default role (monitor attached → `master`, else `worker`),
prompts only if ambiguous, downloads everything, labels the computer, reboots.

Non-interactive variants — append the role as an argument:

```
wget run <url> master
wget run <url> worker
wget run <url> monitor_slave
```

On the master, open the **Workers** tab and assign roles to new workers.

## Update

On any computer, from the shell:

```
update
```

Re-pulls the latest code for the role this computer is running. Data (registry,
queue, par-stock, recipes, drill history) is preserved.

## CLI

```
fct                 # status
fct peripherals     # list attached peripherals with types
fct log             # open /factory/data/log.txt
fct reinstall       # re-run installer interactively
fct reset           # wipe /factory/data (keeps code), reboot
fct export          # copy /factory/data onto a floppy (for migration)
fct import          # restore /factory/data from a floppy
fct find-master     # force a worker to rediscover the master
```

## Migrating the master

Workers locate the master by the well-known label `master` in the rednet
protocol, not by a fixed computer ID — so you can move the master anywhere on
the network without reconfiguring workers.

1. On the **old master**: attach a Disk Drive with a floppy, run `fct export`,
   pop out the floppy.
2. On the **new computer**: install master (`wget run <url> master`), insert
   the floppy, run `fct import`, reboot.
3. Workers discover the new master automatically within ~30s. If a worker
   stays stuck on the old cached ID, run `fct find-master` on it (or just
   reboot it).

You can also skip the floppy and transfer data in-game via a Wired Modem chain
— any shared filesystem works; the installer only cares that `/factory/data`
exists on the new master before it reads state on boot.

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
