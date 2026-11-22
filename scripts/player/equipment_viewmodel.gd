extends Node3D
class_name EquipmentViewmodel

## First-person assault rifle with two animated hands, built from primitives.
## The right hand holds the pistol grip with the index finger on the trigger, the left hand
## cups the handguard. Animations: bob, sway, sprint pose, recoil kick, bolt cycling,
## muzzle flash, shell ejection, full reload (magazine swap) and wall-avoidance.

@export var idle_position := Vector3(0.20, -0.215, -0.50)

var _rig: Node3D
var _camera: Camera3D
var _player_body: CollisionObject3D
var _muzzle: Marker3D
var _bolt: MeshInstance3D
var _magazine: Node3D
var _left_hand: Node3D
var _left_forearm: MeshInstance3D
var _left_wrist_base := Vector3(-0.005, -0.06, -0.20)
var _left_elbow := Vector3(-0.17, -0.30, 0.16)
var _trigger_finger: MeshInstance3D
var _flash_root: Node3D
var _flash_light: OmniLight3D
var _dot_material: StandardMaterial3D
var _shells: Array[CPUParticles3D] = []
var _shell_cursor: int = 0

var _phase: float = 0.0
var _kick := Vector2.ZERO
var _impact_offset: float = 0.0
var _impact_velocity: float = 0.0
var _jump_tuck: float = 0.0
var _acceleration_sway := Vector3.ZERO
var _flash_left: float = 0.0
var _inspect_left: float = 0.0
var _inspect_roll: float = 0.0
var _reload_elapsed: float = -1.0
var _reload_duration: float = 0.0
var _wall_pull: float = 0.0
var _gun_extent: float = -1.0
var _weapon_id: String = ""
var _style: String = "rifle"
var _left_hand_base := Vector3.ZERO
var _swap_dip: float = 0.0

## How close (m) to a wall the rifle is fully raised ("high ready"). Beyond this the barrel would
## poke into the wall, so the pose is also capped here.
const WALL_FULL_PULL_DISTANCE: float = 0.42
const WALL_CLEARANCE: float = 0.07
## Probe offsets (camera-local x, y) so a corner or a pole in front of the barrel is noticed too.
const WALL_PROBES: Array[Vector2] = [
    Vector2(0.0, 0.0), Vector2(0.16, -0.12), Vector2(-0.16, -0.12), Vector2(0.16, 0.07), Vector2(-0.16, 0.07),
    Vector2(0.0, -0.20),
]
var _base_rotation := Vector3(0.012, 0.010, 0.0)
var _bolt_base_z: float = 0.02

func _ready() -> void:
    _camera = get_parent() as Camera3D
    if _camera != null and _camera.get_parent() != null:
        _player_body = _camera.get_parent().get_parent() as CollisionObject3D
    _weapon_id = "rifle"
    _style = "rifle"
    _build_weapon("rifle", "rifle")

# ---------------------------------------------------------------- public API

func get_muzzle_global_position() -> Vector3:
    if _muzzle != null and _muzzle.is_inside_tree():
        return _muzzle.global_position
    return global_position

func play_fire() -> void:
    _kick.y += 78.0
    _flash_left = 0.05
    if _flash_root != null:
        _flash_root.rotation.z = randf() * TAU
        _flash_root.scale = Vector3.ONE * randf_range(0.8, 1.25)
    if _shells.size() > 0:
        var shell := _shells[_shell_cursor]
        _shell_cursor = (_shell_cursor + 1) % _shells.size()
        shell.restart()
        shell.emitting = true

func play_reload(duration: float) -> void:
    _reload_duration = maxf(duration, 0.4)
    _reload_elapsed = 0.0

func cancel_reload() -> void:
    _reload_elapsed = -1.0
    _reload_duration = 0.0

func play_inspect() -> void:
    _inspect_left = 0.9

func play_jump() -> void:
    _jump_tuck = 1.0
    _impact_velocity += 0.16

func play_landing(intensity: float) -> void:
    _jump_tuck = 0.0
    _impact_velocity -= 0.26 + clampf(intensity, 0.0, 1.0) * 0.72

func is_reloading() -> bool:
    return _reload_elapsed >= 0.0

# ---------------------------------------------------------------- animation

