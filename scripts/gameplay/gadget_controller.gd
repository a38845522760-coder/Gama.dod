extends Node
class_name GadgetController

## Throwables for wave modes: grenades (X) and floor traps (C). The player carries at most
## MAX_COUNT of each. They are refilled after every fifth wave and by rare supply drops.

signal counts_changed(grenades: int, traps: int)

const MAX_COUNT: int = 4
const GRENADE_RADIUS: float = 7.5
const GRENADE_DAMAGE: float = 190.0

var grenades: int = MAX_COUNT
var traps: int = MAX_COUNT
var _player: CharacterBody3D
var _camera: Camera3D
var _cooldown: float = 0.0

func setup(player: CharacterBody3D) -> void:
    _player = player
    _camera = player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
    _ensure_actions()
    counts_changed.emit(grenades, traps)

func _ensure_actions() -> void:
    for pair in [["throw_grenade", KEY_X], ["place_trap", KEY_C]]:
        var action: String = str(pair[0])
        if not InputMap.has_action(action):
            InputMap.add_action(action)
            var event := InputEventKey.new()
            event.physical_keycode = int(pair[1]) as Key
            InputMap.action_add_event(action, event)

func refill() -> void:
    grenades = MAX_COUNT
    traps = MAX_COUNT
    counts_changed.emit(grenades, traps)

## Supply drop from a zombie: tops both up.
func add_pack() -> void:
    refill()

func _process(delta: float) -> void:
    if _player == null or _camera == null:
        return
    _cooldown = maxf(0.0, _cooldown - delta)
    if bool(_player.call("is_dead")) or _cooldown > 0.0:
        return
    if Input.is_action_just_pressed("throw_grenade"):
        request_grenade()
    elif Input.is_action_just_pressed("place_trap"):
        request_trap()

func request_grenade() -> bool:
    if grenades <= 0 or _player == null or _camera == null:
        return false
    grenades -= 1
    _cooldown = 0.6
    var projectile := GrenadeProjectile.new()
    projectile.thrower = _player
    projectile.velocity = -_camera.global_transform.basis.z * 17.0 + Vector3.UP * 4.5 + _player.velocity * 0.4
    _player.get_parent().add_child(projectile)
    projectile.global_position = _camera.global_position + (-_camera.global_transform.basis.z) * 0.8
    counts_changed.emit(grenades, traps)
    return true

func request_trap() -> bool:
    if traps <= 0 or _player == null:
        return false
    var forward: Vector3 = -_player.global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var from_point: Vector3 = _player.global_position + forward * 1.8 + Vector3.UP * 1.5
    var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from_point, from_point + Vector3.DOWN * 4.0, 1)
    query.exclude = [_player.get_rid()]
    var hit: Dictionary = space.intersect_ray(query)
    if hit.is_empty():
        return false
    traps -= 1
    _cooldown = 0.5
    var trap := ZombieTrap.new()
    trap.owner_node = _player
    _player.get_parent().add_child(trap)
    trap.global_position = (hit["position"] as Vector3) + Vector3(0.0, 0.03, 0.0)
    counts_changed.emit(grenades, traps)
    return true
