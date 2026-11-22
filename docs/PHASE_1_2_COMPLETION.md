# Phases 1 and 2 — completion report

## Phase 1 — foundation
| # | Item | State |
|---|------|-------|
| 1 | Godot 4 project | boot -> main menu -> maps; icon, landscape, stretch `expand` for every phone aspect |
| 2 | Architecture | autoloads: EventBus, AppState, SettingsManager, SaveManager, Loc, PerformanceManager |
| 3 | Folder structure | `scripts/{core,autoload,player,weapons,input,ui,world,gameplay,...}`, `scenes/{boot,ui,player,world}`, `data/definitions` |
| 4 | Save system | atomic write (tmp+rename), `.bak` recovery, `.corrupt` quarantine, schema v2 + migration, debounced autosave, flush on pause/quit; credits, score, stats, progress, equipment |
| 5 | Settings | quality preset, auto-quality, FOV, 3 volume buses (applied to Master/Music/SFX), mouse + touch sensitivity, invert Y, button size/opacity, vibration, debug overlay, Persian/English; full settings screen |

## Phase 2 — core
| # | Item | State |
|---|------|-------|
| 6 | Player | first person, third person (camera button / V), stamina, sprint |
| 7 | Touch | round icon buttons, safe-area aware layout, multi-touch, fire+drag to aim, push-stick-to-sprint |
| 8 | Desktop | WASD, mouse, Ctrl, R reload, V camera, T weather, Esc pause |
| 9 | Collision | capsule, step climbing, surface types, wall-aware weapon |
| 10 | Health | health + armor (absorbs 60%), damage vignette, death, 3 s respawn, void kill |
| 11 | Animation | rifle viewmodel with two hands, recoil, bolt, reload (magazine swap), inspect, sprint pose, third-person body with leg swing |
| 12 | Camera | FOV setting, recoil recovery, slide tilt, spring-arm third person |

## Requested fixes
- Buttons are drawn circles with icons (no text, no rectangles).
- Rifle is held correctly: right hand on the grip with finger on the trigger, left hand under the handguard.
- Firing: hitscan from the crosshair with spread, recoil, muzzle flash, shell ejection, procedural sound.
- Bullets are visible moving tracers (bright streak + head).
- Bullet holes stay on surfaces permanently (capped at 90, oldest removed), also follow moving bodies.
- Jump works while walking and running (own multi-touch button).
- While sprinting, tapping crouch starts a slide; otherwise tapping crouch sits/stands (toggle).