func update_motion(delta: float, speed_ratio: float, sprint_blend: float, grounded: bool, look_sway: Vector2, crouch_blend: float = 0.0, vertical_speed: float = 0.0, horizontal_acceleration: Vector3 = Vector3.ZERO, gait_phase: float = -1.0) -> void:
    delta = clampf(delta, 0.0, 0.05)
    var motion_intensity := clampf(speed_ratio, 0.0, 1.0)
    if gait_phase >= 0.0:
        _phase = gait_phase
    else:
        _phase = fposmod(_phase + delta * lerpf(5.6, 11.8, motion_intensity), TAU)
    var bob_factor := motion_intensity if grounded else 0.20
    var bob_y := sin(_phase * 2.0) * lerpf(0.004, 0.010, motion_intensity) * bob_factor
    var bob_x := sin(_phase) * 0.007 * bob_factor

    var impact_state := _critical_spring(_impact_offset, 0.0, _impact_velocity, 0.13, delta)
    _impact_offset = clampf(impact_state.x, -0.10, 0.04)
    _impact_velocity = impact_state.y
    var kick_state := _critical_spring(_kick.x, 0.0, _kick.y, 0.07, delta)
    _kick = Vector2(clampf(kick_state.x, -0.2, 1.7), kick_state.y)
    _jump_tuck = move_toward(_jump_tuck, 0.0, delta * 4.6)
    _swap_dip = move_toward(_swap_dip, 0.0, delta * 3.4)
    _inspect_left = maxf(0.0, _inspect_left - delta)
    var inspect_envelope := sin((1.0 - _inspect_left / 0.9) * PI) if _inspect_left > 0.0 else 0.0
    _inspect_roll = lerpf(_inspect_roll, inspect_envelope, 1.0 - exp(-10.0 * delta))

    var acceleration_target := Vector3(
        clampf(-horizontal_acceleration.x * 0.00018, -0.04, 0.04),
        clampf(horizontal_acceleration.z * 0.00009, -0.025, 0.025), 0.0)
    _acceleration_sway = _acceleration_sway.lerp(acceleration_target, 1.0 - exp(-8.5 * delta))
    var idle_breath := sin(Time.get_ticks_msec() * 0.00155) * 0.0022 if motion_intensity < 0.08 and grounded else 0.0
    var airborne_tuck := clampf(-vertical_speed * 0.003, -0.02, 0.035) if not grounded else 0.0

    # Reload envelopes (0..1 curves) drive the whole pose, magazine and left hand.
    var reload_pose: float = 0.0
    var mag_out: float = 0.0
    var hand_to_mag: float = 0.0
    var bolt_pull: float = 0.0
    if _reload_elapsed >= 0.0:
        _reload_elapsed += delta
        var t := _reload_elapsed / _reload_duration
        if t >= 1.0:
            _reload_elapsed = -1.0
        else:
            reload_pose = smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.84, 1.0, t))
            mag_out = smoothstep(0.30, 0.42, t) - smoothstep(0.56, 0.70, t)
            hand_to_mag = smoothstep(0.12, 0.28, t) - smoothstep(0.72, 0.88, t)
            bolt_pull = sin(PI * smoothstep(0.86, 0.98, t))

    var wall_target := _measure_wall_pull()
    # Snap back fast when a wall appears (the barrel must never enter it), relax slowly afterwards.
    var wall_rate := 28.0 if wall_target > _wall_pull else 7.0
    _wall_pull = lerpf(_wall_pull, wall_target, 1.0 - exp(-wall_rate * delta))

    var sprint_drop := sprint_blend * 0.065
    var target_position := idle_position + Vector3(
        bob_x - look_sway.x * 0.15 + _acceleration_sway.x - sprint_blend * 0.045 - _inspect_roll * 0.05,
        bob_y - sprint_drop - crouch_blend * 0.025 + idle_breath + _impact_offset + _jump_tuck * 0.015 + airborne_tuck + _acceleration_sway.y - reload_pose * 0.055 - _wall_pull * 0.06 + _kick.x * 0.006 - _swap_dip * 0.14,
        sprint_blend * 0.05 + _wall_pull * 0.30 + _kick.x * 0.038 + reload_pose * 0.03 + _inspect_roll * 0.06)

    var target_rotation := _base_rotation + Vector3(
        look_sway.y * 0.85 - _acceleration_sway.y * 0.6 + _kick.x * 0.050 - sprint_blend * 0.38 - reload_pose * 0.30 + _wall_pull * 1.20 + _impact_offset * 0.7 - _jump_tuck * 0.05 - _swap_dip * 0.55,
        -look_sway.x * 0.80 + _acceleration_sway.x + sprint_blend * 0.55 + _inspect_roll * 0.85 + _wall_pull * 0.28,
        -sprint_blend * 0.16 + reload_pose * 0.42 + _inspect_roll * 0.30 + sin(_phase * 0.5) * 0.012 * bob_factor)
    if _rig != null:
        _rig.position = _rig.position.lerp(target_position, 1.0 - exp(-15.0 * delta))
        _rig.rotation = _rig.rotation.lerp(target_rotation, 1.0 - exp(-14.0 * delta))

    # Bolt cycles back with each shot and is pulled during the end of a reload.
    if _bolt != null:
        _bolt.position.z = _bolt_base_z + clampf(_kick.x, 0.0, 1.0) * 0.032 + bolt_pull * 0.05
    if _magazine != null:
        _magazine.position = Vector3(0.0, -mag_out * 0.16, mag_out * 0.02)
    if _left_hand != null:
        var to_mag := Vector3(0.0, -0.045, 0.17)
        var hand_offset := _left_hand_base + to_mag * hand_to_mag + Vector3(0.0, -mag_out * 0.16 * hand_to_mag, 0.0)
        hand_offset += Vector3(0.0, 0.0, bolt_pull * 0.03)
        _left_hand.position = _left_hand.position.lerp(hand_offset, 1.0 - exp(-22.0 * delta))
        if _left_forearm != null:
            _orient_limb(_left_forearm, _left_wrist_base + _left_hand.position, _left_elbow)
    _flash_left = maxf(0.0, _flash_left - delta)
    if _flash_root != null:
        _flash_root.visible = _flash_left > 0.0
    if _flash_light != null:
        _flash_light.light_energy = 3.2 * clampf(_flash_left / 0.05, 0.0, 1.0)
    if _dot_material != null:
        _dot_material.emission_energy_multiplier = 2.6 + sin(Time.get_ticks_msec() * 0.004) * 0.15

