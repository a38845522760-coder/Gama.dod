extends CharacterBody3D
class_name Bot

## One AI fighter. Armed soldiers pick a range band for their gun (rushers close in, marksmen
## hold back, heavies suppress), strafe, lose and re-find targets, and fight anybody hostile -
## the player or other bots. Zombies hunt relentlessly and attack in melee (spitters from range).
## Everything is driven by a BotDefinitions profile, so adding a new enemy is a data change.

signal died(bot: Bot, killer: Node, headshot: bool)

enum State { IDLE, ROAM, ENGAGE, HUNT, SEARCH, DEAD }

var profile_id: String = "grunt"
var team: String = "enemy"
var team_color: Color = Color(0, 0, 0, 0)
var use_team_look: bool = false
var difficulty: int = 1
var health_scale: float = 1.0
var always_hunt: bool = false
var show_marker: bool = false
var display_name: String = "Bot"
var weapon_override: String = ""
var fx: BulletEffects = null
var mode_ref: Node = null
## Multiplayer guests run bots as passive puppets: the host does all thinking and shooting.
var net_puppet: bool = false
var _puppet_target: Vector3 = Vector3.ZERO
var _puppet_yaw: float = 0.0
var _puppet_has_state: bool = false

var profile: Dictionary = {}
var max_health: float = 100.0
var health: float = 100.0
var state: State = State.IDLE
var is_zombie: bool = false
var points_value: int = 100

var _model: SoldierModel
var _weapon_def: Dictionary = {}
var _body_scale: float = 1.0
const PLAYER_PRIORITY: float = 0.4
var _target: Node3D = null
var _target_visible: bool = false
var _last_known: Vector3 = Vector3.ZERO
var _memory_left: float = 0.0
var _scan_left: float = 0.0
var _reaction_left: float = 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _repath_left: float = 0.0
var _path_goal: Vector3 = Vector3(1.0e9, 0.0, 1.0e9)
var _strafe_dir: float = 1.0
var _strafe_flip_left: float = 1.5
var _burst_left: int = 0
var _burst_pause_left: float = 0.0
var _fire_cd: float = 0.0
var _mag: int = 0
var _reload_left: float = 0.0
var _melee_cd: float = 0.0
var _melee_windup: float = -1.0
var _spit_cd: float = 0.0
var _charge_left: float = 0.0
var _charge_cd: float = 6.0
var _stuck_time: float = 0.0
var _stuck_check_left: float = 0.25
var _last_check_pos: Vector3 = Vector3.ZERO
var _unstick_left: float = 0.0
var _unstick_dir: Vector3 = Vector3.ZERO
var _roam_goal: Vector3 = Vector3(1.0e9, 0.0, 1.0e9)
var _roam_wait: float = 0.0
var _gravity: float = 18.0
var _alive: bool = true
var _audio: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _voice_left: float = 3.0
var _flash_mesh: MeshInstance3D
var _flash_left: float = 0.0
var _laser: MeshInstance3D
var _move_dir: Vector3 = Vector3.ZERO
var _move_speed: float = 0.0
var _want_jump: bool = false
var _avoid_left: float = 0.0
var _avoid_vec: Vector3 = Vector3.ZERO
var _marker: Label3D
var _last_attacker: Node = null
var _slow_left: float = 0.0
var _slow_factor: float = 1.0

