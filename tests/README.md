# Tests and validation

## Headless smoke test

From the project root with Godot 4.4+ installed:

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/smoke_test.gd
```

The first command imports/parses project resources. The second checks that the player scene, capsule collision, camera, health component, arena scene, and settings script can be loaded. It is a resource smoke test, not a substitute for physics playtesting.

## Manual physics QA

Run the project normally and follow `docs/QA_CHECKLIST.md`. Test the same sequence at each quality preset and record device/GPU/renderer, average FPS, p95 frame time, memory, and thermal behavior. Do not infer Android performance from desktop results.


## Runtime integration test

```bash
godot --headless --path . --script res://tests/runtime_integration_test.gd
```

This instantiates the test arena, checks the expected core scene nodes and surface panels, verifies independent player capsule resources, and exercises the reusable standing-clearance query against a temporary low overhead beam. The test does not substitute for a full manual movement session or Android device profiling.