func _compute_gun_extent() -> float:
    ## Distance from the camera to the muzzle tip when the rifle is in its idle pose.
    if _muzzle == null or _rig == null or not _muzzle.is_inside_tree():
        return 1.1
    var local_tip: Vector3 = _rig.to_local(_muzzle.global_position)
    return clampf(-(idle_position.z + local_tip.z) + 0.04, 0.6, 1.8)

func _measure_wall_pull() -> float:
    ## 0 = free, 1 = wall right in front of the face. Several probes are cast from the camera; the
    ## nearest obstacle (measured along the view direction) decides how far the rifle is pulled back
    ## and raised so the barrel never goes through the wall.
    if _camera == null or not _camera.is_inside_tree():
        return 0.0
    if _gun_extent < 0.0:
        _gun_extent = _compute_gun_extent()
    var reach := _gun_extent + WALL_CLEARANCE
    var space := _camera.get_world_3d().direct_space_state
    var origin := _camera.global_position
    var cam_basis := _camera.global_transform.basis
    var forward := -cam_basis.z
    var nearest := reach
    for probe in WALL_PROBES:
        var target := origin + forward * reach + cam_basis.x * probe.x + cam_basis.y * probe.y
        var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
        if _player_body != null:
            query.exclude = [_player_body.get_rid()]
        var hit := space.intersect_ray(query)
        if hit.is_empty():
            continue
        var depth: float = (hit["position"] - origin).dot(forward)
        nearest = minf(nearest, maxf(depth, 0.0))
    if nearest >= reach:
        return 0.0
    var raw := clampf((reach - nearest) / maxf(reach - WALL_FULL_PULL_DISTANCE, 0.1), 0.0, 1.0)
    # The curve rises quickly at first so the barrel is already clear well before the wall.
    return pow(raw, 0.7)

func _critical_spring(current_value: float, target_value: float, current_velocity: float, smooth_time: float, delta: float) -> Vector2:
    var safe_time := maxf(smooth_time, 0.01)
    var omega := 2.0 / safe_time
    var offset := current_value - target_value
    var decay := exp(-omega * delta)
    var temporary := (current_velocity + omega * offset) * delta
    var next_value := target_value + (offset + temporary) * decay
    var next_velocity := (current_velocity - omega * temporary) * decay
    return Vector2(next_value, next_velocity)

# ---------------------------------------------------------------- construction

func set_weapon(new_weapon_id: String, style: String, animate: bool = true) -> void:
    ## Swaps the model in the player's hands (called by WeaponController when the gun changes).
    if _rig != null and new_weapon_id == _weapon_id:
        return
    _weapon_id = new_weapon_id
    _style = style
    if _rig != null:
        _rig.queue_free()
        _rig = null
    _build_weapon(new_weapon_id, style)
    _gun_extent = -1.0
    _wall_pull = 0.0
    _reload_elapsed = -1.0
    if animate:
        _swap_dip = 1.0

func get_weapon_style() -> String:
    return _style

func _build_weapon(new_weapon_id: String, style: String) -> void:
    _shells.clear()
    _shell_cursor = 0
    _bolt = null
    _trigger_finger = null
    _dot_material = null
    _left_hand_base = Vector3.ZERO
    _bolt_base_z = 0.02
    _rig = Node3D.new()
    _rig.name = "WeaponRig"
    _rig.position = idle_position
    _rig.rotation = _base_rotation
    add_child(_rig)
    var mats: Dictionary = {
        "metal": _mat(Color("#2b3136"), 0.38, 0.85),
        "dark": _mat(Color("#181c20"), 0.45, 0.8),
        "polymer": _mat(Color("#1d2125"), 0.82, 0.05),
        "accent": _mat(WeaponDefinitions.get_accent(new_weapon_id), 0.45, 0.45),
        "glove": _mat(Color("#14181b"), 0.9, 0.02),
        "sleeve": _mat(Color("#2f3b34"), 0.85, 0.05),
        "pad": _mat(Color("#3b4348"), 0.7, 0.2),
    }
    if style == "pistol" or style == "revolver":
        _build_handgun(style, mats)
    else:
        _build_long_gun(style, mats)
    _build_hands(mats)
    _build_flash_and_shells()

