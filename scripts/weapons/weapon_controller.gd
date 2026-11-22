extends Node
class_name WeaponController

## Hitscan weapon logic for the player: a loadout of several guns, ammo per gun, fire rate,
## semi/full-auto, shotgun pellets, spread, recoil, reload, damage, tracers and holes.
## Visuals live in EquipmentViewmodel; effects in BulletEffects; numbers in WeaponDefinitions.

signal ammo_changed(magazine: int, reserve: int, magazine_size: int)
signal reload_state_changed(is_reloading: bool, duration: float)
signal fired
signal dry_fired
signal hit_confirmed(headshot: bool, killed: bool)
signal weapon_changed(weapon_id: String, display_name: String)
signal loadout_changed

@export var weapon_id: String = "rifle"

var _def: Dictionary = {}
var _player: CharacterBody3D
var _camera: Camera3D
var _viewmodel: Node3D
var _fx: BulletEffects
var _weapons: Array[String] = []
var _state: Dictionary = {}
var _current_id: String = ""
var _magazine: int = 0
var _reserve: int = 0
var _magazine_size: int = 30
var _cooldown: float = 0.0
var _spread: float = 0.0
var _reloading: bool = false
var _reload_left: float = 0.0
var _reload_total: float = 1.0
var _reload_stage: int = 0
var _auto_reload_delay: float = -1.0
var _shot_players: Array[AudioStreamPlayer] = []
var _shot_cursor: int = 0
var _fx_player: AudioStreamPlayer
var _shots_in_burst: int = 0
var _burst_reset: float = 0.0
var _last_cone: float = 0.0
var _fire_buffer: float = 0.0
var _damage_multiplier: float = 1.0

func _ready() -> void:
    add_to_group("weapon_controller")
    _player = get_parent() as CharacterBody3D
    if _player != null:
        _camera = _player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
        if _camera != null:
            _viewmodel = _camera.get_node_or_null("EquipmentViewmodel") as Node3D
    # On touch devices emulated mouse clicks must never fire the weapon; only the FIRE button does.
    if OS.has_feature("android") or OS.has_feature("ios"):
        InputMap.action_erase_events("fire")
    _fx = BulletEffects.new()
    _fx.name = "BulletEffects"
    add_child(_fx)
    for i in range(4):
        var shot_player := AudioStreamPlayer.new()
        shot_player.stream = WeaponAudio.get_stream("shot")
        shot_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
        shot_player.volume_db = -3.0
        add_child(shot_player)
        _shot_players.append(shot_player)
    _fx_player = AudioStreamPlayer.new()
    _fx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
    add_child(_fx_player)
    _damage_multiplier = 1.0 + 0.10 * float(SaveManager.get_upgrade_level("damage"))
    _build_loadout()

func _build_loadout() -> void:
    _weapons = SaveManager.get_owned_weapons()
    _state.clear()
    for id in _weapons:
        var def: Dictionary = WeaponDefinitions.get_definition(id)
        _state[id] = {"mag": int(def["magazine_size"]), "reserve": int(def["reserve_ammo"])}
    var start_id: String = SaveManager.get_selected_weapon()
    if not _weapons.has(start_id):
        start_id = _weapons[0]
    if weapon_id != "rifle" and _weapons.has(weapon_id):
        start_id = weapon_id
    _current_id = ""
    _apply_weapon(start_id, false)
    loadout_changed.emit()

# ---------------------------------------------------------------- queries

func get_magazine() -> int:
    return _magazine

func get_reserve() -> int:
    return _reserve

func get_magazine_size() -> int:
    return _magazine_size

func is_reloading() -> bool:
    return _reloading

func get_reload_progress() -> float:
    if not _reloading:
        return 0.0
    return clampf(1.0 - _reload_left / maxf(_reload_total, 0.01), 0.0, 1.0)

func get_current_spread() -> float:
    return _last_cone

func get_effects() -> BulletEffects:
    return _fx

func get_weapon_name() -> String:
    return WeaponDefinitions.get_display_name(_current_id, Loc.language)

func get_weapon_id() -> String:
    return _current_id

func get_weapon_ids() -> Array[String]:
    return _weapons.duplicate()

func get_ammo_for(id: String) -> Vector2i:
    if id == _current_id:
        return Vector2i(_magazine, _reserve)
    if _state.has(id):
        var entry: Dictionary = _state[id]
        return Vector2i(int(entry["mag"]), int(entry["reserve"]))
    return Vector2i.ZERO

