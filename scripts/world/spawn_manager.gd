extends Node
class_name SpawnManager

## Scene-scoped spawn selector. It prefers points with a clear player-sized capsule,
## then tries a small set of nearby offsets before using a documented fallback.

const PLAYER_CAPSULE_RADIUS: float = 0.36
const PLAYER_CAPSULE_HEIGHT: float = 1.82
const SPAWN_OFFSETS: Array[Vector3] = [
    Vector3.ZERO,
    Vector3(0.0, 0.0, 0.95),
    Vector3(0.95, 0.0, 0.0),
    Vector3(-0.95, 0.0, 0.0),
    Vector3(0.0, 0.0, -0.95),
]

var _next_index: int = 0
var _spawn_capsule: CapsuleShape3D
var _spawn_query: PhysicsShapeQueryParameters3D

func _ready() -> void:
    _spawn_capsule = CapsuleShape3D.new()
    _spawn_capsule.radius = PLAYER_CAPSULE_RADIUS
    _spawn_capsule.height = PLAYER_CAPSULE_HEIGHT
    _spawn_query = PhysicsShapeQueryParameters3D.new()
    _spawn_query.shape = _spawn_capsule
    _spawn_query.collision_mask = 1
    _spawn_query.collide_with_bodies = true
    _spawn_query.collide_with_areas = false
    _spawn_query.margin = 0.001

func get_spawn_points(team_id: String = "") -> Array[Node3D]:
    var result: Array[Node3D] = []
    for node in get_tree().get_nodes_in_group("spawn_points"):
        if not (node is Node3D):
            continue
        if team_id.is_empty() or str(node.get("team_id")) == team_id:
            result.append(node)
    result.sort_custom(func(a: Node3D, b: Node3D) -> bool: return str(a.get("spawn_id")) < str(b.get("spawn_id")))
    return result

func get_next_spawn_transform(team_id: String = "") -> Transform3D:
    var points := get_spawn_points(team_id)
    if points.is_empty():
        return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 12.0))

    var start_index := _next_index % points.size()
    for point_offset in range(points.size()):
        var point_index := (start_index + point_offset) % points.size()
        var point := points[point_index]
        var base_transform := point.global_transform
        for local_offset in SPAWN_OFFSETS:
            var candidate := base_transform
            candidate.origin += base_transform.basis * local_offset
            if _is_spawn_transform_clear(candidate):
                _next_index = (point_index + 1) % points.size()
                return candidate

    # A fallback is still returned so the session can initialize, but the warning
    # makes an authored spawn-layout problem visible instead of silently hiding it.
    push_warning("No fully clear spawn capsule was found; using the next authored spawn point.")
    _next_index = (start_index + 1) % points.size()
    return points[start_index].global_transform

func _is_spawn_transform_clear(candidate: Transform3D) -> bool:
    if _spawn_query == null or get_viewport() == null or get_viewport().world_3d == null:
        return true
    var query_transform := candidate
    query_transform.origin += candidate.basis.y * (PLAYER_CAPSULE_HEIGHT * 0.5)
    _spawn_query.transform = query_transform
    var overlaps := get_viewport().world_3d.direct_space_state.intersect_shape(_spawn_query, 12)
    return overlaps.is_empty()