func _long_gun_config(style: String) -> Dictionary:
    # guard_center/len: handguard; barrel_center/len/radius; muzzle_z; hand_z: where the left hand grips.
    match style:
        "smg":
            return {"guard_center": -0.205, "guard_len": 0.14, "barrel_center": -0.34, "barrel_len": 0.10, "barrel_radius": 0.0095,
                "muzzle_z": -0.42, "brake_z": -0.395, "hand_z": -0.20, "optic": "dot", "stock": "short", "mag": "straight"}
        "shotgun":
            return {"guard_center": -0.26, "guard_len": 0.17, "barrel_center": -0.42, "barrel_len": 0.30, "barrel_radius": 0.0145,
                "muzzle_z": -0.575, "brake_z": -0.56, "hand_z": -0.26, "optic": "iron", "stock": "full", "mag": "shells"}
        "lmg":
            return {"guard_center": -0.27, "guard_len": 0.26, "barrel_center": -0.51, "barrel_len": 0.26, "barrel_radius": 0.0135,
                "muzzle_z": -0.68, "brake_z": -0.65, "hand_z": -0.25, "optic": "iron", "stock": "full", "mag": "box"}
        "sniper":
            return {"guard_center": -0.28, "guard_len": 0.30, "barrel_center": -0.60, "barrel_len": 0.34, "barrel_radius": 0.0125,
                "muzzle_z": -0.80, "brake_z": -0.765, "hand_z": -0.27, "optic": "scope", "stock": "full", "mag": "short"}
        _:
            return {"guard_center": -0.255, "guard_len": 0.24, "barrel_center": -0.49, "barrel_len": 0.24, "barrel_radius": 0.0105,
                "muzzle_z": -0.665, "brake_z": -0.625, "hand_z": -0.235, "optic": "dot", "stock": "full", "mag": "curved"}

