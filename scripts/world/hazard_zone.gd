extends Area3D
class_name HazardZone

## Floor hazard that damages the local player each second. Used to test health, armor,
## death and respawn without needing enemy AI.

@export var damage_per_second: float = 22.0
@export var zone_size: Vector3 = Vector3(4.0, 0.2, 4.0)

var _bodies: Array[Node] = []
var _pulse: float = 0.0
var _material: StandardMaterial3D

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    monitorable = false
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(zone_size.x, 1.6, zone_size.z)
    shape_node.shape = shape
    shape_node.position = Vector3(0.0, 0.8, 0.0)
    add_child(shape_node)
    _material = StandardMaterial3D.new()
    _material.albedo_color = Color(0.9, 0.2, 0.1)
    _material.emission_enabled = true
    _material.emission = Color(1.0, 0.25, 0.1)
    _material.emission_energy_multiplier = 1.2
    var floor_mesh := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(zone_size.x, 0.03, zone_size.z)
    floor_mesh.mesh = mesh
    floor_mesh.material_override = _material
    floor_mesh.position = Vector3(0.0, 0.016, 0.0)
    add_child(floor_mesh)
    # Hazard stripes along the edges.
    var stripe := StandardMaterial3D.new()
    stripe.albedo_color = Color("#151a1d")
    for k in range(6):
        var bar := MeshInstance3D.new()
        var bar_mesh := BoxMesh.new()
        bar_mesh.size = Vector3(zone_size.x * 0.12, 0.034, zone_size.z)
        bar.mesh = bar_mesh
        bar.material_override = stripe
        bar.position = Vector3(-zone_size.x * 0.45 + float(k) * zone_size.x * 0.18, 0.018, 0.0)
        add_child(bar)
    body_entered.connect(func(body: Node) -> void:
        if body.is_in_group("player_controller") and not _bodies.has(body):
            _bodies.append(body))
    body_exited.connect(func(body: Node) -> void: _bodies.erase(body))

func _physics_process(delta: float) -> void:
    _pulse += delta * 4.0
    _material.emission_energy_multiplier = 1.0 + 0.6 * sin(_pulse)
    for body in _bodies:
        if not is_instance_valid(body):
            continue
        var health := body.get_node_or_null("HealthComponent") as HealthComponent
        if health != null and health.is_alive():
            health.apply_damage(damage_per_second * delta, self)
