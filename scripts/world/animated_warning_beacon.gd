extends Node3D
class_name AnimatedWarningBeacon

@export_range(0.5, 6.0, 0.1) var pulse_speed: float = 2.2
var _phase: float = 0.0
var _warning_light: OmniLight3D
var _dome_material: StandardMaterial3D

func _ready() -> void:
    var base_material := StandardMaterial3D.new()
    base_material.albedo_color = Color("#25323a")
    base_material.metallic = 0.72
    base_material.roughness = 0.48
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.16
    base_mesh.bottom_radius = 0.20
    base_mesh.height = 0.12
    var base := MeshInstance3D.new()
    base.mesh = base_mesh
    base.material_override = base_material
    add_child(base)

    _dome_material = StandardMaterial3D.new()
    _dome_material.albedo_color = Color("#9a4d21")
    _dome_material.emission_enabled = true
    _dome_material.emission = Color("#ff9a36")
    _dome_material.emission_energy_multiplier = 0.4
    _dome_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var dome_mesh := SphereMesh.new()
    dome_mesh.radius = 0.13
    dome_mesh.height = 0.26
    var dome := MeshInstance3D.new()
    dome.name = "BeaconDome"
    dome.mesh = dome_mesh
    dome.material_override = _dome_material
    dome.position.y = 0.12
    dome.scale = Vector3(1.0, 0.72, 1.0)
    add_child(dome)

    _warning_light = OmniLight3D.new()
    _warning_light.position.y = 0.16
    _warning_light.light_color = Color("#ff9a36")
    _warning_light.omni_range = 4.8
    _warning_light.shadow_enabled = false
    add_child(_warning_light)

func _process(delta: float) -> void:
    _phase = fposmod(_phase + delta * pulse_speed, TAU)
    var pulse := maxf(0.0, sin(_phase))
    if _warning_light != null:
        _warning_light.light_energy = 0.06 + pulse * 0.58
    if _dome_material != null:
        _dome_material.emission_energy_multiplier = 0.35 + pulse * 2.1
