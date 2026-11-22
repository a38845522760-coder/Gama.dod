# Iron Yard

**New:** Zombie Survival now has its own huge dark map, "Dead City" — see `docs/ZOMBIE_MODE_DEAD_CITY.md`.

**Status:** Phases 1-2 complete, Phase 3 started (main map, weather, regions, spawns).
See `docs/PHASE_1_2_COMPLETION.md` and `docs/PHASE_3_PROGRESS.md`.

# Iron Yard — Phase 2 Core

This archive is a **complete replacement project folder** based on the Phase 1 repository, with a first playable first-person core and a dedicated physics test arena.

## Requirements

- Godot 4.4 or newer (standard editor build).
- Desktop test: Windows, Linux, or macOS.
- Android export requires a matching Godot export template, Android SDK/JDK setup, and device testing. No signed APK is included because signing credentials must remain private.

## Run

1. Extract the ZIP. `project.godot` must be at the extracted project root.
2. Import `project.godot` in Godot Project Manager.
3. Let the editor finish importing, then press Run.
4. The project opens directly in the Core Test Arena.

## Controls

| Action | Desktop | Touch |
|---|---|---|
| Move | WASD / arrows | Left virtual joystick |
| Look | Mouse | Drag on right half of screen |
| Jump | Space | JUMP button |
| Sprint | Left Shift | SPRINT button |
| Interact | E | USE button |
| Crouch | Left Ctrl (hold) | CROUCH button |
| Equipment activation (cosmetic visual only) | Left mouse | ACT button |
| Utility scanner scan effect (visual only) | Q | SCAN button |
| Inspect equipment animation | G | — |
| Release mouse | Escape | — |

Click the game viewport to capture the mouse again. The test arena contains a floor, perimeter walls, step flight, ramp, platforms, collision obstacles, an interactable console, service pipes, wall ribs, vents, floor grid marks, safety markings, work lights, a machine service bay, pressure gauges, valve wheels, and pushable crate/canister physics props. It is a physics/controls test map, not the final art map.

## Implemented in this package

- Refined first-person `CharacterBody3D` controller with smooth acceleration/deceleration, sprint transition blending, air control, jump buffering, coyote time, floor snapping, slope handling, conservative step-up probes, camera bob/lean/FOV response, and landing feedback.
- Variable-height jump, jump buffering, coyote time, faster fall response, terminal fall-speed limit, and conservative step traversal.
- Damped landing camera spring, speed-scaled sprint bob, lateral lean, sprint FOV response, and jump/landing feedback for the first-person presentation rig.
- Distance-based footsteps with separately synthesized concrete, metal, rubber, and crate sound profiles, pooled 3D audio players, and landing-dust particles.
- Procedural first-person stylized utility-scanner viewmodel with layered casing details, emissive core, forearm guards, idle/run sway, sprint lowering, look response, and non-weapon scan-light animation. This is a fictional visual effect, not a simulation of real weapon operation.
- Expanded physics arena detailing using instanced floor/wall geometry, tileable PBR albedo/normal/roughness textures, floor drains and grate bars, overhead cable trays and bundles, wall service panels and fasteners, service conduits, rotating ventilation fans, a pulsing warning beacon, moving physics platform, safety markings, work lights, reinforced crate details, and a dynamic rigid-body test crate.
- Capsule collision, camera pivot, interaction ray, health component, player runtime state, bounded pushing of tagged rigid-body props, and movement telemetry.
- Touch joystick, right-side touch-look area, crouch and equipment-activation controls; keyboard/mouse remains available on desktop.
- Procedural industrial physics arena with separate visual meshes and collision shapes, expanded machinery details, pressure gauges, valve wheels, service tanks, access plates, labels, and pushable props.
- Interaction base contract and a working test console.
- Match lifecycle foundation and local ENet host/client adapter (LAN transport foundation, not a complete 4-player game mode).
- Low/Medium/High/Ultra render scaling and shadow tiers, 512 px seamless PBR material maps, plus frame-time diagnostics and opt-in dynamic quality.
- Existing Phase 1 settings/save services retained and extended only where needed.
- Headless smoke-test script, QA checklist, implementation notes, and CI validation workflow.

