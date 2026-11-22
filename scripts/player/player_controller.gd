extends CharacterBody3D
class_name PlayerController

signal movement_state_changed(state: StringName)
signal interaction_prompt_changed(prompt: String)
signal footstep_played(intensity: float)
signal scan_requested()
signal stamina_changed(current: float, maximum: float)
signal died
signal respawned
signal slide_started

@export_group("Movement - Ground")
@export_range(1.0, 12.0, 0.1) var walk_speed: float = 3.3
@export_range(1.0, 16.0, 0.1) var sprint_speed: float = 3.3  # running removed: kept equal to walk_speed
@export_range(1.0, 70.0, 0.5) var ground_acceleration: float = 32.0
@export_range(1.0, 70.0, 0.5) var ground_deceleration: float = 38.0
@export_range(1.0, 35.0, 0.5) var air_acceleration: float = 8.5
@export_range(0.0, 10.0, 0.1) var air_drag: float = 0.65
@export_range(1.0, 20.0, 0.1) var sprint_transition_speed: float = 4.5
## How fast the sprint pose (low rifle) is dropped when the player starts shooting.
@export_range(2.0, 30.0, 0.5) var sprint_exit_speed: float = 11.0
@export_range(0.9, 1.6, 0.01) var crouch_capsule_height: float = 1.28
@export_range(0.35, 0.85, 0.01) var crouch_speed_multiplier: float = 0.54
@export_range(0.5, 1.2, 0.01) var prone_capsule_height: float = 0.72
@export_range(0.1, 0.6, 0.01) var prone_speed_multiplier: float = 0.26
@export_range(1.0, 10.0, 0.1) var prone_transition_speed: float = 3.4
@export_range(0.2, 0.7, 0.01) var prone_eye_height: float = 0.42
@export_range(2.0, 14.0, 0.2) var crouch_transition_speed: float = 5.5
@export_range(1.0, 12.0, 0.1) var jump_velocity: float = 5.35
@export_range(0.0, 0.5, 0.01) var jump_hold_duration: float = 0.16
@export_range(0.3, 1.0, 0.01) var jump_hold_gravity_multiplier: float = 0.66
@export_range(1.0, 2.5, 0.05) var fall_gravity_multiplier: float = 1.42
@export_range(0.2, 0.9, 0.01) var jump_release_cut_multiplier: float = 0.54
@export_range(10.0, 60.0, 1.0) var terminal_fall_speed: float = 28.0
@export_range(0.0, 1.0, 0.01) var coyote_time: float = 0.14
@export_range(0.0, 1.0, 0.01) var jump_buffer_time: float = 0.16
@export_range(0.05, 0.5, 0.01) var max_step_height: float = 0.30
@export_range(0.1, 1.0, 0.01) var floor_snap_distance: float = 0.34
@export_range(20.0, 60.0, 1.0) var max_walkable_slope_degrees: float = 48.0
@export_range(0.5, 2.0, 0.05) var backward_speed_multiplier: float = 0.76
@export_range(0.5, 2.0, 0.05) var strafe_speed_multiplier: float = 0.90
@export_range(1.0, 3.0, 0.05) var counter_steer_multiplier: float = 1.55
@export_range(0.0, 1.0, 0.05) var air_control_multiplier: float = 1.0

@export_group("Slide")
@export_range(0.2, 1.5, 0.05) var slide_duration: float = 0.8
@export_range(1.0, 14.0, 0.1) var slide_boost_speed: float = 5.0
@export_range(0.5, 12.0, 0.1) var slide_friction: float = 5.2
@export_range(2.0, 7.0, 0.1) var slide_min_speed: float = 3.2
## Pause after a slide ends before the next one may start (no back-to-back sliding).
@export_range(0.0, 3.0, 0.1) var slide_cooldown: float = 1.2

@export_group("Respawn")
@export_range(1.0, 10.0, 0.5) var respawn_delay: float = 3.0

@export_group("Sprint Endurance")
@export var use_sprint_stamina: bool = false
@export_range(10.0, 200.0, 1.0) var stamina_max: float = 100.0
@export_range(1.0, 60.0, 1.0) var stamina_drain_per_second: float = 23.0
@export_range(1.0, 60.0, 1.0) var stamina_regen_per_second: float = 18.0
@export_range(0.0, 3.0, 0.1) var stamina_regen_delay: float = 0.8
@export_range(0.0, 0.6, 0.05) var sprint_rearm_fraction: float = 0.20

@export_group("Look and Camera")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
@export_range(60.0, 110.0, 1.0) var camera_fov: float = 82.0
@export_range(0.5, 8.0, 0.1) var interaction_distance: float = 3.2
@export_range(0.0, 0.08, 0.002) var walk_bob_amount: float = 0.022
@export_range(0.0, 0.12, 0.002) var sprint_bob_amount: float = 0.043

@export_group("Feedback")
@export_range(0.1, 1.0, 0.05) var footstep_distance: float = 0.72
@export var enable_procedural_footsteps: bool = true
@export var enable_landing_dust: bool = true

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _interaction_ray: RayCast3D = $CameraPivot/Camera3D/InteractionRay
@onready var health: HealthComponent = $HealthComponent

var _pitch: float = 0.0
var _jump_buffer_left: float = 0.0
var _jump_hold_left: float = 0.0
var _coyote_left: float = 0.0
var _gravity: float = 18.0
var _interaction_refresh: float = 0.0
var _current_interactable: Node = null
var _movement_state: StringName = &"idle"
var _sprint_blend: float = 0.0
const SCOPE_SCRIPT := preload("res://scripts/player/scope_overlay.gd")
## Field-of-view divider while zoomed (scope button / right mouse button).
@export_range(1.5, 8.0, 0.1) var zoom_factor: float = 3.0
var _zoom_toggled: bool = false
var _zoom_blend: float = 0.0
var _scope_layer: CanvasLayer = null
var _scope_overlay: Control = null
var _walk_phase: float = 0.0
var _landing_kick: float = 0.0
var _landing_spring_offset: float = 0.0
var _landing_spring_velocity: float = 0.0
var _camera_base_height: float = 1.58
var _look_sway: Vector2 = Vector2.ZERO
var _step_distance: float = 0.0
var _footstep_players: Array[AudioStreamPlayer3D] = []
var _landing_player: AudioStreamPlayer3D
var _footstep_streams: Dictionary = {}
var _footstep_cursor: int = 0
var _dust_particles: CPUParticles3D
var _surface_probes: Array[RayCast3D] = []
var _standing_clearance_query: PhysicsShapeQueryParameters3D
var _step_wall_collision: KinematicCollision3D
var _step_down_collision: KinematicCollision3D
var _current_surface_type: StringName = &"concrete"
var _surface_candidate_type: StringName = &""
var _surface_candidate_votes: int = 0
var _surface_target_speed_multiplier: float = 1.0
var _surface_target_traction_multiplier: float = 1.0
var _surface_target_jump_multiplier: float = 1.0
var _surface_target_stride_multiplier: float = 1.0
var _surface_footstep_volume_db: float = 0.0
var _surface_target_footstep_volume_db: float = 0.0
var _viewmodel: Node3D
var _capsule_shape: CapsuleShape3D
var _standing_capsule_shape: CapsuleShape3D
var _standing_capsule_height: float = 1.82
var _current_capsule_height: float = 1.82
var _crouch_blend: float = 0.0
var _crouch_toggled: bool = false
var _prone_toggled: bool = false
var _prone_blend: float = 0.0
var _sprint_block_left: float = 0.0
var _slide_left: float = 0.0
var _slide_cooldown_left: float = 0.0
var _slide_direction: Vector3 = Vector3.ZERO
var _slide_speed: float = 0.0
var _slide_tilt: float = 0.0
var _dead: bool = false
var _third_person: bool = false
var _tp_blend: float = 0.0
var _body_visual: Node3D
var _tp_muzzle: Marker3D
var _leg_left: Node3D
var _leg_right: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _death_roll: float = 0.0
var _recoil_pitch: float = 0.0
var _recoil_target: float = 0.0
var _last_horizontal_velocity: Vector3 = Vector3.ZERO
var _horizontal_acceleration: Vector3 = Vector3.ZERO
var _gait_distance: float = 0.0
var _stamina: float = 100.0
var _stamina_regen_left: float = 0.0
var _sprint_locked: bool = false
var _stamina_signal_left: float = 0.0
var _surface_refresh_left: float = 0.0
var _surface_speed_multiplier: float = 1.0
var _surface_traction_multiplier: float = 1.0
var _surface_jump_multiplier: float = 1.0
var _surface_stride_multiplier: float = 1.0

