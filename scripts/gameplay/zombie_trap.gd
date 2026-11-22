extends Node3D
class_name ZombieTrap

## Floor trap: arms after a moment, then snaps shut when an enemy walks close. Everything in
## the trigger area takes heavy damage and is held down (almost stopped) for a few seconds.

const ARM_TIME: float = 1.0
const TRIGGER_RADIUS: float = 1.7
const BLAST_RADIUS: float = 3.2
const DAMAGE: float = 150.0
const SLOW_SECONDS: float = 4.0
const LIFETIME: float = 180.0

var owner_node: Node = null
var _age: float = 0.0
var _check: float = 0.0
var _light: OmniLight3D
var _material: StandardMaterial3D

func _ready() -> void:
    var base := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 0.7
    disc.bottom_radius = 0.7
    disc.height = 0.06
    base.mesh = disc
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color("#1a1d1f")
    dark.metallic = 0.7
    dark.roughness = 0.5
    base.material_override = dark
    base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(base)
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.52
    torus.outer_radius = 0.66
    ring.mesh = torus
    ring.position.y = 0.04
    ring.scale = Vector3(1.0, 0.3, 1.0)
    _material = StandardMaterial3D.new()
    _material.albedo_color = Color("#ff3b2e")
    _material.emission_enabled = true
    _material.emission = Color("#ff3b2e")
    _material.emission_energy_multiplier = 1.5
    ring.material_override = _material
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ring)
    _light = OmniLight3D.new()
    _light.light_color = Color("#ff3b2e")
    _light.light_energy = 0.5
    _light.omni_range = 3.5
    _light.position.y = 0.3
    _light.shadow_enabled = false
    _light.add_to_group("no_shadow")
    add_child(_light)

func _physics_process(delta: float) -> void:
    _age += delta
    if _age >= LIFETIME:
        queue_free()
        return
    var armed: bool = _age >= ARM_TIME
    var blink: float = 0.4 + 0.6 * absf(sin(_age * (6.0 if armed else 14.0)))
    _material.emission_energy_multiplier = 1.5 * blink
    _light.light_energy = 0.8 * blink
    if not armed:
        return
    _check -= delta
    if _check > 0.0:
        return
    _check = 0.08
    for node in get_tree().get_nodes_in_group("combatants"):
        if not (node is Node3D) or not CombatUtil.is_alive(node):
            continue
        if owner_node != null and not CombatUtil.is_hostile(owner_node, node):
            continue
        if (node as Node3D).global_position.distance_to(global_position) <= TRIGGER_RADIUS:
            _snap()
            return

func _snap() -> void:
    for node in get_tree().get_nodes_in_group("combatants"):
        if not (node is Node3D) or not CombatUtil.is_alive(node):
            continue
        if owner_node != null and not CombatUtil.is_hostile(owner_node, node):
            continue
        var target := node as Node3D
        if target.global_position.distance_to(global_position) > BLAST_RADIUS:
            continue
        var direction: Vector3 = (target.global_position - global_position).normalized()
        CombatUtil.apply_damage(target, DAMAGE, owner_node, {
            "position": target.global_position + Vector3(0.0, 0.5, 0.0), "direction": direction,
            "normal": -direction, "weapon_id": "trap", "headshot_multiplier": 1.0,
        })
        if is_instance_valid(target) and target.has_method("apply_slow"):
            target.call("apply_slow", 0.12, SLOW_SECONDS)
    var flash := OmniLight3D.new()
    flash.light_color = Color("#ff5a3c")
    flash.light_energy = 4.0
    flash.omni_range = 8.0
    flash.shadow_enabled = false
    flash.add_to_group("no_shadow")
    get_parent().add_child(flash)
    flash.global_position = global_position + Vector3(0.0, 0.5, 0.0)
    var tween := flash.create_tween()
    tween.tween_property(flash, "light_energy", 0.0, 0.4)
    tween.tween_callback(flash.queue_free)
    queue_free()
