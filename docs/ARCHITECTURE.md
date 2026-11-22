# Iron Yard — Architecture (Phase 2)

## Design goals

- Mobile-first 3D gameplay with the same simulation quality at every graphics preset.
- Modular player, world, match, interaction, input, network, and presentation systems.
- Offline-capable local networking is a future target; ENet transport wrapper is now present.
- Zombie mode remains an independent future module. Its narrative and detailed mechanics are deliberately unspecified until the designer supplies them.

## Runtime layers

- **Application:** AppState, SettingsManager, SaveManager, EventBus, scene lifecycle.
- **Gameplay:** PlayerController, HealthComponent, PlayerRuntimeState, MatchController, InteractableBase.
- **Input:** InputMap actions with platform adapters for mouse/keyboard, touch, and later gamepad.
- **World:** arena/map geometry, collision proxies, spawn locations, interactable objects.
- **Networking:** LocalNetworkSession transport wrapper. Gameplay authority and replication are not implemented yet.
- **Presentation:** camera, HUD, touch overlay, environment, and audio (audio content is later work).
- **Diagnostics:** PerformanceManager reports frame-time and memory metrics and applies visual quality settings.

## Dependency direction

- PlayerController reads InputMap and SettingsManager, publishes signals, and uses its child HealthComponent.
- TouchHUD only translates gestures into InputMap actions and camera-look deltas; it does not own player simulation.
- World scenes create player and interactables; they do not implement movement rules.
- MatchController owns match lifecycle, not global application state.
- Network code does not mutate player state directly; future replication must go through explicit state/command contracts.
- EventBus is a signal channel, never an object database.

## Physics conventions

- Player root: CharacterBody3D with a capsule collision proxy.
- Static map geometry: StaticBody3D and simple collision shapes.
- Visual meshes are separate children, so visual detail can change without changing collision.
- Player world up is +Y; forward is -Z.
- Use physics layers deliberately: world geometry = layer 1; interactables = layer 2. The player body collides with world layer 1; its interaction ray queries layer 2.
- Movement is processed in `_physics_process`. Camera input is applied from unhandled input/touch deltas.

## Networking target

The intended complete local match is host-authoritative with one host plus up to three remote peers. The current adapter only creates ENet server/client peers and emits connection events. Discovery, room metadata, authentication, authoritative gameplay replication, interpolation, prediction, disconnect policy, reconnect, and Android device validation remain future work.

## Rendering profiles

Low/Medium/High/Ultra adjust viewport 3D render scale and light shadow enablement. Dynamic quality is opt-in and uses a rolling frame-time p95 with cooldowns. This is a first game-level quality layer, not a complete material/texture/effect pipeline; later graphics work must add measured LOD, visibility, texture compression, instancing, and content budgets.

## Persistence

SaveManager persists only long-lived data using a schema version. Never store credentials, signing keys, or temporary match state in the save file or repository. Schema changes require explicit migration tests.