func _build_long_gun(style: String, mats: Dictionary) -> void:
    var metal: Material = mats["metal"]
    var dark_metal: Material = mats["dark"]
    var polymer: Material = mats["polymer"]
    var accent: Material = mats["accent"]
    var cfg: Dictionary = _long_gun_config(style)
    var guard_c: float = float(cfg["guard_center"])
    var guard_len: float = float(cfg["guard_len"])
    var barrel_c: float = float(cfg["barrel_center"])
    var barrel_len: float = float(cfg["barrel_len"])
    var barrel_r: float = float(cfg["barrel_radius"])
    var optic: String = str(cfg["optic"])
    var stock: String = str(cfg["stock"])
    var mag_kind: String = str(cfg["mag"])
    var guard_front: float = guard_c - guard_len * 0.5
    _left_hand_base = Vector3(0.0, 0.0, float(cfg["hand_z"]) + 0.235)

    # --- receiver, rails, barrel -------------------------------------------------
    _box("UpperReceiver", Vector3(0, 0, 0.0), Vector3(0.054, 0.064, 0.27), metal)
    if optic != "iron":
        _box("TopRail", Vector3(0, 0.039, -0.005), Vector3(0.026, 0.012, 0.27), dark_metal)
        for k in range(9):
            _box("RailSlot_%d" % k, Vector3(0, 0.0455, -0.12 + float(k) * 0.03), Vector3(0.028, 0.003, 0.008), metal)
    _box("LowerReceiver", Vector3(0, -0.052, 0.035), Vector3(0.05, 0.046, 0.2), polymer)
    if style == "shotgun":
        # Pump forend and tube magazine under the barrel.
        _box("PumpForend", Vector3(0, -0.012, guard_c), Vector3(0.062, 0.05, guard_len), polymer)
        for k in range(4):
            _box("PumpGroove_%d" % k, Vector3(0, -0.012, guard_c - 0.055 + float(k) * 0.035), Vector3(0.066, 0.052, 0.006), dark_metal)
        _cyl("MagTube", Vector3(0, -0.034, barrel_c + 0.02), 0.0125, 0.34, metal)
    else:
        _box("HandguardA", Vector3(0, 0, guard_c), Vector3(0.052, 0.054, guard_len), polymer)
        _box("HandguardB", Vector3(0, 0, guard_c), Vector3(0.04, 0.066, guard_len), polymer, Vector3(0, 0, deg_to_rad(45.0)))
        var vent_count: int = clampi(int(guard_len / 0.055), 1, 5)
        for k in range(vent_count):
            _box("HandguardVent_%d" % k, Vector3(0.0265, 0.0, guard_c + guard_len * 0.5 - 0.035 - float(k) * 0.045), Vector3(0.002, 0.02, 0.026), dark_metal)
    _cyl("Barrel", Vector3(0, 0.002, barrel_c), barrel_r, barrel_len, dark_metal)
    _cyl("GasBlock", Vector3(0, 0.004, guard_front - 0.03), barrel_r + 0.006, 0.035, metal)
    if style == "lmg":
        _cyl("BarrelShroud", Vector3(0, 0.0, guard_front - 0.10), 0.021, 0.16, metal)
        for k in range(4):
            _box("ShroudHole_%d" % k, Vector3(0.0, 0.0215, guard_front - 0.05 - float(k) * 0.035), Vector3(0.016, 0.004, 0.014), dark_metal)
        # Folded bipod legs.
        _limb("BipodLegL", Vector3(-0.018, -0.02, guard_front - 0.04), Vector3(-0.045, -0.11, guard_front - 0.13), 0.005, dark_metal)
        _limb("BipodLegR", Vector3(0.018, -0.02, guard_front - 0.04), Vector3(0.045, -0.11, guard_front - 0.13), 0.005, dark_metal)
        _box("CarryHandle", Vector3(0, 0.07, 0.01), Vector3(0.016, 0.03, 0.14), dark_metal)
    _box("FrontSightPost", Vector3(0, 0.042, guard_front - 0.02), Vector3(0.008, 0.05, 0.012), dark_metal)
    _cyl("MuzzleBrake", Vector3(0, 0.002, float(cfg["brake_z"])), barrel_r + 0.006, 0.065, metal)
    for k in range(3):
        _box("MuzzleSlot_%d" % k, Vector3(0, 0.0, float(cfg["brake_z"]) + 0.02 - float(k) * 0.02), Vector3(0.036, 0.006, 0.007), dark_metal)
    _muzzle = Marker3D.new()
    _muzzle.name = "Muzzle"
    _muzzle.position = Vector3(0, 0.002, float(cfg["muzzle_z"]))
    _rig.add_child(_muzzle)

    # --- optic --------------------------------------------------------------------------
    if optic == "dot":
        _box("OpticBase", Vector3(0, 0.054, -0.035), Vector3(0.032, 0.014, 0.075), dark_metal)
        _box("OpticBody", Vector3(0, 0.083, -0.03), Vector3(0.036, 0.04, 0.068), metal)
        _box("OpticHood", Vector3(0, 0.083, -0.075), Vector3(0.04, 0.046, 0.012), dark_metal)
        _dot_material = StandardMaterial3D.new()
        _dot_material.albedo_color = Color(1.0, 0.1, 0.08)
        _dot_material.emission_enabled = true
        _dot_material.emission = Color(1.0, 0.12, 0.1)
        _dot_material.emission_energy_multiplier = 2.6
        _dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        var dot := MeshInstance3D.new()
        var dot_mesh := SphereMesh.new()
        dot_mesh.radius = 0.0028
        dot_mesh.height = 0.0056
        dot.mesh = dot_mesh
        dot.material_override = _dot_material
        dot.position = Vector3(0, 0.083, 0.0)
        _rig.add_child(dot)
        var lens := _mat(Color(0.3, 0.7, 0.9, 0.35), 0.1, 0.0)
        lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _box("OpticLens", Vector3(0, 0.083, 0.004), Vector3(0.03, 0.032, 0.002), lens)
    elif optic == "scope":
        _box("ScopeMountFront", Vector3(0, 0.05, -0.08), Vector3(0.02, 0.03, 0.02), dark_metal)
        _box("ScopeMountRear", Vector3(0, 0.05, 0.04), Vector3(0.02, 0.03, 0.02), dark_metal)
        _cyl("ScopeTube", Vector3(0, 0.083, -0.02), 0.0185, 0.2, metal)
        _cyl("ScopeObjective", Vector3(0, 0.083, -0.135), 0.0275, 0.05, dark_metal)
        _cyl("ScopeEyepiece", Vector3(0, 0.083, 0.095), 0.0245, 0.04, dark_metal)
        _box("ScopeTurret", Vector3(0, 0.113, -0.02), Vector3(0.018, 0.016, 0.022), accent)
        var glass := _mat(Color(0.25, 0.5, 0.9, 0.55), 0.05, 0.0)
        glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _cyl("ScopeGlass", Vector3(0, 0.083, -0.161), 0.0255, 0.004, glass)
    else:
        _box("RearSight", Vector3(0, 0.044, 0.03), Vector3(0.022, 0.026, 0.012), dark_metal)

    # --- stock, grip, trigger ---------------------------------------------------------
    if stock == "full":
        _cyl("BufferTube", Vector3(0, -0.004, 0.215), 0.017, 0.15, dark_metal)
        _box("StockBody", Vector3(0, -0.022, 0.31), Vector3(0.042, 0.088, 0.15), polymer)
        _box("CheekRest", Vector3(0, 0.026, 0.305), Vector3(0.036, 0.016, 0.12), polymer)
        _box("ButtPad", Vector3(0, -0.026, 0.39), Vector3(0.044, 0.1, 0.018), _mat(Color("#0c0e10"), 0.95, 0.0))
    else:
        _cyl("BufferTube", Vector3(0, -0.004, 0.2), 0.015, 0.1, dark_metal)
        _box("StockFrame", Vector3(0, -0.01, 0.285), Vector3(0.02, 0.07, 0.1), metal)
        _box("StockPad", Vector3(0, -0.012, 0.345), Vector3(0.034, 0.085, 0.016), _mat(Color("#0c0e10"), 0.95, 0.0))
    _box("PistolGrip", Vector3(0, -0.118, 0.108), Vector3(0.036, 0.098, 0.044), polymer, Vector3(deg_to_rad(-20.0), 0, 0))
    _box("GripCap", Vector3(0, -0.168, 0.124), Vector3(0.038, 0.01, 0.048), dark_metal, Vector3(deg_to_rad(-20.0), 0, 0))
    _box("TriggerGuard", Vector3(0, -0.092, 0.03), Vector3(0.008, 0.012, 0.08), dark_metal)
    _box("TriggerGuardFront", Vector3(0, -0.076, -0.008), Vector3(0.008, 0.032, 0.01), dark_metal)
    _box("Trigger", Vector3(0, -0.07, 0.05), Vector3(0.007, 0.03, 0.01), accent, Vector3(deg_to_rad(-15.0), 0, 0))
    _box("EjectionPort", Vector3(0.0275, 0.012, -0.005), Vector3(0.002, 0.024, 0.055), dark_metal)
    _box("FireSelector", Vector3(-0.028, -0.04, 0.085), Vector3(0.004, 0.012, 0.028), accent)
    _box("MagWell", Vector3(0, -0.082, -0.02), Vector3(0.042, 0.03, 0.062), polymer)
    _bolt = _box("ChargingBolt", Vector3(0.031, 0.012, _bolt_base_z), Vector3(0.012, 0.016, 0.04), accent)

    # --- magazine (separate node so it can drop during a reload) ------------------------
    _magazine = Node3D.new()
    _magazine.name = "Magazine"
    _rig.add_child(_magazine)
    match mag_kind:
        "straight":
            _mag_box("MagUpper", Vector3(0, -0.14, -0.02), Vector3(0.03, 0.12, 0.044), polymer, Vector3.ZERO)
            _mag_box("MagPlate", Vector3(0, -0.205, -0.02), Vector3(0.034, 0.01, 0.05), accent, Vector3.ZERO)
        "box":
            _mag_box("AmmoBox", Vector3(0, -0.15, -0.015), Vector3(0.07, 0.11, 0.1), dark_metal, Vector3.ZERO)
            _mag_box("AmmoBoxLid", Vector3(0, -0.098, -0.015), Vector3(0.072, 0.012, 0.102), accent, Vector3.ZERO)
            _mag_box("BeltFeed", Vector3(0, -0.085, -0.045), Vector3(0.026, 0.02, 0.05), metal, Vector3.ZERO)
            for k in range(5):
                _mag_box("Round_%d" % k, Vector3(0.0, -0.068, -0.056 + float(k) * 0.011), Vector3(0.008, 0.008, 0.008), _mat(Color("#c8a24a"), 0.3, 0.9), Vector3.ZERO)
        "shells":
            for k in range(3):
                _mag_box("Shell_%d" % k, Vector3(0.0, -0.085, -0.012 + float(k) * 0.02), Vector3(0.026, 0.018, 0.016), accent, Vector3.ZERO)
        "short":
            _mag_box("MagUpper", Vector3(0, -0.115, -0.02), Vector3(0.034, 0.06, 0.05), polymer, Vector3.ZERO)
            _mag_box("MagPlate", Vector3(0, -0.148, -0.02), Vector3(0.037, 0.01, 0.054), accent, Vector3.ZERO)
        _:
            _mag_box("MagUpper", Vector3(0, -0.12, -0.016), Vector3(0.034, 0.075, 0.052), polymer, Vector3(deg_to_rad(6.0), 0, 0))
            _mag_box("MagLower", Vector3(0, -0.182, -0.03), Vector3(0.034, 0.075, 0.052), polymer, Vector3(deg_to_rad(16.0), 0, 0))
            _mag_box("MagPlate", Vector3(0, -0.222, -0.04), Vector3(0.037, 0.01, 0.056), accent, Vector3(deg_to_rad(16.0), 0, 0))
            _mag_box("MagRib", Vector3(0.0175, -0.15, -0.022), Vector3(0.002, 0.12, 0.03), dark_metal, Vector3(deg_to_rad(11.0), 0, 0))

