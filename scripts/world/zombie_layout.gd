extends RefCounted
class_name ZombieLayout

## Layout of the zombie map "Dead City" (400 x 400 m, about six times the Iron Yard): a dark,
## ruined city at night. Districts: central plaza, hospital, reactor lab (Tesla shop),
## military checkpoint (armory), foundry (heavy weapons), graveyard, rail yard, residential
## ruins and a container maze, joined by cracked roads and littered with wrecks and rubble.

const HALF: float = 200.0

var spawn_positions: Array[Dictionary] = []
var shop_sites: Array[Dictionary] = []
var supply_sites: Array[Vector3] = []
var light_sites: Array[Dictionary] = []
var stats: Dictionary = {"buildings": 0, "vehicles": 0, "graves": 0, "trees": 0, "props": 0, "lights": 0}

var _kit: MapKit
var _root: Node3D
var _rng := RandomNumberGenerator.new()
var _keepout: Array[Rect2] = []

func build(root: Node3D, kit: MapKit) -> void:
    _root = root
    _kit = kit
    _rng.seed = 66613
    _setup_materials()
    _build_ground()
    _build_perimeter()
    _build_roads()
    _kit.force_core = true
    _build_plaza(Vector3(0.0, 0.0, 0.0))
    _build_hospital(Vector3(-125.0, 0.0, -125.0))
    _build_reactor_lab(Vector3(125.0, 0.0, -125.0))
    _kit.force_core = false
    _build_checkpoint(Vector3(-125.0, 0.0, 125.0))
    _build_foundry(Vector3(125.0, 0.0, 125.0))
    _build_graveyard(Vector3(0.0, 0.0, -150.0))
    _build_rail_yard(Vector3(0.0, 0.0, 150.0))
    _build_residential(Vector3(-155.0, 0.0, 0.0))
    _build_container_maze(Vector3(155.0, 0.0, 0.0))
    _scatter_wrecks(46)
    _scatter_rubble(120)
    _scatter_dead_trees(90)
    _scatter_street_lamps()
    _build_spawns()

# ---------------------------------------------------------------- materials

func _setup_materials() -> void:
    _kit.darken(0.5)
    _kit.add_plain("blood", Color("#3d0a0a"), 0.6, 0.0)
    _kit.add_plain("bone", Color("#8f8872"), 0.9, 0.0)
    _kit.add_plain("dead_grass", Color("#232a1c"), 1.0, 0.0)
    _kit.add_plain("mud", Color("#1c1812"), 1.0, 0.0)
    _kit.add_plain("burnt", Color("#14110f"), 0.95, 0.1)
    _kit.add_emissive("toxic", Color("#3dff7a"), 1.7)
    _kit.add_emissive("lava", Color("#ff5a1a"), 2.1)
    _kit.add_emissive("tesla_blue", Color("#4fd8ff"), 2.6)
    _kit.add_emissive("sick_light", Color("#9dffb0"), 1.8)
    _kit.add_emissive("warn_red", Color("#ff2a1a"), 2.2)

# ---------------------------------------------------------------- terrain

func _core() -> Node3D:
    return _root.get_node("Regions/Core") as Node3D

func _build_ground() -> void:
    var core := _core()
    _kit.solid_box("Ground", Vector3(0.0, -0.5, 0.0), Vector3(HALF * 2.0 + 30.0, 1.0, HALF * 2.0 + 30.0), "mud", Vector3.ZERO, &"concrete", core)
    _kit.decor_box("DeadGrass", Vector3(0.0, 0.01, 0.0), Vector3(HALF * 2.0, 0.02, HALF * 2.0), "dead_grass", Vector3.ZERO, false, core)

func _build_perimeter() -> void:
    var core := _core()
    var length: float = HALF * 2.0 + 6.0
    var height: float = 11.0
    _kit.solid_box("WallNorth", Vector3(0.0, height * 0.5, -HALF - 1.5), Vector3(length, height, 2.0), "dark_steel", Vector3.ZERO, &"concrete", core)
    _kit.solid_box("WallSouth", Vector3(0.0, height * 0.5, HALF + 1.5), Vector3(length, height, 2.0), "dark_steel", Vector3.ZERO, &"concrete", core)
    _kit.solid_box("WallWest", Vector3(-HALF - 1.5, height * 0.5, 0.0), Vector3(2.0, height, length), "dark_steel", Vector3.ZERO, &"concrete", core)
    _kit.solid_box("WallEast", Vector3(HALF + 1.5, height * 0.5, 0.0), Vector3(2.0, height, length), "dark_steel", Vector3.ZERO, &"concrete", core)
    for index in range(-9, 10):
        var offset: float = float(index) * 20.0
        for wall_pos in [Vector3(offset, 10.6, -HALF + 0.02), Vector3(offset, 10.6, HALF - 0.02)]:
            _kit.decor_box("WallLight", wall_pos, Vector3(2.0, 0.2, 0.1), "warn_red", Vector3.ZERO, false, core)
        for wall_pos in [Vector3(-HALF + 0.02, 10.6, offset), Vector3(HALF - 0.02, 10.6, offset)]:
            _kit.decor_box("WallLight", wall_pos, Vector3(0.1, 0.2, 2.0), "warn_red", Vector3.ZERO, false, core)

