# Development Setup

## Required tools

- Godot Engine 4.4 or newer (standard editor build).
- Git for version control.
- Android SDK/JDK and matching Godot export templates for Android export.

Never commit local SDK paths, keystores, passwords, signing files, or private export configuration.

## First launch

1. Extract the project folder.
2. Import `project.godot` in Godot Project Manager.
3. Allow the initial resource scan to finish.
4. Run the project; the Core Test Arena should open directly.
5. Confirm that the player spawns above the arena floor and the HUD displays FPS and p95 frame time.

## Coding conventions

- Prefer typed GDScript for public APIs.
- Use `snake_case` for files/functions/variables and `PascalCase` for classes.
- Keep Autoloads limited to cross-scene application services.
- Keep gameplay logic out of map props and HUD scripts.
- Keep render meshes separate from collision proxies.
- Add a test note for each behavior change.

## Android compatibility

Do not assume the Android OS floor from the original project notes is supported by every Godot 4.4+ export/runtime combination. Select the engine version and renderer based on device tests, and verify the actual export template and minimum API. No Android 8.1 compatibility guarantee is made by this package.
