# Zombie mode — "Dead City" map

Zombie Survival now loads its own map (`scenes/world/zombie_map.tscn`). The other modes still use Iron Yard.

## Map
- 400 x 400 m (about six times Iron Yard), night, fog, dim moonlight, green/red/blue/orange emissive light pools, flickering lamps.
- Districts: central plaza (survivor start), hospital (NW), Tesla reactor lab (NE), military checkpoint + armory (SW), foundry + heavy-weapon depot (SE), graveyard (N), rail yard (S), residential ruins (W), container maze (E). Buildings have breaches, collapsed roofs and interiors.
- Spawn groups: `survivor` (plaza ring, also used for respawn) and `horde` (outer ring + district corners, always far from the player).
- Weapon shops (E to use, sells for credits, guns last for the match only): Tesla Lab = Tesla gun; Armory = shotgun, SMG, revolver; Foundry Depot = LMG, sniper. Supply stations restore health/ammo.

## Tesla gun (`tesla`)
Hitscan to the first zombie, then the bolt arcs to the nearest enemies (radius 9 m) for 3-5 targets total (85% damage per jump). 5-round magazine, 30 reserve, price 1200 credits, sold only in the Tesla Lab (`map_shop_only`).

## Waves (zombie mode)
| Rule | Result |
|---|---|
| wave % 5 == 0 | whole wave is Sprinters (speed 7.4, 30 HP, 6 dmg) |
| wave % 3 == 0 | wave/3 Brutes (wave 3 = 1, 6 = 2, 9 = 3 ...; 620 HP, speed 2.0, 45 dmg) |
| wave % 10 == 0 | one big Pyro flamethrower zombie (1700 HP, range 13 m) |
| other waves | Walkers, plus Spitters from wave 4 |

After a wave that is a multiple of 5: all guns refilled and grenades/traps set to 4/4. Zombies rarely drop a purple supply crate (ammo + 4 grenades + 4 traps); Brutes drop it 30% of the time, the Pyro always.

## Gadgets
- Grenade: key X (touch button), 190 damage, 7.5 m radius, 2.2 s fuse.
- Trap: key C (touch button), arms after 1 s, 150 damage + near-stop for 4 s.
- HUD header shows both counts. Max 4 each.

## Health (all modes)
The red screen grows with missing health. After 3 s without damage, health refills completely over 6 s (`HealthComponent.regen_*`, enabled for the player in `player_controller.gd`).

## Tuning
Numbers live in `bot_definitions.gd` (zombies), `mode_manager.gd::_wave_list`, `weapon_definitions.gd` (tesla), `gadget_controller.gd` / `grenade_projectile.gd` / `zombie_trap.gd`, `health_component.gd`.

## Not verified
No Godot executable was available while this was written, so none of it has been parsed or run. Run `tests/zombie_map_test.gd` and the existing tests first (see `tests/README.md`).