func _build_roads() -> void:
    var core := _core()
    _kit.decor_box("RoadEW", Vector3(0.0, 0.03, 0.0), Vector3(HALF * 2.0, 0.02, 14.0), "asphalt", Vector3.ZERO, false, core)
    _kit.decor_box("RoadNS", Vector3(0.0, 0.031, 0.0), Vector3(14.0, 0.02, HALF * 2.0), "asphalt", Vector3.ZERO, false, core)
    for sign_x in [-1.0, 1.0]:
        for sign_z in [-1.0, 1.0]:
            _kit.decor_box("RoadDiag", Vector3(sign_x * 62.0, 0.032, sign_z * 62.0), Vector3(126.0, 0.02, 9.0), "asphalt", Vector3(0.0, deg_to_rad(45.0 * sign_x * sign_z), 0.0), false, core)
    for index in range(-19, 20):
        _kit.decor_box("DashEW_%d" % index, Vector3(float(index) * 10.0, 0.05, 0.0), Vector3(3.0, 0.01, 0.25), "bone", Vector3.ZERO, false, core)
        _kit.decor_box("DashNS_%d" % index, Vector3(0.0, 0.051, float(index) * 10.0), Vector3(0.25, 0.01, 3.0), "bone", Vector3.ZERO, false, core)
    for index in range(26):
        var spot := Vector3(_rng.randf_range(-170.0, 170.0), 0.04, _rng.randf_range(-170.0, 170.0))
        _kit.decor_box("BloodPool_%d" % index, spot, Vector3(_rng.randf_range(1.5, 4.0), 0.012, _rng.randf_range(1.5, 4.0)), "blood", Vector3(0.0, _rng.randf() * TAU, 0.0), false, core)

# ---------------------------------------------------------------- generic builders

func _wall_piece(piece_name: String, origin: Vector3, axis_x: bool, a: float, b: float, y0: float, y1: float, thick: float, mat: String) -> void:
    if b - a < 0.05 or y1 - y0 < 0.05:
        return
    var mid: float = (a + b) * 0.5
    var height: float = y1 - y0
    var pos: Vector3 = origin + (Vector3(mid, y0 + height * 0.5, 0.0) if axis_x else Vector3(0.0, y0 + height * 0.5, mid))
    var size: Vector3 = Vector3(b - a, height, thick) if axis_x else Vector3(thick, height, b - a)
    _kit.solid_box(piece_name, pos, size, mat)

## A wall with openings. Each gap: {at, width, bottom, top} measured along the wall.
func _wall(prefix: String, origin: Vector3, length: float, height: float, thick: float, axis_x: bool, mat: String, gaps: Array) -> void:
    var cursor: float = -length * 0.5
    var ordered: Array = gaps.duplicate()
    ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
    var index: int = 0
    for gap in ordered:
        var g_start: float = float(gap["at"]) - float(gap["width"]) * 0.5
        var g_end: float = float(gap["at"]) + float(gap["width"]) * 0.5
        _wall_piece("%s_%d" % [prefix, index], origin, axis_x, cursor, g_start, 0.0, height, thick, mat)
        _wall_piece("%s_%d_sill" % [prefix, index], origin, axis_x, g_start, g_end, 0.0, float(gap["bottom"]), thick, mat)
        _wall_piece("%s_%d_lintel" % [prefix, index], origin, axis_x, g_start, g_end, float(gap["top"]), height, thick, mat)
        cursor = g_end
        index += 1
    _wall_piece("%s_end" % prefix, origin, axis_x, cursor, length * 0.5, 0.0, height, thick, mat)