func _ready() -> void:
    profile = BotDefinitions.get_profile(profile_id)
    is_zombie = str(profile.get("kind", "soldier")) == "zombie"
    points_value = int(profile.get("points", 100))
    max_health = float(profile.get("health", 100.0)) * BotDefinitions.DIFFICULTY_HEALTH[difficulty] * health_scale
    health = max_health
    var look_raw: Dictionary = profile.get("look", {})
    _body_scale = float(look_raw.get("scale", 1.0))
    _gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
    set_meta("team", team)
    set_meta("display_name", display_name)
    add_to_group("combatants")
    add_to_group("bots")
    collision_layer = 1
    collision_mask = 1
    floor_snap_length = 0.35
    floor_max_angle = deg_to_rad(48.0)
    safe_margin = 0.02
    max_slides = 6

    var shape_node := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32 * minf(_body_scale, 1.4)
    capsule.height = 1.8 * _body_scale
    shape_node.shape = capsule
    shape_node.position = Vector3(0.0, capsule.height * 0.5, 0.0)
    add_child(shape_node)

    _model = SoldierModel.new()
    _model.name = "Model"
    add_child(_model)
    _model.build(_make_look(look_raw))
    if bool(profile.get("flame", false)):
        var glow := OmniLight3D.new()
        glow.name = "FlameGlow"
        glow.light_color = Color("#ff7a2a")
        glow.light_energy = 1.6
        glow.omni_range = 7.0
        glow.position = Vector3(0.0, 1.6 * _body_scale * 0.6, 0.0)
        glow.shadow_enabled = false
        glow.add_to_group("no_shadow")
        add_child(glow)

    var weapon_id: String = str(profile.get("weapon", ""))
    if not weapon_override.is_empty() and not is_zombie:
        weapon_id = weapon_override
    if not weapon_id.is_empty():
        _weapon_def = WeaponDefinitions.get_definition(weapon_id)
        _mag = int(_weapon_def["magazine_size"])
    elif profile.has("spit"):
        var spit: Dictionary = profile["spit"]
        _weapon_def = {"damage": float(spit["damage"]), "range": float(spit["range"]), "pellets": 1, "pellet_spread": 0.0,
            "tracer_speed": float(spit["speed"]), "falloff_min_multiplier": 0.7, "headshot_multiplier": 1.0}

    _audio = AudioStreamPlayer3D.new()
    _audio.stream = WeaponAudio.get_stream("shot")
    _audio.max_distance = 120.0
    _audio.unit_size = 9.0
    _audio.volume_db = -3.0
    _audio.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
    add_child(_audio)
    _voice = AudioStreamPlayer3D.new()
    _voice.max_distance = 45.0
    _voice.unit_size = 6.0
    _voice.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
    add_child(_voice)

    _flash_mesh = MeshInstance3D.new()
    var flash_mesh := SphereMesh.new()
    flash_mesh.radius = 0.09
    flash_mesh.height = 0.18
    flash_mesh.radial_segments = 8
    flash_mesh.rings = 4
    _flash_mesh.mesh = flash_mesh
    var flash_material := StandardMaterial3D.new()
    flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_material.albedo_color = Color(1.0, 0.8, 0.4)
    flash_material.emission_enabled = true
    flash_material.emission = Color(1.0, 0.65, 0.2)
    flash_material.emission_energy_multiplier = 3.0
    _flash_mesh.material_override = flash_material
    _flash_mesh.top_level = true
    _flash_mesh.visible = false
    _flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_flash_mesh)

    if bool(profile.get("laser", false)):
        _laser = MeshInstance3D.new()
        var laser_mesh := BoxMesh.new()
        laser_mesh.size = Vector3(0.012, 0.012, 1.0)
        _laser.mesh = laser_mesh
        var laser_material := StandardMaterial3D.new()
        laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        laser_material.albedo_color = Color(1.0, 0.1, 0.1, 0.8)
        laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _laser.material_override = laser_material
        _laser.top_level = true
        _laser.visible = false
        _laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(_laser)

    if show_marker:
        _marker = Label3D.new()
        _marker.text = "▼"
        _marker.font_size = 72
        _marker.pixel_size = 0.006
        _marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _marker.no_depth_test = true
        _marker.modulate = team_color if team_color.a > 0.0 else Color(0.3, 0.8, 1.0)
        _marker.outline_size = 8
        _marker.position = Vector3(0.0, 2.15 * _body_scale, 0.0)
        _marker.render_priority = 5
        add_child(_marker)

    _scan_left = randf() * 0.25
    _last_check_pos = global_position
    _strafe_dir = 1.0 if randf() < 0.5 else -1.0
    _voice_left = randf_range(2.0, 7.0)

func _make_look(source: Dictionary) -> Dictionary:
    var look: Dictionary = {
        "kind": str(profile.get("kind", "soldier")),
        "primary": Color(str(source.get("primary", "#4a5a3c"))),
        "secondary": Color(str(source.get("secondary", "#2b2f33"))),
        "headgear": str(source.get("headgear", "helmet")),
        "bulk": float(source.get("bulk", 1.0)),
        "scale": float(source.get("scale", 1.0)),
        "weapon_id": weapon_override if not weapon_override.is_empty() else str(profile.get("weapon", "rifle")),
        "zombie_variant": randi() % 4,
    }
    if source.has("skin"):
        look["skin"] = Color(str(source["skin"]))
    if use_team_look and team_color.a > 0.0:
        look["team_color"] = team_color
        # Team modes: the uniform itself leans toward the team colour so teams read at a glance.
        var tinted: Color = (look["primary"] as Color).lerp(team_color, 0.35)
        look["primary"] = tinted
    return look

# ---------------------------------------------------------------- queries

## Traps and similar effects: move at `factor` of normal speed for `seconds`.
func apply_slow(factor: float, seconds: float) -> void:
    _slow_factor = clampf(factor, 0.0, 1.0)
    _slow_left = maxf(_slow_left, seconds)

func is_alive() -> bool:
    return _alive

func get_health_fraction() -> float:
    return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)

func get_eye_position() -> Vector3:
    return global_position + Vector3(0.0, 1.55 * _body_scale, 0.0)

func _aim_point(node: Node3D, head: bool = false) -> Vector3:
    var height: float = 1.25
    if node is Bot:
        height = 1.25 * float((node as Bot)._body_scale)
        if head:
            height = 1.62 * float((node as Bot)._body_scale)
    elif head:
        height = 1.6
    return node.global_position + Vector3(0.0, height, 0.0)

# ---------------------------------------------------------------- main loop

