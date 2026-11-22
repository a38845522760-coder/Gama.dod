extends Node3D

## Zombie map "Dead City": a very large (400 x 400 m), dark, ruined city at night. Builds the
## gloomy environment, the district layout, weapon shops (Tesla lab, armory, foundry depot),
## supply stations, spawn points, player, HUD layers and the zombie ModeManager at runtime.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/core_hud.gd")
const TOUCH_HUD_SCRIPT := preload("res://scripts/input/touch_hud.gd")
const PAUSE_MENU_SCRIPT := preload("res://scripts/ui/pause_menu.gd")
const REGION_SIZE: float = 100.0
const MAP_HALF: float = 200.0
const NAV_CELL_SIZE: float = 0.75

var _regions: Dictionary = {}
var _region_root: Node3D
var _core: Node3D
var _world_environment: WorldEnvironment
var _moon: DirectionalLight3D
var _lamps: Array[OmniLight3D] = []
var _layout: ZombieLayout
var _kit: MapKit
var _spawn_manager: SpawnManager
var _player: CharacterBody3D
var _region_manager: RegionManager
var _mode_manager: ModeManager
var _mode_id: String = "zombie"

func _ready() -> void:
    _mode_id = "zombie"
    _build_environment()
    _region_root = Node3D.new()
    _region_root.name = "Regions"
    add_child(_region_root)
    _core = Node3D.new()
    _core.name = "Core"
    _region_root.add_child(_core)
    _kit = MapKit.new(Callable(self, "_region_for"))
    _kit.core_node = _core
    _layout = ZombieLayout.new()
    _layout.build(self, _kit)
    _build_lights()
    _build_spawn_points()
    _spawn_manager = SpawnManager.new()
    _spawn_manager.name = "SpawnManager"
    add_child(_spawn_manager)
    _spawn_player()
    _build_shops_and_supplies()
    _spawn_huds()
    _build_systems()
    PerformanceManager.apply_quality_preset(SettingsManager.get_quality_preset())
    AppState.set_active_screen("zombie_map")

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
    sky_material.sky_top_color = Color("#04060c")
    sky_material.sky_horizon_color = Color("#16201c")
    sky_material.ground_horizon_color = Color("#101612")
    sky_material.ground_bottom_color = Color("#050706")
    sky_material.sun_angle_max = 8.0
    sky_material.sky_energy_multiplier = 0.6
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#46586a")
    environment.ambient_light_energy = 0.55
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.tonemap_exposure = 1.15
    environment.tonemap_white = 6.0
    environment.glow_enabled = true
    environment.glow_intensity = 0.8
    environment.glow_bloom = 0.1
    environment.glow_hdr_threshold = 0.9
    environment.adjustment_enabled = true
    environment.adjustment_contrast = 1.15
    environment.adjustment_saturation = 0.8
    environment.fog_enabled = true
    environment.fog_density = 0.011
    environment.fog_light_color = Color("#0d1511")
    environment.fog_sky_affect = 0.2
    _world_environment = WorldEnvironment.new()
    _world_environment.name = "WorldEnvironment"
    _world_environment.environment = environment
    add_child(_world_environment)
    _moon = DirectionalLight3D.new()
    _moon.name = "Moon"
    _moon.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
    _moon.light_energy = 0.5
    _moon.light_color = Color("#7f9bd8")
    _moon.shadow_enabled = true
    _moon.shadow_blur = 1.6
    _moon.directional_shadow_max_distance = 70.0
    add_child(_moon)

func _build_lights() -> void:
    var index: int = 0
    for site in _layout.light_sites:
        var lamp := OmniLight3D.new()
        lamp.name = "DeadLight_%d" % index
        lamp.position = site["pos"]
        lamp.light_color = site["color"]
        lamp.light_energy = float(site["energy"])
        lamp.omni_range = 12.0
        lamp.shadow_enabled = false
        lamp.add_to_group("no_shadow")
        _region_for(lamp.position).add_child(lamp)
        _lamps.append(lamp)
        if bool(site["flicker"]):
            _start_flicker(lamp, float(site["energy"]))
        index += 1

func _start_flicker(lamp: OmniLight3D, base_energy: float) -> void:
    var tween := lamp.create_tween().set_loops()
    tween.tween_interval(randf_range(0.4, 2.8))
    tween.tween_property(lamp, "light_energy", base_energy * 0.15, 0.06)
    tween.tween_property(lamp, "light_energy", base_energy, 0.08)
    tween.tween_property(lamp, "light_energy", base_energy * 0.4, 0.05)
    tween.tween_property(lamp, "light_energy", base_energy, 0.12)

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
    _player.global_transform = _spawn_manager.get_next_spawn_transform("survivor")

func _build_shops_and_supplies() -> void:
    for site in _layout.shop_sites:
        var shop := WeaponShop.new()
        shop.name = "WeaponShop_%s" % str(site["title"]).replace(" ", "")
        var stock: Array[String] = []
        for weapon_id in site["stock"]:
            stock.append(str(weapon_id))
        shop.stock = stock
        shop.title = str(site["title"])
        shop.accent = site["color"]
        var world_position: Vector3 = site["pos"]
        shop.position = world_position
        shop.rotation.y = float(site["yaw"])
        _region_for(world_position).add_child(shop)
    for supply_position in _layout.supply_sites:
        _add_supply_station(supply_position)

func _add_supply_station(world_position: Vector3) -> void:
    var station := SupplyStation.new()
    station.name = "SupplyStation_%d_%d" % [int(world_position.x), int(world_position.z)]
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
    _region_manager = RegionManager.new()
    _region_manager.name = "RegionManager"
    _region_manager.region_half_diagonal = REGION_SIZE * 0.72
    add_child(_region_manager)
    var region_list: Array[Node3D] = []
    for region in _regions.values():
        region_list.append(region)
    _region_manager.setup(region_list, _player)
    var session := SessionHelper.new()
    session.name = "SessionHelper"
    add_child(session)
    session.setup(_player, _spawn_manager, _mode_id)
    BotNav.cell_size = NAV_CELL_SIZE
    if NetGame.is_guest():
        NetGame.attach_guest(self, _player, _spawn_manager, _mode_id)
        return
    _mode_manager = ModeManager.new()
    _mode_manager.name = "ModeManager"
    add_child(_mode_manager)
    _mode_manager.setup(self, _player, _spawn_manager, _mode_id, AppState.pending_difficulty)
    if NetGame.is_host():
        NetGame.attach_host(self, _player, _mode_manager, _mode_id)