func _side_gaps(length: float, has_door: bool, door_at: float, breach_chance: float) -> Array:
    var gaps: Array = []
    if has_door:
        gaps.append({"at": door_at, "width": 5.0, "bottom": 0.0, "top": 4.2})
    var count: int = int(length / 8.0)
    for index in range(count):
        var at: float = -length * 0.5 + 5.0 + float(index) * (length - 10.0) / maxf(float(count - 1), 1.0)
        if has_door and absf(at - door_at) < 5.0:
            continue
        gaps.append({"at": at, "width": 1.8, "bottom": 1.3, "top": 3.1})
    if _rng.randf() < breach_chance:
        var breach_at: float = _rng.randf_range(-length * 0.3, length * 0.3)
        var clear: bool = true
        for gap in gaps:
            if absf(float(gap["at"]) - breach_at) < 5.0:
                clear = false
        if clear:
            gaps.append({"at": breach_at, "width": 5.0, "bottom": 0.0, "top": 2.6 + _rng.randf() * 1.2})
    return gaps

func _building(bname: String, center: Vector3, size: Vector2, height: float, mat: String, door_sides: Array, breach_chance: float = 0.5, roof_hole: bool = true) -> void:
    stats["buildings"] = int(stats["buildings"]) + 1
    _keepout.append(Rect2(center.x - size.x * 0.5 - 2.0, center.z - size.y * 0.5 - 2.0, size.x + 4.0, size.y + 4.0))
    var thick: float = 0.6
    var hx: float = size.x * 0.5
    var hz: float = size.y * 0.5
    _wall("%s_N" % bname, center + Vector3(0.0, 0.0, -hz), size.x, height, thick, true, mat, _side_gaps(size.x, door_sides.has("north"), 0.0, breach_chance))
    _wall("%s_S" % bname, center + Vector3(0.0, 0.0, hz), size.x, height, thick, true, mat, _side_gaps(size.x, door_sides.has("south"), 0.0, breach_chance))
    _wall("%s_W" % bname, center + Vector3(-hx, 0.0, 0.0), size.y, height, thick, false, mat, _side_gaps(size.y, door_sides.has("west"), 0.0, breach_chance))
    _wall("%s_E" % bname, center + Vector3(hx, 0.0, 0.0), size.y, height, thick, false, mat, _side_gaps(size.y, door_sides.has("east"), 0.0, breach_chance))
    var roof_y: float = height + 0.25
    if roof_hole:
        # Collapsed roof: four slabs around an open hole so the moonlight falls inside.
        var hole: float = minf(size.x, size.y) * 0.35
        _kit.solid_box("%s_RoofN" % bname, center + Vector3(0.0, roof_y, -(hz + hole * 0.5) * 0.5 - hole * 0.25), Vector3(size.x + 1.0, 0.5, hz - hole * 0.5 + 0.5), "roof", Vector3.ZERO, &"metal")
        _kit.solid_box("%s_RoofS" % bname, center + Vector3(0.0, roof_y, (hz + hole * 0.5) * 0.5 + hole * 0.25), Vector3(size.x + 1.0, 0.5, hz - hole * 0.5 + 0.5), "roof", Vector3.ZERO, &"metal")
        _kit.solid_box("%s_RoofW" % bname, center + Vector3(-(hx + hole * 0.5) * 0.5 - hole * 0.25, roof_y, 0.0), Vector3(hx - hole * 0.5 + 0.5, 0.5, hole), "roof", Vector3.ZERO, &"metal")
        _kit.solid_box("%s_RoofE" % bname, center + Vector3((hx + hole * 0.5) * 0.5 + hole * 0.25, roof_y, 0.0), Vector3(hx - hole * 0.5 + 0.5, 0.5, hole), "roof", Vector3.ZERO, &"metal")
    else:
        _kit.solid_box("%s_Roof" % bname, center + Vector3(0.0, roof_y, 0.0), Vector3(size.x + 1.0, 0.5, size.y + 1.0), "roof", Vector3.ZERO, &"metal")
    _interior(bname, center, size, 4 + int(size.x * size.y / 120.0))

func _interior(bname: String, center: Vector3, size: Vector2, count: int) -> void:
    for index in range(count):
        var spot := center + Vector3(_rng.randf_range(-size.x * 0.38, size.x * 0.38), 0.0, _rng.randf_range(-size.y * 0.38, size.y * 0.38))
        if absf(spot.x - center.x) < 3.0 and absf(spot.z - center.z) < 3.0:
            continue
        var kind: int = _rng.randi() % 3
        if kind == 0:
            _kit.solid_box("%s_Crate_%d" % [bname, index], spot + Vector3(0.0, 0.6, 0.0), Vector3(1.2, 1.2, 1.2), "wood", Vector3(0.0, _rng.randf() * TAU, 0.0), &"crate")
        elif kind == 1:
            _kit.solid_box("%s_Desk_%d" % [bname, index], spot + Vector3(0.0, 0.45, 0.0), Vector3(2.0, 0.9, 0.9), "dark_steel", Vector3(0.0, _rng.randf() * TAU, 0.0), &"metal")
        else:
            _kit.decor_box("%s_Blood_%d" % [bname, index], spot + Vector3(0.0, 0.03, 0.0), Vector3(2.4, 0.01, 2.0), "blood", Vector3(0.0, _rng.randf() * TAU, 0.0))
        stats["props"] = int(stats["props"]) + 1

