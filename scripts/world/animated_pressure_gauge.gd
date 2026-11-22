extends Node3D
class_name AnimatedPressureGauge

@export var phase_offset: float = 0.0
var _needle: Node3D
var _phase: float = 0.0

func _ready() -> void:
    var casing := _mat(Color("#1b272d"), 0.42, 0.76)
    var face := _mat(Color("#cbd5d4"), 0.86, 0.04)
    var body_mesh := CylinderMesh.new()
    body_mesh.top_radius = 0.28
    body_mesh.bottom_radius = 0.28
    body_mesh.height = 0.105
    var body := MeshInstance3D.new()
    body.mesh = body_mesh
    body.material_override = casing
    body.rotation.x = PI * 0.5
    add_child(body)
    var face_mesh := CylinderMesh.new()
    face_mesh.top_radius = 0.235
    face_mesh.bottom_radius = 0.235
    face_mesh.height = 0.012
    var face_node := MeshInstance3D.new()
    face_node.mesh = face_mesh
    face_node.material_override = face
    face_node.rotation.x = PI * 0.5
    face_node.position.z = -0.06
    add_child(face_node)
    for index in range(9):
        var tick := MeshInstance3D.new()
        var tick_mesh := BoxMesh.new()
        tick_mesh.size = Vector3(0.012, 0.038, 0.009)
        tick.mesh = tick_mesh
        tick.material_override = casing
        var angle := -PI * 0.78 + float(index) * PI * 0.195
        tick.position = Vector3(sin(angle) * 0.185, cos(angle) * 0.185, -0.072)
        tick.rotation.z = -angle
        add_child(tick)
    _needle = Node3D.new()
    _needle.position.z = -0.078
    add_child(_needle)
    var needle := MeshInstance3D.new()
    var needle_mesh := BoxMesh.new()
    needle_mesh.size = Vector3(0.012, 0.17, 0.009)
    needle.mesh = needle_mesh
    needle.material_override = _mat(Color("#c34f36"), 0.48, 0.12)
    needle.position.y = 0.062
    _needle.add_child(needle)
    var hub := MeshInstance3D.new()
    var hub_mesh := SphereMesh.new()
    hub_mesh.radius = 0.024
    hub_mesh.height = 0.048
    hub.mesh = hub_mesh
    hub.material_override = casing
    _needle.add_child(hub)

func _process(delta: float) -> void:
    _phase += delta
    if _needle != null:
        var gauge_value := 0.5 + 0.25 * sin(_phase * 0.38 + phase_offset) + 0.035 * sin(_phase * 2.1 + phase_offset)
        var target_angle := lerpf(-1.12, 1.12, gauge_value)
        _needle.rotation.z = lerp_angle(_needle.rotation.z, target_angle, 1.0 - exp(-4.0 * delta))

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material
