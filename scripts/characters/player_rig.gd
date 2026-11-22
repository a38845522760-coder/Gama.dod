extends Node3D
class_name PlayerRig

## Jointed third-person soldier used for the local player (third-person camera) and for
## remote players in multiplayer. Hips, spine, head, two-bone legs and two-bone arms.
## Limb convention: a pivot hangs along -Y; a positive rotation.x swings the limb forward (-Z).
## update_pose() blends standing / walking / crouching (kneeling squat) / sliding / lying prone,
## and keeps the feet on the ground by deriving the hip height from the leg angles.

const THIGH: float = 0.46
const SHIN: float = 0.46
const UPPER_ARM: float = 0.30
const FORE_ARM: float = 0.28
const RIFLE_STAND_POS: Vector3 = Vector3(0.04, 0.34, -0.42)
const RIFLE_PRONE_POS: Vector3 = Vector3(0.04, 0.62, 0.06)

var muzzle: Marker3D
var _hips: Node3D
var _spine: Node3D
var _head: Node3D
var _thigh_l: Node3D
var _thigh_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _fore_l: Node3D
var _fore_r: Node3D
var _rifle: Node3D
var _phase: float = 0.0
var _slide_blend: float = 0.0
var _crouch: float = 0.0
var _prone: float = 0.0
var _move: float = 0.0
var _run: float = 0.0

func build(suit_color: Color = Color("#3a4a44"), vest_color: Color = Color("#d9822b")) -> void:
    var suit := _material(suit_color, 0.8, 0.0)
    var vest := _material(vest_color, 0.6, 0.0)
    var dark := _material(Color("#161a1d"), 0.5, 0.6)
    var skin := _material(Color("#b98a68"), 0.9, 0.0)
    var boots := _material(Color("#1c1f22"), 0.7, 0.1)

    _hips = Node3D.new()
    _hips.name = "Hips"
    _hips.position = Vector3(0.0, THIGH + SHIN, 0.0)
    add_child(_hips)
    _add_box(_hips, Vector3(0.0, 0.0, 0.0), Vector3(0.34, 0.18, 0.2), suit)

    _thigh_l = _make_leg(Vector3(-0.12, -0.02, 0.0), suit, boots)
    _thigh_r = _make_leg(Vector3(0.12, -0.02, 0.0), suit, boots)
    _shin_l = _thigh_l.get_node("Shin") as Node3D
    _shin_r = _thigh_r.get_node("Shin") as Node3D

    _spine = Node3D.new()
    _spine.name = "Spine"
    _spine.position = Vector3(0.0, 0.06, 0.0)
    _hips.add_child(_spine)
    _add_capsule(_spine, Vector3(0.0, 0.12, 0.0), 0.15, 0.3, suit)
    _add_box(_spine, Vector3(0.0, 0.36, 0.0), Vector3(0.44, 0.38, 0.24), vest)
    _add_box(_spine, Vector3(0.0, 0.36, -0.125), Vector3(0.3, 0.2, 0.05), dark)
    _add_capsule(_spine, Vector3(0.0, 0.58, 0.0), 0.05, 0.14, skin)

    _head = Node3D.new()
    _head.name = "Head"
    _head.position = Vector3(0.0, 0.64, 0.0)
    _spine.add_child(_head)
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.115
    head_mesh.height = 0.23
    _add_mesh(_head, head_mesh, Vector3(0.0, 0.1, 0.0), Vector3.ONE, skin)
    var helmet_mesh := SphereMesh.new()
    helmet_mesh.radius = 0.14
    helmet_mesh.height = 0.2
    _add_mesh(_head, helmet_mesh, Vector3(0.0, 0.16, 0.01), Vector3(1.0, 0.9, 1.05), dark)

    _arm_l = _make_arm(Vector3(-0.29, 0.52, 0.0), suit, skin)
    _arm_r = _make_arm(Vector3(0.29, 0.52, 0.0), suit, skin)
    _fore_l = _arm_l.get_node("Fore") as Node3D
    _fore_r = _arm_r.get_node("Fore") as Node3D

    _rifle = Node3D.new()
    _rifle.name = "Rifle"
    _rifle.position = RIFLE_STAND_POS
    _spine.add_child(_rifle)
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(0.07, 0.1, 0.8)
    _add_mesh(_rifle, body_mesh, Vector3(0.0, 0.0, -0.1), Vector3.ONE, dark)
    var stock_mesh := BoxMesh.new()
    stock_mesh.size = Vector3(0.06, 0.14, 0.2)
    _add_mesh(_rifle, stock_mesh, Vector3(0.0, -0.03, 0.34), Vector3.ONE, dark)
    muzzle = Marker3D.new()
    muzzle.name = "Muzzle"
    muzzle.position = Vector3(0.0, 0.0, -0.52)
    _rifle.add_child(muzzle)
    update_pose(0.0, 0.0, 0.0, 0.0, false, 0.0, true)