# ---------------------------------------------------------------- loadout management

func _save_current_state() -> void:
    if _current_id.is_empty():
        return
    _state[_current_id] = {"mag": _magazine, "reserve": _reserve}

func _apply_weapon(id: String, animate: bool) -> void:
    _save_current_state()
    _current_id = id
    _def = WeaponDefinitions.get_definition(id)
    _magazine_size = int(_def["magazine_size"])
    var entry: Dictionary = _state.get(id, {"mag": _magazine_size, "reserve": int(_def["reserve_ammo"])})
    _magazine = int(entry["mag"])
    _reserve = int(entry["reserve"])
    _reloading = false
    _reload_left = 0.0
    _auto_reload_delay = -1.0
    _spread = 0.0
    _shots_in_burst = 0
    _fire_buffer = 0.0
    _cooldown = 0.38 if animate else 0.0
    if _viewmodel != null:
        if _viewmodel.has_method("cancel_reload"):
            _viewmodel.call("cancel_reload")
        if _viewmodel.has_method("set_weapon"):
            _viewmodel.call("set_weapon", id, str(_def.get("style", "rifle")), animate)
    reload_state_changed.emit(false, 0.0)
    ammo_changed.emit(_magazine, _reserve, _magazine_size)
    weapon_changed.emit(id, get_weapon_name())
    if animate:
        _play_fx("bolt", -8.0)
    SaveManager.set_selected_weapon(id)
    if _magazine == 0 and _reserve > 0:
        _auto_reload_delay = 0.4

func equip(id: String) -> bool:
    if id == _current_id or not _weapons.has(id):
        return false
    _apply_weapon(id, true)
    return true

func equip_index(index: int) -> bool:
    if index < 0 or index >= _weapons.size():
        return false
    return equip(_weapons[index])

func cycle_weapon(direction: int) -> void:
    if _weapons.size() < 2:
        return
    var index: int = _weapons.find(_current_id)
    index = posmod(index + direction, _weapons.size())
    equip(_weapons[index])

func add_weapon(id: String, equip_now: bool = true) -> void:
    if not WeaponDefinitions.exists(id):
        return
    if not _weapons.has(id):
        _save_current_state()
        var def: Dictionary = WeaponDefinitions.get_definition(id)
        _state[id] = {"mag": int(def["magazine_size"]), "reserve": int(def["reserve_ammo"])}
        _weapons.append(id)
        # Keep the canonical order of the catalogue.
        var ordered: Array[String] = []
        for known in WeaponDefinitions.ORDER:
            if _weapons.has(known):
                ordered.append(known)
        _weapons = ordered
        loadout_changed.emit()
    if equip_now:
        equip(id)

func refill() -> void:
    ## Full resupply: every gun in the loadout gets a full magazine and full reserve.
    _reloading = false
    _reload_left = 0.0
    for id in _weapons:
        var def: Dictionary = WeaponDefinitions.get_definition(id)
        _state[id] = {"mag": int(def["magazine_size"]), "reserve": int(def["reserve_ammo"])}
    var current_entry: Dictionary = _state.get(_current_id, {"mag": _magazine_size, "reserve": int(_def["reserve_ammo"])})
    _magazine = int(current_entry["mag"])
    _reserve = int(current_entry["reserve"])
    _spread = 0.0
    _cooldown = 0.0
    if _viewmodel != null and _viewmodel.has_method("cancel_reload"):
        _viewmodel.call("cancel_reload")
    reload_state_changed.emit(false, 0.0)
    ammo_changed.emit(_magazine, _reserve, _magazine_size)

func give_ammo_pack() -> void:
    ## Shop "ammo pack": +60% of the reserve of every gun, capped at twice the normal reserve.
    _save_current_state()
    for id in _weapons:
        var def: Dictionary = WeaponDefinitions.get_definition(id)
        var base_reserve: int = int(def["reserve_ammo"])
        var entry: Dictionary = _state[id]
        entry["reserve"] = mini(int(entry["reserve"]) + int(ceil(float(base_reserve) * 0.6)), base_reserve * 2)
        _state[id] = entry
    var current_entry: Dictionary = _state[_current_id]
    _reserve = int(current_entry["reserve"])
    ammo_changed.emit(_magazine, _reserve, _magazine_size)
    if _magazine == 0 and _reserve > 0:
        _auto_reload_delay = 0.2

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
    if _player == null or _weapons.size() < 2:
        return
    if event is InputEventKey:
        var key_event := event as InputEventKey
        if key_event.pressed and not key_event.echo:
            var number: int = int(key_event.physical_keycode) - int(KEY_1)
            if number >= 0 and number < 9:
                equip_index(number)
    elif event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
                cycle_weapon(-1)
            elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                cycle_weapon(1)

