extends Node3D
class_name BulletEffects

## Visible, moving tracer bullets, impact sparks and PERMANENT bullet holes.
## Everything is pooled / capped so long fights do not leak nodes or hurt frame time.

const TRACER_POOL: int = 14
const SPARK_POOL: int = 10
const MAX_HOLES: int = 90
const TRACER_LENGTH: float = 3.2

class Tracer extends RefCounted:
    var node: MeshInstance3D
    var head_node: MeshInstance3D
    var from_point: Vector3
    var to_point: Vector3
    var distance: float = 0.0
    var travelled: float = 0.0
    var speed: float = 200.0
    var active: bool = false

var _tracers: Array[Tracer] = []
var _tracer_cursor: int = 0
var _sparks: Array[CPUParticles3D] = []
var _spark_cursor: int = 0
var _holes: Array[Node3D] = []
var _tracer_material: StandardMaterial3D
var _head_material: StandardMaterial3D
var _spark_material: StandardMaterial3D
var _hole_material: StandardMaterial3D
var _hole_ring_material: StandardMaterial3D
var _hole_mesh: CylinderMesh
var _ring_mesh: CylinderMesh
var _crack_mesh: BoxMesh

func _ready() -> void:
    top_level = true
    global_transform = Transform3D.IDENTITY
    _tracer_material = StandardMaterial3D.new()
    _tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _tracer_material.albedo_color = Color(1.0, 0.72, 0.28, 0.95)
    _tracer_material.emission_enabled = true
    _tracer_material.emission = Color(1.0, 0.6, 0.18)
    _tracer_material.emission_energy_multiplier = 3.0
    _tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _head_material = StandardMaterial3D.new()
    _head_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _head_material.albedo_color = Color(1.0, 0.95, 0.75)
    _head_material.emission_enabled = true
    _head_material.emission = Color(1.0, 0.9, 0.6)
    _head_material.emission_energy_multiplier = 4.0
    _spark_material = StandardMaterial3D.new()
    _spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _spark_material.vertex_color_use_as_albedo = true
    _hole_material = StandardMaterial3D.new()
    _hole_material.albedo_color = Color(0.015, 0.015, 0.018)
    _hole_material.roughness = 1.0
    _hole_ring_material = StandardMaterial3D.new()
    _hole_ring_material.albedo_color = Color(0.09, 0.09, 0.1)
    _hole_ring_material.roughness = 1.0
    _hole_mesh = CylinderMesh.new()
    _hole_mesh.top_radius = 0.022
    _hole_mesh.bottom_radius = 0.022
    _hole_mesh.height = 0.004
    _hole_mesh.radial_segments = 12
    _hole_mesh.rings = 1
    _ring_mesh = CylinderMesh.new()
    _ring_mesh.top_radius = 0.05
    _ring_mesh.bottom_radius = 0.05
    _ring_mesh.height = 0.003
    _ring_mesh.radial_segments = 14
    _ring_mesh.rings = 1
    _crack_mesh = BoxMesh.new()
    _crack_mesh.size = Vector3(0.09, 0.002, 0.004)

    for i in range(TRACER_POOL):
        var tracer := Tracer.new()
        var streak := MeshInstance3D.new()
        var streak_mesh := BoxMesh.new()
        streak_mesh.size = Vector3(0.018, 0.018, 1.0)
        streak.mesh = streak_mesh
        streak.material_override = _tracer_material
        streak.visible = false
        streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(streak)
        var head := MeshInstance3D.new()
        var head_mesh := SphereMesh.new()
        head_mesh.radius = 0.028
        head_mesh.height = 0.056
        head_mesh.radial_segments = 8
        head_mesh.rings = 4
        head.mesh = head_mesh
        head.material_override = _head_material
        head.visible = false
        head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(head)
        tracer.node = streak
        tracer.head_node = head
        _tracers.append(tracer)

    for i in range(SPARK_POOL):
        var sparks := CPUParticles3D.new()
        sparks.amount = 10
        sparks.lifetime = 0.35
        sparks.one_shot = true
        sparks.emitting = false
        sparks.explosiveness = 1.0
        sparks.direction = Vector3.UP
        sparks.spread = 55.0
        sparks.initial_velocity_min = 2.0
        sparks.initial_velocity_max = 5.5
        sparks.gravity = Vector3(0.0, -9.0, 0.0)
        sparks.scale_amount_min = 0.7
        sparks.scale_amount_max = 1.4
        var spark_mesh := SphereMesh.new()
        spark_mesh.radius = 0.012
        spark_mesh.height = 0.024
        spark_mesh.radial_segments = 4
        spark_mesh.rings = 2
        sparks.mesh = spark_mesh
        sparks.material_override = _spark_material
        add_child(sparks)
        _sparks.append(sparks)

