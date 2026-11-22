extends Marker3D
class_name SpawnPoint

@export var spawn_id: String = "default"
@export var team_id: String = ""

func _ready() -> void:
    add_to_group("spawn_points")