func update_pose(delta: float, speed: float, crouch: float, prone: float, sliding: bool, pitch: float, on_floor: bool) -> void:
    if _hips == null:
        return
    _slide_blend = move_toward(_slide_blend, 1.0 if sliding else 0.0, delta * 6.0)
    _crouch = lerpf(_crouch, crouch * (1.0 - prone), clampf(delta * 14.0, 0.0, 1.0))
    _prone = lerpf(_prone, prone, clampf(delta * 10.0, 0.0, 1.0))
    var target_move: float = clampf(speed / 5.6, 0.0, 1.0) if on_floor else 0.0
    _move = lerpf(_move, target_move, clampf(delta * 10.0, 0.0, 1.0))
    _run = lerpf(_run, 1.0 if speed > 4.4 else 0.0, clampf(delta * 6.0, 0.0, 1.0))
    _phase += delta * (3.0 + speed * 1.8) * (1.0 - _slide_blend)

    var swing_amount: float = _move * lerpf(0.8, 0.3, _crouch) * (1.0 - _prone) * (1.0 - _slide_blend)
    var swing: float = sin(_phase) * swing_amount
    # Standing / walking legs (the knee bends as the leg swings back).
    var tl: float = swing
    var tr: float = -swing
    var sl: float = -maxf(0.0, -swing) * 1.3 - 0.04
    var sr: float = -maxf(0.0, swing) * 1.3 - 0.04
    # Crouch: deep kneeling squat.
    tl = lerpf(tl, 1.3 + swing * 0.5, _crouch)
    tr = lerpf(tr, 1.12 - swing * 0.5, _crouch)
    sl = lerpf(sl, -1.5, _crouch)
    sr = lerpf(sr, -1.7, _crouch)
    # Prone: legs trail straight behind, tiny crawl motion.
    var crawl: float = sin(_phase) * _move
    tl = lerpf(tl, 0.04 + crawl * 0.12, _prone)
    tr = lerpf(tr, 0.04 - crawl * 0.12, _prone)
    sl = lerpf(sl, -maxf(0.0, -crawl) * 0.5, _prone)
    sr = lerpf(sr, -maxf(0.0, crawl) * 0.5, _prone)
    # Slide: one leg stretched forward, the other folded under.
    tl = lerpf(tl, 1.5, _slide_blend)
    tr = lerpf(tr, 1.0, _slide_blend)
    sl = lerpf(sl, -0.12, _slide_blend)
    sr = lerpf(sr, -2.0, _slide_blend)
    _thigh_l.rotation.x = tl
    _thigh_r.rotation.x = tr
    _shin_l.rotation.x = sl
    _shin_r.rotation.x = sr

    # Hip height from the leg geometry keeps the feet on the ground.
    var drop_l: float = THIGH * cos(tl) + SHIN * cos(tl + sl)
    var drop_r: float = THIGH * cos(tr) + SHIN * cos(tr + sr)
    var hip_y: float = maxf(drop_l, drop_r)
    hip_y -= absf(sin(_phase * 2.0)) * 0.025 * swing_amount
    hip_y = lerpf(hip_y, 0.32, _slide_blend)
    hip_y = lerpf(hip_y, 0.2, _prone)
    _hips.position = Vector3(0.0, hip_y, lerpf(0.0, 0.1, _slide_blend))
    _hips.rotation.x = lerpf(lerpf(0.0, 0.85, _slide_blend), -PI * 0.5, _prone)

    var lean: float = -0.05 - 0.17 * _run
    lean = lerpf(lean, -0.28, _crouch)
    lean = lerpf(lean, -0.55, _slide_blend)
    lean = lerpf(lean, 0.2, _prone)
    _spine.rotation.x = lean
    _head.rotation.x = clampf(pitch * 0.8, -0.9, 0.9) - lean * 0.4

    # Arms hold the rifle in front of the chest.
    var aim: float = 1.0
    _arm_r.rotation = Vector3(lerpf(1.05, 2.55, _prone), 0.3, 0.0)
    _arm_l.rotation = Vector3(lerpf(1.3, 2.7, _prone), -0.38, 0.0)
    _fore_r.rotation.x = lerpf(0.55 * aim, 0.45, _prone)
    _fore_l.rotation.x = lerpf(0.25 * aim, 0.35, _prone)
    # Running swings the arms a little more loosely.
    _arm_r.rotation.x += swing * 0.12 * (1.0 - _prone)
    _arm_l.rotation.x -= swing * 0.12 * (1.0 - _prone)

    # The rifle always points where the body faces, even when lying down.
    _rifle.position = RIFLE_STAND_POS.lerp(RIFLE_PRONE_POS, _prone)
    _rifle.rotation.x = -(_hips.rotation.x + _spine.rotation.x) + clampf(pitch * 0.5, -0.5, 0.5)

