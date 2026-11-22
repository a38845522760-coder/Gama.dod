# Phase 2 — Playable Core Implementation

## Delivered modules

1. **Player controller:** CharacterBody3D, capsule, mouse/touch look, speed-ramped sprinting, vector-based acceleration/deceleration, ground/air control, jump buffer, coyote time, floor snap, slope limit, conservative step-up probes, movement state reporting, camera bob/lean/FOV response, damped landing spring and jump/landing presentation events, variable jump height, fall gravity shaping, and terminal fall-speed control.
2. **Input:** named InputMap actions, virtual touch joystick, right-side touch-look capture, and action buttons. Touch UI is created only on Android/iOS unless debug visibility is enabled.
3. **World/physics lab:** procedural arena generated from StaticBody3D + BoxShape3D with visually separate MeshInstance3D nodes. Includes boundaries, steps, ramp, low platform, narrow passage, beams, blocks, console, instanced floor grid, PBR concrete/steel/rubber texture sets, service pipes, structural ribs, vents, rotating fans, a pulsing warning beacon, safety markings, work lights, a moving AnimatableBody3D platform, and a dynamic RigidBody3D crate for momentum/friction/collision checks.
4. **Interaction and feedback:** InteractableBase contract and a detailed test console reached by the player's interaction ray; surface-aware distance-based footsteps with distinct procedural concrete/metal/rubber/crate profiles, pooled 3D audio, landing dust, and movement telemetry.
5. **Player data:** HealthComponent and PlayerRuntimeState as runtime-only state structures. SpawnManager now checks a reusable player-sized capsule against world collisions and tries nearby offsets before using a warned fallback.
6. **Match lifecycle:** small mode-independent MatchController with lobby/active/results lifecycle and optional duration.
7. **Networking foundation:** LocalNetworkSession wraps ENet host/client transport and peer events. Host allows at most three remote peers (four devices total including host); no discovery, lobby UI, authoritative state replication, prediction, or reconnect strategy is claimed.
8. **Performance:** render scaling and shadow tiers map the four presets to runtime switches. Frame time p95, FPS, static memory, and object count are exposed. Dynamic quality is opt-in.
9. **Persistence:** Phase 1 settings and versioned save service retained; temporary match data remains outside persistent save.
10. **First-person presentation:** Procedural stylized utility-scanner viewmodel with idle/run sway, sprint lowering, look response, emissive energy core, small armor/casing details, and a non-realistic scanner light-sweep effect. No real-world weapon operation is modeled.

## Movement and presentation upgrade

- Sprint speed blends over time instead of switching immediately; acceleration and deceleration use separate configurable rates.
- Camera response is presentation-only: it does not feed back into physics. It includes a restrained walk/run bob, lateral lean, sprint FOV shift, and landing compression.
- Step traversal uses a three-part probe: clear vertical lift, clear forward path, and a walkable downward landing check. The helper remains conservative, caches collision result objects, and commits only the vertical lift before the single normal `move_and_slide()` call.
- Ground-material sampling uses five probes (center, left, right, front, rear), a weighted center vote, two-sample hysteresis, and eased material response for speed, traction, jump, stride and step volume.
- Footstep cadence is distance-based, not frame-count-based. The short procedural WAV is generated once when the player spawns; it is not regenerated on every step. The source position alternates left/right and the active surface profile affects its tonal balance and volume.
- Dynamic props rely on Godot's native `CharacterBody3D.move_and_slide()` interaction with `RigidBody3D`, with mass, damping, and physics materials tuned on the props themselves. A second hand-authored impulse layer was removed to avoid double-applying contact forces.
- Landing dust uses a small one-shot CPU particle burst to avoid requiring a GPU-particle feature on low-end devices.
- The viewmodel is built from simple primitives at runtime, keeping the ZIP self-contained and avoiding external model dependencies.
- Repeated arena grid lines, columns, vents, and warning marks use MultiMesh batches where practical to limit draw calls.

## Technical notes

- Physics/gameplay is independent of graphics preset. Quality changes do not change collision layers, movement speed, jump, or simulation.
- The step helper uses `test_move` probes and commits only if the raised horizontal path is clear and a walkable landing surface is detected. It is intentionally conservative; tune on the target capsule and final collision geometry after in-engine testing. `CharacterBody3D` is the intended script-driven character type, and `test_move` checks a candidate path without moving the body; see the [Godot 4.4 CharacterBody3D API](https://docs.godotengine.org/en/4.4/classes/class_characterbody3d.html) and [PhysicsBody3D API](https://docs.godotengine.org/en/4.4/classes/class_physicsbody3d.html).
- Standing clearance reuses a `PhysicsShapeQueryParameters3D` instance. Its almost-zero margin is deliberate to avoid interpreting resting floor contact as a headroom obstruction; see [Godot 4.4 PhysicsShapeQueryParameters3D](https://docs.godotengine.org/en/4.4/classes/class_physicsshapequeryparameters3d.html).
- Environment collision uses primitive boxes in this test arena. Final production maps should use carefully authored collision proxies rather than high-detail render meshes as physics geometry.
- Mobile UI uses relative touch input and does not capture mouse. Desktop uses captured mouse and keyboard.
- ENet can transport local peer traffic, but Android hotspot discovery and firewall/permission behavior vary by device and OS. Validate on actual target phones.

## Not included in Phase 2

Final industrial map art, AI, later game-mode and equipment content, shop/economy, full game modes, full multiplayer lobby and replication, server authority validation, reconnect, zombie mode content, final audio, and production Android signing/export. Those require later phases and user-provided Zombie Mode specifications.

## Validation status

This package was assembled from the audited Phase 1 repository tree. A Godot executable was not available in the authoring environment, so no local Godot parser run or Android device test is claimed. The enhanced movement, procedural audio, particles, viewmodel, and instanced arena details therefore still require validation in Godot 4.4+ and on target hardware. Run the smoke test and manual QA procedure before release.