const SURFACE_PROFILES: Dictionary = {
    &"concrete": {"speed": 1.0, "traction": 1.0, "jump": 1.0, "stride": 1.0, "volume": 0.0},
    &"metal": {"speed": 0.98, "traction": 0.86, "jump": 0.98, "stride": 0.94, "volume": 1.0},
    &"rubber": {"speed": 0.96, "traction": 1.12, "jump": 1.0, "stride": 1.08, "volume": -1.4},
    &"crate": {"speed": 0.91, "traction": 0.78, "jump": 0.94, "stride": 0.90, "volume": -0.6},
    &"grate": {"speed": 0.99, "traction": 0.92, "jump": 0.99, "stride": 0.96, "volume": 0.8},
    &"composite": {"speed": 1.0, "traction": 1.04, "jump": 1.0, "stride": 1.02, "volume": -0.2},
}

func _ready() -> void:
    add_to_group("player_controller")
    _stamina = stamina_max
    _surface_refresh_left = 0.0
    var source_capsule := _collision_shape.shape as CapsuleShape3D
    if source_capsule != null:
        # CollisionShape resources from a PackedScene can be shared between instances.
        # Give every player a private shape before any runtime crouch resizing.
        _capsule_shape = source_capsule.duplicate() as CapsuleShape3D
        _collision_shape.shape = _capsule_shape
        _standing_capsule_shape = _capsule_shape.duplicate() as CapsuleShape3D
        _standing_capsule_height = _capsule_shape.height
        _current_capsule_height = _standing_capsule_height
        crouch_capsule_height = clampf(crouch_capsule_height, _capsule_shape.radius * 2.0, _standing_capsule_height)
        _standing_clearance_query = PhysicsShapeQueryParameters3D.new()
        _standing_clearance_query.shape = _standing_capsule_shape
        _standing_clearance_query.collide_with_bodies = true
        _standing_clearance_query.collide_with_areas = false
        _standing_clearance_query.collision_mask = collision_mask
        # A near-zero margin avoids treating a player resting just above the floor
        # as an obstruction while still keeping the headroom query conservative.
        _standing_clearance_query.margin = 0.001
        _standing_clearance_query.exclude = [get_rid()]
    collision_layer = 1
    collision_mask = 1
    if _standing_clearance_query != null:
        _standing_clearance_query.collision_mask = collision_mask
    _step_wall_collision = KinematicCollision3D.new()
    _step_down_collision = KinematicCollision3D.new()
    motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
    up_direction = Vector3.UP
    floor_snap_length = floor_snap_distance
    floor_max_angle = deg_to_rad(max_walkable_slope_degrees)
    floor_stop_on_slope = true
    floor_constant_speed = true
    floor_block_on_wall = true
    safe_margin = 0.015
    max_slides = 8
    camera_fov = float(SettingsManager.get_setting("fov", camera_fov))
    SettingsManager.settings_changed.connect(_on_settings_changed)
    _camera.fov = camera_fov
    _camera_pivot.position.y = _camera_base_height
    _interaction_ray.target_position = Vector3(0.0, 0.0, -interaction_distance)
    _interaction_ray.collision_mask = 2
    _interaction_ray.enabled = true
    health.regen_enabled = true
    health.health_changed.connect(_on_health_changed)
    health.depleted.connect(_on_health_depleted)
    health.armor_changed.connect(_on_armor_changed)
    health.damaged.connect(_on_damaged)
    # Five probes cover the footprint in both axes. The center sample is weighted
    # more strongly; this reduces false changes while crossing seams and step edges.
    var probe_offsets := [
        Vector3.ZERO,
        Vector3(-0.22, 0.0, 0.0),
        Vector3(0.22, 0.0, 0.0),
        Vector3(0.0, 0.0, -0.22),
        Vector3(0.0, 0.0, 0.22),
    ]
    for probe_index in range(probe_offsets.size()):
        var probe := RayCast3D.new()
        probe.name = "SurfaceProbe_%d" % probe_index
        probe.position = probe_offsets[probe_index] + Vector3(0.0, 0.12, 0.0)
        probe.target_position = Vector3(0.0, -0.62, 0.0)
        probe.collision_mask = 1
        probe.enabled = true
        add_child(probe)
        _surface_probes.append(probe)
    _create_feedback_nodes()
    _viewmodel = _camera.get_node_or_null("EquipmentViewmodel") as Node3D
    _build_body_visual()
    _create_scope_overlay()
    _camera.current = is_multiplayer_authority()
    if _viewmodel != null:
        _viewmodel.visible = is_multiplayer_authority()
    if not OS.has_feature("android") and not OS.has_feature("ios"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if OS.has_feature("android") or OS.has_feature("ios"):
        return
    if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        add_look_delta(event.relative)

func _apply_camera_pitch() -> void:
    _camera_pivot.rotation.x = clampf(_pitch + _recoil_pitch, -1.5, 1.5)

func add_recoil(pitch_amount: float, yaw_amount: float) -> void:
    # The view kicks up immediately, then eases back down (partly stays, like a real climb).
    _pitch = clampf(_pitch + pitch_amount * 0.55, -1.48, 1.48)
    _recoil_target += pitch_amount * 0.45
    _recoil_pitch += pitch_amount * 0.45
    rotate_y(yaw_amount)
    _apply_camera_pitch()

func toggle_zoom() -> void:
    if _dead or _third_person:
        return
    _zoom_toggled = not _zoom_toggled

func is_zoomed() -> bool:
    return _zoom_blend > 0.5 or _zoom_toggled

func get_zoom_blend() -> float:
    return _zoom_blend

func _update_zoom(delta: float) -> void:
    var wants_zoom := (_zoom_toggled or Input.is_action_pressed("zoom")) and not _dead and not _third_person
    if _third_person or _dead:
        _zoom_toggled = false
    _zoom_blend = move_toward(_zoom_blend, 1.0 if wants_zoom else 0.0, 6.0 * delta)
    if _viewmodel != null and not _third_person:
        _viewmodel.visible = is_multiplayer_authority() and _zoom_blend < 0.6
    if _scope_overlay != null:
        _scope_overlay.set("amount", _zoom_blend)

func _create_scope_overlay() -> void:
    if not is_multiplayer_authority():
        return
    _scope_layer = CanvasLayer.new()
    _scope_layer.name = "ScopeLayer"
    _scope_layer.layer = 5
    add_child(_scope_layer)
    _scope_overlay = Control.new()
    _scope_overlay.name = "ScopeOverlay"
    _scope_overlay.set_script(SCOPE_SCRIPT)
    _scope_layer.add_child(_scope_overlay)

func is_third_person() -> bool:
    return _third_person

func get_third_person_muzzle() -> Vector3:
    if _tp_muzzle != null and _tp_muzzle.is_inside_tree():
        return _tp_muzzle.global_position
    return global_position + Vector3(0.0, 1.4, 0.0)

func toggle_camera_view() -> void:
    if _dead:
        return
    _third_person = not _third_person
    if _viewmodel != null:
        _viewmodel.visible = not _third_person
    if _body_visual != null:
        _body_visual.visible = _third_person

func _update_third_person(delta: float) -> void:
    _tp_blend = move_toward(_tp_blend, 1.0 if _third_person else 0.0, delta * 5.0)
    var desired_local := Vector3(0.55, 0.2, 3.1) * smoothstep(0.0, 1.0, _tp_blend)
    var from_point := _camera_pivot.global_position
    var to_point := _camera_pivot.global_transform * desired_local
    if _tp_blend > 0.01:
        var query := PhysicsRayQueryParameters3D.create(from_point, to_point, 1)
        query.exclude = [get_rid()]
        var hit := get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            var hit_point: Vector3 = hit["position"]
            var clear_distance := maxf(from_point.distance_to(hit_point) - 0.25, 0.25)
            desired_local = desired_local.normalized() * minf(clear_distance, desired_local.length())
    _camera.position = _camera.position.lerp(desired_local, 1.0 - exp(-18.0 * delta))
    if _body_visual != null and _body_visual.visible:
        var horizontal := Vector2(velocity.x, velocity.z).length()
        var swing := sin(_walk_phase) * clampf(horizontal / 6.0, 0.0, 1.0) * 0.7 if is_on_floor() else 0.0
        _leg_left.rotation.x = swing
        _leg_right.rotation.x = -swing
        _arm_left.rotation.x = -1.25 + swing * 0.1
        _body_visual.scale.y = lerpf(1.0, 0.76, _crouch_blend * (1.0 - _prone_blend))
        _body_visual.rotation.x = -PI * 0.5 * _prone_blend

func _build_body_visual() -> void:
    _body_visual = Node3D.new()
    _body_visual.name = "BodyVisual"
    _body_visual.visible = false
    add_child(_body_visual)
    var suit := StandardMaterial3D.new()
    suit.albedo_color = Color("#3a4a44")
    suit.roughness = 0.8
    var vest := StandardMaterial3D.new()
    vest.albedo_color = Color("#d9822b")
    vest.roughness = 0.6
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color("#161a1d")
    dark.roughness = 0.5
    dark.metallic = 0.6
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color("#b98a68")
    skin.roughness = 0.9
    _body_part(CapsuleMesh.new(), Vector3(0.0, 1.18, 0.0), Vector3(0.26, 0.34, 0.16), suit)
    _body_part(BoxMesh.new(), Vector3(0.0, 1.2, 0.02), Vector3(0.5, 0.52, 0.28), vest)
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.12
    head_mesh.height = 0.24
    _body_part(head_mesh, Vector3(0.0, 1.63, 0.0), Vector3.ONE, skin)
    var helmet_mesh := SphereMesh.new()
    helmet_mesh.radius = 0.14
    helmet_mesh.height = 0.2
    _body_part(helmet_mesh, Vector3(0.0, 1.69, 0.0), Vector3.ONE, dark)
    _leg_left = _make_limb_pivot(Vector3(-0.13, 0.86, 0.0), 0.78, 0.085, suit)
    _leg_right = _make_limb_pivot(Vector3(0.13, 0.86, 0.0), 0.78, 0.085, suit)
    _arm_right = _make_limb_pivot(Vector3(0.33, 1.42, 0.0), 0.62, 0.065, suit)
    _arm_right.rotation.x = -1.3
    _arm_left = _make_limb_pivot(Vector3(-0.33, 1.42, 0.0), 0.62, 0.065, suit)
    _arm_left.rotation.x = -1.25
    var rifle := Node3D.new()
    rifle.position = Vector3(0.12, 1.28, -0.38)
    _body_visual.add_child(rifle)
    var rifle_body := MeshInstance3D.new()
    var rifle_mesh := BoxMesh.new()
    rifle_mesh.size = Vector3(0.07, 0.1, 0.8)
    rifle_body.mesh = rifle_mesh
    rifle_body.material_override = dark
    rifle.add_child(rifle_body)
    _tp_muzzle = Marker3D.new()
    _tp_muzzle.name = "ThirdPersonMuzzle"
    _tp_muzzle.position = Vector3(0.0, 0.0, -0.45)
    rifle.add_child(_tp_muzzle)

func _body_part(mesh: Mesh, local_position: Vector3, mesh_scale: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.position = local_position
    instance.scale = mesh_scale
    instance.material_override = material
    _body_visual.add_child(instance)

func _make_limb_pivot(pivot_position: Vector3, length: float, radius: float, material: Material) -> Node3D:
    var pivot := Node3D.new()
    pivot.position = pivot_position
    _body_visual.add_child(pivot)
    var limb := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = length
    limb.mesh = mesh
    limb.position = Vector3(0.0, -length * 0.5, 0.0)
    limb.material_override = material
    pivot.add_child(limb)
    return pivot

func is_dead() -> bool:
    return _dead

func is_crouch_active() -> bool:
    return _crouch_blend > 0.5 or _slide_left > 0.0

func is_sliding() -> bool:
    return _slide_left > 0.0

func add_look_delta(delta: Vector2) -> void:
    if _dead:
        return
    var sensitivity := float(SettingsManager.get_setting("look_sensitivity", 1.0))
    var invert_y := bool(SettingsManager.get_setting("invert_y", false))
    var scaled := delta * mouse_sensitivity * sensitivity * 0.01
    scaled *= lerpf(1.0, 0.38, _zoom_blend)
    rotate_y(-scaled.x)
    var vertical_sign := 1.0 if invert_y else -1.0
    _pitch = clampf(_pitch + scaled.y * vertical_sign, -1.48, 1.48)
    _apply_camera_pitch()
    _look_sway += delta.limit_length(90.0) * 0.0018
    _look_sway = _look_sway.limit_length(0.12)

func _physics_process(delta: float) -> void:
    if _dead:
        velocity.x = 0.0
        velocity.z = 0.0
        velocity.y = maxf(velocity.y - _gravity * delta, -terminal_fall_speed)
        move_and_slide()
        return
    _slide_cooldown_left = maxf(0.0, _slide_cooldown_left - delta)
    _sprint_block_left = maxf(0.0, _sprint_block_left - delta)
    if Input.is_action_just_pressed("crouch"):
        _handle_crouch_press()
    if InputMap.has_action("prone") and Input.is_action_just_pressed("prone"):
        _toggle_prone()
    _refresh_surface_profile(delta)
    _blend_surface_response(delta)
    _update_crouch(delta)

    var was_on_floor := is_on_floor()
    var vertical_speed_before_move := velocity.y

    if was_on_floor:
        _coyote_left = coyote_time
    else:
        _coyote_left = maxf(0.0, _coyote_left - delta)

    if Input.is_action_just_pressed("jump"):
        _jump_buffer_left = jump_buffer_time
    else:
        _jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

    if _jump_buffer_left > 0.0 and _prone_toggled:
        # Jump while lying down only gets the player up; it never launches them from the ground.
        _stand_up_from_prone()
        _jump_buffer_left = 0.0
    if _jump_buffer_left > 0.0 and _coyote_left > 0.0 and (_slide_left > 0.0 or _crouch_toggled):
        # Jumping out of a slide / toggled crouch is allowed when there is headroom.
        if _has_standing_clearance():
            _slide_left = 0.0
            _crouch_toggled = false
    if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
        velocity.y = jump_velocity * _surface_jump_multiplier
        _jump_hold_left = jump_hold_duration
        _jump_buffer_left = 0.0
        _coyote_left = 0.0
        was_on_floor = false
        if _viewmodel != null and _viewmodel.has_method("play_jump"):
            _viewmodel.call("play_jump")
    elif not was_on_floor:
        var gravity_multiplier := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
        if velocity.y > 0.0 and Input.is_action_pressed("jump") and _jump_hold_left > 0.0:
            gravity_multiplier = jump_hold_gravity_multiplier
            _jump_hold_left = maxf(0.0, _jump_hold_left - delta)
        elif Input.is_action_just_released("jump") and velocity.y > 0.0:
            velocity.y *= jump_release_cut_multiplier
            _jump_hold_left = 0.0
        velocity.y = maxf(velocity.y - _gravity * gravity_multiplier * delta, -terminal_fall_speed)
    else:
        velocity.y = minf(velocity.y, 0.0)
        _jump_hold_left = 0.0

    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
    var world_direction := global_transform.basis * local_direction
    world_direction.y = 0.0
    if world_direction.length_squared() > 1.0:
        world_direction = world_direction.normalized()

    # Project the wish direction onto the current walkable plane. The vertical
    # component is retained for slope geometry, while the CharacterBody owns
    # vertical velocity and gravity separately.
    if was_on_floor:
        var floor_tangent := world_direction.slide(get_floor_normal())
        if floor_tangent.length_squared() > 0.0001:
            world_direction = floor_tangent.normalized()

    var stamina_available := not use_sprint_stamina or (not _sprint_locked and _stamina > 0.5)
    # Running has been removed from the game: the sprint input is ignored.
    var sprint_pressed := false
    if sprint_pressed and (_crouch_toggled or _prone_toggled) and _slide_left <= 0.0:
        # Running from a crouch or from the ground stands the player up first.
        _stand_up_from_prone()
        if _crouch_toggled and _has_standing_clearance():
            _crouch_toggled = false
    var wants_sprint := stamina_available and _crouch_blend < 0.35 and sprint_pressed
    var blend_rate := sprint_transition_speed if wants_sprint else maxf(sprint_transition_speed, sprint_exit_speed if _sprint_block_left > 0.0 else sprint_transition_speed * 1.6)
    _sprint_blend = move_toward(_sprint_blend, 1.0 if wants_sprint else 0.0, blend_rate * delta)
    _update_sprint_stamina(wants_sprint, delta)

    var target_speed := lerpf(walk_speed, sprint_speed, _sprint_blend)
    target_speed *= lerpf(lerpf(1.0, crouch_speed_multiplier, _crouch_blend), prone_speed_multiplier, _prone_blend)
    target_speed *= _surface_speed_multiplier
    if input_vector.y > 0.20:
        target_speed *= backward_speed_multiplier
    elif absf(input_vector.x) > 0.20 and absf(input_vector.y) < 0.32:
        target_speed *= strafe_speed_multiplier
    elif input_vector.length_squared() > 0.01 and absf(input_vector.x) > 0.2:
        target_speed *= lerpf(1.0, strafe_speed_multiplier, 0.45)

    var target_horizontal := Vector3(world_direction.x, 0.0, world_direction.z) * target_speed
    var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
    var has_move_input := input_vector.length_squared() > 0.0001

    if has_move_input:
        var acceleration := ground_acceleration * _surface_traction_multiplier if was_on_floor else air_acceleration * air_control_multiplier
        if horizontal_velocity.dot(target_horizontal) < -0.05:
            acceleration *= counter_steer_multiplier
        horizontal_velocity = horizontal_velocity.move_toward(target_horizontal, acceleration * delta)
    elif was_on_floor:
        var braking := ground_deceleration * _surface_traction_multiplier
        horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, braking * delta)
    else:
        horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, air_drag * delta)

    if _slide_left > 0.0:
        # Sliding: momentum along the slide direction, friction bleeds speed, light steering allowed.
        _slide_left = maxf(0.0, _slide_left - delta)
        _slide_speed = maxf(0.0, _slide_speed - slide_friction * delta * (1.0 + (1.0 - _slide_left / slide_duration) * 0.8))
        if has_move_input and world_direction.length_squared() > 0.01:
            _slide_direction = _slide_direction.lerp(world_direction.normalized(), minf(1.0, 1.6 * delta)).normalized()
        horizontal_velocity = _slide_direction * _slide_speed
        if _slide_speed < slide_min_speed * 0.55 or not was_on_floor and _slide_left < slide_duration * 0.5:
            _slide_left = 0.0
        if _slide_left <= 0.0:
            _slide_cooldown_left = slide_cooldown
    var previous_horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z
    _horizontal_acceleration = (horizontal_velocity - previous_horizontal_velocity) / maxf(delta, 0.0001)
    _last_horizontal_velocity = horizontal_velocity

    var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
    if was_on_floor and horizontal_motion.length_squared() > 0.000001:
        _try_step_up(horizontal_motion)
    move_and_slide()

    if is_on_ceiling() and velocity.y > 0.0:
        velocity.y = 0.0
        _jump_hold_left = 0.0

    if not was_on_floor and is_on_floor() and vertical_speed_before_move < -1.1:
        var impact_strength := clampf(absf(vertical_speed_before_move) / 15.0, 0.12, 1.0)
        _landing_kick = 0.025 + impact_strength * 0.115
        _landing_spring_velocity -= 0.42 + impact_strength * 0.72
        if enable_landing_dust and _dust_particles != null:
            _dust_particles.restart()
            _dust_particles.emitting = true
        if _viewmodel != null and _viewmodel.has_method("play_landing"):
            _viewmodel.call("play_landing", impact_strength)
        if _landing_player != null and impact_strength > 0.16:
            _landing_player.pitch_scale = lerpf(1.08, 0.84, impact_strength)
            _landing_player.volume_db = lerpf(-20.0, -11.0, impact_strength)
            _landing_player.play()

    _update_movement_state(input_vector)
    _update_footsteps(delta)
    _handle_equipment_input()

    _interaction_refresh -= delta
    if _interaction_refresh <= 0.0:
        _interaction_refresh = 0.07
        _refresh_interactable()
    if Input.is_action_just_pressed("interact"):
        _try_interact()

