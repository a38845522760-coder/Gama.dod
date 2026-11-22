extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/core_hud.gd")
const TOUCH_HUD_SCRIPT := preload("res://scripts/input/touch_hud.gd")
const INTERACTABLE_SCRIPT := preload("res://scripts/player/interactable_base.gd")
const SPAWN_POINT_SCRIPT := preload("res://scripts/world/spawn_point.gd")
const SPAWN_MANAGER_SCRIPT := preload("res://scripts/world/spawn_manager.gd")
const PLAYER_REGISTRY_SCRIPT := preload("res://scripts/player/player_registry.gd")
const MATCH_CONTROLLER_SCRIPT := preload("res://scripts/gameplay/match_controller.gd")
const NETWORK_SESSION_SCRIPT := preload("res://scripts/network/local_network_session.gd")
const ROTATING_FAN_SCRIPT := preload("res://scripts/world/rotating_industrial_fan.gd")
const WARNING_BEACON_SCRIPT := preload("res://scripts/world/animated_warning_beacon.gd")
const MOVING_PLATFORM_SCRIPT := preload("res://scripts/world/moving_test_platform.gd")
const TARGET_SCRIPT := preload("res://scripts/world/training_target.gd")
const HAZARD_SCRIPT := preload("res://scripts/world/hazard_zone.gd")
const PAUSE_MENU_SCRIPT := preload("res://scripts/ui/pause_menu.gd")

var _materials: Dictionary = {}
var _spawn_manager: Node
var _player_registry: Node
var _player: CharacterBody3D
var _session_score: int = 0

func _ready() -> void:
    _create_materials()
    _build_arena()
    _create_runtime_services()
    _spawn_player()
    _build_training_range()
    _spawn_huds()
    EventBus.target_destroyed.connect(_on_target_destroyed)
    AppState.begin_session("training")
    PerformanceManager.apply_quality_preset(SettingsManager.get_quality_preset())
    AppState.set_active_screen("core_test_arena")

func _create_materials() -> void:
    var concrete := _make_material(Color("#343f45"), 0.88, 0.08)
    _apply_pbr_textures(concrete, "concrete", 0.22)
    var painted_steel := _make_material(Color("#59666c"), 0.68, 0.42)
    _apply_pbr_textures(painted_steel, "painted_steel", 0.28)
    var rubber := _make_material(Color("#20282c"), 0.94, 0.02)
    _apply_pbr_textures(rubber, "rubber", 0.12)
    _materials["floor"] = concrete
    _materials["wall"] = painted_steel
    _materials["step"] = painted_steel
    _materials["accent"] = _make_material(Color("#d58a3a"), 0.55, 0.28)
    _apply_pbr_textures(_materials["accent"], "painted_steel", 0.20)
    _materials["blue"] = _make_material(Color("#367f94"), 0.48, 0.32)
    _apply_pbr_textures(_materials["blue"], "painted_steel", 0.24)
    _materials["dark"] = _make_material(Color("#1a252b"), 0.78, 0.08)
    _apply_pbr_textures(_materials["dark"], "rubber", 0.12)
    _materials["trim"] = _make_material(Color("#8b9a9e"), 0.52, 0.72)
    _apply_pbr_textures(_materials["trim"], "painted_steel", 0.18)
    _materials["rubber"] = rubber
    _materials["grid"] = _make_material(Color("#59666a"), 0.96, 0.02)
    _materials["warning"] = _make_material(Color("#e0a33e"), 0.68, 0.12)
    _materials["warning_dark"] = _make_material(Color("#151b1e"), 0.84, 0.04)
    _materials["glow"] = _make_emissive_material(Color("#53cfe3"), 1.8)
    _materials["signal"] = _make_emissive_material(Color("#e3a34a"), 1.2)

func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material


func _apply_pbr_textures(material: StandardMaterial3D, texture_prefix: String, normal_strength: float) -> void:
    var profile := SettingsManager.get_quality_profile()
    var texture_tier := int(profile.get("texture_tier", 1))
    if texture_tier <= 0:
        return
    var root_path := "res://assets/textures/%s" % texture_prefix
    var albedo_texture := load(root_path + "_albedo.png") as Texture2D
    var normal_texture := load(root_path + "_normal.png") as Texture2D
    var roughness_texture := load(root_path + "_roughness.png") as Texture2D
    if albedo_texture != null:
        material.albedo_texture = albedo_texture
    if roughness_texture != null:
        material.roughness_texture = roughness_texture
    if normal_texture != null and texture_tier >= 1:
        material.normal_enabled = true
        material.normal_texture = normal_texture
        material.normal_scale = normal_strength * (0.68 if texture_tier == 1 else 1.0)
    var advanced_projection := texture_tier >= 2
    material.uv1_triplanar = advanced_projection
    material.uv1_world_triplanar = advanced_projection
    material.uv1_scale = Vector3(0.62, 0.62, 0.62) if advanced_projection else Vector3.ONE

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color.darkened(0.22)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    material.roughness = 0.36
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return material

func _build_arena_details() -> void:
    _add_floor_grid()
    _add_wall_structure()
    _add_pipe_runs()
    _add_step_markings()
    _add_floor_service_details()
    _add_cable_trays()
    _add_wall_control_panels()
    _add_narrow_passage_details()
    _add_console_details()
    _decorate_test_crates()
    _add_dynamic_test_crate(Vector3(8.0, 2.4, 13.0))
    _add_moving_test_platform()
    _add_animated_industrial_props()
    _add_work_lights()
    _add_precision_detail_pass()
    _add_surface_response_test_panels()