func _is_fire_held() -> bool:
    if Input.is_action_pressed("fire") and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or OS.has_feature("android") or OS.has_feature("ios") or _touch_hud_present()):
        return true
    return false

func _touch_hud_present() -> bool:
    return get_tree().get_first_node_in_group("touch_controls") != null

func _process(delta: float) -> void:
    if _player == null or _camera == null:
        return
    if _player.has_method("is_dead") and bool(_player.call("is_dead")):
        return
    _cooldown = maxf(0.0, _cooldown - delta)
    _fire_buffer = maxf(0.0, _fire_buffer - delta)
    _spread = maxf(0.0, _spread - float(_def["spread_recovery"]) * delta)
    _burst_reset -= delta
    if _burst_reset <= 0.0:
        _shots_in_burst = 0
    if _auto_reload_delay >= 0.0:
        _auto_reload_delay -= delta
        if _auto_reload_delay < 0.0:
            start_reload()
    if InputMap.has_action("next_weapon") and Input.is_action_just_pressed("next_weapon"):
        cycle_weapon(1)
    if Input.is_action_just_pressed("reload"):
        start_reload()
    var held: bool = _is_fire_held()
    if held and Input.is_action_just_pressed("fire"):
        _fire_buffer = 0.25
    elif not held:
        _fire_buffer = minf(_fire_buffer, 0.25)
    if _reloading:
        _update_reload(delta)
        return
    var wants_fire: bool = held if bool(_def["auto"]) else (_fire_buffer > 0.0)
    if wants_fire:
        # Shooting from a sprint: the gun first comes up to the ready position, then fires.
        if _player.has_method("suppress_sprint"):
            _player.call("suppress_sprint", 0.35)
        if _player.has_method("is_ready_to_fire") and not bool(_player.call("is_ready_to_fire")):
            return
        if _cooldown <= 0.0:
            _fire_buffer = 0.0
            _try_fire()

func _try_fire() -> void:
    if _magazine <= 0:
        _cooldown = 0.28
        _fire_buffer = 0.0
        _play_fx("dry", -6.0)
        dry_fired.emit()
        if _reserve > 0:
            _auto_reload_delay = 0.1
        return
    _magazine -= 1
    _cooldown = 60.0 / float(_def["rounds_per_minute"])
    _shots_in_burst += 1
    _burst_reset = 0.25
    SaveManager.increment_stat("shots_fired")
    _fire_shot()
    _spread = minf(_spread + float(_def["spread_per_shot"]), float(_def["spread_max"]))
    var shot_player := _shot_players[_shot_cursor]
    _shot_cursor = (_shot_cursor + 1) % _shot_players.size()
    shot_player.pitch_scale = float(_def["sound_pitch"]) * randf_range(0.95, 1.06)
    shot_player.volume_db = float(_def["sound_volume"])
    shot_player.play()
    if _viewmodel != null and _viewmodel.has_method("play_fire"):
        _viewmodel.call("play_fire")
    if _player.has_method("add_recoil"):
        var climb: float = float(_def["recoil_pitch"]) * (1.0 + minf(float(_shots_in_burst), 12.0) * 0.035)
        var sway: float = randf_range(-1.0, 1.0) * float(_def["recoil_yaw"])
        _player.call("add_recoil", climb, sway)
    fired.emit()
    ammo_changed.emit(_magazine, _reserve, _magazine_size)
    if _magazine == 0 and _reserve > 0:
        _auto_reload_delay = 0.28

func _compute_cone() -> float:
    var cone: float = float(_def["spread_base"]) + _spread
    var horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
    cone += float(_def["spread_move"]) * clampf(horizontal_speed / 7.0, 0.0, 1.3)
    if not _player.is_on_floor():
        cone += float(_def["spread_air"])
    if _player.has_method("is_crouch_active") and bool(_player.call("is_crouch_active")):
        cone *= float(_def["crouch_spread_multiplier"])
    if _player.has_method("is_zoomed") and bool(_player.call("is_zoomed")):
        cone *= 0.6
    _last_cone = cone
    return cone

