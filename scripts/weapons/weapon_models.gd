extends RefCounted
class_name WeaponModels

## Builds third-person / display models of every gun (used by AI soldiers, the shop preview
## and pickups). The gun points down -Z; the origin sits where the right hand grips it.
## A Marker3D called "Muzzle" marks the barrel tip.

static var _materials: Dictionary = {}

static func _mat(key: String, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    if _materials.has(key):
        return _materials[key]
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    _materials[key] = material
    return material

static func _accent_mat(weapon_id: String) -> StandardMaterial3D:
    var color: Color = WeaponDefinitions.get_accent(weapon_id)
    return _mat("accent_" + weapon_id, color, 0.45, 0.4)

static func _part(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = part_name
    var smallest: float = minf(size.x, minf(size.y, size.z))
    instance.mesh = BevelMesh.box(size, clampf(smallest * 0.2, 0.002, 0.012))
    instance.material_override = material
    instance.position = pos
    instance.rotation = rot
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(instance)
    return instance

static func _tube(parent: Node3D, part_name: String, pos: Vector3, radius: float, length: float, material: Material) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 10
    mesh.rings = 1
    var instance := MeshInstance3D.new()
    instance.name = part_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = pos
    instance.rotation = Vector3(PI * 0.5, 0.0, 0.0)
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(instance)
    return instance

static func get_muzzle(model: Node3D) -> Marker3D:
    return model.find_child("Muzzle", true, false) as Marker3D

static func build(weapon_id: String) -> Node3D:
    var root := Node3D.new()
    root.name = "Gun_" + weapon_id
    var body := Node3D.new()
    body.name = "Body"
    root.add_child(body)
    var metal := _mat("metal", Color("#2b3136"), 0.4, 0.85)
    var dark := _mat("dark", Color("#15191c"), 0.5, 0.75)
    var polymer := _mat("polymer", Color("#202428"), 0.8, 0.05)
    var accent := _accent_mat(weapon_id)
    var style: String = str(WeaponDefinitions.get_definition(weapon_id).get("style", "rifle"))
    var muzzle_z: float = -0.7
    match style:
        "pistol":
            body.position = Vector3(0.0, 0.07, -0.05)
            _part(body, "Slide", Vector3(0, 0.0, -0.03), Vector3(0.034, 0.042, 0.22), metal)
            _part(body, "Frame", Vector3(0, -0.035, 0.0), Vector3(0.03, 0.03, 0.18), polymer)
            _part(body, "Grip", Vector3(0, -0.09, 0.07), Vector3(0.034, 0.1, 0.045), polymer, Vector3(deg_to_rad(-18.0), 0, 0))
            _part(body, "MagBase", Vector3(0, -0.145, 0.082), Vector3(0.036, 0.012, 0.05), accent, Vector3(deg_to_rad(-18.0), 0, 0))
            muzzle_z = -0.145
        "revolver":
            body.position = Vector3(0.0, 0.07, -0.05)
            _tube(body, "Cylinder", Vector3(0, 0.0, -0.015), 0.03, 0.06, metal)
            _part(body, "Frame", Vector3(0, -0.01, 0.02), Vector3(0.03, 0.06, 0.13), metal)
            _tube(body, "Barrel", Vector3(0, 0.02, -0.17), 0.0125, 0.22, dark)
            _part(body, "Rib", Vector3(0, 0.036, -0.17), Vector3(0.012, 0.008, 0.22), metal)
            _part(body, "Grip", Vector3(0, -0.085, 0.075), Vector3(0.034, 0.1, 0.045), accent, Vector3(deg_to_rad(-18.0), 0, 0))
            muzzle_z = -0.285
        "smg":
            body.position = Vector3(0.0, 0.09, -0.1)
            _part(body, "Receiver", Vector3(0, 0.0, 0.0), Vector3(0.05, 0.068, 0.30), metal)
            _part(body, "Guard", Vector3(0, 0, -0.2), Vector3(0.05, 0.052, 0.12), polymer)
            _tube(body, "Barrel", Vector3(0, 0.002, -0.32), 0.0095, 0.1, dark)
            _part(body, "StockFrame", Vector3(0, -0.005, 0.22), Vector3(0.018, 0.06, 0.14), metal)
            _part(body, "Grip", Vector3(0, -0.09, 0.1), Vector3(0.035, 0.1, 0.045), polymer, Vector3(deg_to_rad(-20.0), 0, 0))
            _part(body, "Mag", Vector3(0, -0.13, -0.04), Vector3(0.03, 0.14, 0.045), accent)
            _part(body, "Sight", Vector3(0, 0.05, -0.02), Vector3(0.03, 0.03, 0.08), dark)
            muzzle_z = -0.39
        "shotgun":
            body.position = Vector3(0.0, 0.09, -0.1)
            _part(body, "Receiver", Vector3(0, 0.0, 0.0), Vector3(0.055, 0.07, 0.30), metal)
            _tube(body, "Barrel", Vector3(0, 0.012, -0.34), 0.0145, 0.4, dark)
            _tube(body, "Tube", Vector3(0, -0.022, -0.32), 0.013, 0.36, metal)
            _part(body, "Pump", Vector3(0, -0.02, -0.28), Vector3(0.062, 0.05, 0.17), accent)
            _part(body, "Stock", Vector3(0, -0.02, 0.26), Vector3(0.045, 0.09, 0.22), polymer)
            _part(body, "Grip", Vector3(0, -0.085, 0.09), Vector3(0.034, 0.09, 0.045), polymer, Vector3(deg_to_rad(-20.0), 0, 0))
            muzzle_z = -0.55
        "lmg":
            body.position = Vector3(0.0, 0.09, -0.1)
            _part(body, "Receiver", Vector3(0, 0.0, 0.0), Vector3(0.058, 0.075, 0.34), metal)
            _part(body, "Guard", Vector3(0, 0, -0.27), Vector3(0.06, 0.06, 0.2), polymer)
            _tube(body, "Barrel", Vector3(0, 0.002, -0.52), 0.0135, 0.3, dark)
            _tube(body, "Shroud", Vector3(0, 0.0, -0.4), 0.022, 0.18, metal)
            _part(body, "Stock", Vector3(0, -0.02, 0.28), Vector3(0.045, 0.09, 0.2), polymer)
            _part(body, "Grip", Vector3(0, -0.095, 0.11), Vector3(0.036, 0.1, 0.045), polymer, Vector3(deg_to_rad(-20.0), 0, 0))
            _part(body, "AmmoBox", Vector3(0, -0.12, -0.03), Vector3(0.075, 0.12, 0.1), accent)
            _part(body, "Handle", Vector3(0, 0.07, 0.0), Vector3(0.016, 0.035, 0.15), dark)
            muzzle_z = -0.68
        "sniper":
            body.position = Vector3(0.0, 0.09, -0.1)
            _part(body, "Receiver", Vector3(0, 0.0, 0.0), Vector3(0.05, 0.07, 0.34), metal)
            _part(body, "Guard", Vector3(0, 0, -0.3), Vector3(0.05, 0.05, 0.28), polymer)
            _tube(body, "Barrel", Vector3(0, 0.002, -0.62), 0.0125, 0.4, dark)
            _tube(body, "Brake", Vector3(0, 0.002, -0.83), 0.019, 0.06, metal)
            _part(body, "Stock", Vector3(0, -0.015, 0.3), Vector3(0.045, 0.095, 0.24), polymer)
            _part(body, "Cheek", Vector3(0, 0.04, 0.28), Vector3(0.04, 0.02, 0.14), accent)
            _part(body, "Grip", Vector3(0, -0.09, 0.11), Vector3(0.035, 0.1, 0.045), polymer, Vector3(deg_to_rad(-20.0), 0, 0))
            _tube(body, "Scope", Vector3(0, 0.085, -0.03), 0.02, 0.26, metal)
            _tube(body, "ScopeFront", Vector3(0, 0.085, -0.17), 0.028, 0.05, dark)
            _part(body, "Mag", Vector3(0, -0.1, -0.02), Vector3(0.034, 0.07, 0.05), polymer)
            muzzle_z = -0.865
        _:
            body.position = Vector3(0.0, 0.09, -0.1)
            _part(body, "Receiver", Vector3(0, 0.0, 0.0), Vector3(0.052, 0.07, 0.30), metal)
            _part(body, "Guard", Vector3(0, 0, -0.27), Vector3(0.056, 0.056, 0.26), polymer)
            _tube(body, "Barrel", Vector3(0, 0.002, -0.55), 0.0105, 0.3, dark)
            _tube(body, "Brake", Vector3(0, 0.002, -0.68), 0.0165, 0.06, metal)
            _part(body, "Stock", Vector3(0, -0.02, 0.26), Vector3(0.045, 0.09, 0.2), polymer)
            _part(body, "Grip", Vector3(0, -0.095, 0.1), Vector3(0.035, 0.1, 0.045), polymer, Vector3(deg_to_rad(-20.0), 0, 0))
            _part(body, "Mag", Vector3(0, -0.125, -0.04), Vector3(0.035, 0.14, 0.05), polymer, Vector3(deg_to_rad(8.0), 0, 0))
            _part(body, "Optic", Vector3(0, 0.06, -0.02), Vector3(0.04, 0.045, 0.09), accent)
            muzzle_z = -0.715
    var muzzle := Marker3D.new()
    muzzle.name = "Muzzle"
    muzzle.position = Vector3(0.0, 0.002, muzzle_z)
    body.add_child(muzzle)
    return root