func net_set_state(target_position: Vector3, target_yaw: float, alive_now: bool) -> void:
    _puppet_target = target_position
    _puppet_yaw = target_yaw
    if not _puppet_has_state:
        global_position = target_position
        rotation.y = target_yaw
        _puppet_has_state = true
    if not alive_now and _alive:
        _puppet_die()

func _puppet_die() -> void:
    _alive = false
    state = State.DEAD
    remove_from_group("combatants")
    collision_layer = 0
    collision_mask = 0
    velocity = Vector3.ZERO
    if _marker != null:
        _marker.visible = false
    _model.play_death(Vector3.ZERO)
    var timer := get_tree().create_timer(6.0)
    timer.timeout.connect(func() -> void:
        if is_instance_valid(self):
            queue_free())

func _puppet_tick(delta: float) -> void:
    if not _puppet_has_state:
        return
    var before: Vector3 = global_position
    global_position = global_position.lerp(_puppet_target, 1.0 - exp(-14.0 * delta))
    rotation.y = lerp_angle(rotation.y, _puppet_yaw, 1.0 - exp(-12.0 * delta))
    var speed: float = Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 0.001)
    _model.animate(delta, minf(speed, 8.0), 0.0)

func _physics_process(delta: float) -> void:
    if net_puppet:
        if _alive:
            _puppet_tick(delta)
        return
    if not _alive:
        return
    delta = minf(delta, 0.05)
    _melee_cd = maxf(0.0, _melee_cd - delta)
    _spit_cd = maxf(0.0, _spit_cd - delta)
    _charge_cd = maxf(0.0, _charge_cd - delta)
    _charge_left = maxf(0.0, _charge_left - delta)
    _slow_left = maxf(0.0, _slow_left - delta)
    _memory_left = maxf(0.0, _memory_left - delta)
    _repath_left -= delta
    _scan_left -= delta
    if _scan_left <= 0.0:
        _scan_left = 0.18 + randf() * 0.1
        _perceive()
    _decide(delta)
    _apply_movement(delta)
    _update_attack(delta)
    _update_facing(delta)
    _update_visuals(delta)
    _update_voice(delta)

# ---------------------------------------------------------------- perception

func _perceive() -> void:
    var sight: float = float(profile.get("sight", 70.0))
    var fov: float = float(profile.get("fov", 120.0))
    var eye: Vector3 = get_eye_position()
    var forward: Vector3 = -global_transform.basis.z
    var cos_half_fov: float = cos(deg_to_rad(fov * 0.5))
    var visible_best: Node3D = null
    var visible_distance: float = INF
    var hunt_best: Node3D = null
    var hunt_distance: float = INF
    for node in get_tree().get_nodes_in_group("combatants"):
        if node == self or not (node is Node3D):
            continue
        if not CombatUtil.is_alive(node) or not CombatUtil.is_hostile(self, node):
            continue
        var other: Node3D = node as Node3D
        var offset: Vector3 = other.global_position - global_position
        var distance: float = offset.length()
        # Enemies and zombies care about the player first; allies only distract them when
        # they are much closer than the player.
        var rank: float = distance * (PLAYER_PRIORITY if (other.is_in_group("player_controller") or other is NetAvatar) else 1.0)
        if rank < hunt_distance:
            hunt_distance = rank
            hunt_best = other
        if distance > sight:
            continue
        if distance > 7.0 and not is_zombie:
            var flat: Vector3 = Vector3(offset.x, 0.0, offset.z)
            if flat.length() > 0.01 and forward.dot(flat.normalized()) < cos_half_fov:
                continue
        if rank < visible_distance and _has_line_of_sight(eye, other):
            visible_distance = rank
            visible_best = other
    if visible_best != null:
        if _target != visible_best or not _target_visible:
            _reaction_left = float(profile.get("reaction", 0.4)) * BotDefinitions.DIFFICULTY_REACTION[difficulty]
        _target = visible_best
        _target_visible = true
        _last_known = visible_best.global_position
        _memory_left = 6.0
    else:
        _target_visible = false
        if always_hunt and hunt_best != null:
            _target = hunt_best
            _last_known = hunt_best.global_position
            _memory_left = 6.0
        elif _memory_left <= 0.0:
            _target = null

func _has_line_of_sight(from_point: Vector3, other: Node3D) -> bool:
    var query := PhysicsRayQueryParameters3D.create(from_point, _aim_point(other), 1)
    query.exclude = [get_rid()]
    query.collide_with_areas = false
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return true
    return hit["collider"] == other

# ---------------------------------------------------------------- decisions

func _flat(vector: Vector3) -> Vector3:
    return Vector3(vector.x, 0.0, vector.z)