func _update_sprint_stamina(wants_sprint: bool, delta: float) -> void:
    if not use_sprint_stamina:
        _stamina = stamina_max
        _sprint_locked = false
        return

    if wants_sprint and _sprint_blend > 0.08:
        _stamina = maxf(0.0, _stamina - stamina_drain_per_second * delta)
        _stamina_regen_left = stamina_regen_delay
        if _stamina <= 0.001:
            _sprint_locked = true
    else:
        _stamina_regen_left = maxf(0.0, _stamina_regen_left - delta)
        if _stamina_regen_left <= 0.0:
            _stamina = minf(stamina_max, _stamina + stamina_regen_per_second * delta)
        if _sprint_locked and _stamina >= stamina_max * sprint_rearm_fraction:
            _sprint_locked = false

    _stamina_signal_left -= delta
    if _stamina_signal_left <= 0.0:
        _stamina_signal_left = 0.10
        stamina_changed.emit(_stamina, stamina_max)

func _refresh_surface_profile(delta: float) -> void:
    _surface_refresh_left -= delta
    if _surface_refresh_left > 0.0 or _surface_probes.is_empty() or not is_on_floor():
        return
    _surface_refresh_left = 0.08

    var surface_votes: Dictionary = {}
    var representative_nodes: Dictionary = {}
    var center_type: StringName = _current_surface_type
    for probe_index in range(_surface_probes.size()):
        var probe := _surface_probes[probe_index]
        probe.force_raycast_update()
        var collider := probe.get_collider() as Node
        if collider == null:
            continue
        var sampled_type := StringName(str(collider.get_meta("surface_type", "concrete")))
        var weight := 2 if probe_index == 0 else 1
        surface_votes[sampled_type] = int(surface_votes.get(sampled_type, 0)) + weight
        representative_nodes[sampled_type] = collider
        if probe_index == 0:
            center_type = sampled_type

    if surface_votes.is_empty():
        return

    var chosen_type: StringName = center_type
    var highest_score := -1
    for sampled_type in surface_votes:
        var score := int(surface_votes[sampled_type])
        if score > highest_score or (score == highest_score and sampled_type == _current_surface_type):
            highest_score = score
            chosen_type = sampled_type

    # Require two consecutive samples before changing the active surface. This
    # prevents alternating material multipliers when the foot straddles a seam.
    if chosen_type == _current_surface_type:
        _surface_candidate_type = &""
        _surface_candidate_votes = 0
    elif chosen_type == _surface_candidate_type:
        _surface_candidate_votes += 1
    else:
        _surface_candidate_type = chosen_type
        _surface_candidate_votes = 1

    if chosen_type != _current_surface_type and _surface_candidate_votes < 2:
        return

    _current_surface_type = chosen_type
    _surface_candidate_type = &""
    _surface_candidate_votes = 0
    var profile: Dictionary = SURFACE_PROFILES.get(chosen_type, SURFACE_PROFILES[&"concrete"]).duplicate(true)
    var chosen_node := representative_nodes.get(chosen_type) as Node
    if chosen_node != null:
        profile["speed"] = float(chosen_node.get_meta("move_speed_multiplier", profile["speed"]))
        profile["traction"] = float(chosen_node.get_meta("traction_multiplier", profile["traction"]))
        profile["jump"] = float(chosen_node.get_meta("jump_multiplier", profile["jump"]))
        profile["stride"] = float(chosen_node.get_meta("stride_multiplier", profile["stride"]))
        profile["volume"] = float(chosen_node.get_meta("footstep_volume_db", profile["volume"]))

    _surface_target_speed_multiplier = clampf(float(profile.get("speed", 1.0)), 0.55, 1.25)
    _surface_target_traction_multiplier = clampf(float(profile.get("traction", 1.0)), 0.45, 1.25)
    _surface_target_jump_multiplier = clampf(float(profile.get("jump", 1.0)), 0.75, 1.20)
    _surface_target_stride_multiplier = clampf(float(profile.get("stride", 1.0)), 0.75, 1.25)
    _surface_target_footstep_volume_db = clampf(float(profile.get("volume", 0.0)), -6.0, 4.0)