func _add_floor_grid() -> void:
    var long_lines: Array[Transform3D] = []
    for x in range(-16, 17, 4):
        long_lines.append(Transform3D(Basis(), Vector3(float(x), 0.012, 0.0)))
    _add_multimesh_boxes("FloorGridLong", Vector3(0.018, 0.012, 44.0), long_lines, _materials["grid"])

    var cross_lines: Array[Transform3D] = []
    for z in range(-20, 21, 4):
        cross_lines.append(Transform3D(Basis(), Vector3(0.0, 0.012, float(z))))
    _add_multimesh_boxes("FloorGridCross", Vector3(34.0, 0.012, 0.018), cross_lines, _materials["grid"])

    var black_stripes: Array[Transform3D] = []
    var yellow_stripes: Array[Transform3D] = []
    for index in range(12):
        var z_position := -11.21 + float(index) * 0.22
        var transform := Transform3D(Basis(), Vector3(14.2, 0.02, z_position))
        if index % 2 == 0:
            yellow_stripes.append(transform)
        else:
            black_stripes.append(transform)
    _add_multimesh_boxes("PassageWarningYellow", Vector3(3.2, 0.02, 0.11), yellow_stripes, _materials["warning"])
    _add_multimesh_boxes("PassageWarningDark", Vector3(3.2, 0.021, 0.11), black_stripes, _materials["warning_dark"])

    _add_detail_box("ArenaCenterInset", Vector3(0.0, 0.018, 0.0), Vector3(8.0, 0.012, 0.025), _materials["trim"])
    _add_detail_box("ArenaCenterInsetCross", Vector3(0.0, 0.019, 0.0), Vector3(0.025, 0.012, 8.0), _materials["trim"])

func _add_wall_structure() -> void:
    var column_transforms: Array[Transform3D] = []
    for z in range(-18, 19, 6):
        column_transforms.append(Transform3D(Basis(), Vector3(-18.58, 1.92, float(z))))
        column_transforms.append(Transform3D(Basis(), Vector3(18.58, 1.92, float(z))))
    _add_multimesh_boxes("WallSupportColumns", Vector3(0.28, 3.72, 0.34), column_transforms, _materials["trim"])

    var base_transforms: Array[Transform3D] = []
    for z in range(-18, 19, 6):
        base_transforms.append(Transform3D(Basis(), Vector3(-18.58, 0.12, float(z))))
        base_transforms.append(Transform3D(Basis(), Vector3(18.58, 0.12, float(z))))
    _add_multimesh_boxes("ColumnFootPlates", Vector3(0.62, 0.16, 0.62), base_transforms, _materials["dark"])

    var vent_transforms: Array[Transform3D] = []
    for side: float in [-1.0, 1.0]:
        for z: float in [-15.0, -5.0, 5.0, 15.0]:
            for slat in range(5):
                vent_transforms.append(Transform3D(Basis(), Vector3(side * 18.57, 2.48 + float(slat) * 0.075, z)))
    _add_multimesh_boxes("WallVentSlats", Vector3(0.08, 0.025, 2.2), vent_transforms, _materials["dark"])

    for side: float in [-1.0, 1.0]:
        _add_detail_box("UpperWallTrim_%s" % str(side), Vector3(side * 18.64, 3.82, 0.0), Vector3(0.12, 0.11, 46.0), _materials["trim"])

func _add_pipe_runs() -> void:
    for side: float in [-1.0, 1.0]:
        var pipe := MeshInstance3D.new()
        pipe.name = "UpperServicePipe_%s" % str(side)
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = 0.075
        cylinder.bottom_radius = 0.075
        cylinder.height = 40.0
        pipe.mesh = cylinder
        pipe.material_override = _materials["blue"]
        pipe.position = Vector3(side * 17.85, 3.28, 0.0)
        pipe.rotation.x = PI * 0.5
        add_child(pipe)

        for z in range(-16, 17, 8):
            _add_detail_box("PipeClamp_%s_%d" % [str(side), z], Vector3(side * 17.85, 3.28, float(z)), Vector3(0.20, 0.20, 0.15), _materials["trim"])

    var ceiling_beams: Array[Transform3D] = []
    for z: float in [-18.0, -9.0, 0.0, 9.0, 18.0]:
        ceiling_beams.append(Transform3D(Basis(), Vector3(0.0, 3.92, z)))
    _add_multimesh_boxes("OverheadCrossBeams", Vector3(36.0, 0.16, 0.22), ceiling_beams, _materials["dark"])

func _add_step_markings() -> void:
    var stripe_transforms: Array[Transform3D] = []
    for index in range(8):
        var step_height := 0.18 * float(index + 1)
        var step_z := 3.0 - float(index) * 0.58 + 0.22
        stripe_transforms.append(Transform3D(Basis(), Vector3(-6.0, step_height + 0.014, step_z)))
    _add_multimesh_boxes("StepEdgeSafetyStripes", Vector3(2.9, 0.025, 0.045), stripe_transforms, _materials["warning"])

    for index in range(6):
        var x_position := -12.2 - float(index % 2) * 0.12
        var z_position := -7.0 - float(index) * 0.38
        _add_detail_box("CrateFloorLabel_%02d" % index, Vector3(x_position, 0.018, z_position), Vector3(0.5, 0.012, 0.035), _materials["warning"])

func _add_floor_service_details() -> void:
    # Low-profile drain channels and repeated grate bars add scale without extra colliders.
    for side: float in [-1.0, 1.0]:
        var x_position := side * 16.7
        _add_detail_box("FloorDrainChannel_%s" % str(side), Vector3(x_position, 0.018, 0.0), Vector3(0.16, 0.018, 39.0), _materials["dark"])
        var grate_transforms: Array[Transform3D] = []
        for index in range(39):
            var z_position := -18.5 + float(index) * 0.98
            grate_transforms.append(Transform3D(Basis(), Vector3(x_position, 0.032, z_position)))
        _add_multimesh_boxes("FloorDrainGrates_%s" % str(side), Vector3(0.12, 0.012, 0.035), grate_transforms, _materials["trim"])

    var floor_bolts: Array[Transform3D] = []
    for x_position: float in [-17.7, -10.0, 10.0, 17.7]:
        for z_position: float in [-20.0, -12.0, -4.0, 4.0, 12.0, 20.0]:
            floor_bolts.append(Transform3D(Basis(), Vector3(x_position, 0.028, z_position)))
    _add_multimesh_boxes("FloorAnchorPlates", Vector3(0.12, 0.035, 0.12), floor_bolts, _materials["trim"])