func _build_handgun(style: String, mats: Dictionary) -> void:
    var metal: Material = mats["metal"]
    var dark_metal: Material = mats["dark"]
    var polymer: Material = mats["polymer"]
    var accent: Material = mats["accent"]
    # The support hand wraps the grip from the other side.
    _left_hand_base = Vector3(-0.048, -0.045, 0.335)
    _box("Frame", Vector3(0, -0.032, 0.0), Vector3(0.03, 0.03, 0.19), polymer)
    _box("PistolGrip", Vector3(0, -0.118, 0.108), Vector3(0.036, 0.098, 0.044), polymer, Vector3(deg_to_rad(-20.0), 0, 0))
    _box("GripCap", Vector3(0, -0.168, 0.124), Vector3(0.038, 0.01, 0.048), dark_metal, Vector3(deg_to_rad(-20.0), 0, 0))
    _box("TriggerGuard", Vector3(0, -0.062, 0.02), Vector3(0.008, 0.012, 0.07), dark_metal)
    _box("TriggerGuardFront", Vector3(0, -0.05, -0.014), Vector3(0.008, 0.026, 0.01), dark_metal)
    _box("Trigger", Vector3(0, -0.048, 0.034), Vector3(0.007, 0.026, 0.01), accent, Vector3(deg_to_rad(-15.0), 0, 0))
    if style == "revolver":
        _bolt_base_z = 0.075
        _cyl("Cylinder", Vector3(0, 0.002, -0.015), 0.030, 0.06, metal)
        for k in range(6):
            var angle: float = float(k) * TAU / 6.0
            var chamber := _cyl("Chamber_%d" % k, Vector3(cos(angle) * 0.019, 0.002 + sin(angle) * 0.019, -0.015), 0.0065, 0.062, dark_metal)
            chamber.scale = Vector3(1.0, 1.0, 1.0)
        _box("TopStrap", Vector3(0, 0.034, -0.02), Vector3(0.022, 0.012, 0.16), metal)
        _cyl("Barrel", Vector3(0, 0.02, -0.17), 0.0125, 0.22, dark_metal)
        _box("BarrelRib", Vector3(0, 0.036, -0.17), Vector3(0.012, 0.008, 0.22), metal)
        _box("FrontSightPost", Vector3(0, 0.046, -0.275), Vector3(0.006, 0.018, 0.01), accent)
        _bolt = _box("Hammer", Vector3(0, 0.044, _bolt_base_z), Vector3(0.012, 0.03, 0.016), accent, Vector3(deg_to_rad(-25.0), 0, 0))
        _muzzle = Marker3D.new()
        _muzzle.position = Vector3(0, 0.02, -0.285)
    else:
        _bolt_base_z = -0.035
        _bolt = _box("Slide", Vector3(0, 0.0, _bolt_base_z), Vector3(0.034, 0.04, 0.22), metal)
        for k in range(5):
            _box("Serration_%d" % k, Vector3(0.0175, 0.0, 0.035 + float(k) * 0.012), Vector3(0.002, 0.03, 0.005), dark_metal)
        _box("FrontSight", Vector3(0, 0.026, -0.135), Vector3(0.006, 0.012, 0.01), accent)
        _box("RearSight", Vector3(0, 0.026, 0.06), Vector3(0.02, 0.012, 0.01), dark_metal)
        _cyl("Barrel", Vector3(0, 0.0, -0.152), 0.0075, 0.03, dark_metal)
        _muzzle = Marker3D.new()
        _muzzle.position = Vector3(0, 0.0, -0.172)
    _muzzle.name = "Muzzle"
    _rig.add_child(_muzzle)
    _magazine = Node3D.new()
    _magazine.name = "Magazine"
    _rig.add_child(_magazine)
    _mag_box("MagBase", Vector3(0, -0.176, 0.126), Vector3(0.034, 0.012, 0.046), accent, Vector3(deg_to_rad(-20.0), 0, 0))
    _mag_box("MagBody", Vector3(0, -0.15, 0.116), Vector3(0.03, 0.05, 0.04), dark_metal, Vector3(deg_to_rad(-20.0), 0, 0))