func _make_leg(hip_position: Vector3, suit: Material, boots: Material) -> Node3D:
    var thigh := Node3D.new()
    thigh.position = hip_position
    _hips.add_child(thigh)
    _add_limb(thigh, THIGH, 0.085, suit)
    var shin := Node3D.new()
    shin.name = "Shin"
    shin.position = Vector3(0.0, -THIGH, 0.0)
    thigh.add_child(shin)
    _add_limb(shin, SHIN, 0.07, suit)
    _add_box(shin, Vector3(0.0, -SHIN + 0.02, -0.05), Vector3(0.13, 0.1, 0.26), boots)
    return thigh

func _make_arm(shoulder_position: Vector3, suit: Material, skin: Material) -> Node3D:
    var arm := Node3D.new()
    arm.position = shoulder_position
    _spine.add_child(arm)
    _add_limb(arm, UPPER_ARM, 0.058, suit)
    var fore := Node3D.new()
    fore.name = "Fore"
    fore.position = Vector3(0.0, -UPPER_ARM, 0.0)
    arm.add_child(fore)
    _add_limb(fore, FORE_ARM, 0.05, suit)
    var hand_mesh := SphereMesh.new()
    hand_mesh.radius = 0.055
    hand_mesh.height = 0.11
    _add_mesh(fore, hand_mesh, Vector3(0.0, -FORE_ARM, 0.0), Vector3.ONE, skin)
    return arm

func _add_limb(parent: Node3D, length: float, radius: float, material: Material) -> void:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = length
    _add_mesh(parent, mesh, Vector3(0.0, -length * 0.5, 0.0), Vector3.ONE, material)

func _add_box(parent: Node3D, at: Vector3, box_size: Vector3, material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = box_size
    _add_mesh(parent, mesh, at, Vector3.ONE, material)

func _add_capsule(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> void:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = maxf(height, radius * 2.0)
    _add_mesh(parent, mesh, at, Vector3.ONE, material)

func _add_mesh(parent: Node3D, mesh: Mesh, at: Vector3, mesh_scale: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.position = at
    instance.scale = mesh_scale
    instance.material_override = material
    parent.add_child(instance)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material