func _add_cable_trays() -> void:
    for side: float in [-1.0, 1.0]:
        var x_position := side * 4.8
        _add_detail_box("CableTrayRail_%s_A" % str(side), Vector3(x_position - 0.18, 3.48, 0.0), Vector3(0.055, 0.06, 39.0), _materials["trim"])
        _add_detail_box("CableTrayRail_%s_B" % str(side), Vector3(x_position + 0.18, 3.48, 0.0), Vector3(0.055, 0.06, 39.0), _materials["trim"])
        var support_transforms: Array[Transform3D] = []
        for z_position in range(-18, 19, 3):
            support_transforms.append(Transform3D(Basis(), Vector3(x_position, 3.44, float(z_position))))
        _add_multimesh_boxes("CableTrayCrossbars_%s" % str(side), Vector3(0.42, 0.035, 0.055), support_transforms, _materials["dark"])
        for cable_index in range(3):
            var cable := MeshInstance3D.new()
            cable.name = "CableBundle_%s_%d" % [str(side), cable_index]
            var cable_mesh := CylinderMesh.new()
            cable_mesh.top_radius = 0.018
            cable_mesh.bottom_radius = 0.018
            cable_mesh.height = 38.0
            cable.mesh = cable_mesh
            cable.material_override = _materials["blue"] if cable_index == 0 else _materials["dark"]
            cable.position = Vector3(x_position - 0.12 + float(cable_index) * 0.12, 3.53, 0.0)
            cable.rotation.x = PI * 0.5
            add_child(cable)

func _add_wall_control_panels() -> void:
    for side: float in [-1.0, 1.0]:
        for index in range(3):
            var panel_root := Node3D.new()
            panel_root.name = "WallServicePanel_%s_%d" % [str(side), index]
            panel_root.position = Vector3(side * 18.36, 1.42, -13.0 + float(index) * 12.0)
            panel_root.rotation.y = -PI * 0.5 if side < 0.0 else PI * 0.5
            add_child(panel_root)
            _add_detail_box("PanelHousing", Vector3.ZERO, Vector3(0.72, 0.92, 0.16), _materials["dark"], panel_root)
            _add_detail_box("PanelInset", Vector3(0.0, 0.12, -0.09), Vector3(0.48, 0.32, 0.025), _materials["blue"], panel_root)
            _add_detail_box("PanelStatusBar", Vector3(0.0, -0.22, -0.095), Vector3(0.42, 0.045, 0.02), _materials["glow"], panel_root)
            for bolt_x: float in [-0.28, 0.28]:
                for bolt_y: float in [-0.36, 0.36]:
                    _add_detail_box("PanelFastener", Vector3(bolt_x, bolt_y, -0.095), Vector3(0.045, 0.045, 0.02), _materials["trim"], panel_root)

func _add_narrow_passage_details() -> void:
    for side: float in [-1.0, 1.0]:
        var x_position := 12.5 if side < 0.0 else 16.0
        var inner_x := x_position - side * 0.34
        _add_detail_box("PassageTopRail_%s" % str(side), Vector3(inner_x, 2.15, -10.0), Vector3(0.12, 0.12, 8.0), _materials["trim"])
        for z: float in [-13.0, -10.0, -7.0]:
            _add_detail_box("PassageMarker_%s_%s" % [str(side), str(z)], Vector3(inner_x, 1.25, z), Vector3(0.035, 0.18, 0.55), _materials["warning"])

func _add_console_details() -> void:
    var console := get_node_or_null("TestConsole") as Node3D
    if console == null:
        return
    _add_detail_box("ConsoleScreenFrame", Vector3(0.0, 0.27, -0.285), Vector3(0.72, 0.38, 0.045), _materials["dark"], console)
    _add_detail_box("ConsoleScreen", Vector3(0.0, 0.27, -0.311), Vector3(0.62, 0.28, 0.012), _materials["glow"], console)
    for index in range(4):
        var x_position := -0.39 + float(index) * 0.26
        _add_detail_box("ConsoleButton_%d" % index, Vector3(x_position, -0.24, -0.29), Vector3(0.12, 0.08, 0.055), _materials["signal"] if index == 0 else _materials["trim"], console)
    _add_detail_box("ConsoleLowerPanel", Vector3(0.0, -0.48, -0.29), Vector3(0.78, 0.06, 0.035), _materials["dark"], console)

func _decorate_test_crates() -> void:
    var block_a := get_node_or_null("BlockA") as Node3D
    if block_a != null:
        for side: float in [-1.0, 1.0]:
            _add_detail_box("BlockA_CornerGuard_%s" % str(side), Vector3(side * 0.72, 0.0, 0.0), Vector3(0.12, 1.18, 1.72), _materials["trim"], block_a)
        _add_detail_box("BlockA_TopPlate", Vector3(0.0, 0.67, 0.0), Vector3(1.48, 0.06, 1.48), _materials["dark"], block_a)
        for x: float in [-0.5, 0.5]:
            for z: float in [-0.5, 0.5]:
                var bolt_mesh := SphereMesh.new()
                bolt_mesh.radius = 0.035
                bolt_mesh.height = 0.07
                var bolt := MeshInstance3D.new()
                bolt.mesh = bolt_mesh
                bolt.material_override = _materials["warning"]
                bolt.position = Vector3(x, 0.70, z)
                block_a.add_child(bolt)

    var block_b := get_node_or_null("BlockB") as Node3D
    if block_b != null:
        _add_detail_box("BlockB_Band", Vector3(0.0, 0.30, 0.0), Vector3(2.42, 0.12, 2.42), _materials["trim"], block_b)

