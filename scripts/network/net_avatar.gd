extends CharacterBody3D
class_name NetAvatar

## Stand-in for another human player in a multiplayer match. It shows the jointed soldier,
## can be shot, and forwards damage to the real owner through NetGame.

var peer_id: int = 0
var display_name: String = "Player"
var alive: bool = true
var max_health: float = 100.0

var _rig: PlayerRig
var _target_position: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _pitch: float = 0.0
var _speed: float = 0.0
var _crouch: float = 0.0
var _prone: float = 0.0
var _sliding: bool = false
var _has_state: bool = false
var _label: Label3D

func setup(new_peer_id: int, new_name: String, team_name: String) -> void:
    peer_id = new_peer_id
    display_name = new_name
    set_meta("team", team_name)
    set_meta("display_name", new_name)
    set_meta("net_peer", new_peer_id)
    collision_layer = 1
    collision_mask = 0
    add_to_group("combatants")
    var shape_node := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.8
    shape_node.shape = capsule
    shape_node.position = Vector3(0.0, 0.9, 0.0)
    shape_node.name = "Shape"
    add_child(shape_node)
    _rig = PlayerRig.new()
    _rig.name = "Rig"
    add_child(_rig)
    _rig.build(Color("#2f5d8a"), Color("#e8e8e8"))
    _label = Label3D.new()
    _label.text = new_name
    _label.font_size = 56
    _label.pixel_size = 0.005
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.no_depth_test = true
    _label.modulate = Color(0.55, 0.9, 1.0)
    _label.outline_size = 8
    _label.position = Vector3(0.0, 2.15, 0.0)
    add_child(_label)

func net_set_state(state: Array) -> void:
    if state.size() < 8:
        return
    _target_position = state[0] as Vector3
    _target_yaw = float(state[1])
    _pitch = float(state[2])
    _speed = float(state[3])
    _crouch = float(state[4])
    _prone = float(state[5])
    _sliding = bool(state[6])
    var now_alive: bool = bool(state[7])
    if not _has_state:
        global_position = _target_position
        rotation.y = _target_yaw
        _has_state = true
    if now_alive != alive:
        alive = now_alive
        _rig.visible = alive
        _label.visible = alive
        (get_node("Shape") as CollisionShape3D).disabled = not alive
        if alive:
            add_to_group("combatants")
            global_position = _target_position
        else:
            remove_from_group("combatants")

func _process(delta: float) -> void:
    if not _has_state or not alive:
        return
    global_position = global_position.lerp(_target_position, 1.0 - exp(-16.0 * delta))
    rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-14.0 * delta))
    _rig.update_pose(delta, _speed, _crouch, _prone, _sliding, _pitch, true)

func is_alive() -> bool:
    return alive

func receive_hit(info: Dictionary) -> Dictionary:
    if not alive:
        return {"headshot": false, "killed": false}
    var source: Node = info.get("source", null) as Node
    if source != null and not CombatUtil.is_hostile(self, source):
        return {"headshot": false, "killed": false}
    var amount: float = float(info.get("damage", 0.0))
    var hit_position: Vector3 = info.get("position", global_position)
    var headshot: bool = false
    var from_human: bool = source != null and (source.is_in_group("player_controller") or source is NetAvatar)
    if from_human:
        var head_height: float = lerpf(1.5, 0.35, _prone) if _crouch < 0.5 else lerpf(1.1, 0.35, _prone)
        headshot = hit_position.y - global_position.y >= head_height
        if headshot:
            amount *= float(info.get("headshot_multiplier", 2.0))
    NetGame.damage_player(peer_id, amount)
    return {"headshot": headshot, "killed": false}
