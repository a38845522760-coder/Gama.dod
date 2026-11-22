# Phase 2 QA Checklist

## Controller, animation, and collision

- [ ] Move in all four directions and diagonally; diagonal speed must not exceed the configured cap.
- [ ] Accelerate, stop, and reverse direction; motion should not snap or drift unexpectedly.
- [ ] Hold and release sprint; speed, camera height, FOV, and viewmodel pose must blend smoothly without one-frame jumps.
- [ ] Walk and sprint in diagonals; speed must remain capped and animation cadence must match actual ground speed.
- [ ] Verify footstep cadence is distance-based and only plays while grounded.
- [ ] Walk across concrete, step metal, ramp, and the moving platform; confirm surface metadata and footstep tone change as expected.
- [ ] Hold jump at different durations; verify tap-jumps are shorter and held jumps are taller.
- [ ] Drop from multiple heights; verify faster falling remains capped and landing camera response remains restrained.
- [ ] Trigger the scanner scan-light repeatedly; glow and viewmodel movement must settle without accumulating transform offsets.
- [ ] Verify forearm guards and device remain inside the intended view on 16:9, tall-phone, and narrow aspect ratios.
- [ ] Land from several safe test heights; camera compression and dust burst should be brief and not obscure the view.
- [ ] Walk against each arena wall and into corners; no visible capsule penetration or permanent sticking.
- [ ] Traverse the step flight in both directions; verify every riser and edge.
- [ ] Traverse the ramp in both directions and verify stable ground contact.
- [ ] Push the dynamic test crate from multiple sides and verify expected mass, friction, resting stability, and no tunneling at normal player speed.
- [ ] Ride the moving platform; verify the player follows its motion without jitter or unexpected sliding.
- [ ] Observe the two rotating wall fans and warning beacon; confirm animation is smooth and light does not flicker excessively.
- [ ] Jump from level ground and near an edge; verify jump buffer and coyote-time windows.
- [ ] Land on the low platform and move off its edges.
- [ ] Verify that the camera remains above the ground and does not enter walls at ordinary speed.

## Interaction and health foundation

- [ ] Aim at the blue console and verify the prompt appears only while the ray hits it.
- [ ] Press E / USE and verify the interaction log appears once per press.
- [ ] Verify an unavailable interaction is not offered.
- [ ] In a temporary test harness, verify health clamps to [0, max] and depletion emits once.

## Input

- [ ] Test mouse capture/release and mouse look on desktop.
- [ ] Test keyboard movement, jump, sprint, interact, and the separate left-mouse cosmetic activation, Q scanner scan, and G inspect controls.
- [ ] On a touchscreen device, hold the joystick while dragging the right look area.
- [ ] Press two touch action buttons while moving; confirm no action gets stuck after release.
- [ ] Verify the SCAN touch button only triggers the stylized scan-light feedback.
- [ ] Rotate the device and verify controls remain inside the viewport.

## Performance and persistence

- [ ] Record FPS and p95 frame time for Low, Medium, High, and Ultra on the same device and scene.
- [ ] Verify profile changes affect render scale/shadows but do not change movement/physics.
- [ ] Enable dynamic quality and verify only rendering quality changes.
- [ ] Change sensitivity and quality preset, restart, and verify settings persist.
- [ ] Run for at least 15 minutes and watch memory and thermal behavior.

## Network adapter

- [ ] In an isolated test, host on a private LAN and join from another device.
- [ ] Verify peer join/leave signals.
- [ ] Verify host shutdown returns the adapter to offline.
- [ ] Do not treat transport connection as proof of gameplay replication or Android hotspot discovery.


## Enhanced locomotion / body clearance

- [ ] Hold crouch and verify the capsule shrinks smoothly while the camera lowers smoothly.
- [ ] Release crouch beneath a low ceiling; the player must remain crouched without clipping.
- [ ] Move out from beneath the ceiling; standing must resume automatically when clearance exists.
- [ ] Walk, sprint, jump, and land while observing first-person equipment sway and forearm motion.
- [ ] Check camera roll during strafing and acceleration changes; no persistent camera drift is allowed.
- [ ] Verify footstep cadence changes with walk/sprint/crouch and surface type.
- [ ] Push the test crate and canister; verify stable impulses, no explosive jitter, and no excessive acceleration.

## First-person presentation (fictional prop only)

- [ ] Verify idle breathing, movement bob, sprint lowering, crouch lowering, airborne tuck, and landing settle.
- [ ] Activate the equipment animation; confirm it is only a local glow/light animation with no projectile or damage.
- [ ] Trigger scan and inspect animations; verify they blend back to idle without snapping.
- [ ] Confirm first-person prop is hidden for non-authoritative remote player instances.

## Environment detail / materials

- [ ] Inspect 512 px PBR albedo, normal, and roughness maps at close range and oblique angles.
- [ ] Check material tiling seams on long floor and wall surfaces.
- [ ] Inspect machine service bay, service tanks, fasteners, gauges, valve wheels, labels, and floor access plates.
- [ ] Check moving rigid-body props do not intersect decorative render-only meshes at spawn.
- [ ] Re-run Low/Medium/High/Ultra benchmarks after the increased texture resolution and detail pass.


## Deep movement upgrade checks

- [ ] Traverse the step flight at walking and sprint pace; verify that step assistance does not produce a double horizontal jump.
- [ ] Walk up/down the ramp and across the moving platform; confirm floor contact and camera stability.
- [ ] Compare all four surface-response panels; verify their movement profile and footstep timbre change.
- [ ] Hold sprint until stamina is exhausted, release sprint, and verify delayed recovery and re-arming.
- [ ] Compare camera bob, viewmodel sway, and footstep cadence at 30/60/90 FPS; cadence should follow distance rather than rendered frame count.
- [ ] Try to stand under the low beam while crouched; confirm standing is blocked until the capsule has clearance.
- [ ] Push the crate and canister from different directions; confirm response follows body mass/damping and no repeated multi-contact impulse spikes.
- [ ] Test on a real Android device for touch + look + sprint + jump simultaneously.


## Surface response and collision-query regression

- [ ] Walk across each material seam in both longitudinal and lateral directions; surface selection should not flicker.
- [ ] Confirm the five ground probes cover center, left, right, front, and rear foot-contact zones.
- [ ] Confirm speed, traction, jump, and stride values blend smoothly across material changes.
- [ ] Crouch on open floor and verify the standing-clearance query does not mistake floor contact for a ceiling obstruction.
- [ ] Place a low beam over the crouched player; standing must remain blocked until the beam is removed.
- [ ] Push a test rigid body while moving into it, then move away/sideways; native CharacterBody3D-to-RigidBody3D contact response should remain stable without a second manual impulse.
- [ ] Compare left/right alternating footstep source positions with 3D audio enabled.
- [ ] Pause/resume during a scanner animation; impact spring and rotor must not snap or accumulate unbounded angle.


## Spawn validation

- [ ] Block an authored spawn point with a static prop; spawning should choose a nearby clear offset or another authored point.
- [ ] Block every candidate around all spawn markers; a warning must be emitted and the documented fallback used.
- [ ] Verify the query uses the same radius/height as the player capsule and does not classify a player resting just above the floor as obstructed.