func _add_dynamic_test_crate(world_position: Vector3) -> void:
    var crate := RigidBody3D.new()
    crate.name = "DynamicPhysicsCrate"
    crate.position = world_position
    crate.mass = 11.0
    crate.add_to_group("pushable")
    crate.gravity_scale = 1.0
    crate.linear_damp = 0.28
    crate.angular_damp = 0.62
    crate.continuous_cd = true
    crate.set_meta("surface_type", &"crate")
    crate.collision_layer = 1
    crate.collision_mask = 1
    var physics_material := PhysicsMaterial.new()
    physics_material.friction = 0.82
    physics_material.bounce = 0.08
    crate.physics_material_override = physics_material

    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.8, 0.8, 0.8)
    shape_node.shape = shape
    crate.add_child(shape_node)
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.8, 0.8, 0.8)
    mesh_node.mesh = mesh
    mesh_node.material_override = _materials["accent"]
    crate.add_child(mesh_node)
    _add_detail_box("CrateBottomPad", Vector3(0.0, -0.405, 0.0), Vector3(0.68, 0.035, 0.68), _materials["rubber"], crate)
    _add_detail_box("CrateTopPanel", Vector3(0.0, 0.405, 0.0), Vector3(0.62, 0.025, 0.62), _materials["dark"], crate)
    _add_detail_box("CrateStatusStrip", Vector3(0.0, 0.0, -0.408), Vector3(0.42, 0.07, 0.018), _materials["glow"], crate)
    for side: float in [-1.0, 1.0]:
        _add_detail_box("CrateCornerRail_%s" % str(side), Vector3(side * 0.365, 0.0, 0.0), Vector3(0.035, 0.72, 0.84), _materials["trim"], crate)
        for y_position: float in [-0.31, 0.31]:
            var stud := SphereMesh.new()
            stud.radius = 0.028
            stud.height = 0.056
            var stud_node := MeshInstance3D.new()
            stud_node.mesh = stud
            stud_node.material_override = _materials["warning"]
            stud_node.position = Vector3(side * 0.405, y_position, -0.20)
            crate.add_child(stud_node)
    add_child(crate)

func _add_moving_test_platform() -> void:
    var platform := AnimatableBody3D.new()
    platform.name = "MovingPhysicsPlatform"
    platform.set_script(MOVING_PLATFORM_SCRIPT)
    platform.position = Vector3(-12.0, 1.45, 7.0)
    platform.collision_layer = 1
    platform.collision_mask = 1
    platform.set("travel_axis", Vector3.UP)
    platform.set("amplitude", 0.72)
    platform.set("period_seconds", 5.2)
    platform.set_meta("surface_type", &"metal")
    var platform_physics := PhysicsMaterial.new()
    platform_physics.friction = 0.74
    platform_physics.bounce = 0.0
    platform.physics_material_override = platform_physics

    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(3.4, 0.28, 3.0)
    shape_node.shape = shape
    platform.add_child(shape_node)
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(3.4, 0.28, 3.0)
    mesh_node.mesh = mesh
    mesh_node.material_override = _materials["blue"]
    platform.add_child(mesh_node)
    _add_detail_box("MovingPlatformTopStripe", Vector3(0.0, 0.15, 0.0), Vector3(3.1, 0.025, 0.08), _materials["warning"], platform)
    _add_detail_box("MovingPlatformSideTrim", Vector3(0.0, -0.02, -1.51), Vector3(3.0, 0.08, 0.035), _materials["trim"], platform)
    add_child(platform)

func _add_animated_industrial_props() -> void:
    var west_fan := Node3D.new()
    west_fan.name = "WestRotatingVentFan"
    west_fan.set_script(ROTATING_FAN_SCRIPT)
    west_fan.position = Vector3(-18.48, 2.55, -16.0)
    west_fan.rotation.y = PI * 0.5
    add_child(west_fan)

    var east_fan := Node3D.new()
    east_fan.name = "EastRotatingVentFan"
    east_fan.set_script(ROTATING_FAN_SCRIPT)
    east_fan.set("spin_speed", -1.85)
    east_fan.position = Vector3(18.48, 2.55, 16.0)
    east_fan.rotation.y = -PI * 0.5
    add_child(east_fan)

    var beacon := Node3D.new()
    beacon.name = "AnimatedWarningBeacon"
    beacon.set_script(WARNING_BEACON_SCRIPT)
    beacon.position = Vector3(14.25, 2.58, -10.0)
    add_child(beacon)

func _add_work_lights() -> void:
    for light_spec in [
        {"position": Vector3(-8.0, 3.65, -12.0), "color": Color("#6ac8dc")},
        {"position": Vector3(8.0, 3.65, -12.0), "color": Color("#e5aa58")},
        {"position": Vector3(0.0, 3.65, 16.0), "color": Color("#6ac8dc")},
    ]:
        var light := OmniLight3D.new()
        light.position = light_spec["position"]
        light.light_color = light_spec["color"]
        light.light_energy = 0.38
        light.omni_range = 8.5
        light.shadow_enabled = false
        add_child(light)