func _car(pos: Vector3, yaw: float) -> void:
    stats["vehicles"] = int(stats["vehicles"]) + 1
    var rot := Vector3(0.0, yaw, 0.0)
    _kit.solid_box("Wreck_Body", pos + Vector3(0.0, 0.55, 0.0), Vector3(4.2, 1.0, 1.9), "burnt", rot, &"metal")
    _kit.solid_box("Wreck_Cabin", pos + Vector3(0.0, 1.35, 0.0) + Vector3(-0.3 * sin(yaw), 0.0, -0.3 * cos(yaw)), Vector3(2.2, 0.8, 1.7), "rust", rot, &"metal")
    _keepout.append(Rect2(pos.x - 3.0, pos.z - 3.0, 6.0, 6.0))

func _barricade(pos: Vector3, yaw: float, length: float) -> void:
    var rot := Vector3(0.0, yaw, 0.0)
    var along := Vector3(cos(yaw), 0.0, -sin(yaw))
    var blocks: int = maxi(1, int(length / 2.0))
    for index in range(blocks):
        var offset: float = (float(index) - float(blocks - 1) * 0.5) * 2.0
        _kit.solid_box("Barrier_%d" % index, pos + along * offset + Vector3(0.0, 0.5, 0.0), Vector3(2.0, 1.0, 0.7), "concrete", rot)
    _kit.decor_box("BarrierStripe", pos + Vector3(0.0, 1.02, 0.0), Vector3(length, 0.04, 0.5), "warning", rot)
    stats["props"] = int(stats["props"]) + 1

func _lamp(pos: Vector3, color: Color, energy: float, flicker: bool, post: bool = true) -> void:
    if post:
        _kit.solid_box("LampPost", pos + Vector3(0.0, 2.6, 0.0), Vector3(0.25, 5.2, 0.25), "dark_steel", Vector3.ZERO, &"metal")
        _kit.decor_box("LampHead", pos + Vector3(0.0, 5.3, 0.0), Vector3(0.6, 0.25, 0.6), "sick_light" if color.g > color.r else "lava")
    light_sites.append({"pos": pos + Vector3(0.0, 4.8 if post else 1.5, 0.0), "color": color, "energy": energy, "flicker": flicker})
    stats["lights"] = int(stats["lights"]) + 1

func _dead_tree(pos: Vector3, scale: float = 1.0) -> void:
    stats["trees"] = int(stats["trees"]) + 1
    _kit.cylinder("DeadTree", pos + Vector3(0.0, 2.2 * scale, 0.0), 0.28 * scale, 4.4 * scale, "trunk", true, Vector3.ZERO, 0.14 * scale)
    for index in range(4):
        var yaw: float = float(index) * TAU / 4.0 + _rng.randf() * 0.5
        var branch_pos := pos + Vector3(cos(yaw) * 0.7 * scale, (3.2 + float(index) * 0.45) * scale, sin(yaw) * 0.7 * scale)
        _kit.decor_box("Branch", branch_pos, Vector3(1.6 * scale, 0.1, 0.1), "trunk", Vector3(0.0, -yaw, deg_to_rad(25.0)))

func _tombstone(pos: Vector3, yaw: float) -> void:
    stats["graves"] = int(stats["graves"]) + 1
    if _rng.randf() < 0.3:
        _kit.solid_box("Cross_V", pos + Vector3(0.0, 0.8, 0.0), Vector3(0.18, 1.6, 0.18), "bone", Vector3(0.0, yaw, 0.0))
        _kit.decor_box("Cross_H", pos + Vector3(0.0, 1.15, 0.0), Vector3(0.8, 0.16, 0.16), "bone", Vector3(0.0, yaw, 0.0))
    else:
        _kit.solid_box("Tombstone", pos + Vector3(0.0, 0.55, 0.0), Vector3(0.8, 1.1, 0.25), "bone", Vector3(0.0, yaw, deg_to_rad(_rng.randf_range(-6.0, 6.0))))

