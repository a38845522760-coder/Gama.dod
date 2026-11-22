extends Node3D

## Main playable map "Iron Yard" (Phase 3). Builds the environment, the industrial layout,
## regional visibility, weather, spawn points, the player and all HUD layers at runtime.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/core_hud.gd")
const TOUCH_HUD_SCRIPT := preload("res://scripts/input/touch_hud.gd")
const PAUSE_MENU_SCRIPT := preload("res://scripts/ui/pause_menu.gd")
const TARGET_SCRIPT := preload("res://scripts/world/training_target.gd")
const REGION_SIZE: float = 40.0
const MAP_HALF: float = 80.0

var _regions: Dictionary = {}
var _region_root: Node3D
var _core: Node3D
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _lamps: Array[OmniLight3D] = []
var _layout: IndustrialMap
var _kit: MapKit
var _spawn_manager: SpawnManager
var _player: CharacterBody3D
var _weather: WeatherSystem
var _region_manager: RegionManager
var _mode_id: String = "ffa"
var _mode_manager: ModeManager

func _ready() -> void:
    _mode_id = AppState.pending_mode
    _build_environment()
    _region_root = Node3D.new()
    _region_root.name = "Regions"
    add_child(_region_root)
    _core = Node3D.new()
    _core.name = "Core"
    _region_root.add_child(_core)
    _kit = MapKit.new(Callable(self, "_region_for"))
    _kit.core_node = _core
    _layout = IndustrialMap.new()
    _layout.build(self, _kit)
    _build_lamps()
    _build_spawn_points()
    _spawn_manager = SpawnManager.new()
    _spawn_manager.name = "SpawnManager"
    add_child(_spawn_manager)
    _spawn_player()
    _build_gameplay_props()
    _spawn_huds()
    _build_systems()
    PerformanceManager.apply_quality_preset(SettingsManager.get_quality_preset())
    AppState.set_active_screen("iron_yard")

func get_layout_stats() -> Dictionary:
    return _layout.stats.duplicate(true)

func _region_for(world_position: Vector3) -> Node3D:
    var ix: int = clampi(int(floor((world_position.x + MAP_HALF) / REGION_SIZE)), 0, 3)
    var iz: int = clampi(int(floor((world_position.z + MAP_HALF) / REGION_SIZE)), 0, 3)
    var key := Vector2i(ix, iz)
    if not _regions.has(key):
        var region := Node3D.new()
        region.name = "Region_%d_%d" % [ix, iz]
        region.set_meta("center", Vector3(-MAP_HALF + REGION_SIZE * (float(ix) + 0.5), 0.0, -MAP_HALF + REGION_SIZE * (float(iz) + 0.5)))
        _region_root.add_child(region)
        _regions[key] = region
    return _regions[key]

func _build_environment() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("#3f7fc4")
    sky_material.sky_horizon_color = Color("#bcd6e8")
    sky_material.ground_horizon_color = Color("#bcd6e8")
    sky_material.ground_bottom_color = Color("#6b6a62")
    sky_material.sun_angle_max = 30.0
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.95
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.tonemap_exposure = 1.05
    environment.tonemap_white = 6.0
    environment.glow_enabled = true
    environment.glow_intensity = 0.55
    environment.glow_bloom = 0.06
    environment.glow_hdr_threshold = 1.1
    environment.adjustment_enabled = true
    environment.adjustment_contrast = 1.08
    environment.adjustment_saturation = 1.12
    environment.fog_enabled = true
    environment.fog_density = 0.0007
    environment.fog_light_color = Color("#b9cde0")
    environment.fog_sky_affect = 0.35
    _world_environment = WorldEnvironment.new()
    _world_environment.name = "WorldEnvironment"
    _world_environment.environment = environment
    add_child(_world_environment)
    _sun = DirectionalLight3D.new()
    _sun.name = "Sun"
    _sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
    _sun.light_energy = 1.25
    _sun.shadow_enabled = true
    _sun.shadow_blur = 1.2
    _sun.light_color = Color("#fff1dc")
    _sun.directional_shadow_max_distance = 75.0
    add_child(_sun)

func _build_lamps() -> void:
    var count: int = mini(_layout.light_poles.size(), 8)
    for index in range(count):
        var lamp := OmniLight3D.new()
        lamp.name = "LampLight_%d" % index
        lamp.position = _layout.light_poles[index]
        lamp.omni_range = 16.0
        lamp.light_color = Color("#ffd9a0")
        lamp.light_energy = 0.0
        lamp.shadow_enabled = false
        lamp.visible = false
        lamp.add_to_group("no_shadow")
        add_child(lamp)
        _lamps.append(lamp)