func _add_detail_box(object_name: String, local_position: Vector3, box_size: Vector3, material: Material, parent_node: Node = null, local_rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = object_name
    var mesh := BoxMesh.new()
    mesh.size = box_size
    mesh_node.mesh = mesh
    mesh_node.material_override = material
    mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh_node.position = local_position
    mesh_node.rotation = local_rotation
    if parent_node == null:
        add_child(mesh_node)
    else:
        parent_node.add_child(mesh_node)
    return mesh_node

func _add_multimesh_boxes(object_name: String, box_size: Vector3, transforms: Array[Transform3D], material: Material) -> void:
    if transforms.is_empty():
        return
    var box_mesh := BoxMesh.new()
    box_mesh.size = box_size
    var multi_mesh := MultiMesh.new()
    multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
    multi_mesh.mesh = box_mesh
    multi_mesh.instance_count = transforms.size()
    for index in range(transforms.size()):
        multi_mesh.set_instance_transform(index, transforms[index])
    var multi_instance := MultiMeshInstance3D.new()
    multi_instance.name = object_name
    multi_instance.multimesh = multi_mesh
    multi_instance.material_override = material
    add_child(multi_instance)

func _add_precision_detail_pass() -> void:
    _add_machine_service_bay()
    _add_pressure_gauges_and_valves()
    _add_floor_access_plates()
    _add_overhead_brackets_and_cable_drops()
    _add_sector_signage()
    _add_dynamic_canister(Vector3(9.3, 0.52, 15.0))

func _add_machine_service_bay() -> void:
    # A large, collision-backed machine plinth anchors the far service wall.
    _add_static_box("ServiceBayMachineBase", Vector3(-11.6, 0.72, -20.7), Vector3(5.4, 1.42, 2.1), _materials["dark"])
    _add_detail_box("ServiceBayMachineTop", Vector3(-11.6, 1.47, -20.7), Vector3(5.18, 0.12, 1.92), _materials["trim"])
    for index in range(6):
        var x_position := -13.7 + float(index) * 0.84
        _add_detail_box("MachineFrontRib_%02d" % index, Vector3(x_position, 0.82, -19.62), Vector3(0.16, 0.82, 0.045), _materials["blue"] if index % 2 == 0 else _materials["trim"])
        _add_detail_box("MachineStatusLamp_%02d" % index, Vector3(x_position, 1.38, -19.58), Vector3(0.11, 0.035, 0.018), _materials["glow"] if index % 3 else _materials["signal"])
    for side: float in [-1.0, 1.0]:
        _add_detail_box("MachineSideGuard_%s" % str(side), Vector3(-11.6 + side * 2.58, 0.86, -20.7), Vector3(0.12, 1.02, 1.94), _materials["accent"])
    var top_bolts: Array[Transform3D] = []
    for x_position: float in [-13.8, -12.7, -11.6, -10.5, -9.4]:
        for z_position: float in [-21.45, -19.95]:
            top_bolts.append(Transform3D(Basis(), Vector3(x_position, 1.545, z_position)))
    _add_multimesh_boxes("ServiceBayTopFasteners", Vector3(0.065, 0.025, 0.065), top_bolts, _materials["warning"])

    # A pair of vertical tanks with separate bands and bottom footings.
    for index in range(2):
        var tank_x := -15.0 + float(index) * 6.8
        var tank := MeshInstance3D.new()
        tank.name = "ServiceTank_%d" % index
        var tank_mesh := CylinderMesh.new()
        tank_mesh.top_radius = 0.52
        tank_mesh.bottom_radius = 0.52
        tank_mesh.height = 1.9
        tank.mesh = tank_mesh
        tank.material_override = _materials["wall"]
        tank.position = Vector3(tank_x, 2.05, -21.5)
        add_child(tank)
        for band_y: float in [1.42, 2.48]:
            var band := MeshInstance3D.new()
            var band_mesh := CylinderMesh.new()
            band_mesh.top_radius = 0.55
            band_mesh.bottom_radius = 0.55
            band_mesh.height = 0.075
            band.mesh = band_mesh
            band.material_override = _materials["accent"]
            band.position = Vector3(tank_x, band_y, -21.5)
            add_child(band)
        _add_detail_box("TankFoot_%d" % index, Vector3(tank_x, 1.12, -21.5), Vector3(1.26, 0.16, 1.26), _materials["dark"])

func _add_pressure_gauges_and_valves() -> void:
    for index in range(3):
        var side := -1.0 if index % 2 == 0 else 1.0
        var z_position := -15.0 + float(index) * 12.0
        var wheel_root := Node3D.new()
        wheel_root.name = "AnimatedValveWheel_%d" % index
        wheel_root.position = Vector3(side * 17.45, 1.58, z_position)
        wheel_root.rotation.y = PI * 0.5 if side < 0.0 else -PI * 0.5
        wheel_root.set_script(load("res://scripts/world/rotating_valve_wheel.gd"))
        wheel_root.set("idle_wobble", 0.035 + float(index) * 0.01)
        add_child(wheel_root)

        var gauge_root := Node3D.new()
        gauge_root.name = "AnimatedPressureGauge_%d" % index
        gauge_root.position = Vector3(side * 17.42, 2.34, z_position + 1.35)
        gauge_root.rotation.y = PI * 0.5 if side < 0.0 else -PI * 0.5
        gauge_root.set_script(load("res://scripts/world/animated_pressure_gauge.gd"))
        gauge_root.set("phase_offset", float(index) * 1.8)
        add_child(gauge_root)

func _add_floor_access_plates() -> void:
    var plate_transforms: Array[Transform3D] = []
    for x_position: float in [-8.0, 0.0, 8.0]:
        for z_position: float in [-18.0, -2.0, 14.0]:
            plate_transforms.append(Transform3D(Basis(), Vector3(x_position, 0.026, z_position)))
    _add_multimesh_boxes("FloorAccessPlateBases", Vector3(2.1, 0.045, 1.25), plate_transforms, _materials["dark"])
    var plate_edges: Array[Transform3D] = []
    var plate_bolts: Array[Transform3D] = []
    for x_position: float in [-8.0, 0.0, 8.0]:
        for z_position: float in [-18.0, -2.0, 14.0]:
            for side: float in [-1.0, 1.0]:
                plate_edges.append(Transform3D(Basis(), Vector3(x_position + side * 1.0, 0.054, z_position)))
                plate_bolts.append(Transform3D(Basis(), Vector3(x_position + side * 0.84, 0.078, z_position - 0.47)))
                plate_bolts.append(Transform3D(Basis(), Vector3(x_position + side * 0.84, 0.078, z_position + 0.47)))
    _add_multimesh_boxes("AccessPlateEdgeRims", Vector3(0.035, 0.025, 1.12), plate_edges, _materials["trim"])
    _add_multimesh_boxes("AccessPlateFasteners", Vector3(0.065, 0.025, 0.065), plate_bolts, _materials["warning"])

    # Parallel inset lines and numbered service-bay markers provide readable scale cues.
    for index in range(7):
        var z_position := -19.0 + float(index) * 0.42
        _add_detail_box("MachineBayFloorIndex_%02d" % index, Vector3(-11.6, 0.019, z_position), Vector3(3.8, 0.012, 0.025), _materials["warning"] if index % 2 == 0 else _materials["trim"])

func _add_overhead_brackets_and_cable_drops() -> void:
    var bracket_transforms: Array[Transform3D] = []
    for z_position in range(-18, 19, 3):
        bracket_transforms.append(Transform3D(Basis(), Vector3(-4.8, 3.34, float(z_position))))
        bracket_transforms.append(Transform3D(Basis(), Vector3(4.8, 3.34, float(z_position))))
    _add_multimesh_boxes("OverheadCableHangers", Vector3(0.09, 0.34, 0.12), bracket_transforms, _materials["trim"])

    for side: float in [-1.0, 1.0]:
        for index in range(4):
            var drop := MeshInstance3D.new()
            drop.name = "CableDrop_%s_%d" % [str(side), index]
            var drop_mesh := CylinderMesh.new()
            drop_mesh.top_radius = 0.021
            drop_mesh.bottom_radius = 0.021
            drop_mesh.height = 0.66 + float(index % 2) * 0.24
            drop.mesh = drop_mesh
            drop.material_override = _materials["dark"] if index % 2 else _materials["blue"]
            drop.position = Vector3(side * 4.8, 3.12 - float(index % 2) * 0.1, -14.0 + float(index) * 9.0)
            add_child(drop)
            _add_detail_box("CableDropClamp_%s_%d" % [str(side), index], drop.position + Vector3(0.0, -drop_mesh.height * 0.5, 0.0), Vector3(0.12, 0.06, 0.12), _materials["accent"])

func _add_sector_signage() -> void:
    _add_label("SECTOR 04  /  SERVICE BAY", Vector3(0.0, 3.1, -23.55), Vector3.ZERO, 0.012, Color("#8ee7ef"))
    _add_label("PRESSURE SYSTEM", Vector3(-11.6, 2.65, -19.48), Vector3.ZERO, 0.009, Color("#ffd08a"))
    _add_label("MAINTENANCE ACCESS", Vector3(14.25, 2.86, -9.68), Vector3.ZERO, 0.008, Color("#8ee7ef"))

func _add_label(label_text: String, world_position: Vector3, world_rotation: Vector3, pixel_size: float, color: Color) -> void:
    var label := Label3D.new()
    label.text = label_text
    label.position = world_position
    label.rotation = world_rotation
    label.pixel_size = pixel_size
    label.font_size = 48
    label.outline_size = 7
    label.modulate = color
    label.shaded = false
    label.no_depth_test = false
    add_child(label)

func _add_dynamic_canister(world_position: Vector3) -> void:
    var canister := RigidBody3D.new()
    canister.name = "RollingPhysicsCanister"
    canister.position = world_position
    canister.mass = 8.5
    canister.linear_damp = 0.35
    canister.angular_damp = 0.5
    canister.continuous_cd = true
    canister.collision_layer = 1
    canister.collision_mask = 1
    canister.add_to_group("pushable")
    canister.set_meta("surface_type", &"metal")
    var physics_material := PhysicsMaterial.new()
    physics_material.friction = 0.58
    physics_material.bounce = 0.035
    canister.physics_material_override = physics_material

    var shape_node := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 0.34
    shape.height = 0.88
    shape_node.shape = shape
    canister.add_child(shape_node)
    var body_mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.34
    cylinder.bottom_radius = 0.34
    cylinder.height = 0.88
    body_mesh.mesh = cylinder
    body_mesh.material_override = _materials["blue"]
    canister.add_child(body_mesh)
    for band_y: float in [-0.28, 0.28]:
        var band := MeshInstance3D.new()
        var band_mesh := CylinderMesh.new()
        band_mesh.top_radius = 0.352
        band_mesh.bottom_radius = 0.352
        band_mesh.height = 0.065
        band.mesh = band_mesh
        band.material_override = _materials["accent"]
        band.position.y = band_y
        canister.add_child(band)
    var top_cap := MeshInstance3D.new()
    var cap_mesh := CylinderMesh.new()
    cap_mesh.top_radius = 0.25
    cap_mesh.bottom_radius = 0.25
    cap_mesh.height = 0.055
    top_cap.mesh = cap_mesh
    top_cap.material_override = _materials["trim"]
    top_cap.position.y = 0.455
    canister.add_child(top_cap)
    add_child(canister)

func _add_surface_response_test_panels() -> void:
    # Flush-mounted test strips exercise surface-dependent movement and footstep profiles.
    var panels := [
        {"name": "SurfacePanel_Concrete", "x": -13.0, "type": &"concrete", "material": _materials["floor"], "speed": 1.0, "traction": 1.0, "stride": 1.0},
        {"name": "SurfacePanel_PaintedSteel", "x": -4.3, "type": &"metal", "material": _materials["wall"], "speed": 0.98, "traction": 0.82, "stride": 0.94},
        {"name": "SurfacePanel_Rubber", "x": 4.3, "type": &"rubber", "material": _materials["rubber"], "speed": 0.96, "traction": 1.12, "stride": 1.08},
        {"name": "SurfacePanel_Grate", "x": 13.0, "type": &"grate", "material": _materials["grid"], "speed": 0.99, "traction": 0.91, "stride": 0.96},
    ]
    for panel in panels:
        var body := _add_static_box(
            str(panel["name"]),
            Vector3(float(panel["x"]), 0.025, 20.4),
            Vector3(2.65, 0.05, 2.35),
            panel["material"]
        )
        body.set_meta("surface_type", panel["type"])
        body.set_meta("move_speed_multiplier", float(panel["speed"]))
        body.set_meta("traction_multiplier", float(panel["traction"]))
        body.set_meta("stride_multiplier", float(panel["stride"]))
        var physics_profile := PhysicsMaterial.new()
        match panel["type"]:
            &"concrete":
                physics_profile.friction = 0.86
            &"metal":
                physics_profile.friction = 0.56
            &"rubber":
                physics_profile.friction = 0.96
            &"grate":
                physics_profile.friction = 0.68
        physics_profile.bounce = 0.01
        body.physics_material_override = physics_profile
        _add_detail_box(
            "%s_EdgeTrim" % str(panel["name"]),
            Vector3(float(panel["x"]), 0.055, 20.4),
            Vector3(2.68, 0.018, 0.035),
            _materials["trim"]
        )
        _add_label(str(panel["type"]).to_upper(), Vector3(float(panel["x"]), 0.18, 19.0), Vector3.ZERO, 0.012, Color("#b8d5dc"))

    _add_label("SURFACE RESPONSE TEST", Vector3(0.0, 3.1, 20.9), Vector3.ZERO, 0.018, Color("#8adbe8"))

func _exit_tree() -> void:
    AppState.end_session()
    SaveManager.flush()

func _physics_process(_delta: float) -> void:
    # Falling out of the world counts as a death, so the respawn flow always recovers the player.
    if is_instance_valid(_player) and not bool(_player.call("is_dead")) and _player.global_position.y < -12.0:
        var health := _player.get_node_or_null("HealthComponent") as HealthComponent
        if health != null:
            health.apply_damage(9999.0)

func _build_training_range() -> void:
    var target_specs := [
        {"pos": Vector3(-8.0, 0.0, -18.0), "patrol": 0.0},
        {"pos": Vector3(-4.0, 0.0, -20.0), "patrol": 0.0},
        {"pos": Vector3(0.0, 0.0, -18.5), "patrol": 0.0},
        {"pos": Vector3(4.0, 0.0, -20.0), "patrol": 0.0},
        {"pos": Vector3(8.0, 0.0, -18.0), "patrol": 0.0},
        {"pos": Vector3(0.0, 0.0, -21.8), "patrol": 6.0},
        {"pos": Vector3(-14.0, 0.0, 6.0), "patrol": 0.0},
        {"pos": Vector3(14.0, 0.0, 8.0), "patrol": 0.0},
    ]
    var index: int = 0
    for spec in target_specs:
        var target := StaticBody3D.new()
        target.set_script(TARGET_SCRIPT)
        target.name = "TrainingTarget_%d" % index
        target.set("patrol_distance", float(spec["patrol"]))
        target.position = spec["pos"]
        add_child(target)
        index += 1
    var hazard := Area3D.new()
    hazard.set_script(HAZARD_SCRIPT)
    hazard.name = "HazardZone"
    hazard.position = Vector3(-12.0, 0.0, -1.5)
    add_child(hazard)
    _add_supply_station(Vector3(-4.5, 0.0, 9.0))

func _add_supply_station(world_position: Vector3) -> void:
    var station := StaticBody3D.new()
    station.set_script(INTERACTABLE_SCRIPT)
    station.name = "SupplyStation"
    station.position = world_position + Vector3(0.0, 0.6, 0.0)
    station.collision_layer = 3
    station.collision_mask = 0
    station.set("interaction_text", Loc.t("supply_prompt"))
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.0, 1.2, 0.6)
    shape_node.shape = shape
    station.add_child(shape_node)
    var body_mesh := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = shape.size
    body_mesh.mesh = mesh
    body_mesh.material_override = _materials["blue"]
    station.add_child(body_mesh)
    var cross_material := _make_emissive_material(Color("#3ddc84"), 1.6)
    var bar_a := MeshInstance3D.new()
    var bar_a_mesh := BoxMesh.new()
    bar_a_mesh.size = Vector3(0.46, 0.14, 0.02)
    bar_a.mesh = bar_a_mesh
    bar_a.material_override = cross_material
    bar_a.position = Vector3(0.0, 0.15, 0.31)
    station.add_child(bar_a)
    var bar_b := MeshInstance3D.new()
    var bar_b_mesh := BoxMesh.new()
    bar_b_mesh.size = Vector3(0.14, 0.46, 0.02)
    bar_b.mesh = bar_b_mesh
    bar_b.material_override = cross_material
    bar_b.position = Vector3(0.0, 0.15, 0.31)
    station.add_child(bar_b)
    station.connect("interacted", Callable(self, "_on_supply_used").bind(station))
    add_child(station)