func _decide(delta: float) -> void:
    _move_dir = Vector3.ZERO
    _move_speed = 0.0
    var base_speed: float = float(profile.get("speed", 3.5))
    if _slow_left > 0.0:
        base_speed *= _slow_factor
    if _target != null and (not is_instance_valid(_target) or not CombatUtil.is_alive(_target)):
        _target = null
        _target_visible = false
    if is_zombie:
        _decide_zombie(delta, base_speed)
        return
    _strafe_flip_left -= delta
    if _strafe_flip_left <= 0.0:
        _strafe_flip_left = randf_range(1.2, 3.2)
        if randf() < 0.65:
            _strafe_dir = -_strafe_dir
    if _target != null and _target_visible:
        state = State.ENGAGE
        var to_target: Vector3 = _flat(_target.global_position - global_position)
        var distance: float = to_target.length()
        var direction: Vector3 = to_target.normalized() if distance > 0.01 else -global_transform.basis.z
        var range_min: float = float(profile.get("range_min", 10.0))
        var range_max: float = float(profile.get("range_max", 30.0))
        var strafe_amount: float = float(profile.get("strafe", 0.5))
        if distance > range_max:
            _move_toward_goal(_target.global_position, base_speed)
        elif distance < range_min:
            # Too close for this gun: back off while shooting, or close in for short-range guns.
            if range_max < 14.0:
                _move_toward_goal(_target.global_position, base_speed)
            else:
                _move_dir = -direction
                _move_speed = base_speed * 0.85
        else:
            var side: Vector3 = Vector3(-direction.z, 0.0, direction.x) * _strafe_dir
            _move_dir = (side * strafe_amount + direction * (0.15 if distance > (range_min + range_max) * 0.5 else -0.1)).normalized()
            _move_speed = base_speed * strafe_amount
            if strafe_amount < 0.2:
                _move_speed = 0.0
        return
    if _target != null and _memory_left > 0.0:
        state = State.SEARCH
        var flat_distance: float = _flat(_last_known - global_position).length()
        if flat_distance > 2.0:
            _move_toward_goal(_last_known, base_speed)
            return
        _memory_left = 0.0
    state = State.ROAM
    _roam(delta, base_speed * 0.7)

func _decide_zombie(delta: float, base_speed: float) -> void:
    if _target == null:
        state = State.ROAM
        _roam(delta, base_speed * 0.5)
        return
    state = State.HUNT
    var to_target: Vector3 = _flat(_target.global_position - global_position)
    var distance: float = to_target.length()
    var melee: Dictionary = profile.get("melee", {})
    var reach: float = float(melee.get("reach", 1.7)) * 0.8
    var speed: float = base_speed
    if bool(profile.get("boss", false)):
        if _charge_left > 0.0:
            speed = base_speed * 2.1
        elif _charge_cd <= 0.0 and distance > 7.0 and distance < 26.0 and _target_visible:
            _charge_left = 1.4
            _charge_cd = randf_range(7.0, 11.0)
    if profile.has("spit") and _target_visible and distance <= float(profile.get("range_max", 22.0)) and distance >= float(profile.get("range_min", 10.0)):
        # Spitters keep their distance and lob acid.
        var side: Vector3 = Vector3(-to_target.z, 0.0, to_target.x).normalized() * _strafe_dir
        _move_dir = side
        _move_speed = base_speed * 0.5
        return
    if distance > reach:
        _move_toward_goal(_target.global_position, speed)
    elif _melee_windup < 0.0:
        _move_dir = to_target.normalized() * 0.01

func _roam(delta: float, speed: float) -> void:
    _roam_wait -= delta
    if _roam_wait > 0.0:
        return
    var flat_distance: float = _flat(_roam_goal - global_position).length()
    if _roam_goal.x > 1.0e8 or flat_distance < 2.0 or _stuck_time > 1.5:
        _roam_goal = _pick_roam_goal()
        _roam_wait = randf_range(0.2, 1.4) if not is_zombie else 0.1
        _stuck_time = 0.0
        _repath_left = 0.0
        return
    _move_toward_goal(_roam_goal, speed)

func _pick_roam_goal() -> Vector3:
    if mode_ref != null and is_instance_valid(mode_ref) and mode_ref.has_method("get_roam_point"):
        var point: Vector3 = mode_ref.call("get_roam_point", self)
        return BotNav.closest_point(get_world_3d(), point)
    var random_point := Vector3(randf_range(-60.0, 60.0), 0.0, randf_range(-60.0, 60.0))
    return BotNav.closest_point(get_world_3d(), random_point)

func _move_toward_goal(goal: Vector3, speed: float) -> void:
    if _repath_left <= 0.0 or _flat(goal - _path_goal).length() > 3.0:
        _repath_left = 0.5 + randf() * 0.2
        _path_goal = goal
        _path = BotNav.find_path(get_world_3d(), global_position, goal)
        _path_index = 0
    var next_point: Vector3 = goal
    if _path.size() > 1:
        while _path_index < _path.size() - 1 and _flat(_path[_path_index] - global_position).length() < 0.8:
            _path_index += 1
        next_point = _path[mini(_path_index, _path.size() - 1)]
    var direction: Vector3 = _flat(next_point - global_position)
    if direction.length() < 0.05:
        direction = _flat(goal - global_position)
    _move_dir = direction.normalized()
    _move_speed = speed

