extends RefCounted
class_name MapKit

## Toolbox used by map builders: shared materials plus helpers that create solid (collider +
## mesh) and decorative (mesh only) primitives and file them into streaming regions.

const SURFACE_META: Dictionary = {
    &"concrete": {"speed": 1.0, "traction": 1.0, "jump": 1.0, "stride": 1.0},
    &"metal": {"speed": 0.98, "traction": 0.86, "jump": 0.98, "stride": 0.94},
    &"crate": {"speed": 0.91, "traction": 0.78, "jump": 0.94, "stride": 0.90},
    &"composite": {"speed": 1.0, "traction": 1.04, "jump": 1.0, "stride": 1.02},
}

var materials: Dictionary = {}
var _region_provider: Callable
var core_node: Node3D
var force_core: bool = false
var _shared_meshes: Dictionary = {}
var _box_count: int = 0
var _body_count: int = 0

func _init(region_provider: Callable) -> void:
    _region_provider = region_provider
    _create_materials()

func get_body_count() -> int:
    return _body_count

func mat(key: String) -> Material:
    return materials.get(key, materials["concrete"])

func _create_materials() -> void:
    var texture_tier: int = int(SettingsManager.get_quality_profile().get("texture_tier", 1))
    materials["concrete"] = _pbr(Color("#6c7479"), 0.9, 0.05, "concrete", texture_tier)
    materials["asphalt"] = _pbr(Color("#24292d"), 0.95, 0.02, "concrete", texture_tier)
    materials["dirt"] = _plain(Color("#4a4034"), 0.98, 0.0)
    materials["grass"] = _plain(Color("#3d5a30"), 1.0, 0.0)
    materials["steel"] = _pbr(Color("#59666c"), 0.62, 0.55, "painted_steel", texture_tier)
    materials["dark_steel"] = _pbr(Color("#242d33"), 0.6, 0.6, "painted_steel", texture_tier)
    materials["rust"] = _pbr(Color("#7a4a2c"), 0.85, 0.35, "painted_steel", texture_tier)
    materials["wall"] = _pbr(Color("#8a8f8c"), 0.92, 0.04, "concrete", texture_tier)
    materials["brick"] = _pbr(Color("#8a4f3c"), 0.95, 0.02, "concrete", texture_tier)
    materials["roof"] = _pbr(Color("#3b4448"), 0.7, 0.45, "painted_steel", texture_tier)
    materials["rubber"] = _pbr(Color("#1b2124"), 0.95, 0.02, "rubber", texture_tier)
    materials["wood"] = _plain(Color("#8a6a45"), 0.9, 0.0)
    materials["warning"] = _plain(Color("#e0a33e"), 0.7, 0.1)
    materials["black"] = _plain(Color("#0f1315"), 0.8, 0.1)
    materials["glass"] = _glass()
    materials["lamp"] = _emissive(Color("#ffe2a8"), 2.2)
    materials["red_lamp"] = _emissive(Color("#ff5a3c"), 2.0)
    materials["trunk"] = _plain(Color("#4d3a2a"), 1.0, 0.0)
    materials["leaf"] = _plain(Color("#35602d"), 1.0, 0.0)
    materials["leaf_dark"] = _plain(Color("#2a4a25"), 1.0, 0.0)
    materials["puddle"] = _puddle()
    var palette: Array = ["#b5412e", "#2f6f8c", "#d9a02f", "#3f7d4f", "#5c6b73", "#8f3b52", "#c26a2a", "#2b4f7a"]
    for index in range(palette.size()):
        materials["container_%d" % index] = _pbr(Color(str(palette[index])), 0.55, 0.45, "painted_steel", texture_tier)

## Night / horror look: scales every lit material toward black (glowing ones are left alone).
func darken(factor: float, tint: Color = Color(0.85, 0.95, 1.0)) -> void:
    for key in materials.keys():
        if ["lamp", "red_lamp", "glass", "puddle"].has(str(key)):
            continue
        var material := materials[key] as StandardMaterial3D
        if material != null:
            var base: Color = material.albedo_color
            material.albedo_color = Color(base.r * factor * tint.r, base.g * factor * tint.g, base.b * factor * tint.b, base.a)

func add_plain(key: String, color: Color, roughness: float = 0.9, metallic: float = 0.0) -> void:
    materials[key] = _plain(color, roughness, metallic)

func add_emissive(key: String, color: Color, energy: float = 2.0) -> void:
    materials[key] = _emissive(color, energy)

func container_material(index: int) -> Material:
    return materials["container_%d" % (absi(index) % 8)]