func _on_supply_used(_actor: Node, station: Node) -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var health := _player.get_node_or_null("HealthComponent") as HealthComponent
    if health != null:
        health.restore(health.max_health)
        health.add_armor(health.max_armor)
    var weapon := _player.get_node_or_null("WeaponController")
    if weapon != null and weapon.has_method("refill"):
        weapon.call("refill")
    station.set("interaction_enabled", false)
    get_tree().create_timer(5.0).timeout.connect(func() -> void:
        if is_instance_valid(station):
            station.set("interaction_enabled", true))

func _on_target_destroyed(points: int, headshot: bool) -> void:
    _session_score += points
    SaveManager.add_score(points)
    SaveManager.add_credits(maxi(1, points / 10))
    SaveManager.increment_stat("kills")
    if headshot:
        SaveManager.increment_stat("headshots")
    SaveManager.record_best_score(_session_score)
    EventBus.player_score_changed.emit("local", _session_score)

func _on_player_died() -> void:
    var delay: float = float(_player.get("respawn_delay"))
    await get_tree().create_timer(delay).timeout
    if not is_instance_valid(_player):
        return
    var spawn_transform: Transform3D = _spawn_manager.call("get_next_spawn_transform", "")
    _player.call("respawn", spawn_transform)

func _build_arena() -> void:
    _add_static_box("ArenaFloor", Vector3(0.0, -0.5, 0.0), Vector3(38.0, 1.0, 48.0), _materials["floor"])
    _add_static_box("NorthWall", Vector3(0.0, 2.0, -24.0), Vector3(38.0, 4.0, 0.6), _materials["wall"])
    _add_static_box("SouthWall", Vector3(0.0, 2.0, 24.0), Vector3(38.0, 4.0, 0.6), _materials["wall"])
    _add_static_box("WestWall", Vector3(-19.0, 2.0, 0.0), Vector3(0.6, 4.0, 48.0), _materials["wall"])
    _add_static_box("EastWall", Vector3(19.0, 2.0, 0.0), Vector3(0.6, 4.0, 48.0), _materials["wall"])

    # Step flight: each tread rises by 0.18 m, useful for testing the step-assist probe.
    for index in range(8):
        var height := 0.18 * float(index + 1)
        var step_depth := 0.58
        var step := _add_static_box(
            "Step_%02d" % index,
            Vector3(-6.0, height * 0.5, 3.0 - float(index) * step_depth),
            Vector3(3.2, height, step_depth),
            _materials["step"]
        )
        step.set_meta("test_feature", "step")

    # A walkable ramp, separate from its visible mesh via the helper's dedicated collision shape.
    _add_static_box("Ramp", Vector3(5.0, 0.74, -5.0), Vector3(3.5, 0.25, 7.0), _materials["blue"], Vector3(deg_to_rad(12.0), 0.0, 0.0))

    _add_static_box("LowPlatform", Vector3(10.0, 0.45, 2.0), Vector3(4.0, 0.9, 4.0), _materials["wall"])
    _add_static_box("NarrowPassageLeft", Vector3(12.5, 1.0, -10.0), Vector3(0.6, 2.0, 8.0), _materials["dark"])
    _add_static_box("NarrowPassageRight", Vector3(16.0, 1.0, -10.0), Vector3(0.6, 2.0, 8.0), _materials["dark"])
    _add_static_box("OverheadBeam", Vector3(14.25, 2.3, -10.0), Vector3(4.0, 0.35, 0.5), _materials["accent"])

    _add_static_box("BlockA", Vector3(-11.0, 0.65, -8.0), Vector3(1.6, 1.3, 1.6), _materials["accent"])
    _add_static_box("BlockB", Vector3(-14.0, 0.45, -12.0), Vector3(2.4, 0.9, 2.4), _materials["blue"])
    _add_static_box("LowBeam", Vector3(0.0, 1.65, -15.0), Vector3(6.0, 0.3, 0.4), _materials["accent"])

    _add_interactable_console(Vector3(3.0, 0.0, -1.5))
    _add_visual_marker(Vector3(0.0, 0.015, 10.0), Vector3(3.0, 0.03, 0.12), _materials["accent"])
    _add_visual_marker(Vector3(0.0, 0.015, 10.5), Vector3(3.0, 0.03, 0.12), _materials["blue"])
    _create_spawn_points()
    _build_arena_details()