func _blend_surface_response(delta: float) -> void:
    # Physical response changes are eased over several physics ticks instead of
    # snapping when the center of the player crosses a material boundary.
    _surface_speed_multiplier = move_toward(_surface_speed_multiplier, _surface_target_speed_multiplier, 3.8 * delta)
    _surface_traction_multiplier = move_toward(_surface_traction_multiplier, _surface_target_traction_multiplier, 5.5 * delta)
    _surface_jump_multiplier = move_toward(_surface_jump_multiplier, _surface_target_jump_multiplier, 7.0 * delta)
    _surface_stride_multiplier = move_toward(_surface_stride_multiplier, _surface_target_stride_multiplier, 4.5 * delta)
    _surface_footstep_volume_db = move_toward(_surface_footstep_volume_db, _surface_target_footstep_volume_db, 14.0 * delta)

func _get_current_stride_length() -> float:
    var sprint_factor := lerpf(1.0, 0.84, _sprint_blend)
    var crouch_factor := lerpf(1.0, 0.94, _crouch_blend)
    return maxf(0.30, footstep_distance * sprint_factor * crouch_factor * _surface_stride_multiplier)


func _process(delta: float) -> void:
    if absf(_recoil_pitch) > 0.00005:
        _recoil_pitch = lerpf(_recoil_pitch, 0.0, 1.0 - exp(-7.0 * delta))
        _apply_camera_pitch()
    if Input.is_action_just_pressed("toggle_camera"):
        toggle_camera_view()
    _update_third_person(delta)
    _update_zoom(delta)
    if _dead:
        _death_roll = lerpf(_death_roll, 0.9, 1.0 - exp(-3.5 * delta))
        _camera_pivot.position.y = lerpf(_camera_pivot.position.y, 0.35, 1.0 - exp(-4.0 * delta))
        _camera.rotation.z = _death_roll
        return
    var horizontal_speed := Vector2(velocity.x, velocity.z).length()
    var speed_ratio := clampf(horizontal_speed / maxf(sprint_speed * _surface_speed_multiplier, 0.1), 0.0, 1.0)
    var grounded := is_on_floor()
    var movement_ratio := clampf(horizontal_speed / maxf(walk_speed * _surface_speed_multiplier, 0.1), 0.0, 1.0)
    var bob_strength := movement_ratio if grounded else 0.0
    bob_strength *= lerpf(lerpf(1.0, 0.72, _crouch_blend), 0.35, _prone_blend)
    var stride := _get_current_stride_length()
    _walk_phase = fposmod(_gait_distance * PI / stride, TAU)

    # Gait is distance-driven and therefore remains synchronized with footstep
    # events at variable frame rates and during acceleration/deceleration.
    var bob_y := absf(sin(_walk_phase)) * lerpf(walk_bob_amount, sprint_bob_amount, _sprint_blend) * bob_strength
    var bob_x := sin(_walk_phase) * 0.010 * bob_strength
    _landing_kick = move_toward(_landing_kick, 0.0, delta * 2.4)
    var landing_spring := _critical_spring(_landing_spring_offset, 0.0, _landing_spring_velocity, 0.17, delta)
    _landing_spring_offset = clampf(landing_spring.x, -0.09, 0.045)
    _landing_spring_velocity = landing_spring.y

    var crouch_eye_height := lerpf(lerpf(_camera_base_height, 1.08, _crouch_blend), prone_eye_height, _prone_blend)
    var target_height := crouch_eye_height - (_sprint_blend * 0.055) - bob_y - _landing_kick + _landing_spring_offset
    _camera_pivot.position.y = lerpf(_camera_pivot.position.y, target_height, 1.0 - exp(-14.0 * delta))
    _camera_pivot.position.x = lerpf(_camera_pivot.position.x, bob_x, 1.0 - exp(-12.0 * delta))

    var inverse_basis := global_transform.basis.inverse()
    var local_velocity := inverse_basis * Vector3(velocity.x, 0.0, velocity.z)
    var local_acceleration := inverse_basis * _horizontal_acceleration
    var target_roll := clampf(-local_velocity.x * 0.014, -0.09, 0.09)
    target_roll += clampf(local_acceleration.x * -0.00055, -0.025, 0.025)
    var target_pitch := clampf(local_acceleration.z * 0.00042, -0.025, 0.025)
    target_pitch += clampf(-velocity.y * 0.0012, -0.018, 0.025) if not grounded else 0.0
    _slide_tilt = lerpf(_slide_tilt, 0.07 if _slide_left > 0.0 else 0.0, 1.0 - exp(-9.0 * delta))
    _camera.rotation.z = lerpf(_camera.rotation.z, target_roll + _slide_tilt, 1.0 - exp(-7.0 * delta))
    _camera.rotation.x = lerpf(_camera.rotation.x, target_pitch, 1.0 - exp(-8.0 * delta))

    var target_fov := camera_fov + (4.0 if _slide_left > 0.0 else 0.0) + _sprint_blend * 6.0 + clampf(speed_ratio - 0.5, 0.0, 0.5) * 1.8 + (0.5 if not grounded else 0.0)
    target_fov = lerpf(target_fov, camera_fov / zoom_factor, _zoom_blend)
    _camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-5.5 * delta))
    _look_sway = _look_sway.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))

    if _viewmodel != null and _viewmodel.has_method("update_motion"):
        _viewmodel.call("update_motion", delta, speed_ratio, _sprint_blend, grounded, _look_sway, _crouch_blend, velocity.y, local_acceleration, _walk_phase)


