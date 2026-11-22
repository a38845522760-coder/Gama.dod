extends Node3D
class_name SoldierModel

## Procedural humanoid used by every AI fighter (soldiers and zombies). It replaces the old
## capsule/box dummy with rounded limbs, a helmet, vest, backpack, boots, a gun in hand,
## a walk cycle, aiming pose, hit flash and a death fall. Feet are at y = 0, facing -Z.

const SKIN_TONES: Array[String] = ["#c99572", "#a97854", "#8a5d3e", "#e0b794"]

static var _material_cache: Dictionary = {}
static var _flash_material: StandardMaterial3D = null

var kind: String = "soldier"
var bulk: float = 1.0

var _meshes: Array[MeshInstance3D] = []
var _torso: Node3D
var _head: Node3D
var _thigh_l: Node3D
var _thigh_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _gun_mount: Node3D
var _gun: Node3D
var _muzzle: Marker3D
var _phase: float = 0.0
var _flash_left: float = 0.0
var _aim_weight: float = 0.0
var _swing_amp: float = 0.0
var _attack_swing: float = 0.0
var _zombie_variant: int = 0
var _is_dead: bool = false
var _eyes: Array[MeshInstance3D] = []

static func _mat(color: Color, roughness: float = 0.85, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
    var key := "%s_%.2f_%.2f_%.2f" % [color.to_html(), roughness, metallic, emission]
    if _material_cache.has(key):
        return _material_cache[key]
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = emission
    _material_cache[key] = material
    return material

static func _get_flash_material() -> StandardMaterial3D:
    if _flash_material == null:
        _flash_material = StandardMaterial3D.new()
        _flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _flash_material.albedo_color = Color(1.0, 0.32, 0.25, 0.55)
        _flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return _flash_material

## look keys: kind, primary, secondary, skin, headgear, bulk, scale, team_color, weapon_id, zombie_variant
func build(look: Dictionary) -> void:
    kind = str(look.get("kind", "soldier"))
    bulk = float(look.get("bulk", 1.0))
    _zombie_variant = int(look.get("zombie_variant", 0))
    var overall_scale: float = float(look.get("scale", 1.0))
    scale = Vector3.ONE * overall_scale
    var primary: Color = look.get("primary", Color("#4a5a3c"))
    var secondary: Color = look.get("secondary", Color("#2b2f33"))
    var skin_color: Color = look.get("skin", Color(SKIN_TONES[randi() % SKIN_TONES.size()]))
    var team_color: Color = look.get("team_color", Color(0, 0, 0, 0))
    var headgear: String = str(look.get("headgear", "helmet"))
    var is_zombie: bool = kind == "zombie"
    var cloth := _mat(primary, 0.88)
    var cloth_dark := _mat(primary.darkened(0.35), 0.9)
    var armor := _mat(secondary, 0.5, 0.35)
    var skin := _mat(skin_color, 0.9)
    var boots := _mat(Color("#17191b"), 0.7, 0.1)

    # ---------------------------------------------------------------- legs
    var pelvis := Node3D.new()
    pelvis.name = "Pelvis"
    pelvis.position = Vector3(0.0, 0.93, 0.0)
    add_child(pelvis)
    _add_box(pelvis, Vector3(0.0, 0.0, 0.0), Vector3(0.36 * bulk, 0.2, 0.22), cloth_dark)
    for side in [-1.0, 1.0]:
        var s: float = side
        var thigh := Node3D.new()
        thigh.name = "ThighL" if s < 0.0 else "ThighR"
        thigh.position = Vector3(s * 0.1 * bulk, -0.04, 0.0)
        pelvis.add_child(thigh)
        _add_capsule(thigh, Vector3(0.0, -0.19, 0.0), 0.078 * bulk, 0.46, cloth)
        var knee := Node3D.new()
        knee.position = Vector3(0.0, -0.4, 0.0)
        thigh.add_child(knee)
        _add_capsule(knee, Vector3(0.0, -0.2, 0.0), 0.064 * bulk, 0.46, cloth)
        _add_box(knee, Vector3(0.0, -0.4, -0.04), Vector3(0.115 * bulk, 0.09, 0.24), boots)
        if not is_zombie:
            _add_box(knee, Vector3(0.0, -0.02, -0.055), Vector3(0.12 * bulk, 0.1, 0.05), armor)
        if s < 0.0:
            _thigh_l = thigh
            _knee_l = knee
        else:
            _thigh_r = thigh
            _knee_r = knee

    # ---------------------------------------------------------------- torso
    _torso = Node3D.new()
    _torso.name = "Torso"
    _torso.position = Vector3(0.0, 1.1, 0.0)
    add_child(_torso)
    _add_box(_torso, Vector3(0.0, 0.2, 0.0), Vector3(0.40 * bulk, 0.5, 0.23), cloth)
    _add_box(_torso, Vector3(0.0, -0.02, 0.0), Vector3(0.38 * bulk, 0.08, 0.24), _mat(Color("#2a241d"), 0.8))
    if not is_zombie:
        _add_box(_torso, Vector3(0.0, 0.29, -0.005), Vector3(0.43 * bulk, 0.33, 0.265), armor)
        _add_box(_torso, Vector3(0.0, 0.34, -0.14), Vector3(0.3 * bulk, 0.1, 0.03), cloth_dark)
        for side in [-1.0, 1.0]:
            var px: float = side
            _add_box(_torso, Vector3(px * 0.12 * bulk, 0.1, -0.15), Vector3(0.09, 0.11, 0.05), cloth_dark)
        _add_box(_torso, Vector3(0.0, 0.26, 0.19), Vector3(0.3 * bulk, 0.34, 0.14), cloth_dark)
        if look.has("team_color"):
            _add_box(_torso, Vector3(0.0, 0.36, 0.265), Vector3(0.22, 0.12, 0.02), _mat(team_color, 0.6, 0.0, 1.4))
    else:
        # Torn shirt, exposed ribs and old blood.
        _add_box(_torso, Vector3(0.1, 0.12, -0.12), Vector3(0.14, 0.2, 0.03), _mat(Color("#5a1b17"), 0.9))
        _add_box(_torso, Vector3(-0.08, 0.32, -0.125), Vector3(0.12, 0.1, 0.03), _mat(Color("#6b2a22"), 0.9))
        _add_box(_torso, Vector3(0.0, 0.05, -0.12), Vector3(0.34 * bulk, 0.06, 0.02), skin)
    var neck := MeshInstance3D.new()
    var neck_mesh := CylinderMesh.new()
    neck_mesh.top_radius = 0.05
    neck_mesh.bottom_radius = 0.055
    neck_mesh.height = 0.1
    neck_mesh.radial_segments = 8
    neck_mesh.rings = 1
    neck.mesh = neck_mesh
    neck.material_override = skin
    neck.position = Vector3(0.0, 0.5, 0.0)
    _register(neck)
    _torso.add_child(neck)

    # ---------------------------------------------------------------- head
    _head = Node3D.new()
    _head.name = "Head"
    _head.position = Vector3(0.0, 0.62, 0.0)
    _torso.add_child(_head)
    _add_sphere(_head, Vector3.ZERO, 0.115, skin, Vector3(0.95, 1.08, 1.0))
    _add_box(_head, Vector3(0.0, -0.075, -0.075), Vector3(0.1, 0.06, 0.06), skin)
    if is_zombie:
        for side in [-1.0, 1.0]:
            var ex: float = side
            var eye := _add_sphere(_head, Vector3(ex * 0.045, 0.02, -0.1), 0.017, _mat(Color("#ffe14a"), 0.4, 0.0, 3.0), Vector3.ONE)
            _eyes.append(eye)
        _add_box(_head, Vector3(0.0, -0.085, -0.095), Vector3(0.07, 0.03, 0.02), _mat(Color("#3a0d0d"), 0.9))
        if _zombie_variant % 2 == 0:
            _add_sphere(_head, Vector3(0.0, 0.1, 0.02), 0.085, _mat(Color("#2d241c"), 1.0), Vector3(1.0, 0.45, 1.0))
    else:
        for side in [-1.0, 1.0]:
            var ex2: float = side
            _add_sphere(_head, Vector3(ex2 * 0.04, 0.012, -0.1), 0.012, _mat(Color("#101010"), 0.5), Vector3.ONE)
    match headgear:
        "helmet":
            _add_sphere(_head, Vector3(0.0, 0.03, 0.0), 0.138, armor, Vector3(1.0, 0.78, 1.04))
            _add_box(_head, Vector3(0.0, 0.0, -0.01), Vector3(0.3, 0.03, 0.3), cloth_dark)
            if look.has("team_color"):
                _add_box(_head, Vector3(0.0, 0.085, -0.02), Vector3(0.05, 0.015, 0.24), _mat(team_color, 0.6, 0.0, 1.6))
        "heavy":
            _add_sphere(_head, Vector3(0.0, 0.03, 0.0), 0.16, armor, Vector3(1.0, 0.85, 1.05))
            _add_box(_head, Vector3(0.0, 0.0, -0.12), Vector3(0.2, 0.05, 0.05), _mat(Color("#41d9ee"), 0.3, 0.0, 2.2))
            _add_box(_head, Vector3(0.0, -0.06, -0.08), Vector3(0.2, 0.08, 0.08), armor)
        "hood":
            _add_sphere(_head, Vector3(0.0, 0.02, 0.02), 0.145, cloth, Vector3(1.0, 1.0, 1.1))
            _add_box(_head, Vector3(0.0, -0.045, -0.1), Vector3(0.17, 0.08, 0.04), _mat(Color("#141414"), 0.9))
        "bandana":
            _add_box(_head, Vector3(0.0, 0.07, 0.0), Vector3(0.25, 0.05, 0.25), _mat(Color("#c0392b"), 0.8))
            _add_box(_head, Vector3(0.0, 0.04, 0.14), Vector3(0.07, 0.1, 0.03), _mat(Color("#c0392b"), 0.8))
        "cap":
            _add_sphere(_head, Vector3(0.0, 0.05, 0.0), 0.12, cloth, Vector3(1.0, 0.55, 1.0))
            _add_box(_head, Vector3(0.0, 0.035, -0.12), Vector3(0.18, 0.02, 0.09), cloth_dark)
        _:
            pass

    # ---------------------------------------------------------------- arms
    for side in [-1.0, 1.0]:
        var s2: float = side
        var shoulder := Node3D.new()
        shoulder.name = "ShoulderL" if s2 < 0.0 else "ShoulderR"
        shoulder.position = Vector3(s2 * 0.255 * bulk, 0.44, 0.0)
        _torso.add_child(shoulder)
        _add_sphere(shoulder, Vector3.ZERO, 0.075 * bulk, armor if not is_zombie else cloth, Vector3.ONE)
        _add_capsule(shoulder, Vector3(0.0, -0.14, 0.0), 0.058 * bulk, 0.34, cloth if not is_zombie else skin)
        var elbow := Node3D.new()
        elbow.position = Vector3(0.0, -0.29, 0.0)
        shoulder.add_child(elbow)
        _add_capsule(elbow, Vector3(0.0, -0.13, 0.0), 0.05 * bulk, 0.32, cloth_dark if not is_zombie else skin)
        _add_sphere(elbow, Vector3(0.0, -0.29, 0.0), 0.052, _mat(Color("#14181b"), 0.9) if not is_zombie else skin, Vector3.ONE)
        if look.has("team_color") and not is_zombie:
            _add_box(shoulder, Vector3(0.0, -0.1, 0.0), Vector3(0.13 * bulk, 0.05, 0.13), _mat(team_color, 0.6, 0.0, 1.5))
        if s2 < 0.0:
            _shoulder_l = shoulder
            _elbow_l = elbow
        else:
            _shoulder_r = shoulder
            _elbow_r = elbow

    _gun_mount = Node3D.new()
    _gun_mount.name = "GunMount"
    _gun_mount.position = Vector3(0.095, 0.265, -0.52)
    _torso.add_child(_gun_mount)
    if not is_zombie:
        set_weapon(str(look.get("weapon_id", "rifle")))
    _apply_pose(0.0, 0.0)

func set_weapon(weapon_id: String) -> void:
    if _gun != null:
        _gun.queue_free()
        _gun = null
        _muzzle = null
    if _gun_mount == null:
        return
    _gun = WeaponModels.build(weapon_id)
    _gun_mount.add_child(_gun)
    _muzzle = WeaponModels.get_muzzle(_gun)
    for node in _gun.find_children("*", "MeshInstance3D", true, false):
        var mesh_node := node as MeshInstance3D
        if mesh_node != null:
            _meshes.append(mesh_node)

func get_muzzle_position() -> Vector3:
    if _muzzle != null and _muzzle.is_inside_tree():
        return _muzzle.global_position
    return global_position + Vector3(0.0, 1.4, 0.0)

func get_head_position() -> Vector3:
    if _head != null and _head.is_inside_tree():
        return _head.global_position
    return global_position + Vector3(0.0, 1.7, 0.0)

# ---------------------------------------------------------------- helpers

func _register(instance: MeshInstance3D) -> void:
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _meshes.append(instance)

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var smallest: float = minf(size.x, minf(size.y, size.z))
    instance.mesh = BevelMesh.box(size, clampf(smallest * 0.22, 0.004, 0.025))
    instance.material_override = material
    instance.position = pos
    _register(instance)
    parent.add_child(instance)
    return instance

func _add_capsule(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = maxf(height, radius * 2.0 + 0.01)
    mesh.radial_segments = 10
    mesh.rings = 4
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = material
    instance.position = pos
    _register(instance)
    parent.add_child(instance)
    return instance

func _add_sphere(parent: Node3D, pos: Vector3, radius: float, material: Material, mesh_scale: Vector3) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 12
    mesh.rings = 6
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = material
    instance.position = pos
    instance.scale = mesh_scale
    _register(instance)
    parent.add_child(instance)
    return instance

# ---------------------------------------------------------------- animation

func flash() -> void:
    _flash_left = 0.09
    var overlay := _get_flash_material()
    for instance in _meshes:
        if is_instance_valid(instance):
            instance.material_overlay = overlay

func attack_swing() -> void:
    _attack_swing = 1.0

func animate(delta: float, speed: float, aim_weight: float) -> void:
    if _is_dead:
        return
    _aim_weight = lerpf(_aim_weight, aim_weight, 1.0 - exp(-10.0 * delta))
    var stride: float = 4.2 + speed * 1.6
    _phase = fposmod(_phase + delta * stride, TAU)
    var target_amp: float = clampf(speed / 3.6, 0.0, 1.0)
    _swing_amp = lerpf(_swing_amp, target_amp, 1.0 - exp(-10.0 * delta))
    _attack_swing = maxf(0.0, _attack_swing - delta * 3.2)
    _apply_pose(_phase, _swing_amp)
    if _flash_left > 0.0:
        _flash_left -= delta
        if _flash_left <= 0.0:
            for instance in _meshes:
                if is_instance_valid(instance):
                    instance.material_overlay = null

func _apply_pose(phase: float, amp: float) -> void:
    if _torso == null:
        return
    var swing: float = sin(phase) * 0.8 * amp
    _thigh_l.rotation.x = swing
    _thigh_r.rotation.x = -swing
    _knee_l.rotation.x = -maxf(0.0, sin(phase + 1.4)) * 0.95 * amp
    _knee_r.rotation.x = -maxf(0.0, -sin(phase + 1.4)) * 0.95 * amp
    _torso.position.y = 1.1 + absf(sin(phase)) * 0.035 * amp
    if kind == "zombie":
        var lurch: float = sin(phase * 0.5) * 0.12 * amp
        _torso.rotation.x = -0.28 - _attack_swing * 0.3
        _torso.rotation.z = lurch
        _head.rotation.z = -lurch * 1.6
        _head.rotation.x = 0.2
        var reach: float = 1.35 + sin(phase * 1.0) * 0.12 * amp - _attack_swing * 0.9
        _shoulder_l.rotation = Vector3(reach, 0.12, 0.05)
        _shoulder_r.rotation = Vector3(reach + (0.15 if _zombie_variant % 2 == 0 else -0.25), -0.12, -0.05)
        _elbow_l.rotation.x = 0.15 + _attack_swing * 0.8
        _elbow_r.rotation.x = 0.25 + _attack_swing * 0.8
        return
    # Soldier: arms swing when running, raise the weapon when aiming.
    var aim: float = _aim_weight
    var run_l: float = -swing * 0.9
    var run_r: float = swing * 0.9
    _shoulder_r.rotation = Vector3(lerpf(run_r + 0.2, 0.95, aim), lerpf(0.0, 0.3, aim), 0.0)
    _shoulder_l.rotation = Vector3(lerpf(run_l + 0.2, 1.05, aim), lerpf(0.0, -0.55, aim), 0.0)
    _elbow_r.rotation.x = lerpf(0.35, 0.55, aim)
    _elbow_l.rotation.x = lerpf(0.35, 0.75, aim)
    _torso.rotation.x = lerpf(0.05, 0.0, aim)
    _torso.rotation.y = lerpf(0.0, -0.18, aim)
    _head.rotation.y = lerpf(0.0, 0.18, aim)

func play_death(push_direction: Vector3) -> void:
    _is_dead = true
    var local_push: Vector3 = global_transform.basis.inverse() * push_direction
    # Fall backwards when shot from the front, forwards when shot from behind.
    var fall_sign: float = -1.0 if local_push.z >= 0.0 else 1.0
    var side_tilt: float = clampf(local_push.x, -1.0, 1.0) * 0.35
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "rotation:x", fall_sign * PI * 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "rotation:z", side_tilt, 0.55)
    tween.tween_property(self, "position:y", position.y + 0.12, 0.55)
    if _shoulder_l != null:
        tween.tween_property(_shoulder_l, "rotation:x", 0.2, 0.4)
        tween.tween_property(_shoulder_r, "rotation:x", 0.2, 0.4)
    for eye in _eyes:
        if is_instance_valid(eye):
            eye.visible = false

func revive_pose() -> void:
    _is_dead = false
    rotation = Vector3.ZERO