# ---------------------------------------------------------------- movement

func _apply_movement(delta: float) -> void:
    var direction: Vector3 = _move_dir
    var speed: float = _move_speed
    if _unstick_left > 0.0:
        _unstick_left -= delta
        direction = _unstick_dir
        speed = maxf(speed, 2.4)
    elif speed > 0.0:
        direction = _avoid_obstacles(direction, delta)
    var wanted: Vector3 = direction * speed
    var accel: float = 16.0 if speed > 0.0 else 22.0
    velocity.x = move_toward(velocity.x, wanted.x, accel * delta)
    velocity.z = move_toward(velocity.z, wanted.z, accel * delta)
    if is_on_floor():
        velocity.y = -0.5
        if _want_jump:
            velocity.y = 6.2
            _want_jump = false
    else:
        velocity.y = maxf(velocity.y - _gravity * delta, -28.0)
    move_and_slide()
    if global_position.y < -20.0:
        _kill(null, false)
        return
    _stuck_check_left -= delta
    if _stuck_check_left <= 0.0:
        _stuck_check_left = 0.25
        var moved: float = _flat(global_position - _last_check_pos).length()
        _last_check_pos = global_position
        if speed > 0.5 and moved < 0.1:
            _stuck_time += 0.25
        else:
            _stuck_time = maxf(0.0, _stuck_time - 0.25)
        if _stuck_time >= 0.75:
            _stuck_time = 0.0
            _want_jump = true
            _unstick_left = 0.8
            var turn: float = deg_to_rad(randf_range(70.0, 130.0)) * (1.0 if randf() < 0.5 else -1.0)
            _unstick_dir = direction.rotated(Vector3.UP, turn) if direction.length() > 0.1 else Vector3.RIGHT
            _repath_left = 0.0
            _roam_goal = Vector3(1.0e9, 0.0, 1.0e9)

func _avoid_obstacles(direction: Vector3, delta: float) -> Vector3:
    _avoid_left -= delta
    if _avoid_left > 0.0:
        return (direction + _avoid_vec).normalized()
    _avoid_left = 0.1
    _avoid_vec = Vector3.ZERO
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var origin: Vector3 = global_position + Vector3(0.0, 0.55, 0.0)
    var reach: float = 1.6
    var forward_query := PhysicsRayQueryParameters3D.create(origin, origin + direction * reach, 1)
    forward_query.exclude = [get_rid()]
    var forward_hit: Dictionary = space.intersect_ray(forward_query)
    if forward_hit.is_empty():
        return direction
    # Low obstacle in front but clear at head height: hop over it.
    var high_origin: Vector3 = global_position + Vector3(0.0, 1.25, 0.0)
    var high_query := PhysicsRayQueryParameters3D.create(high_origin, high_origin + direction * reach, 1)
    high_query.exclude = [get_rid()]
    var high_hit: Dictionary = space.intersect_ray(high_query)
    var low_query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 0.2, 0.0), global_position + Vector3(0.0, 0.2, 0.0) + direction * 1.0, 1)
    low_query.exclude = [get_rid()]
    var low_hit: Dictionary = space.intersect_ray(low_query)
    var blocker: Object = forward_hit["collider"]
    if blocker is Bot:
        # Other fighters: slide around them.
        _avoid_vec = Vector3(-direction.z, 0.0, direction.x) * (1.0 if randf() < 0.5 else -1.0) * 0.8
        return (direction + _avoid_vec).normalized()
    if high_hit.is_empty() and not low_hit.is_empty() and is_on_floor():
        _want_jump = true
        return direction
    # Wall: pick the freer side.
    var left_dir: Vector3 = direction.rotated(Vector3.UP, 0.9)
    var right_dir: Vector3 = direction.rotated(Vector3.UP, -0.9)
    var left_query := PhysicsRayQueryParameters3D.create(origin, origin + left_dir * reach * 1.5, 1)
    left_query.exclude = [get_rid()]
    var right_query := PhysicsRayQueryParameters3D.create(origin, origin + right_dir * reach * 1.5, 1)
    right_query.exclude = [get_rid()]
    var left_free: bool = space.intersect_ray(left_query).is_empty()
    var right_free: bool = space.intersect_ray(right_query).is_empty()
    if left_free and not right_free:
        _avoid_vec = left_dir * 0.9
    elif right_free and not left_free:
        _avoid_vec = right_dir * 0.9
    else:
        _avoid_vec = left_dir * 0.9 if randf() < 0.5 else right_dir * 0.9
    return (direction * 0.4 + _avoid_vec).normalized()

func _update_facing(delta: float) -> void:
    var face: Vector3 = Vector3.ZERO
    if _target != null and (_target_visible or is_zombie) and is_instance_valid(_target):
        face = _flat(_target.global_position - global_position)
    elif _flat(velocity).length() > 0.3:
        face = _flat(velocity)
    if face.length() < 0.01:
        return
    var yaw: float = atan2(-face.x, -face.z)
    var turn_rate: float = 5.5 if is_zombie else 10.0
    rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-turn_rate * delta))