func _critical_spring(current_value: float, target_value: float, current_velocity: float, smooth_time: float, delta: float) -> Vector2:
    var safe_time := maxf(smooth_time, 0.01)
    var omega := 2.0 / safe_time
    var offset := current_value - target_value
    var decay := exp(-omega * delta)
    var temporary := (current_velocity + omega * offset) * delta
    var next_value := target_value + (offset + temporary) * decay
    var next_velocity := (current_velocity - omega * temporary) * decay
    return Vector2(next_value, next_velocity)

func request_crouch_tap() -> void:
    # Touch button: while running it starts a slide; otherwise each tap cycles
    # stand -> crouch -> lie down -> stand.
    if _dead:
        return
    _handle_crouch_press(true)

func _handle_crouch_press(from_touch: bool = false) -> void:
    if _try_start_slide():
        return
    if from_touch:
        _cycle_stance()

func _cycle_stance() -> void:
    if _prone_toggled:
        _stand_up_from_prone()
    elif _crouch_toggled:
        _crouch_toggled = false
        _prone_toggled = true
    else:
        _crouch_toggled = true

func _toggle_prone() -> void:
    if _prone_toggled:
        _stand_up_from_prone()
    else:
        _prone_toggled = true
        _crouch_toggled = false

func _stand_up_from_prone() -> void:
    ## Leaves the prone stance if there is room: to standing, or to crouch when the ceiling is low.
    if not _prone_toggled:
        return
    if _has_clearance_for(_standing_capsule_height):
        _prone_toggled = false
    elif _has_clearance_for(crouch_capsule_height):
        _prone_toggled = false
        _crouch_toggled = true

