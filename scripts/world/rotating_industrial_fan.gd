extends Node3D
class_name RotatingIndustrialFan

@export_range(0.2, 8.0, 0.1) var spin_speed: float = 2.4
var _rotor: Node3D

func _ready() -> void:
    var housing_material := _make_material(Color("#202a30"), 0.72, 0.52)
    var blade_material := _make_material(Color("#69777b"), 0.5, 0.68)
    var hub_material := _make_emissive(Color("#58d7e8"), 1.25)

    var housing_mesh := CylinderMesh.new()
    housing_mesh.top_radius = 0.46
    housing_mesh.bottom_radius = 0.46
    housing_mesh.height = 0.10
    var housing := MeshInstance3D.new()
    housing.name = "FanHousing"
    housing.mesh = housing_mesh
    housing.material_override = housing_material
    housing.rotation.x = PI * 0.5
    add_child(housing)

    _rotor = Node3D.new()
    _rotor.name = "AnimatedRotor"
    _rotor.position.z = 0.065
    add_child(_rotor)

    for index in range(4):
        var blade_mesh := BoxMesh.new()
        blade_mesh.size = Vector3(0.58, 0.105, 0.035)
        var blade := MeshInstance3D.new()
        blade.name = "Blade_%d" % index
        blade.mesh = blade_mesh
        blade.material_override = blade_material
        blade.position = Vector3(0.0, 0.22, 0.0)
        blade.rotation.z = float(index) * PI * 0.5
        _rotor.add_child(blade)

    var hub_mesh := SphereMesh.new()
    hub_mesh.radius = 0.115
    hub_mesh.height = 0.23
    var hub := MeshInstance3D.new()
    hub.name = "FanHub"
    hub.mesh = hub_mesh
    hub.material_override = hub_material
    _rotor.add_child(hub)

    _add_guard_bar(Vector3(0.0, 0.0, 0.10), Vector3(0.82, 0.025, 0.025), blade_material)
    _add_guard_bar(Vector3(0.0, 0.0, 0.10), Vector3(0.025, 0.82, 0.025), blade_material)

func _process(delta: float) -> void:
    if _rotor != null:
        _rotor.rotation.z = fposmod(_rotor.rotation.z + spin_speed * delta, TAU)

func _add_guard_bar(local_position: Vector3, bar_size: Vector3, material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = bar_size
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = material
    instance.position = local_position
    add_child(instance)

func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func _make_emissive(color: Color, energy: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color.darkened(0.25)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return material