func _free(pos: Vector3, margin: float = 0.0) -> bool:
    if absf(pos.x) > HALF - 6.0 or absf(pos.z) > HALF - 6.0:
        return false
    if absf(pos.x) < 9.0 or absf(pos.z) < 9.0:
        return false
    for rect in _keepout:
        if rect.grow(margin).has_point(Vector2(pos.x, pos.z)):
            return false
    return true

# ---------------------------------------------------------------- districts

func _build_plaza(center: Vector3) -> void:
    _keepout.append(Rect2(center.x - 24.0, center.z - 24.0, 48.0, 48.0))
    _kit.decor_box("PlazaPad", center + Vector3(0.0, 0.04, 0.0), Vector3(46.0, 0.02, 46.0), "concrete")
    # Dry fountain with a toxic puddle.
    _kit.cylinder("FountainBasin", center + Vector3(0.0, 0.5, 0.0), 5.0, 1.0, "concrete", true)
    _kit.cylinder("FountainWater", center + Vector3(0.0, 1.02, 0.0), 4.4, 0.04, "toxic", false)
    _kit.cylinder("FountainColumn", center + Vector3(0.0, 2.6, 0.0), 0.6, 3.2, "concrete", true)
    _lamp(center + Vector3(0.0, 0.0, 0.0), Color("#7bff9a"), 1.4, true, false)
    for index in range(8):
        var angle: float = float(index) * TAU / 8.0
        _barricade(center + Vector3(cos(angle) * 20.0, 0.0, sin(angle) * 20.0), -angle + PI * 0.5, 6.0 if index % 2 == 0 else 4.0)
    for sign_x in [-1.0, 1.0]:
        for sign_z in [-1.0, 1.0]:
            _lamp(center + Vector3(sign_x * 15.0, 0.0, sign_z * 15.0), Color("#9dffb0"), 1.0, true)
            _building("PlazaKiosk_%d_%d" % [int(sign_x), int(sign_z)], center + Vector3(sign_x * 32.0, 0.0, sign_z * 32.0), Vector2(14.0, 10.0), 5.0, "brick", ["south" if sign_z > 0 else "north"], 0.6)
    supply_sites.append(center + Vector3(8.0, 0.0, 8.0))
    # Survivor start points around the fountain.
    for index in range(6):
        var start_angle: float = float(index) * TAU / 6.0
        spawn_positions.append({"pos": center + Vector3(cos(start_angle) * 12.0, 0.1, sin(start_angle) * 12.0), "team": "survivor"})

func _build_hospital(center: Vector3) -> void:
    _keepout.append(Rect2(center.x - 40.0, center.z - 30.0, 80.0, 60.0))
    _building("HospitalMain", center, Vector2(60.0, 34.0), 11.0, "wall", ["south", "east"], 0.8)
    _building("HospitalWingW", center + Vector3(-42.0, 0.0, 6.0), Vector2(22.0, 16.0), 8.0, "wall", ["east"], 0.7)
    _building("HospitalWingE", center + Vector3(40.0, 0.0, -2.0), Vector2(18.0, 20.0), 8.0, "wall", ["west"], 0.7)
    # Interior beds, red crosses and a flickering green exam light.
    for index in range(10):
        _kit.solid_box("Bed_%d" % index, center + Vector3(-22.0 + float(index) * 4.5, 0.4, -8.0 + float(index % 2) * 14.0), Vector3(1.0, 0.8, 2.1), "bone", Vector3.ZERO, &"crate")
    _kit.decor_box("RedCross_V", center + Vector3(0.0, 8.0, 17.4), Vector3(1.0, 4.0, 0.1), "warn_red")
    _kit.decor_box("RedCross_H", center + Vector3(0.0, 8.0, 17.4), Vector3(4.0, 1.0, 0.1), "warn_red")
    _lamp(center + Vector3(0.0, 0.0, 2.0), Color("#7bff9a"), 1.5, true, false)
    _lamp(center + Vector3(-20.0, 0.0, 0.0), Color("#ff4a3a"), 1.2, true, false)
    _car(center + Vector3(10.0, 0.0, 26.0), 0.4)
    supply_sites.append(center + Vector3(0.0, 0.0, -10.0))
    for point in [Vector3(-55.0, 0.1, -34.0), Vector3(45.0, 0.1, -30.0)]:
        spawn_positions.append({"pos": center + point, "team": "horde"})