func suppress_sprint(duration: float) -> void:
    ## Called by the weapon while the fire button is held: the rifle comes up from the sprint pose.
    _sprint_block_left = maxf(_sprint_block_left, duration)

func is_ready_to_fire() -> bool:
    return _sprint_blend < 0.25

func is_prone() -> bool:
    return _prone_blend > 0.5

func _try_start_slide() -> bool:
    if _slide_left > 0.0 or _slide_cooldown_left > 0.0 or not is_on_floor():
        return false
    var horizontal := Vector3(velocity.x, 0.0, velocity.z)
    var speed := horizontal.length()
    var running := _sprint_blend > 0.55 or speed > walk_speed * 1.25
    if not running or speed < slide_min_speed:
        return false
    _slide_direction = horizontal.normalized()
    _slide_speed = maxf(speed * 1.08, slide_boost_speed * clampf(speed / sprint_speed, 0.7, 1.0))
    _slide_left = slide_duration
    _crouch_toggled = false
    _prone_toggled = false
    _sprint_blend = 0.0
    slide_started.emit()
    return true

func _update_crouch(delta: float) -> void:
    if _capsule_shape == null:
        return
    var wants_prone := _prone_toggled
    var wants_crouch := Input.is_action_pressed("crouch") or _crouch_toggled or wants_prone or _slide_left > 0.0
    if not wants_crouch and _crouch_blend > 0.001 and not _has_clearance_for(_standing_capsule_height):
        wants_crouch = true
    if not wants_prone and _prone_blend > 0.001 and not _has_clearance_for(maxf(crouch_capsule_height, _current_capsule_height)):
        wants_prone = true
    var blend_speed := crouch_transition_speed * (2.2 if _slide_left > 0.0 else 1.0)
    _crouch_blend = move_toward(_crouch_blend, 1.0 if wants_crouch else 0.0, blend_speed * delta)
    _prone_blend = move_toward(_prone_blend, 1.0 if wants_prone else 0.0, prone_transition_speed * delta)
    var stance_height := lerpf(_standing_capsule_height, crouch_capsule_height, _crouch_blend)
    _current_capsule_height = lerpf(stance_height, prone_capsule_height, _prone_blend)
    _capsule_shape.height = _current_capsule_height
    _collision_shape.position.y = _current_capsule_height * 0.5

