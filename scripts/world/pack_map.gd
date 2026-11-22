extends Node3D
class_name PackMap

## Generic runner for a map that was downloaded as a content pack. It instantiates the pack's
## entry scene (data only) and adds everything the pack must not carry: environment fallback,
## spawn points (from nodes in group "pack_spawn"), the player, HUD layers and session glue.
## Set PackMap.pending_pack_id, then change to res://scenes/world/pack_map.tscn.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/core_hud.gd")
const TOUCH_HUD_SCRIPT := preload("res://scripts/input/touch_hud.gd")
const PAUSE_MENU_SCRIPT := preload("res://scripts/ui/pause_menu.gd")
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const SCENE_PATH := "res://scenes/world/pack_map.tscn"

static var pending_pack_id: String = ""

var _player: CharacterBody3D
var _spawn_manager: SpawnManager
var _session: SessionHelper

static func open(pack_id: String, tree: SceneTree) -> bool:
    ## Returns false (and changes nothing) when the pack is not installed or has no scene.
    if not ContentManager.is_installed(pack_id) or ContentManager.load_pack_scene(pack_id) == null:
        return false
    pending_pack_id = pack_id
    tree.change_scene_to_file(SCENE_PATH)
    return true

func _ready() -> void:
    var pack_scene := ContentManager.load_pack_scene(pending_pack_id)
    if pack_scene == null:
        push_warning("PackMap: pack '%s' has no loadable scene; returning to menu." % pending_pack_id)
        get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
        return
    var content := pack_scene.instantiate()
    content.name = "PackContent"
    add_child(content)
    if content.find_children("*", "WorldEnvironment", true, false).is_empty():
        _build_default_environment()
    if content.find_children("*", "DirectionalLight3D", true, false).is_empty():
        _build_default_sun()
    _build_spawn_points()
    _spawn_manager = SpawnManager.new()
    _spawn_manager.name = "SpawnManager"
    add_child(_spawn_manager)
    _player = PLAYER_SCENE.instantiate() as CharacterBody3D
    _player.name = "Player"
    add_child(_player)
    _player.global_transform = _spawn_manager.get_next_spawn_transform("")
    _session = SessionHelper.new()
    _session.name = "SessionHelper"
    add_child(_session)
    _session.setup(_player, _spawn_manager, "pack_map")
    _spawn_huds()
    PerformanceManager.apply_quality_preset(SettingsManager.get_quality_preset())
    AppState.set_active_screen("pack_map")

func _build_spawn_points() -> void:
    var holder := Node3D.new()
    holder.name = "SpawnPoints"
    add_child(holder)
    var index: int = 0
    for node in get_tree().get_nodes_in_group("pack_spawn"):
        if not (node is Node3D) or not is_ancestor_of(node):
            continue
        var marker := node as Node3D
        var point := SpawnPoint.new()
        point.name = "Spawn_%02d" % index
        point.spawn_id = "spawn_%02d" % index
        point.team_id = str(marker.get_meta("team", ""))
        holder.add_child(point)
        point.global_transform = marker.global_transform
        index += 1

func _build_default_environment() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("#3f7fc4")
    sky_material.sky_horizon_color = Color("#bcd6e8")
    sky_material.ground_horizon_color = Color("#bcd6e8")
    sky_material.ground_bottom_color = Color("#6b6a62")
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.95
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var world_environment := WorldEnvironment.new()
    world_environment.name = "WorldEnvironment"
    world_environment.environment = environment
    add_child(world_environment)

func _build_default_sun() -> void:
    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 75.0
    add_child(sun)

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