func _build_reactor_lab(center: Vector3) -> void:
    _keepout.append(Rect2(center.x - 38.0, center.z - 34.0, 76.0, 68.0))
    _building("LabMain", center, Vector2(44.0, 30.0), 10.0, "steel", ["south", "west"], 0.4)
    _building("LabAnnex", center + Vector3(36.0, 0.0, 6.0), Vector2(16.0, 14.0), 6.0, "dark_steel", ["west"], 0.3, false)
    # Cooling towers and glowing Tesla coils around the lab.
    for sign_x in [-1.0, 1.0]:
        _kit.cylinder("CoolingTower_%d" % int(sign_x), center + Vector3(sign_x * 30.0, 9.0, -26.0), 7.0, 18.0, "concrete", true, Vector3.ZERO, 5.0)
    for index in range(6):
        var coil_pos: Vector3 = center + Vector3(-18.0 + float(index) * 7.2, 0.0, -10.0)
        _kit.cylinder("CoilTower_%d" % index, coil_pos + Vector3(0.0, 2.0, 0.0), 0.5, 4.0, "dark_steel", true)
        _kit.cylinder("CoilRing_%d" % index, coil_pos + Vector3(0.0, 4.2, 0.0), 1.1, 0.25, "tesla_blue", false)
        _lamp(coil_pos, Color("#4fd8ff"), 1.0, true, false)
    # Tesla weapon shop inside the lab, lit blue.
    shop_sites.append({"pos": center + Vector3(0.0, 0.0, 8.0), "yaw": PI, "stock": ["tesla"], "title": "Tesla Lab", "color": Color("#4fd8ff")})
    _lamp(center + Vector3(0.0, 0.0, 4.0), Color("#4fd8ff"), 2.2, false, false)
    _car(center + Vector3(-30.0, 0.0, 26.0), 1.1)
    for point in [Vector3(48.0, 0.1, -36.0), Vector3(-46.0, 0.1, 30.0)]:
        spawn_positions.append({"pos": center + point, "team": "horde"})

func _build_checkpoint(center: Vector3) -> void:
    _keepout.append(Rect2(center.x - 36.0, center.z - 30.0, 72.0, 60.0))
    _building("ArmoryHall", center, Vector2(30.0, 20.0), 7.0, "concrete", ["north", "east"], 0.3)
    for index in range(10):
        var angle: float = float(index) * 0.55 - 1.4
        _barricade(center + Vector3(cos(angle) * 28.0, 0.0, -sin(angle) * 26.0), angle, 6.0)
    for sign_x in [-1.0, 1.0]:
        _kit.solid_box("WatchTower_%d" % int(sign_x), center + Vector3(sign_x * 24.0, 5.0, 22.0), Vector3(4.0, 10.0, 4.0), "dark_steel", Vector3.ZERO, &"metal")
        _kit.solid_box("WatchPlatform_%d" % int(sign_x), center + Vector3(sign_x * 24.0, 10.2, 22.0), Vector3(7.0, 0.4, 7.0), "steel", Vector3.ZERO, &"metal")
        _lamp(center + Vector3(sign_x * 24.0, 5.0, 22.0), Color("#ff4a3a"), 1.4, true, false)
    for index in range(7):
        _kit.solid_box("Sandbag_%d" % index, center + Vector3(-12.0 + float(index) * 3.2, 0.5, 14.0), Vector3(2.4, 1.0, 1.0), "mud", Vector3.ZERO, &"crate")
    shop_sites.append({"pos": center + Vector3(0.0, 0.0, 4.0), "yaw": 0.0, "stock": ["shotgun", "smg", "revolver"], "title": "Armory", "color": Color("#ffb04a")})
    _lamp(center + Vector3(0.0, 0.0, 2.0), Color("#ffb04a"), 1.8, false, false)
    supply_sites.append(center + Vector3(10.0, 0.0, -6.0))
    for point in [Vector3(-44.0, 0.1, 36.0), Vector3(46.0, 0.1, 36.0)]:
        spawn_positions.append({"pos": center + point, "team": "horde"})

func _build_foundry(center: Vector3) -> void:
    _keepout.append(Rect2(center.x - 40.0, center.z - 32.0, 80.0, 64.0))
    _building("FoundryHall", center, Vector2(50.0, 28.0), 13.0, "rust", ["west", "north"], 0.5)
    for index in range(3):
        _kit.cylinder("Chimney_%d" % index, center + Vector3(-20.0 + float(index) * 20.0, 14.0, 22.0), 2.4, 28.0, "brick", true, Vector3.ZERO, 1.8)
        _kit.cylinder("ChimneyGlow_%d" % index, center + Vector3(-20.0 + float(index) * 20.0, 27.5, 22.0), 1.9, 0.3, "lava", false)
    for index in range(4):
        _kit.decor_box("LavaPool_%d" % index, center + Vector3(-15.0 + float(index) * 10.0, 0.05, -4.0), Vector3(5.0, 0.05, 7.0), "lava")
        _lamp(center + Vector3(-15.0 + float(index) * 10.0, 0.0, -4.0), Color("#ff6a2a"), 1.6, true, false)
    for index in range(6):
        _kit.cylinder("FuelTank_%d" % index, center + Vector3(-12.0 + float(index) * 6.0, 3.0, -26.0), 2.4, 6.0, "rust", true)
    shop_sites.append({"pos": center + Vector3(0.0, 0.0, 10.0), "yaw": PI, "stock": ["lmg", "sniper"], "title": "Foundry Depot", "color": Color("#ff6a2a")})
    for point in [Vector3(46.0, 0.1, 34.0), Vector3(-44.0, 0.1, -34.0)]:
        spawn_positions.append({"pos": center + point, "team": "horde"})