func _build_hands(mats: Dictionary) -> void:
    var glove: Material = mats["glove"]
    var skin_pad: Material = mats["pad"]
    var sleeve: Material = mats["sleeve"]
    var accent: Material = mats["accent"]
    # --- right hand: palm on the grip, fingers around the front, index on the trigger ----
    _box("RightPalm", Vector3(0.027, -0.118, 0.112), Vector3(0.026, 0.078, 0.056), glove)
    _box("RightWebOfHand", Vector3(0.012, -0.073, 0.138), Vector3(0.042, 0.032, 0.05), glove)
    _box("RightKnuckles", Vector3(0.03, -0.083, 0.082), Vector3(0.022, 0.016, 0.026), skin_pad)
    for k in range(3):
        var y := -0.1 - float(k) * 0.02
        _limb("RightFinger_%d" % k, Vector3(0.032, y, 0.09), Vector3(-0.024, y, 0.086), 0.0092, glove)
    _trigger_finger = _limb("RightIndex", Vector3(0.03, -0.074, 0.092), Vector3(0.004, -0.074, 0.05), 0.0092, glove)
    _limb("RightThumb", Vector3(0.006, -0.082, 0.152), Vector3(-0.03, -0.062, 0.088), 0.01, glove)
    _box("RightCuff", Vector3(0.036, -0.108, 0.166), Vector3(0.05, 0.05, 0.03), accent, Vector3(deg_to_rad(-20.0), 0, 0))
    var right_forearm := _limb("RightForearm", Vector3(0.04, -0.112, 0.18), Vector3(0.13, -0.30, 0.47), 0.034, sleeve)
    right_forearm.name = "RightForearm"

    # --- left hand: cups the handguard, fingers curl up the right side -----------------
    _left_hand = Node3D.new()
    _left_hand.name = "LeftHand"
    _left_hand.position = _left_hand_base
    _rig.add_child(_left_hand)
    var left_palm := MeshInstance3D.new()
    var palm_mesh := BoxMesh.new()
    palm_mesh.size = Vector3(0.056, 0.03, 0.075)
    left_palm.mesh = palm_mesh
    left_palm.material_override = glove
    left_palm.position = Vector3(0.0, -0.054, -0.235)
    _left_hand.add_child(left_palm)
    for k in range(4):
        var z := -0.202 - float(k) * 0.0185
        _hand_limb("LeftFingerUnder_%d" % k, Vector3(-0.024, -0.052, z), Vector3(0.036, -0.046, z), 0.0092, glove)
        _hand_limb("LeftFingerUp_%d" % k, Vector3(0.036, -0.046, z), Vector3(0.034, -0.002, z), 0.0092, glove)
    _hand_limb("LeftThumb", Vector3(-0.028, -0.05, -0.195), Vector3(-0.03, 0.012, -0.285), 0.0105, glove)
    _hand_limb("LeftCuff", Vector3(-0.006, -0.062, -0.188), Vector3(-0.03, -0.1, -0.13), 0.032, accent)
    _left_forearm = _limb("LeftForearm", _left_wrist_base + _left_hand_base, _left_elbow, 0.033, sleeve)