func _update_visuals(delta: float) -> void:
    var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
    var aiming: float = 1.0 if (_target != null and _target_visible) else 0.0
    _model.animate(delta, horizontal_speed, aiming)
    if _flash_left > 0.0:
        _flash_left -= delta
        if _flash_left <= 0.0:
            _flash_mesh.visible = false
    if _laser != null:
        var show_laser: bool = _target != null and _target_visible and _reload_left <= 0.0 and _burst_pause_left <= 0.0 and _alive
        _laser.visible = show_laser
        if show_laser:
            var from_point: Vector3 = _model.get_muzzle_position()
            var to_point: Vector3 = _aim_point(_target)
            var span: Vector3 = to_point - from_point
            if span.length() > 0.5:
                var up_vector: Vector3 = Vector3.UP if absf(span.normalized().y) < 0.98 else Vector3.RIGHT
                var look_basis := Basis.looking_at(span.normalized(), up_vector) * Basis.from_scale(Vector3(1.0, 1.0, span.length()))
                _laser.global_transform = Transform3D(look_basis, (from_point + to_point) * 0.5)

func _update_voice(delta: float) -> void:
    if not is_zombie:
        return
    _voice_left -= delta
    if _voice_left > 0.0:
        return
    _voice_left = randf_range(4.0, 9.0)
    if _target == null:
        return
    var boss: bool = bool(profile.get("boss", false))
    _voice.stream = WeaponAudio.get_stream("roar" if boss else "groan")
    _voice.pitch_scale = randf_range(0.8, 1.15) * (0.7 if _body_scale > 1.2 else 1.0)
    _voice.volume_db = 2.0 if boss else -2.0
    _voice.play()

# ---------------------------------------------------------------- attacking

func _update_attack(delta: float) -> void:
    if is_zombie:
        _update_zombie_attack(delta)
    else:
        _update_ranged_attack(delta)

func _update_ranged_attack(delta: float) -> void:
    _fire_cd = maxf(0.0, _fire_cd - delta)
    _burst_pause_left = maxf(0.0, _burst_pause_left - delta)
    if _weapon_def.is_empty():
        return
    if _reload_left > 0.0:
        _reload_left -= delta
        if _reload_left <= 0.0:
            _mag = int(_weapon_def["magazine_size"])
        return
    if _target == null or not _target_visible or not is_instance_valid(_target):
        _burst_left = 0
        return
    if _reaction_left > 0.0:
        _reaction_left -= delta
        return
    var eye: Vector3 = get_eye_position()
    var aim_point: Vector3 = _aim_point(_target)
    var to_aim: Vector3 = aim_point - eye
    if to_aim.length() > float(_weapon_def["range"]):
        return
    var forward: Vector3 = -global_transform.basis.z
    if forward.dot(to_aim.normalized()) < cos(deg_to_rad(14.0)):
        return
    if _burst_pause_left > 0.0 or _fire_cd > 0.0:
        return
    if _burst_left <= 0:
        _burst_left = randi_range(int(profile.get("burst_min", 3)), int(profile.get("burst_max", 6)))
    _fire_shot()
    _burst_left -= 1
    _mag -= 1
    var interval: float = 60.0 / float(_weapon_def["rounds_per_minute"])
    if not bool(_weapon_def["auto"]):
        interval = maxf(interval, 0.3)
    _fire_cd = interval
    if _burst_left <= 0:
        _burst_pause_left = float(profile.get("burst_pause", 0.7)) * randf_range(0.8, 1.4)
    if _mag <= 0:
        _reload_left = float(_weapon_def["reload_time"]) * 0.8
        _burst_left = 0

func _target_speed(node: Node3D) -> float:
    if node is CharacterBody3D:
        var body := node as CharacterBody3D
        return Vector2(body.velocity.x, body.velocity.z).length()
    return 0.0

func _perturb(direction: Vector3, angle: float) -> Vector3:
    var up_vector: Vector3 = Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT
    var right: Vector3 = direction.cross(up_vector).normalized()
    var real_up: Vector3 = right.cross(direction).normalized()
    var around: float = randf() * TAU
    var radius: float = sqrt(randf()) * tan(angle)
    return (direction + right * cos(around) * radius + real_up * sin(around) * radius).normalized()

