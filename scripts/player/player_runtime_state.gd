extends RefCounted
class_name PlayerRuntimeState

## Lightweight per-player runtime data. Do not use as a persistent save format.

var player_id: String = "local"
var team_id: String = ""
var health: float = 100.0
var max_health: float = 100.0
var is_active: bool = true
var is_local: bool = true
var score: int = 0
var movement_state: StringName = &"idle"

func set_health(value: float) -> void:
    health = clampf(value, 0.0, max_health)
    is_active = health > 0.0

func to_public_dictionary() -> Dictionary:
    return {
        "player_id": player_id,
        "team_id": team_id,
        "health": health,
        "max_health": max_health,
        "is_active": is_active,
        "is_local": is_local,
        "score": score,
        "movement_state": String(movement_state),
    }