func _build_flash_and_shells() -> void:
    var flash_material := StandardMaterial3D.new()
    flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_material.albedo_color = Color(1.0, 0.82, 0.4)
    flash_material.emission_enabled = true
    flash_material.emission = Color(1.0, 0.7, 0.25)
    flash_material.emission_energy_multiplier = 4.0
    _flash_root = Node3D.new()
    _flash_root.name = "MuzzleFlash"
    _flash_root.position = _muzzle.position + Vector3(0, 0, -0.03)
    _flash_root.visible = false
    _rig.add_child(_flash_root)
    for k in range(3):
        var spike := MeshInstance3D.new()
        var spike_mesh := PrismMesh.new()
        spike_mesh.size = Vector3(0.05, 0.22, 0.004)
        spike.mesh = spike_mesh
        spike.material_override = flash_material
        spike.rotation.z = float(k) * PI / 3.0
        spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _flash_root.add_child(spike)
        var spike_back := MeshInstance3D.new()
        spike_back.mesh = spike_mesh
        spike_back.material_override = flash_material
        spike_back.rotation.z = float(k) * PI / 3.0 + PI
        spike_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _flash_root.add_child(spike_back)
    var core := MeshInstance3D.new()
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.035
    core_mesh.height = 0.07
    core_mesh.radial_segments = 8
    core_mesh.rings = 4
    core.mesh = core_mesh
    core.material_override = flash_material
    core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _flash_root.add_child(core)
    _flash_light = OmniLight3D.new()
    _flash_light.name = "MuzzleFlashLight"
    _flash_light.position = _muzzle.position + Vector3(0, 0, -0.1)
    _flash_light.light_color = Color(1.0, 0.72, 0.38)
    _flash_light.omni_range = 7.0
    _flash_light.light_energy = 0.0
    _flash_light.shadow_enabled = false
    _flash_light.add_to_group("no_shadow")
    _rig.add_child(_flash_light)

    # --- ejected shells (world-space particles, small pool) ---------------------------------
    var brass := _mat(Color("#c8a24a"), 0.3, 0.9)
    var shell_length: float = 0.034 if _style == "shotgun" else 0.02
    var shell_radius: float = 0.0065 if _style == "shotgun" else 0.0035
    for k in range(3):
        var shell := CPUParticles3D.new()
        shell.name = "ShellEject_%d" % k
        shell.position = Vector3(0.03, 0.014, 0.0)
        shell.amount = 1
        shell.lifetime = 0.8
        shell.one_shot = true
        shell.emitting = false
        shell.explosiveness = 1.0
        shell.local_coords = false
        shell.direction = Vector3(1.0, 0.7, 0.2)
        shell.spread = 18.0
        shell.initial_velocity_min = 2.2
        shell.initial_velocity_max = 3.4
        shell.gravity = Vector3(0, -9.0, 0)
        shell.angular_velocity_min = 300.0
        shell.angular_velocity_max = 700.0
        var shell_mesh := CylinderMesh.new()
        shell_mesh.top_radius = shell_radius
        shell_mesh.bottom_radius = shell_radius
        shell_mesh.height = shell_length
        shell_mesh.radial_segments = 6
        shell_mesh.rings = 1
        shell.mesh = shell_mesh
        shell.material_override = brass if _style != "shotgun" else _mat(Color("#b83a2a"), 0.5, 0.2)
        _rig.add_child(shell)
        _shells.append(shell)

# ---------------------------------------------------------------- helpers

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func _box(node_name: String, local_position: Vector3, box_size: Vector3, material: Material, local_rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = box_size
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = local_position
    instance.rotation = local_rotation
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _rig.add_child(instance)
    return instance

func _mag_box(node_name: String, local_position: Vector3, box_size: Vector3, material: Material, local_rotation: Vector3) -> void:
    var mesh := BoxMesh.new()
    mesh.size = box_size
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = local_position
    instance.rotation = local_rotation
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _magazine.add_child(instance)

func _cyl(node_name: String, local_position: Vector3, radius: float, length: float, material: Material) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 14
    mesh.rings = 1
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = local_position
    instance.rotation = Vector3(PI * 0.5, 0.0, 0.0)
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _rig.add_child(instance)
    return instance

func _limb(node_name: String, from_point: Vector3, to_point: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var instance := _make_limb(node_name, radius, material)
    _rig.add_child(instance)
    _orient_limb(instance, from_point, to_point)
    return instance

func _hand_limb(node_name: String, from_point: Vector3, to_point: Vector3, radius: float, material: Material) -> void:
    var instance := _make_limb(node_name, radius, material)
    _left_hand.add_child(instance)
    _orient_limb(instance, from_point, to_point)

func _make_limb(node_name: String, radius: float, material: Material) -> MeshInstance3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0 + 0.01
    mesh.radial_segments = 8
    mesh.rings = 3
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    instance.set_meta("limb_radius", radius)
    return instance

func _orient_limb(instance: MeshInstance3D, from_point: Vector3, to_point: Vector3) -> void:
    var span := to_point - from_point
    var length := span.length()
    if length < 0.0005:
        return
    var radius: float = float(instance.get_meta("limb_radius", 0.01))
    var mesh := instance.mesh as CapsuleMesh
    mesh.height = length + radius * 2.0
    var direction := span / length
    var reference := Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
    var x_axis := direction.cross(reference).normalized()
    var z_axis := x_axis.cross(direction).normalized()
    instance.transform = Transform3D(Basis(x_axis, direction, z_axis), (from_point + to_point) * 0.5)