func _create_runtime_services() -> void:
    _spawn_manager = Node.new()
    _spawn_manager.name = "SpawnManager"
    _spawn_manager.set_script(SPAWN_MANAGER_SCRIPT)
    add_child(_spawn_manager)

    _player_registry = Node.new()
    _player_registry.name = "PlayerRegistry"
    _player_registry.set_script(PLAYER_REGISTRY_SCRIPT)
    add_child(_player_registry)

    var match_controller := Node.new()
    match_controller.name = "MatchController"
    match_controller.set_script(MATCH_CONTROLLER_SCRIPT)
    add_child(match_controller)

    var network_session := Node.new()
    network_session.name = "LocalNetworkSession"
    network_session.set_script(NETWORK_SESSION_SCRIPT)
    add_child(network_session)

func _create_spawn_points() -> void:
    var spawn_specs := [
        {"id": "00_main", "position": Vector3(0.0, 0.08, 12.0)},
        {"id": "01_west", "position": Vector3(-15.0, 0.08, 15.0)},
        {"id": "02_east", "position": Vector3(15.0, 0.08, 15.0)},
    ]
    for spec in spawn_specs:
        var point := Marker3D.new()
        point.name = "Spawn_%s" % str(spec["id"])
        point.set_script(SPAWN_POINT_SCRIPT)
        point.set("spawn_id", str(spec["id"]))
        point.position = spec["position"]
        add_child(point)