func _build_graveyard(center: Vector3) -> void:
    _keepout.append(Rect2(center.x - 40.0, center.z - 24.0, 80.0, 48.0))
    for row in range(7):
        for column in range(13):
            var spot: Vector3 = center + Vector3(-36.0 + float(column) * 6.0 + _rng.randf_range(-1.0, 1.0), 0.0, -18.0 + float(row) * 6.0 + _rng.randf_range(-1.0, 1.0))
            if absf(spot.x - center.x) < 7.0:
                continue
            _tombstone(spot, _rng.randf_range(-0.3, 0.3))
    _building("Mausoleum", center + Vector3(0.0, 0.0, -10.0), Vector2(14.0, 12.0), 8.0, "concrete", ["south"], 0.3, false)
    _lamp(center + Vector3(0.0, 0.0, -5.0), Color("#7bff9a"), 1.4, true, false)
    for index in range(8):
        _dead_tree(center + Vector3(-40.0 + float(index) * 11.0, 0.0, 22.0), 1.4)
    for point in [Vector3(-42.0, 0.1, -26.0), Vector3(42.0, 0.1, -26.0)]:
        spawn_positions.append({"pos": center + point, "team": "horde"})

func _build_rail_yard(center: Vector3) -> void:
    _keepout.append(Rect2(center.x - 50.0, center.z - 22.0, 100.0, 44.0))
    for track in range(3):
        var z: float = center.z - 12.0 + float(track) * 12.0
        _kit.decor_box("Rails_%d" % track, Vector3(center.x, 0.1, z), Vector3(96.0, 0.08, 2.4), "dark_steel")
        for tie in range(32):
            _kit.decor_box("Tie", Vector3(center.x - 47.0 + float(tie) * 3.0, 0.05, z), Vector3(0.5, 0.06, 3.0), "wood")
    for index in range(5):
        var car_x: float = center.x - 34.0 + float(index) * 17.0
        var car_z: float = center.z - 12.0 + float(index % 3) * 12.0
        _kit.solid_box("TrainCar_%d" % index, Vector3(car_x, 1.9, car_z), Vector3(13.0, 3.4, 3.0), "container_%d" % index, Vector3.ZERO, &"metal")
        _kit.solid_box("TrainRoof_%d" % index, Vector3(car_x, 3.7, car_z), Vector3(13.4, 0.3, 3.2), "dark_steel", Vector3.ZERO, &"metal")
    _building("StationHouse", center + Vector3(0.0, 0.0, 18.0), Vector2(36.0, 10.0), 6.0, "brick", ["north"], 0.5)
    _lamp(center + Vector3(-20.0, 0.0, 0.0), Color("#ff4a3a"), 1.4, true)
    _lamp(center + Vector3(20.0, 0.0, 0.0), Color("#7bff9a"), 1.4, true)
    for point in [Vector3(-52.0, 0.1, 6.0), Vector3(52.0, 0.1, 6.0)]:
        spawn_positions.append({"pos": center + point, "team": "horde"})

func _build_residential(center: Vector3) -> void:
    _keepout.append(Rect2(center.x - 30.0, center.z - 90.0, 60.0, 180.0))
    for index in range(8):
        var z: float = center.z - 78.0 + float(index) * 22.0
        var width: float = 14.0 + float(index % 3) * 3.0
        _building("Apartment_%d" % index, Vector3(center.x - 10.0 + float(index % 2) * 18.0, 0.0, z), Vector2(width, 14.0), 9.0 + float(index % 3) * 3.0, "brick", ["east" if index % 2 == 0 else "west"], 0.7)
    _lamp(center + Vector3(0.0, 0.0, -30.0), Color("#9dffb0"), 1.2, true)
    _lamp(center + Vector3(0.0, 0.0, 30.0), Color("#ff4a3a"), 1.2, true)
    spawn_positions.append({"pos": center + Vector3(-12.0, 0.1, -96.0), "team": "horde"})
    spawn_positions.append({"pos": center + Vector3(-12.0, 0.1, 96.0), "team": "horde"})

