extends StaticBody3D
class_name TrainingTarget

## Humanoid training dummy: takes damage, flashes, falls when destroyed and stands back up.
## Weapons talk to it only through receive_hit(info) -> {headshot, killed}.

signal destroyed(points: int, headshot: bool)

@export var max_health: float = 100.0
@export var headshot_multiplier: float = 2.0
@export var head_height: float = 1.46
@export var respawn_delay: float = 4.0
@export var patrol_distance: float = 0.0
@export var patrol_seconds: float = 3.2
@export var base_points: int = 100

var _health: float = 100.0
var _alive: bool = true
var _visual: Node3D
var _body_material: StandardMaterial3D
var _flash: float = 0.0
var _collision: CollisionShape3D
var _patrol_tween: Tween

func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("targets")
    _health = max_health
    _build()
    if patrol_distance > 0.0:
        _start_patrol()

func is_alive() -> bool:
    return _alive

func receive_hit(info: Dictionary) -> Dictionary:
    if not _alive:
        return {"headshot": false, "killed": false}
    var hit_position: Vector3 = info.get("position", global_position)
    var damage: float = float(info.get("damage", 0.0))
    var headshot: bool = hit_position.y - global_position.y >= head_height
    if headshot:
        damage *= headshot_multiplier
    _health -= damage
    _flash = 1.0
    _spawn_damage_number(hit_position, damage, headshot)
    var killed: bool = _health <= 0.0
    if killed:
        _die(headshot)
    return {"headshot": headshot, "killed": killed}

func _process(delta: float) -> void:
    if _flash > 0.0:
        _flash = maxf(0.0, _flash - delta * 5.0)
        if _body_material != null:
            _body_material.emission_energy_multiplier = _flash * 2.5

func _die(headshot: bool) -> void:
    _alive = false
    var points := base_points + (50 if headshot else 0)
    destroyed.emit(points, headshot)
    EventBus.target_destroyed.emit(points, headshot)
    _collision.set_deferred("disabled", true)
    var tween := create_tween()
    tween.tween_property(_visual, "rotation:x", -PI * 0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_interval(maxf(respawn_delay - 0.35, 0.2))
    tween.tween_callback(_revive)

func _revive() -> void:
    _health = max_health
    _alive = true
    _collision.disabled = false
    var tween := create_tween()
    tween.tween_property(_visual, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _start_patrol() -> void:
    var origin := position
    _patrol_tween = create_tween().set_loops()
    _patrol_tween.tween_property(self, "position", origin + global_transform.basis.x * patrol_distance, patrol_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _patrol_tween.tween_property(self, "position", origin - global_transform.basis.x * patrol_distance, patrol_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_damage_number(world_point: Vector3, amount: float, headshot: bool) -> void:
    var label := Label3D.new()
    label.text = str(roundi(amount))
    label.font_size = 64 if headshot else 44
    label.pixel_size = 0.006
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.modulate = Color(1.0, 0.35, 0.2) if headshot else Color(1.0, 0.95, 0.7)
    label.outline_size = 10
    label.top_level = true
    add_child(label)
    label.global_position = world_point + Vector3(randf_range(-0.2, 0.2), 0.15, 0.0)
    var tween := create_tween().set_parallel(true)
    tween.tween_property(label, "global_position:y", label.global_position.y + 0.9, 0.7)
    tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
    tween.chain().tween_callback(label.queue_free)

func _build() -> void:
    _collision = CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.8
    _collision.shape = capsule
    _collision.position = Vector3(0.0, 0.9, 0.0)
    add_child(_collision)

    _visual = Node3D.new()
    _visual.name = "Visual"
    add_child(_visual)
    _body_material = StandardMaterial3D.new()
    _body_material.albedo_color = Color("#d9822b")
    _body_material.roughness = 0.6
    _body_material.metallic = 0.25
    _body_material.emission_enabled = true
    _body_material.emission = Color(1.0, 0.3, 0.2)
    _body_material.emission_energy_multiplier = 0.0
    var plate := StandardMaterial3D.new()
    plate.albedo_color = Color("#2b343a")
    plate.roughness = 0.5
    plate.metallic = 0.7
    var white := StandardMaterial3D.new()
    white.albedo_color = Color("#e8eef0")
    white.roughness = 0.7

    _add_mesh(_box_mesh(Vector3(0.52, 0.62, 0.26)), _body_material, Vector3(0, 1.12, 0))
    _add_mesh(_box_mesh(Vector3(0.44, 0.22, 0.24)), plate, Vector3(0, 0.7, 0))
    _add_mesh(_capsule_mesh(0.09, 0.74), plate, Vector3(-0.15, 0.36, 0))
    _add_mesh(_capsule_mesh(0.09, 0.74), plate, Vector3(0.15, 0.36, 0))
    _add_mesh(_capsule_mesh(0.07, 0.6), _body_material, Vector3(-0.35, 1.15, 0))
    _add_mesh(_capsule_mesh(0.07, 0.6), _body_material, Vector3(0.35, 1.15, 0))
    var head := SphereMesh.new()
    head.radius = 0.14
    head.height = 0.28
    _add_mesh(head, white, Vector3(0, 1.62, 0))
    # Bullseye rings on the chest.
    for ring in range(3):
        var disc := CylinderMesh.new()
        disc.top_radius = 0.2 - float(ring) * 0.06
        disc.bottom_radius = disc.top_radius
        disc.height = 0.004
        var ring_material := white if ring % 2 == 0 else plate
        var disc_node := _add_mesh(disc, ring_material, Vector3(0, 1.14, 0.136 + float(ring) * 0.002))
        disc_node.rotation.x = PI * 0.5

func _box_mesh(size: Vector3) -> BoxMesh:
    var mesh := BoxMesh.new()
    mesh.size = size
    return mesh

func _capsule_mesh(radius: float, height: float) -> CapsuleMesh:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 8
    mesh.rings = 3
    return mesh

func _add_mesh(mesh: Mesh, material: Material, local_position: Vector3) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = material
    instance.position = local_position
    _visual.add_child(instance)
    return instance