func _build_spawn_points() -> void:
    var holder := Node3D.new()
    holder.name = "SpawnPoints"
    add_child(holder)
    var index: int = 0
    for spec in _layout.spawn_positions:
        var point := SpawnPoint.new()
        point.name = "Spawn_%02d" % index
        point.spawn_id = "spawn_%02d" % index
        point.team_id = str(spec["team"])
        var world_position: Vector3 = spec["pos"]
        point.position = world_position
        var toward_center := Vector2(-world_position.x, -world_position.z).normalized()
        point.rotation.y = atan2(-toward_center.x, -toward_center.y)
        holder.add_child(point)
        index += 1

func _spawn_player() -> void:
    _player = PLAYER_SCENE.instantiate() as CharacterBody3D
    _player.name = "Player"
    add_child(_player)
    _player.global_transform = _spawn_manager.get_next_spawn_transform("")

func _build_gameplay_props() -> void:
    if _mode_id != "practice":
        for station_position in [Vector3(6.0, 0.0, 60.0), Vector3(6.0, 0.0, -62.0), Vector3(-9.0, 0.0, -14.0)]:
            _add_supply_station(station_position)
        return
    var target_positions: Array[Vector3] = [
        Vector3(-14.0, 0.0, 44.0), Vector3(14.0, 0.0, 42.0), Vector3(22.0, 0.0, -20.0),
        Vector3(-26.0, 0.0, -6.0), Vector3(40.0, 0.0, 12.0), Vector3(-50.0, 0.0, -2.0),
    ]
    var index: int = 0
    for target_position in target_positions:
        var target := StaticBody3D.new()
        target.set_script(TARGET_SCRIPT)
        target.name = "TrainingTarget_%d" % index
        target.position = target_position
        target.rotation.y = atan2(target_position.x, target_position.z) + PI
        _region_for(target_position).add_child(target)
        index += 1
    for station_position in [Vector3(6.0, 0.0, 60.0), Vector3(6.0, 0.0, -62.0), Vector3(-9.0, 0.0, -14.0)]:
        _add_supply_station(station_position)

func _add_supply_station(world_position: Vector3) -> void:
    var station := SupplyStation.new()
    station.name = "SupplyStation_%d" % int(world_position.z)
    station.position = world_position + Vector3(0.0, 0.6, 0.0)
    station.collision_layer = 3
    station.collision_mask = 0
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.0, 1.2, 0.6)
    shape_node.shape = shape
    station.add_child(shape_node)
    var body_mesh := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = shape.size
    body_mesh.mesh = mesh
    body_mesh.material_override = _kit.mat("steel")
    station.add_child(body_mesh)
    var cross_material := StandardMaterial3D.new()
    cross_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cross_material.albedo_color = Color("#3ddc84")
    for size in [Vector3(0.46, 0.14, 0.02), Vector3(0.14, 0.46, 0.02)]:
        var bar := MeshInstance3D.new()
        var bar_mesh := BoxMesh.new()
        bar_mesh.size = size
        bar.mesh = bar_mesh
        bar.material_override = cross_material
        bar.position = Vector3(0.0, 0.15, 0.31)
        station.add_child(bar)
    _region_for(world_position).add_child(station)

func _spawn_huds() -> void:
    var hud := CanvasLayer.new()
    hud.name = "CoreHUD"
    hud.set_script(HUD_SCRIPT)
    add_child(hud)
    var touch_hud := CanvasLayer.new()
    touch_hud.name = "TouchHUD"
    touch_hud.set_script(TOUCH_HUD_SCRIPT)
    add_child(touch_hud)
    var pause_menu := CanvasLayer.new()
    pause_menu.name = "PauseMenu"
    pause_menu.set_script(PAUSE_MENU_SCRIPT)
    add_child(pause_menu)
    ArsenalHUD.attach(self)

func _build_systems() -> void:
    _weather = WeatherSystem.new()
    _weather.name = "WeatherSystem"
    _weather.add_to_group("weather_system")
    add_child(_weather)
    _weather.setup(_world_environment, _sun, _player, _lamps)
    _region_manager = RegionManager.new()
    _region_manager.name = "RegionManager"
    add_child(_region_manager)
    var region_list: Array[Node3D] = []
    for region in _regions.values():
        region_list.append(region)
    _region_manager.setup(region_list, _player)
    var session := SessionHelper.new()
    session.name = "SessionHelper"
    add_child(session)
    session.setup(_player, _spawn_manager, _mode_id)
    if NetGame.is_guest():
        NetGame.attach_guest(self, _player, _spawn_manager, _mode_id)
        return
    if _mode_id != "practice":
        _mode_manager = ModeManager.new()
        _mode_manager.name = "ModeManager"
        add_child(_mode_manager)
        _mode_manager.setup(self, _player, _spawn_manager, _mode_id, AppState.pending_difficulty)
    if NetGame.is_host():
        NetGame.attach_host(self, _player, _mode_manager, _mode_id)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("cycle_weather") and _weather != null:
        _weather.cycle_next()
