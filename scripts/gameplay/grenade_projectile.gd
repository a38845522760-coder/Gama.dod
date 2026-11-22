extends Node3D
class_name GrenadeProjectile

## Thrown grenade: arcs under gravity, bounces off geometry, explodes after the fuse and
## damages every hostile fighter in the blast radius (falling off with distance).

var thrower: Node = null
var velocity: Vector3 = Vector3.ZERO
var _fuse: float = 2.2
var _mesh: MeshInstance3D

func _ready() -> void:
    _mesh = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.11
    sphere.height = 0.22
    _mesh.mesh = sphere
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#2d3a26")
    material.roughness = 0.5
    material.emission_enabled = true
    material.emission = Color("#ff3b2e")
    material.emission_energy_multiplier = 0.6
    _mesh.material_override = material
    add_child(_mesh)

func _physics_process(delta: float) -> void:
    _fuse -= delta
    if _fuse <= 0.0:
        _explode()
        return
    velocity.y -= 18.0 * delta
    var from_point: Vector3 = global_position
    var to_point: Vector3 = from_point + velocity * delta
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from_point, to_point, 1)
    if thrower is CollisionObject3D:
        query.exclude = [(thrower as CollisionObject3D).get_rid()]
    var hit: Dictionary = space.intersect_ray(query)
    if hit.is_empty():
        global_position = to_point
    else:
        var normal: Vector3 = hit["normal"]
        global_position = (hit["position"] as Vector3) + normal * 0.12
        velocity = velocity.bounce(normal) * 0.45
        if velocity.length() < 1.2:
            velocity = Vector3.ZERO
    _mesh.visible = int(_fuse * 8.0) % 2 == 0 or _fuse > 1.0

func _explode() -> void:
    var center: Vector3 = global_position + Vector3(0.0, 0.3, 0.0)
    for node in get_tree().get_nodes_in_group("combatants"):
        if not (node is Node3D) or not CombatUtil.is_alive(node):
            continue
        if thrower != null and not CombatUtil.is_hostile(thrower, node):
            continue
        var target_point: Vector3 = (node as Node3D).global_position + Vector3(0.0, 0.9, 0.0)
        var distance: float = center.distance_to(target_point)
        if distance > GadgetController.GRENADE_RADIUS:
            continue
        var amount: float = GadgetController.GRENADE_DAMAGE * (1.0 - distance / GadgetController.GRENADE_RADIUS * 0.8)
        var direction: Vector3 = (target_point - center).normalized()
        CombatUtil.apply_damage(node, amount, thrower, {
            "position": target_point, "direction": direction, "normal": -direction,
            "weapon_id": "grenade", "headshot_multiplier": 1.0,
        })
    var flash := OmniLight3D.new()
    flash.light_color = Color("#ffb04a")
    flash.light_energy = 6.0
    flash.omni_range = 14.0
    flash.shadow_enabled = false
    flash.add_to_group("no_shadow")
    get_parent().add_child(flash)
    flash.global_position = center
    var ball := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    ball.mesh = sphere
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(1.0, 0.6, 0.15, 0.85)
    ball.material_override = material
    ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    get_parent().add_child(ball)
    ball.global_position = center
    ball.scale = Vector3.ONE * 0.5
    var tween := ball.create_tween().set_parallel(true)
    tween.tween_property(ball, "scale", Vector3.ONE * 5.5, 0.35)
    tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
    tween.tween_property(flash, "light_energy", 0.0, 0.45)
    tween.chain().tween_callback(ball.queue_free)
    tween.tween_callback(flash.queue_free)
    var audio := AudioStreamPlayer3D.new()
    audio.stream = WeaponAudio.get_stream("shot")
    audio.pitch_scale = 0.35
    audio.volume_db = 6.0
    audio.max_distance = 150.0
    audio.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
    get_parent().add_child(audio)
    audio.global_position = center
    audio.finished.connect(audio.queue_free)
    audio.play()
    queue_free()