## Explicit limits

This is the Phase 2 playable-core implementation with an additional deep-polish pass, **not the finished game**. It does not contain final maps, AI, inventory/shop, finished combat systems, full lobby/discovery/reconnect flow, or the designer's future zombie-mode content. The LAN adapter exposes host/client transport only; gameplay replication and Android hotspot discovery still need dedicated development and real-device tests. The handheld field emitter is a fictional visual placeholder and has no projectile or damage behavior. Android 8.1 compatibility is not promised by the current Godot 4.4+ baseline and must be checked against the selected engine/export toolchain.

No Godot executable was available in the authoring environment, so this archive has not been run through the Godot parser or launched on an Android device here. Run the included validation workflow or the commands in `tests/README.md` before treating the build as release-ready.

See `docs/PHASE_2_DEEP_POLISH_UPGRADE.md` for the latest movement, presentation, material, and environment changes.


## Movement and presentation deep upgrade

- Step assistance now lifts the body before the single normal `move_and_slide()` displacement; the old double-horizontal-advance path has been removed.
- Gait timing is based on distance travelled, keeping camera bob, hand sway, and procedural footsteps aligned across frame rates.
- Ground movement responds to concrete, painted steel, rubber, crates, and grates through per-surface speed, traction, stride, and audio profiles.
- Sprint includes a configurable endurance/recovery loop with lockout and HUD telemetry.
- Slope-aware steering, counter-steering, directional speed shaping, ceiling-hit handling, and deduplicated pushable-body response are included.
- The first-person fictional field emitter has denser micro-details, a rotating survey sensor, wrist indicators, articulated stylized glove segments, and stronger run/inspect/scan/landing presentation.
- The test arena contains flush surface-response panels for concrete, steel, rubber, and grate comparison.

These are source-level implementations. Final physics feel, renderer performance, and Android compatibility still require running the Godot validation workflow and testing on target devices.


## Deep polish v3 — physics contact stability

The latest core update expands ground-material sampling to a five-point footprint, adds surface-transition hysteresis and blended movement response, fixes the headroom query margin, caches stair-test collision objects, and uses Godot's native character-to-rigidbody contact response instead of layering custom impulses. Footstep sources alternate left/right for more spatially grounded feedback. The fictional field-emitter viewmodel now uses a critically damped impact spring and bounded frame integration. Runtime integration checks cover low-ceiling clearance and collision-aware spawn selection. Godot engine/runtime and device tests remain required before calling this version validated.


## Deep polish v4 — collision-aware spawning

Spawn selection now checks a reusable player-sized capsule against the active physics world, tests the authored point plus nearby fallback offsets, and logs a warning if the entire spawn set is obstructed. GitHub Actions validation is chained after a successful ZIP extraction so the extracted project is headless-checked automatically.


## Native rigid-body contact response

The player no longer layers a custom per-contact impulse on top of `CharacterBody3D.move_and_slide()`. Godot already affects contacted `RigidBody3D` bodies through the character motion path; the test crate and canister use explicit mass, damping, continuous collision detection, and physics materials instead. This keeps the response easier to tune and avoids double-applying contact impulses.

## Phase 3 — Modes, AI, Shop
- Modes: Free-for-all, Team Deathmatch, Zombie waves, Assault (waves with allies), Practice.
- Bots: grunt, rusher (shotgun), marksman (sniper), heavy (LMG), officer (revolver); zombies: walker, runner, brute, spitter, tyrant boss.
- Shop: weapons, medkit/armor/ammo, permanent upgrades (credits earned from kills and matches).
- Controls: 1-7 / wheel / F weapons, H medkit, J armor, K ammo, B shop. On touch: weapon bar and quick buttons.
