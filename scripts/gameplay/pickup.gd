extends Area3D
class_name Pickup

## Small drop left by fallen enemies: health, armor or ammo. Walk over it to collect.

var kind: String = "health"
var _time: float = 0.0
var _life: float = 28.0
var _visual: Node3D

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    var shape_node := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 1.0
    shape_node.shape = shape
    shape_node.position = Vector3(0.0, 0.6, 0.0)
    add_child(shape_node)
    _visual = Node3D.new()
    _visual.position = Vector3(0.0, 0.55, 0.0)
    add_child(_visual)
    var color := Color("#3ddc84")
    if kind == "armor":
        color = Color("#44b5ee")
    elif kind == "ammo":
        color = Color("#ffc94a")
    elif kind == "supply":
        color = Color("#c77dff")
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.4
    material.roughness = 0.4
    var body := MeshInstance3D.new()
    body.mesh = BevelMesh.box(Vector3(0.34, 0.26, 0.34), 0.04)
    body.material_override = material
    body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _visual.add_child(body)
    var white := StandardMaterial3D.new()
    white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    white.albedo_color = Color(1, 1, 1)
    for size in [Vector3(0.2, 0.06, 0.02), Vector3(0.06, 0.2, 0.02)]:
        for z_sign in [-1.0, 1.0]:
            var mark := MeshInstance3D.new()
            var mark_mesh := BoxMesh.new()
            mark_mesh.size = size
            mark.mesh = mark_mesh
            mark.material_override = white
            mark.position = Vector3(0.0, 0.0, float(z_sign) * 0.175)
            mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            _visual.add_child(mark)
    var light := OmniLight3D.new()
    light.light_color = color
    light.light_energy = 0.6
    light.omni_range = 3.0
    light.shadow_enabled = false
    light.add_to_group("no_shadow")
    _visual.add_child(light)
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    _time += delta
    _life -= delta
    if _life <= 0.0:
        queue_free()
        return
    _visual.rotation.y += delta * 1.8
    _visual.position.y = 0.55 + sin(_time * 3.0) * 0.08
    if _life < 5.0:
        _visual.visible = int(_life * 6.0) % 2 == 0

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player_controller"):
        return
    if body.has_method("is_dead") and bool(body.call("is_dead")):
        return
    var health := body.get_node_or_null("HealthComponent") as HealthComponent
    var weapon := body.get_node_or_null("WeaponController")
    var used: bool = false
    match kind:
        "health":
            if health != null and health.current_health < health.max_health:
                health.restore(40.0)
                used = true
        "armor":
            if health != null and health.current_armor < health.max_armor:
                health.add_armor(35.0)
                used = true
        "ammo":
            if weapon != null and weapon.has_method("give_ammo_pack"):
                weapon.call("give_ammo_pack")
                used = true
        "supply":
            # Rare crate: full guns, 4 grenades and 4 traps.
            if weapon != null and weapon.has_method("refill"):
                weapon.call("refill")
                used = true
            var gadgets := body.get_node_or_null("Gadgets") as GadgetController
            if gadgets != null:
                gadgets.refill()
                used = true
    if not used:
        return
    var player := AudioStreamPlayer.new()
    player.stream = WeaponAudio.get_stream("pickup")
    player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
    get_tree().root.add_child(player)
    player.finished.connect(player.queue_free)
    player.play()
    queue_free()