func spawn_tracer(from_point: Vector3, to_point: Vector3, speed: float) -> void:
    var tracer := _tracers[_tracer_cursor]
    _tracer_cursor = (_tracer_cursor + 1) % _tracers.size()
    tracer.from_point = from_point
    tracer.to_point = to_point
    tracer.distance = maxf(from_point.distance_to(to_point), 0.01)
    tracer.travelled = 0.0
    tracer.speed = speed
    tracer.active = true
    tracer.node.visible = true
    tracer.head_node.visible = true
    _update_tracer(tracer)

func spawn_impact(point: Vector3, normal: Vector3, is_target: bool) -> void:
    var sparks := _sparks[_spark_cursor]
    _spark_cursor = (_spark_cursor + 1) % _sparks.size()
    sparks.global_position = point + normal * 0.02
    sparks.direction = normal
    var color := Color(1.0, 0.25, 0.2) if is_target else Color(1.0, 0.78, 0.4)
    sparks.color = color
    sparks.restart()
    sparks.emitting = true

func spawn_hole(point: Vector3, normal: Vector3, parent_body: Node) -> void:
    var hole := Node3D.new()
    hole.name = "BulletHole"
    var core := MeshInstance3D.new()
    core.mesh = _hole_mesh
    core.material_override = _hole_material
    core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    core.position = Vector3(0.0, 0.003, 0.0)
    hole.add_child(core)
    var ring := MeshInstance3D.new()
    ring.mesh = _ring_mesh
    ring.material_override = _hole_ring_material
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ring.position = Vector3(0.0, 0.0015, 0.0)
    hole.add_child(ring)
    # Two short cracks make the mark read as a real impact, not a sticker.
    for k in range(3):
        var crack := MeshInstance3D.new()
        crack.mesh = _crack_mesh
        crack.material_override = _hole_material
        crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        crack.rotation.y = float(k) * 1.05 + randf() * 0.4
        crack.position = Vector3(0.0, 0.004, 0.0)
        hole.add_child(crack)

    var host: Node = self
    var is_static_world: bool = parent_body != null and parent_body.get_class() == "StaticBody3D"
    if parent_body != null and not is_static_world and parent_body is Node3D:
        host = parent_body
    host.add_child(hole)
    var up := normal.normalized()
    var reference := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
    var x_axis := up.cross(reference).normalized()
    var z_axis := x_axis.cross(up).normalized()
    hole.global_transform = Transform3D(Basis(x_axis, up, z_axis), point + up * 0.008)
    _holes.append(hole)
    while _holes.size() > MAX_HOLES:
        var oldest: Node3D = _holes.pop_front()
        if is_instance_valid(oldest):
            oldest.queue_free()

func clear_holes() -> void:
    for hole in _holes:
        if is_instance_valid(hole):
            hole.queue_free()
    _holes.clear()

func get_hole_count() -> int:
    var count: int = 0
    for hole in _holes:
        if is_instance_valid(hole):
            count += 1
    return count

func _process(delta: float) -> void:
    for tracer in _tracers:
        if not tracer.active:
            continue
        tracer.travelled += tracer.speed * delta
        if tracer.travelled >= tracer.distance + TRACER_LENGTH:
            tracer.active = false
            tracer.node.visible = false
            tracer.head_node.visible = false
            continue
        _update_tracer(tracer)

func _update_tracer(tracer: Tracer) -> void:
    var direction := (tracer.to_point - tracer.from_point) / tracer.distance
    var head_distance := minf(tracer.travelled, tracer.distance)
    var tail_distance := maxf(tracer.travelled - TRACER_LENGTH, 0.0)
    var length := head_distance - tail_distance
    if length <= 0.01:
        tracer.node.visible = false
        tracer.head_node.visible = tracer.travelled < tracer.distance
        tracer.head_node.global_position = tracer.from_point + direction * head_distance
        return
    tracer.node.visible = true
    var head_point := tracer.from_point + direction * head_distance
    var tail_point := tracer.from_point + direction * tail_distance
    var up_vector := Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT
    var aim_basis := Basis.looking_at(direction, up_vector) * Basis.from_scale(Vector3(1.0, 1.0, length))
    tracer.node.global_transform = Transform3D(aim_basis, (head_point + tail_point) * 0.5)
    tracer.head_node.visible = tracer.travelled < tracer.distance
    tracer.head_node.global_position = head_point
