# Iron Yard — Phase 2 Deep Polish Upgrade

This update is a continuation of the existing Phase 2 project, not a new project scaffold.

## New work

### Locomotion and capsule clearance
- Adds crouch with a smoothly resized capsule and matching camera-height transition.
- Standing is blocked when a shape query detects overhead geometry; the player cannot stand through a low ceiling.
- Sprint speed is blended separately from crouched movement speed.
- Adds a small acceleration/turn inertia contribution to the camera and first-person prop.
- Movement telemetry now exposes crouch state and horizontal acceleration.

### Pushable physics props
- Earlier versions added bounded per-contact impulses to tagged `pushable` rigid bodies. This was superseded in v4 by Godot-native character-to-rigidbody contact response to avoid stacking forces.
- Adds a rolling metal canister with a cylinder collider and material-specific physical response.
- Adds a separate impact sound for landing and prevents crouched movement from retaining sprint speed/FOV behavior.
- Existing crate remains a separate pushable rigid body.

### First-person presentation
- Reworks the camera-mounted prop into a detailed, stylized fictional field emitter with layered casing, vents, status display, rivets, side fins, forearm guards, cuffs, and emissive sensor elements.
- Adds movement-synchronised bob, run/sprint lowering, crouch response, acceleration inertia, jump tuck, landing spring, scan pulse, activation pulse, and inspect flourish.
- Activation is strictly cosmetic: no projectile, collision attack, damage, or real-world weapon-operation simulation is implemented.

### Environment and materials
- Adds a second detail pass with a collision-backed machine bay, paired service tanks, fasteners, animated valve wheels, pressure gauges, floor access plates, overhead cable hangers, cable drops, and sector labels.
- Replaces 256 px material maps with seamless 512 px tileable albedo/normal/roughness maps for concrete, painted steel, and rubber.
- Adds a reusable industrial warning stripe tile.

### Mobile controls and HUD
- Adds crouch and cosmetic equipment activation touch buttons.
- HUD now reports movement state, speed, and crouch state alongside performance metrics.

## Compatibility / validation

- Target source baseline remains Godot 4.4+.
- The new crouch stand-up check uses `PhysicsShapeQueryParameters3D` and the active 3D direct-space state.
- The new extra geometry is mostly render-only or MultiMesh-batched; gameplay collision remains separated from micro-detail geometry.
- A runtime integration test is included in the CI workflow to instantiate the generated arena and verify the newly created gameplay props.
- The package still requires Godot headless/editor validation and device profiling. No runtime or Android pass is claimed unless CI/device reports confirm it.
## Instance-safe collision resources

The player duplicates its capsule collision resource per instance before runtime crouch resizing. This avoids one player's stance changing another player's collider when both are instantiated from the same PackedScene. The runtime integration test creates a second player and verifies that the capsule resources are independent.


## Deep polish v3 — contact and animation stability

- Replaced the three lateral surface rays with a five-point footprint sample (center, left, right, front, rear), with a weighted center vote.
- Added a two-sample material hysteresis and eased speed/traction/jump/stride multipliers to avoid abrupt response changes at material seams.
- Changed the standing-headroom query margin to near zero so a character standing just above the floor is not falsely treated as overlapping the floor; runtime integration now tests a temporary low beam and the cleared case.
- Cached step-up collision result objects and retained a single horizontal `move_and_slide()` after step elevation.
- v3 briefly experimented with directional per-contact impulses. The v4 implementation below removes that additional impulse layer in favor of the engine's native response.
- Footstep audio alternates between left/right spatial offsets.
- Replaced the viewmodel's frame-sensitive impact spring with an analytical critically damped spring, bounded animation integration after frame hitches, and wrapped the rotating sensor angle.
- Reduced duplicate per-HUD movement snapshot requests and exposed the detected surface in the HUD telemetry.

The new tests are included in the GitHub Actions headless validation workflow. They have not been executed in this authoring container because a Godot binary is not installed here.


## Deep polish v4 — spawn safety and validation handoff

- Added a cached player-capsule overlap query to `SpawnManager`. It checks authored spawn points against the world collision mask, tries a small set of nearby offsets, and only falls back with an explicit warning when every candidate is obstructed.
- Added a runtime integration assertion for the spawn validation service.
- Removed the additional manually applied push impulse. Godot's native character-to-rigidbody contact response is used instead, avoiding an extra impulse being stacked on top of the engine's own contact response.
- Updated GitHub Actions so the Godot headless validation workflow runs after a successful ZIP extraction workflow. This avoids relying on a second push event from `GITHUB_TOKEN`.