func _fire_shot() -> void:
    var muzzle: Vector3 = _model.get_muzzle_position() if not is_zombie else get_eye_position() + Vector3(0.0, -0.2, 0.0) + (-global_transform.basis.z) * 0.5
    var head_shot_roll: bool = randf() < 0.12 and not is_zombie
    var aim_point: Vector3 = _aim_point(_target, head_shot_roll)
    var base_direction: Vector3 = (aim_point - muzzle).normalized()
    var error_deg: float = float(profile.get("aim_error", 2.5)) * BotDefinitions.DIFFICULTY_AIM[difficulty]
    error_deg += _target_speed(_target) * 0.22
    var spread: float = deg_to_rad(error_deg) + float(_weapon_def.get("pellet_spread", 0.0))
    var pellets: int = maxi(1, int(_weapon_def.get("pellets", 1)))
    var max_range: float = float(_weapon_def["range"])
    var tracer_speed: float = float(_weapon_def.get("tracer_speed", 200.0))
    var damage_scale: float = float(profile.get("damage_scale", 0.5)) * BotDefinitions.DIFFICULTY_DAMAGE[difficulty]
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var damage_by_target: Dictionary = {}
    for pellet in range(pellets):
        var direction: Vector3 = _perturb(base_direction, spread)
        var query := PhysicsRayQueryParameters3D.create(muzzle, muzzle + direction * max_range, 1)
        query.exclude = [get_rid()]
        query.collide_with_areas = false
        var hit: Dictionary = space.intersect_ray(query)
        var end_point: Vector3 = muzzle + direction * max_range
        if not hit.is_empty():
            end_point = hit["position"]
            var collider: Object = hit["collider"]
            var node: Node = collider as Node
            if node != null and CombatUtil.is_hostile(self, node):
                var distance: float = muzzle.distance_to(end_point)
                var falloff: float = lerpf(1.0, float(_weapon_def.get("falloff_min_multiplier", 0.5)), clampf(distance / max_range, 0.0, 1.0))
                var amount: float = float(_weapon_def["damage"]) * damage_scale * falloff
                var key: int = node.get_instance_id()
                if not damage_by_target.has(key):
                    damage_by_target[key] = {"node": node, "damage": 0.0, "position": end_point, "direction": direction}
                var entry: Dictionary = damage_by_target[key]
                entry["damage"] = float(entry["damage"]) + amount
            elif fx != null and pellet < 3:
                fx.spawn_impact(end_point, hit["normal"], false)
        if fx != null and pellet < 2 and not bool(profile.get("flame", false)):
            fx.spawn_tracer(muzzle, end_point, tracer_speed)
        if bool(profile.get("flame", false)) and pellet == 0:
            _spawn_flame(muzzle, end_point)
    for key in damage_by_target.keys():
        var entry: Dictionary = damage_by_target[key]
        var victim: Node = entry["node"]
        if is_instance_valid(victim):
            CombatUtil.apply_damage(victim, float(entry["damage"]), self, {
                "position": entry["position"], "direction": entry["direction"],
                "normal": -(entry["direction"] as Vector3), "headshot_multiplier": float(_weapon_def.get("headshot_multiplier", 2.0)),
                "weapon_id": str(profile.get("weapon", "spit")),
            })
    if is_zombie:
        _voice.stream = WeaponAudio.get_stream("spit")
        _voice.pitch_scale = randf_range(0.9, 1.1)
        _voice.volume_db = 0.0
        _voice.play()
    else:
        _audio.pitch_scale = float(_weapon_def.get("sound_pitch", 1.0)) * randf_range(0.95, 1.06)
        _audio.volume_db = float(_weapon_def.get("sound_volume", -3.0)) - 2.0
        _audio.play()
        _flash_mesh.global_position = muzzle
        _flash_mesh.visible = true
        _flash_left = 0.05

func _spawn_flame(from_point: Vector3, to_point: Vector3) -> void:
    var length: float = minf(from_point.distance_to(to_point), 13.0)
    var direction: Vector3 = (to_point - from_point).normalized()
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(1.0, 0.55, 0.12, 0.8)
    material.emission_enabled = true
    material.emission = Color(1.0, 0.4, 0.05)
    material.emission_energy_multiplier = 3.0
    for index in range(5):
        var puff := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.18
        sphere.height = 0.36
        puff.mesh = sphere
        puff.material_override = material
        puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        puff.top_level = true
        add_child(puff)
        puff.global_position = from_point + direction * (length * float(index) / 4.0)
        var tween := create_tween().set_parallel(true)
        tween.tween_property(puff, "scale", Vector3.ONE * (2.2 + float(index) * 0.5), 0.3)
        tween.tween_property(puff, "global_position:y", puff.global_position.y + 0.5, 0.3)
        tween.chain().tween_callback(puff.queue_free)

func _update_zombie_attack(delta: float) -> void:
    if _target == null or not is_instance_valid(_target):
        _melee_windup = -1.0
        return
    var melee: Dictionary = profile.get("melee", {})
    var reach: float = float(melee.get("reach", 1.7))
    var to_target: Vector3 = _target.global_position - global_position
    var flat_distance: float = _flat(to_target).length()
    if _melee_windup >= 0.0:
        _melee_windup -= delta
        if _melee_windup < 0.0:
            _melee_strike(reach, float(melee.get("damage", 10.0)))
        return
    # Spit attack for spitters while they keep their distance.
    if profile.has("spit") and _target_visible and _spit_cd <= 0.0 and flat_distance > reach * 1.5:
        var spit: Dictionary = profile["spit"]
        if flat_distance <= float(spit["range"]):
            _spit_cd = float(spit["cooldown"])
            _model.attack_swing()
            _fire_shot()
            return
    if flat_distance <= reach and absf(to_target.y) < 2.2 and _melee_cd <= 0.0:
        _melee_windup = float(melee.get("windup", 0.3))
        _melee_cd = float(melee.get("cooldown", 1.0))
        _model.attack_swing()