func _fire_shot() -> void:
    var origin: Vector3 = _camera.global_position
    var basis: Basis = _camera.global_transform.basis
    var forward: Vector3 = -basis.z
    var cone: float = _compute_cone()
    var pellets: int = maxi(1, int(_def["pellets"]))
    var pellet_spread: float = float(_def["pellet_spread"])
    var max_range: float = float(_def["range"])
    var tracer_speed: float = float(_def["tracer_speed"])
    var base_damage: float = float(_def["damage"]) * _damage_multiplier

    var muzzle: Vector3 = origin + forward * 0.9 + basis.x * 0.12 - basis.y * 0.1
    if _viewmodel != null and _viewmodel.has_method("get_muzzle_global_position"):
        muzzle = _viewmodel.call("get_muzzle_global_position")
    if _player.has_method("is_third_person") and bool(_player.call("is_third_person")):
        muzzle = _player.call("get_third_person_muzzle")

    var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
    var aggregated: Dictionary = {}
    for pellet in range(pellets):
        var angle: float = randf() * TAU
        var radius: float = sqrt(randf()) * (cone + pellet_spread)
        var direction: Vector3 = (forward + basis.x * cos(angle) * radius + basis.y * sin(angle) * radius).normalized()
        var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range, 1)
        query.exclude = [_player.get_rid()]
        query.collide_with_areas = false
        var hit: Dictionary = space.intersect_ray(query)
        var show_tracer: bool = pellet < 3
        if hit.is_empty():
            if show_tracer:
                _fx.spawn_tracer(muzzle, origin + direction * max_range, tracer_speed)
            continue
        var end_point: Vector3 = hit["position"]
        var normal: Vector3 = hit["normal"]
        var collider: Object = hit["collider"]
        var distance: float = origin.distance_to(end_point)
        if show_tracer:
            _fx.spawn_tracer(muzzle, end_point, tracer_speed)
        var falloff: float = lerpf(1.0, float(_def["falloff_min_multiplier"]), clampf(distance / max_range, 0.0, 1.0))
        var damage: float = base_damage * falloff
        if collider != null and collider.has_method("receive_hit"):
            var key: int = collider.get_instance_id()
            if not aggregated.has(key):
                aggregated[key] = {"collider": collider, "damage": 0.0, "position": end_point, "normal": normal, "direction": direction}
            var entry: Dictionary = aggregated[key]
            entry["damage"] = float(entry["damage"]) + damage
            if pellet < 4:
                _fx.spawn_impact(end_point, normal, true)
        else:
            if collider is RigidBody3D:
                var body := collider as RigidBody3D
                body.apply_impulse(direction * float(_def["impulse"]) / float(pellets), end_point - body.global_position)
            if pellet < 4:
                _fx.spawn_impact(end_point, normal, false)
            if pellet < 3:
                _fx.spawn_hole(end_point, normal, collider as Node)

    var any_headshot: bool = false
    var any_kill: bool = false
    var any_hit: bool = false
    if int(_def.get("chain_targets_max", 0)) > 0:
        # Tesla gun: the bolt arcs from the first victim to the nearest enemies around it.
        var chain_result: Dictionary = _chain_lightning(aggregated, space, base_damage, muzzle)
        any_hit = bool(chain_result.get("hit", false))
        any_kill = bool(chain_result.get("killed", false))
        if any_hit:
            SaveManager.increment_stat("shots_hit")
            hit_confirmed.emit(false, any_kill)
            _play_fx("kill" if any_kill else "hit", -4.0)
        return
    for key in aggregated.keys():
        var entry: Dictionary = aggregated[key]
        var target: Object = entry["collider"]
        if not is_instance_valid(target):
            continue
        var info: Dictionary = {
            "damage": float(entry["damage"]),
            "position": entry["position"],
            "normal": entry["normal"],
            "direction": entry["direction"],
            "source": _player,
            "weapon_id": _current_id,
            "headshot_multiplier": float(_def["headshot_multiplier"]),
        }
        var result: Dictionary = target.call("receive_hit", info)
        any_hit = true
        if bool(result.get("headshot", false)):
            any_headshot = true
        if bool(result.get("killed", false)):
            any_kill = true
    if any_hit:
        SaveManager.increment_stat("shots_hit")
        hit_confirmed.emit(any_headshot, any_kill)
        _play_fx("kill" if any_kill else "hit", -4.0)

