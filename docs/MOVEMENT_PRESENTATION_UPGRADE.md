# Iron Yard — Movement & First-Person Presentation Upgrade

## Scope

This upgrade improves the feel and readability of the Phase 2 core without turning the placeholder arena into a final content map. It keeps collision simulation independent from camera/viewmodel animation.

## Movement changes

- Separate ground acceleration, ground deceleration, air acceleration, and air drag.
- Smooth sprint blend so speed changes are ramped instead of instantaneous. Sprint is currently intended for forward movement.
- Preserve jump buffering and coyote time. Add variable-height jumping, stronger gravity while falling, jump-release height control, and a terminal fall-speed cap.
- Retain a conservative step-up helper with raised-path and walkable-landing checks.
- Use a stable grounded character configuration with a controlled floor angle and snap distance.
- Expose a movement snapshot for HUD telemetry and automated smoke checks.

## Camera response

- Low-amplitude walk/run bob scaled by actual horizontal velocity.
- Sprint-specific bob, slight camera lowering, and a small FOV increase.
- Restrained lateral camera lean from local horizontal velocity.
- Short landing compression based on pre-landing vertical speed, combined with a damped camera spring so the view settles instead of linearly snapping back.
- A small jump tuck and impact response are sent to the first-person presentation rig; these are cosmetic and do not change the authoritative player collision or physics.
- Look input produces a small decaying viewmodel sway impulse.

These effects are visual only. They never modify collision shape, velocity, or the character's authoritative transform.

## First-person equipment presentation

The viewmodel is a stylized, fictional utility scanner built procedurally from simple meshes. It includes layered casing, cooling fins, small status elements, an emissive sensor window, a scan-light lens, and abstract forearm guards. Idle, run, sprint, look, and scan states animate the presentation. The scan is a glow and short visual feedback only; realistic weapon handling or combat operation is intentionally outside this design.

## Environment detail pass

The test arena now includes tileable PBR concrete/painted-steel/rubber albedo, normal, and roughness maps; batched floor lines; support ribs; base plates; vents; service pipes and clamps; overhead beams and cable trays; cable bundles; floor drain channels and grate bars; wall-mounted service panels and fasteners; safety stripe groups; step-edge markings; console face details; reinforced crate trim; animated rotating fans; a pulsing warning beacon; a moving physics platform; modest work lights; and one dynamic rigid-body crate. Most detail geometry is render-only; collision remains deliberately simple and separate.

## Performance intent

- Use MultiMesh for repeated grid, structural, vent, and stripe geometry where possible.
- Keep the viewmodel primitive-based and asset-free.
- Use a small CPU particle burst for landing dust.
- Synthesize short one-shot footstep profiles for concrete, metal, rubber, and crate surfaces once during player initialization; reuse a small pooled 3D audio-player set.
- Keep physics quality identical across graphics presets.

## Validation still required

Run `tests/smoke_test.gd` with the Godot 4.4+ editor/headless executable, open `scenes/world/core_test_arena.tscn`, inspect the remote scene tree, test the movement QA list, and profile Low/Medium/High/Ultra on target Android hardware. This authoring environment did not have a Godot executable, so no engine parse, runtime, APK, or device pass is claimed.
