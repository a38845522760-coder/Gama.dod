extends Node
class_name SessionHelper

## Per-session glue shared by playable maps: score and credits from kills, respawn flow
## after death, and recovery when the player falls out of the world.

var _player: CharacterBody3D
var _spawn_manager: Node
var _score: int = 0

func setup(player: CharacterBody3D, spawn_manager: Node, mode_id: String) -> void:
    _player = player
    _spawn_manager = spawn_manager
    _player.connect("died", Callable(self, "_on_player_died"))
    EventBus.target_destroyed.connect(_on_target_destroyed)
    AppState.begin_session(mode_id)

func get_score() -> int:
    return _score

func _exit_tree() -> void:
    AppState.end_session()
    SaveManager.flush()

func _physics_process(_delta: float) -> void:
    if is_instance_valid(_player) and not bool(_player.call("is_dead")) and _player.global_position.y < -12.0:
        var health := _player.get_node_or_null("HealthComponent") as HealthComponent
        if health != null:
            health.apply_damage(9999.0)

func _on_target_destroyed(points: int, headshot: bool) -> void:
    _score += points
    SaveManager.add_score(points)
    SaveManager.add_credits(maxi(1, points / 5))
    SaveManager.increment_stat("kills")
    if headshot:
        SaveManager.increment_stat("headshots")
    SaveManager.record_best_score(_score)
    EventBus.player_score_changed.emit("local", _score)

func _on_player_died() -> void:
    var delay: float = float(_player.get("respawn_delay"))
    await get_tree().create_timer(delay).timeout
    if not is_instance_valid(_player):
        return
    var spawn_transform: Transform3D = _spawn_manager.call("get_next_spawn_transform", "")
    var managers := get_tree().get_nodes_in_group("mode_manager")
    if not managers.is_empty() and managers[0].has_method("get_player_spawn_transform"):
        spawn_transform = managers[0].call("get_player_spawn_transform")
    _player.call("respawn", spawn_transform)