func _chain_lightning(aggregated: Dictionary, space: PhysicsDirectSpaceState3D, base_damage: float, muzzle: Vector3) -> Dictionary:
    var first: Node3D = null
    var first_point: Vector3 = Vector3.ZERO
    for key in aggregated.keys():
        var candidate: Object = (aggregated[key] as Dictionary)["collider"]
        if is_instance_valid(candidate) and candidate is Node3D and CombatUtil.is_alive(candidate as Node):
            first = candidate as Node3D
            first_point = (aggregated[key] as Dictionary)["position"]
            break
    var result: Dictionary = {"hit": false, "killed": false}
    if first == null:
        return result
    var count: int = randi_range(int(_def.get("chain_targets_min", 3)), int(_def.get("chain_targets_max", 5)))
    var radius: float = float(_def.get("chain_radius", 9.0))
    var falloff: float = float(_def.get("chain_falloff", 0.85))
    var victims: Array[Node3D] = [first]
    var current: Node3D = first
    while victims.size() < count:
        var best: Node3D = null
        var best_distance: float = radius
        for node in get_tree().get_nodes_in_group("combatants"):
            if not (node is Node3D) or victims.has(node) or node == _player:
                continue
            if not CombatUtil.is_alive(node) or not CombatUtil.is_hostile(_player, node):
                continue
            var distance: float = (node as Node3D).global_position.distance_to(current.global_position)
            if distance < best_distance:
                best_distance = distance
                best = node as Node3D
        if best == null:
            break
        victims.append(best)
        current = best
    var previous_point: Vector3 = muzzle
    var damage: float = base_damage
    for index in range(victims.size()):
        var victim: Node3D = victims[index]
        if not is_instance_valid(victim):
            continue
        var point: Vector3 = first_point if index == 0 else victim.global_position + Vector3(0.0, 1.1, 0.0)
        _fx.spawn_tracer(previous_point, point, 900.0)
        _fx.spawn_impact(point, Vector3.UP, true)
        var info: Dictionary = {
            "damage": damage, "position": point, "normal": Vector3.UP,
            "direction": (point - previous_point).normalized(), "source": _player,
            "weapon_id": _current_id, "headshot_multiplier": 1.0,
        }
        if victim.has_method("receive_hit"):
            var hit_result: Dictionary = victim.call("receive_hit", info)
            result["hit"] = true
            if bool(hit_result.get("killed", false)):
                result["killed"] = true
        previous_point = point
        damage *= falloff
    return result

func start_reload() -> bool:
    if _reloading or _magazine >= _magazine_size or _reserve <= 0:
        return false
    _reloading = true
    _reload_total = float(_def["reload_time"])
    _reload_left = _reload_total
    _reload_stage = 0
    _auto_reload_delay = -1.0
    _fire_buffer = 0.0
    if _viewmodel != null and _viewmodel.has_method("play_reload"):
        _viewmodel.call("play_reload", _reload_total)
    reload_state_changed.emit(true, _reload_total)
    return true

func _update_reload(delta: float) -> void:
    _reload_left -= delta
    var progress := 1.0 - _reload_left / maxf(_reload_total, 0.01)
    if _reload_stage == 0 and progress >= 0.30:
        _reload_stage = 1
        _play_fx("mag_out", -5.0)
    elif _reload_stage == 1 and progress >= 0.62:
        _reload_stage = 2
        _play_fx("mag_in", -4.0)
    elif _reload_stage == 2 and progress >= 0.9:
        _reload_stage = 3
        _play_fx("bolt", -5.0)
    if _reload_left <= 0.0:
        var needed: int = _magazine_size - _magazine
        var taken: int = mini(needed, _reserve)
        _magazine += taken
        _reserve -= taken
        _reloading = false
        reload_state_changed.emit(false, 0.0)
        ammo_changed.emit(_magazine, _reserve, _magazine_size)

func _play_fx(kind: String, volume_db: float) -> void:
    _fx_player.stream = WeaponAudio.get_stream(kind)
    _fx_player.volume_db = volume_db
    _fx_player.play()