func _plain(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func _pbr(color: Color, roughness: float, metallic: float, prefix: String, texture_tier: int) -> StandardMaterial3D:
    var material := _plain(color, roughness, metallic)
    if texture_tier <= 0:
        return material
    var root_path := "res://assets/textures/%s" % prefix
    var albedo := load(root_path + "_albedo.png") as Texture2D
    var normal := load(root_path + "_normal.png") as Texture2D
    if albedo != null:
        material.albedo_texture = albedo
    if normal != null:
        material.normal_enabled = true
        material.normal_texture = normal
        material.normal_scale = 0.35
    material.uv1_triplanar = true
    material.uv1_world_triplanar = true
    material.uv1_scale = Vector3(0.4, 0.4, 0.4)
    return material

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return material

func _glass() -> StandardMaterial3D:
    var material := _plain(Color(0.35, 0.6, 0.7, 0.35), 0.1, 0.1)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material

func _puddle() -> StandardMaterial3D:
    var material := _plain(Color(0.07, 0.1, 0.13, 0.85), 0.04, 0.0)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material

# ---------------------------------------------------------------- primitives

func _parent_for(world_position: Vector3) -> Node3D:
    if force_core and core_node != null:
        return core_node
    return _region_provider.call(world_position)

func _box_mesh(size: Vector3) -> Mesh:
    var key := "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
    if not _shared_meshes.has(key):
        var smallest: float = minf(size.x, minf(size.y, size.z))
        if smallest >= 0.28:
            # Chamfered edges catch the light, so crates, walls and machinery stop looking like
            # flat cardboard boxes. Thin plates (floors, decals) stay plain.
            _shared_meshes[key] = BevelMesh.box(size, clampf(smallest * 0.07, 0.018, 0.07))
        else:
            var mesh := BoxMesh.new()
            mesh.size = size
            _shared_meshes[key] = mesh
    return _shared_meshes[key]

func solid_box(node_name: String, world_position: Vector3, size: Vector3, material_key: String, world_rotation: Vector3 = Vector3.ZERO, surface: StringName = &"concrete", parent: Node3D = null) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = world_position
    body.rotation = world_rotation
    body.collision_layer = 1
    body.collision_mask = 0
    var meta: Dictionary = SURFACE_META.get(surface, SURFACE_META[&"concrete"])
    body.set_meta("surface_type", surface)
    body.set_meta("move_speed_multiplier", float(meta["speed"]))
    body.set_meta("traction_multiplier", float(meta["traction"]))
    body.set_meta("jump_multiplier", float(meta["jump"]))
    body.set_meta("stride_multiplier", float(meta["stride"]))
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    var mesh_node := MeshInstance3D.new()
    mesh_node.mesh = _box_mesh(size)
    mesh_node.material_override = mat(material_key)
    body.add_child(mesh_node)
    var host: Node3D = parent if parent != null else _parent_for(world_position)
    host.add_child(body)
    _body_count += 1
    return body

func decor_box(node_name: String, world_position: Vector3, size: Vector3, material_key: String, world_rotation: Vector3 = Vector3.ZERO, cast_shadow: bool = false, parent: Node3D = null) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = _box_mesh(size)
    instance.material_override = mat(material_key)
    instance.position = world_position
    instance.rotation = world_rotation
    if not cast_shadow:
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var host: Node3D = parent if parent != null else _parent_for(world_position)
    host.add_child(instance)
    return instance

func cylinder(node_name: String, world_position: Vector3, radius: float, height: float, material_key: String, solid: bool = true, world_rotation: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> Node3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius if top_radius < 0.0 else top_radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 16
    mesh.rings = 1
    var host := _parent_for(world_position)
    if solid:
        var body := StaticBody3D.new()
        body.name = node_name
        body.position = world_position
        body.rotation = world_rotation
        body.collision_layer = 1
        body.collision_mask = 0
        body.set_meta("surface_type", &"metal")
        var shape_node := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = radius
        shape.height = height
        shape_node.shape = shape
        body.add_child(shape_node)
        var mesh_node := MeshInstance3D.new()
        mesh_node.mesh = mesh
        mesh_node.material_override = mat(material_key)
        body.add_child(mesh_node)
        host.add_child(body)
        _body_count += 1
        return body
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = mat(material_key)
    instance.position = world_position
    instance.rotation = world_rotation
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    host.add_child(instance)
    return instance

func stairs(node_name: String, start: Vector3, direction: Vector3, steps: int, rise: float, run: float, width: float, material_key: String = "steel") -> void:
    # Each step is a full-height block so the staircase is solid and cannot be walked under.
    var dir := direction.normalized()
    var yaw := atan2(-dir.x, -dir.z)
    for index in range(steps):
        var height := rise * float(index + 1)
        var center := start + dir * (run * (float(index) + 0.5)) + Vector3(0.0, height * 0.5, 0.0)
        solid_box("%s_%d" % [node_name, index], center, Vector3(width, height, run), material_key, Vector3(0.0, yaw, 0.0), &"metal")