func _add_static_box(object_name: String, world_position: Vector3, box_size: Vector3, material: Material, world_rotation: Vector3 = Vector3.ZERO) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = object_name
    body.position = world_position
    body.rotation = world_rotation
    body.collision_layer = 1
    body.collision_mask = 1
    var surface_type: StringName = &"concrete"
    if object_name.begins_with("Step") or object_name == "Ramp" or object_name == "LowPlatform":
        surface_type = &"metal"
    body.set_meta("surface_type", surface_type)
    body.set_meta("move_speed_multiplier", 1.0 if surface_type == &"concrete" else 0.98)
    body.set_meta("traction_multiplier", 1.0 if surface_type == &"concrete" else 0.86)
    body.set_meta("jump_multiplier", 1.0)
    body.set_meta("stride_multiplier", 1.0 if surface_type == &"concrete" else 0.94)
    var surface_physics := PhysicsMaterial.new()
    surface_physics.friction = 0.82 if surface_type == &"concrete" else 0.62
    surface_physics.bounce = 0.015
    body.physics_material_override = surface_physics
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box_size
    shape_node.shape = shape
    body.add_child(shape_node)
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    mesh_node.mesh = mesh
    mesh_node.material_override = material
    body.add_child(mesh_node)
    add_child(body)
    return body

func _add_visual_marker(world_position: Vector3, box_size: Vector3, material: Material) -> void:
    var marker := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    marker.mesh = mesh
    marker.position = world_position
    marker.material_override = material
    add_child(marker)

func _add_interactable_console(world_position: Vector3) -> void:
    var console := StaticBody3D.new()
    console.set_script(INTERACTABLE_SCRIPT)
    console.name = "TestConsole"
    console.position = world_position + Vector3(0.0, 0.65, 0.0)
    console.collision_layer = 2
    console.collision_mask = 0
    console.set("interaction_text", "Test console — press E / USE")
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.2, 1.3, 0.55)
    shape_node.shape = shape
    console.add_child(shape_node)
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = shape.size
    mesh_node.mesh = mesh
    mesh_node.material_override = _materials["blue"]
    console.add_child(mesh_node)
    var top_light := MeshInstance3D.new()
    var light_mesh := BoxMesh.new()
    light_mesh.size = Vector3(0.82, 0.06, 0.3)
    top_light.mesh = light_mesh
    top_light.position = Vector3(0.0, 0.5, -0.02)
    top_light.material_override = _materials["accent"]
    console.add_child(top_light)
    console.connect("interacted", Callable(self, "_on_console_interacted"))
    add_child(console)

func _on_console_interacted(_actor: Node) -> void:
    print("[IronYard] Test console interaction confirmed.")

func _spawn_player() -> void:
    var player := PLAYER_SCENE.instantiate() as CharacterBody3D
    player.name = "Player"
    add_child(player)
    _player = player
    player.connect("died", Callable(self, "_on_player_died"))
    if _spawn_manager != null:
        player.global_transform = _spawn_manager.call("get_next_spawn_transform", "")
    else:
        player.position = Vector3(0.0, 0.08, 12.0)
    if _player_registry != null:
        _player_registry.call("register_player", "local", player)

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
    ArsenalHUD.attach(self)
    pause_menu.set_script(PAUSE_MENU_SCRIPT)
    add_child(pause_menu)