func _build_container_maze(center: Vector3) -> void:
    _keepout.append(Rect2(center.x - 34.0, center.z - 90.0, 68.0, 180.0))
    for row in range(10):
        for column in range(5):
            if (row * 5 + column) % 3 == 0:
                continue
            var yaw: float = 0.0 if (row + column) % 2 == 0 else PI * 0.5
            var pos: Vector3 = center + Vector3(-24.0 + float(column) * 12.0, 1.45, -80.0 + float(row) * 17.0)
            _kit.solid_box("Maze_%d_%d" % [row, column], pos, Vector3(12.0, 2.9, 2.6), "container_%d" % (row + column), Vector3(0.0, yaw, 0.0), &"metal")
            if (row + column) % 4 == 0:
                _kit.solid_box("MazeUpper_%d_%d" % [row, column], pos + Vector3(0.0, 2.9, 0.0), Vector3(12.0, 2.9, 2.6), "container_%d" % (row + column + 3), Vector3(0.0, yaw, 0.0), &"metal")
    _lamp(center + Vector3(0.0, 0.0, 0.0), Color("#ffb04a"), 1.2, true)
    spawn_positions.append({"pos": center + Vector3(12.0, 0.1, -96.0), "team": "horde"})
    spawn_positions.append({"pos": center + Vector3(12.0, 0.1, 96.0), "team": "horde"})

# ---------------------------------------------------------------- scatter

func _scatter_wrecks(count: int) -> void:
    var placed: int = 0
    var attempts: int = 0
    while placed < count and attempts < count * 12:
        attempts += 1
        var on_road: bool = _rng.randf() < 0.6
        var pos := Vector3(_rng.randf_range(-190.0, 190.0), 0.0, _rng.randf_range(-6.0, 6.0))
        if not on_road:
            pos = Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-190.0, 190.0))
        var blocked: bool = false
        for rect in _keepout:
            if rect.grow(2.0).has_point(Vector2(pos.x, pos.z)):
                blocked = true
        if blocked or absf(pos.x) > HALF - 8.0 or absf(pos.z) > HALF - 8.0:
            continue
        _car(pos, _rng.randf() * TAU)
        placed += 1

func _scatter_rubble(count: int) -> void:
    var placed: int = 0
    var attempts: int = 0
    while placed < count and attempts < count * 10:
        attempts += 1
        var pos := Vector3(_rng.randf_range(-190.0, 190.0), 0.0, _rng.randf_range(-190.0, 190.0))
        if not _free(pos, 1.0):
            continue
        var size := Vector3(_rng.randf_range(1.0, 3.2), _rng.randf_range(0.6, 1.8), _rng.randf_range(1.0, 3.2))
        _kit.solid_box("Rubble", pos + Vector3(0.0, size.y * 0.5, 0.0), size, "concrete" if placed % 2 == 0 else "brick", Vector3(0.0, _rng.randf() * TAU, 0.0))
        placed += 1
        stats["props"] = int(stats["props"]) + 1

func _scatter_dead_trees(count: int) -> void:
    var placed: int = 0
    var attempts: int = 0
    while placed < count and attempts < count * 10:
        attempts += 1
        var pos := Vector3(_rng.randf_range(-190.0, 190.0), 0.0, _rng.randf_range(-190.0, 190.0))
        if not _free(pos, 2.0):
            continue
        _dead_tree(pos, _rng.randf_range(0.8, 1.5))
        placed += 1

func _scatter_street_lamps() -> void:
    for index in range(-3, 4):
        if index == 0:
            continue
        _lamp(Vector3(float(index) * 50.0, 0.0, 9.0), Color("#9dffb0") if index % 2 == 0 else Color("#ff4a3a"), 1.1, true)
        _lamp(Vector3(9.0, 0.0, float(index) * 50.0), Color("#9dffb0") if index % 2 != 0 else Color("#ffb04a"), 1.1, true)

# ---------------------------------------------------------------- spawns

func _build_spawns() -> void:
    # Outer ring of horde entrances so waves always come from far away.
    for index in range(12):
        var angle: float = float(index) * TAU / 12.0 + 0.2
        spawn_positions.append({"pos": Vector3(cos(angle) * 188.0, 0.1, sin(angle) * 188.0).clamp(Vector3(-188.0, 0.1, -188.0), Vector3(188.0, 0.1, 188.0)), "team": "horde"})