func _has_standing_clearance() -> bool:
    return _has_clearance_for(_standing_capsule_height)

func _has_clearance_for(target_height: float) -> bool:
    ## True when a capsule of target_height fits at the player's feet without touching anything.
    if _standing_capsule_shape == null or get_world_3d() == null:
        return true
    if _standing_clearance_query == null:
        return true
    _standing_capsule_shape.height = maxf(target_height, _standing_capsule_shape.radius * 2.0)
    _standing_clearance_query.transform = _collision_shape.global_transform
    _standing_clearance_query.transform.origin.y += (_standing_capsule_shape.height - _current_capsule_height) * 0.5 + 0.025
    _standing_clearance_query.collision_mask = collision_mask
    var overlaps := get_world_3d().direct_space_state.intersect_shape(_standing_clearance_query, 8)
    return overlaps.is_empty()

func _try_step_up(horizontal_motion: Vector3) -> bool:
    if max_step_height <= 0.0 or horizontal_motion.length_squared() < 0.000001:
        return false

    if _step_wall_collision == null or _step_down_collision == null:
        return false
    if not test_move(global_transform, horizontal_motion, _step_wall_collision, safe_margin, false, 1):
        return false
    if _step_wall_collision.get_normal().dot(Vector3.UP) > 0.55:
        return false

    var raised_transform := global_transform.translated(Vector3.UP * max_step_height)
    if test_move(global_transform, Vector3.UP * (max_step_height + 0.025), null, safe_margin, false, 1):
        return false
    if test_move(raised_transform, horizontal_motion, null, safe_margin, false, 1):
        return false

    var projected_end := raised_transform.translated(horizontal_motion)
    var down_distance := max_step_height + floor_snap_length + 0.06
    if not test_move(projected_end, Vector3.DOWN * down_distance, _step_down_collision, safe_margin, false, 1):
        return false
    if _step_down_collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
        return false

    # Only lift the body here. move_and_slide() below performs the horizontal
    # displacement exactly once, then floor snapping settles the capsule.
    global_transform = raised_transform
    velocity.y = minf(velocity.y, 0.0)
    return true


func _update_movement_state(input_vector: Vector2) -> void:
    var next_state: StringName
    if not is_on_floor():
        next_state = &"jumping" if velocity.y > 0.1 else &"falling"
    elif _prone_blend > 0.65:
        next_state = &"prone"
    elif _crouch_blend > 0.65:
        next_state = &"crouching"
    elif input_vector.length_squared() < 0.01:
        next_state = &"idle"
    elif _sprint_blend > 0.45:
        next_state = &"running"
    else:
        next_state = &"walking"
    if next_state != _movement_state:
        _movement_state = next_state
        movement_state_changed.emit(_movement_state)

func _update_footsteps(delta: float) -> void:
    var horizontal_speed := Vector2(velocity.x, velocity.z).length()
    if not is_on_floor() or horizontal_speed < 0.65 or _slide_left > 0.0:
        return

    var travelled := horizontal_speed * delta
    _gait_distance += travelled
    _step_distance += travelled
    var stride := _get_current_stride_length()
    var safety_count := 0
    while _step_distance >= stride and safety_count < 3:
        _step_distance -= stride
        safety_count += 1
        var intensity := clampf(horizontal_speed / maxf(sprint_speed, 0.1), 0.22, 1.0)
        footstep_played.emit(intensity)
        if enable_procedural_footsteps and not _footstep_players.is_empty():
            var foot_index := _footstep_cursor
            var step_player := _footstep_players[foot_index]
            _footstep_cursor = (_footstep_cursor + 1) % _footstep_players.size()
            step_player.position.x = -0.12 if foot_index % 2 == 0 else 0.12
            step_player.stream = _footstep_streams.get(_current_surface_type, _footstep_streams.get(&"concrete"))
            var surface_pitch := 1.0
            var surface_volume := _surface_footstep_volume_db
            match _current_surface_type:
                &"metal":
                    surface_pitch = 1.08
                &"rubber":
                    surface_pitch = 0.90
                &"crate":
                    surface_pitch = 0.96
                &"grate":
                    surface_pitch = 1.12
            step_player.pitch_scale = (randf_range(0.94, 1.06) + _sprint_blend * 0.04) * surface_pitch
            step_player.volume_db = lerpf(-17.0, -9.5, intensity) + surface_volume - _crouch_blend * 3.5 - _prone_blend * 4.0
            step_player.play()


func _handle_equipment_input() -> void:
    # Firing and reloading are handled by WeaponController; this only keeps the inspect animation.
    if Input.is_action_just_pressed("inspect_equipment"):
        if _viewmodel != null and _viewmodel.has_method("play_inspect"):
            _viewmodel.call("play_inspect")
    if Input.is_action_just_pressed("scan"):
        scan_requested.emit()