func _melee_strike(reach: float, damage: float) -> void:
    if _target == null or not is_instance_valid(_target) or not CombatUtil.is_alive(_target):
        return
    var flat_distance: float = _flat(_target.global_position - global_position).length()
    if flat_distance > reach * 1.3:
        return
    var amount: float = damage * BotDefinitions.DIFFICULTY_DAMAGE[difficulty]
    var direction: Vector3 = _flat(_target.global_position - global_position).normalized()
    CombatUtil.apply_damage(_target, amount, self, {
        "position": _target.global_position + Vector3(0, 1.0, 0), "direction": direction, "normal": -direction, "weapon_id": "claws",
    })
    _audio.stream = WeaponAudio.get_stream("thud")
    _audio.pitch_scale = randf_range(0.85, 1.1)
    _audio.volume_db = 0.0
    _audio.play()
    _audio.stream = WeaponAudio.get_stream("shot")

# ---------------------------------------------------------------- taking damage

func receive_hit(info: Dictionary) -> Dictionary:
    if not _alive:
        return {"headshot": false, "killed": false}
    if net_puppet:
        # Guest: the host owns the real bot, so the shot is reported to it.
        var puppet_hit: Vector3 = info.get("position", global_position)
        NetGame.report_bot_hit(int(get_meta("net_id", -1)), info)
        _model.flash()
        var puppet_head: bool = puppet_hit.y - global_position.y >= 1.5 * _body_scale and not bool(profile.get("boss", false))
        return {"headshot": puppet_head, "killed": false}
    var source: Node = info.get("source", null) as Node
    if source != null and not CombatUtil.is_hostile(self, source):
        # No friendly fire: shots from teammates do nothing.
        return {"headshot": false, "killed": false}
    var hit_position: Vector3 = info.get("position", global_position)
    var damage: float = float(info.get("damage", 0.0))
    var headshot: bool = hit_position.y - global_position.y >= 1.5 * _body_scale and not bool(profile.get("boss", false))
    if headshot:
        damage *= float(info.get("headshot_multiplier", 2.0))
    damage *= 1.0 - float(profile.get("armor", 0.0))
    health -= damage
    _model.flash()
    if source != null:
        _last_attacker = source
        if source is Node3D and CombatUtil.is_alive(source):
            # Turn on whoever shot us if we did not already see them.
            var locked_on_player: bool = is_instance_valid(_target) and _target.is_in_group("player_controller") and CombatUtil.is_alive(_target)
            if (_target == null or not _target_visible) and not locked_on_player:
                _target = source as Node3D
                _last_known = (source as Node3D).global_position
                _memory_left = 6.0
                _reaction_left = float(profile.get("reaction", 0.4)) * 0.5
    if source != null and source.is_in_group("player_controller"):
        _spawn_damage_number(hit_position, damage, headshot)
    if health <= 0.0:
        _kill(source, headshot)
        return {"headshot": headshot, "killed": true}
    return {"headshot": headshot, "killed": false}

func _kill(killer: Node, headshot: bool) -> void:
    if not _alive:
        return
    _alive = false
    state = State.DEAD
    remove_from_group("combatants")
    collision_layer = 0
    collision_mask = 0
    velocity = Vector3.ZERO
    if _laser != null:
        _laser.visible = false
    if _marker != null:
        _marker.visible = false
    var push: Vector3 = Vector3.ZERO
    if killer is Node3D:
        push = global_position - (killer as Node3D).global_position
    _model.play_death(push)
    died.emit(self, killer, headshot)
    EventBus.combatant_killed.emit(self, killer, headshot)
    if killer != null and killer.is_in_group("player_controller"):
        EventBus.target_destroyed.emit(points_value + (50 if headshot else 0), headshot)
    var timer := get_tree().create_timer(6.0)
    timer.timeout.connect(func() -> void:
        if is_instance_valid(self):
            queue_free())

func _spawn_damage_number(world_point: Vector3, amount: float, headshot: bool) -> void:
    var label := Label3D.new()
    label.text = str(roundi(amount))
    label.font_size = 64 if headshot else 44
    label.pixel_size = 0.006
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.modulate = Color(1.0, 0.35, 0.2) if headshot else Color(1.0, 0.95, 0.7)
    label.outline_size = 10
    label.top_level = true
    add_child(label)
    label.global_position = world_point + Vector3(randf_range(-0.2, 0.2), 0.15, 0.0)
    var tween := create_tween().set_parallel(true)
    tween.tween_property(label, "global_position:y", label.global_position.y + 0.9, 0.7)
    tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
    tween.chain().tween_callback(label.queue_free)
