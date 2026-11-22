extends Node3D
class_name RotatingValveWheel

@export_range(0.0, 0.2, 0.005) var idle_wobble: float = 0.04
var _wheel: Node3D
var _phase: float = 0.0

func _ready() -> void:
    var dark := _mat(Color("#1b272e"), 0.48, 0.74)
    var steel := _mat(Color("#849399"), 0.43, 0.82)
    var amber := _mat(Color("#d99a46"), 0.52, 0.32)
    var hub_mesh := CylinderMesh.new()
    hub_mesh.top_radius = 0.105
    hub_mesh.bottom_radius = 0.105
    hub_mesh.height = 0.11
    var hub := MeshInstance3D.new()
    hub.mesh = hub_mesh
    hub.material_override = amber
    hub.rotation.x = PI * 0.5
    add_child(hub)
    _wheel = Node3D.new()
    _wheel.position.z = 0.055
    add_child(_wheel)
    var ring := TorusMesh.new()
    ring.inner_radius = 0.28
    ring.outer_radius = 0.34
    ring.ring_segments = 24
    ring.rings = 8
    var ring_node := MeshInstance3D.new()
    ring_node.mesh = ring
    ring_node.material_override = steel
    _wheel.add_child(ring_node)
    for index in range(6):
        var spoke := MeshInstance3D.new()
        var spoke_mesh := BoxMesh.new()
        spoke_mesh.size = Vector3(0.065, 0.58, 0.055)
        spoke.mesh = spoke_mesh
        spoke.material_override = dark
        spoke.rotation.z = float(index) * TAU / 6.0
        _wheel.add_child(spoke)
    var grip := MeshInstance3D.new()
    var grip_mesh := BoxMesh.new()
    grip_mesh.size = Vector3(0.11, 0.13, 0.10)
    grip.mesh = grip_mesh
    grip.material_override = amber
    grip.position = Vector3(0.0, 0.34, 0.0)
    _wheel.add_child(grip)

func _process(delta: float) -> void:
    _phase += delta
    if _wheel != null:
        _wheel.rotation.z = sin(_phase * 0.65) * idle_wobble

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material