func _create_feedback_nodes() -> void:
    _footstep_streams[&"concrete"] = _build_footstep_stream(&"concrete")
    _footstep_streams[&"metal"] = _build_footstep_stream(&"metal")
    _footstep_streams[&"rubber"] = _build_footstep_stream(&"rubber")
    _footstep_streams[&"crate"] = _build_footstep_stream(&"crate")
    _footstep_streams[&"grate"] = _build_footstep_stream(&"grate")
    _landing_player = AudioStreamPlayer3D.new()
    _landing_player.name = "LandingImpactAudio"
    _landing_player.stream = _build_footstep_stream(&"landing")
    _landing_player.max_distance = 13.0
    _landing_player.unit_size = 5.0
    add_child(_landing_player)

    for index in range(3):
        var step_player := AudioStreamPlayer3D.new()
        step_player.name = "ProceduralFootsteps_%d" % index
        step_player.max_distance = 11.0
        step_player.unit_size = 5.0
        step_player.volume_db = -14.0
        step_player.stream = _footstep_streams[&"concrete"]
        add_child(step_player)
        _footstep_players.append(step_player)

    _dust_particles = CPUParticles3D.new()
    _dust_particles.name = "LandingDust"
    _dust_particles.amount = 7
    _dust_particles.lifetime = 0.28
    _dust_particles.one_shot = true
    _dust_particles.explosiveness = 0.9
    _dust_particles.emitting = false
    _dust_particles.position = Vector3(0.0, 0.07, 0.0)
    # CPUParticles3D exposes these settings directly (it has no process_material).
    _dust_particles.direction = Vector3(0.0, 1.0, 0.0)
    _dust_particles.spread = 48.0
    _dust_particles.initial_velocity_min = 0.25
    _dust_particles.initial_velocity_max = 0.75
    _dust_particles.gravity = Vector3(0.0, -1.6, 0.0)
    _dust_particles.scale_amount_min = 0.012
    _dust_particles.scale_amount_max = 0.026
    _dust_particles.color = Color(0.56, 0.66, 0.68, 0.30)
    var particle_mesh := SphereMesh.new()
    particle_mesh.radius = 0.018
    particle_mesh.height = 0.036
    _dust_particles.mesh = particle_mesh
    add_child(_dust_particles)

func _build_footstep_stream(surface_type: StringName) -> AudioStreamWAV:
    # Small procedural one-shot sounds; each material gets its own tonal/noise balance.
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    var sample_rate := 22050
    var sample_count := 3308
    var bytes := PackedByteArray()
    bytes.resize(sample_count * 2)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var filtered_noise := 0.0
    var tone_hz := 66.0
    var tone_mix := 0.42
    var noise_mix := 0.11
    var decay := 25.0
    match surface_type:
        &"metal":
            tone_hz = 148.0
            tone_mix = 0.30
            noise_mix = 0.08
            decay = 19.0
        &"rubber":
            tone_hz = 54.0
            tone_mix = 0.48
            noise_mix = 0.045
            decay = 30.0
        &"crate":
            tone_hz = 92.0
            tone_mix = 0.37
            noise_mix = 0.075
            decay = 23.0
        &"grate":
            tone_hz = 182.0
            tone_mix = 0.24
            noise_mix = 0.14
            decay = 15.0
        &"landing":
            tone_hz = 46.0
            tone_mix = 0.58
            noise_mix = 0.16
            decay = 17.0
    for index in range(sample_count):
        var time_seconds := float(index) / float(sample_rate)
        filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.12)
        var fundamental := sin(TAU * tone_hz * time_seconds)
        var secondary := sin(TAU * tone_hz * 2.13 * time_seconds) * 0.16
        var transient := sin(TAU * 48.0 * time_seconds) * exp(-time_seconds * 42.0)
        var envelope := exp(-time_seconds * decay)
        var sample_value := clampf((fundamental * tone_mix + secondary * 0.12 + transient * 0.30 + filtered_noise * noise_mix) * envelope, -1.0, 1.0)
        bytes.encode_s16(index * 2, int(sample_value * 32767.0))
    stream.data = bytes
    return stream

func _refresh_interactable() -> void:
    _interaction_ray.force_raycast_update()
    var found: Node = null
    if _interaction_ray.is_colliding():
        var candidate := _interaction_ray.get_collider() as Node
        if candidate != null and candidate.has_method("get_interaction_text") and candidate.has_method("interact"):
            if not candidate.has_method("can_interact") or bool(candidate.call("can_interact", self)):
                found = candidate
    if found != _current_interactable:
        _current_interactable = found
        var prompt := ""
        if _current_interactable != null:
            prompt = str(_current_interactable.call("get_interaction_text"))
        interaction_prompt_changed.emit(prompt)

func _try_interact() -> void:
    if _current_interactable == null or not is_instance_valid(_current_interactable):
        return
    if _current_interactable.has_method("interact"):
        _current_interactable.call("interact", self)

func get_movement_snapshot() -> Dictionary:
    return {
        "state": _movement_state,
        "horizontal_speed": Vector2(velocity.x, velocity.z).length(),
        "vertical_speed": velocity.y,
        "sprint_blend": _sprint_blend,
        "grounded": is_on_floor(),
        "surface_type": str(_current_surface_type),
        "crouch_blend": _crouch_blend,
        "crouched": _crouch_blend > 0.65,
        "prone": _prone_blend > 0.65,
        "sliding": _slide_left > 0.0,
        "horizontal_acceleration": _horizontal_acceleration.length(),
        "stamina": _stamina,
        "stamina_max": stamina_max,
        "sprinting_locked": _sprint_locked,
        "surface_speed_multiplier": _surface_speed_multiplier,
        "surface_traction_multiplier": _surface_traction_multiplier,
        "surface_jump_multiplier": _surface_jump_multiplier,
        "surface_stride_multiplier": _surface_stride_multiplier,
        "surface_footstep_volume_db": _surface_footstep_volume_db,
        "surface_transition_pending": _surface_candidate_votes > 0,
    }

func _on_health_changed(current: float, maximum: float) -> void:
    EventBus.player_health_changed.emit("local", current, maximum)

func _on_armor_changed(current: float, maximum: float) -> void:
    EventBus.player_armor_changed.emit("local", current, maximum)

func _on_damaged(amount: float, _source: Node) -> void:
    if amount >= 5.0 and bool(SettingsManager.get_setting("haptics", true)):
        Input.vibrate_handheld(int(clampf(amount * 2.0, 25.0, 90.0)))
    _landing_spring_velocity -= clampf(amount * 0.02, 0.0, 0.5)

func _on_settings_changed(settings: Dictionary) -> void:
    camera_fov = float(settings.get("fov", camera_fov))

func _on_health_depleted() -> void:
    _dead = true
    velocity = Vector3.ZERO
    _slide_left = 0.0
    _crouch_toggled = false
    _prone_toggled = false
    _death_roll = 0.0
    interaction_prompt_changed.emit("")
    SaveManager.increment_stat("deaths")
    EventBus.player_died.emit("local")
    died.emit()

func respawn(at: Transform3D) -> void:
    global_transform = at
    velocity = Vector3.ZERO
    _dead = false
    _pitch = 0.0
    _recoil_pitch = 0.0
    _death_roll = 0.0
    _slide_left = 0.0
    _crouch_toggled = false
    _prone_toggled = false
    _camera_pivot.rotation = Vector3.ZERO
    _camera_pivot.position.y = _camera_base_height
    _camera.rotation = Vector3.ZERO
    health.reset()
    var weapon := get_node_or_null("WeaponController")
    if weapon != null and weapon.has_method("refill"):
        weapon.call("refill")
    EventBus.player_respawned.emit("local")
    respawned.emit()
