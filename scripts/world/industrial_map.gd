extends RefCounted
class_name IndustrialMap

## Layout of the main Iron Yard map (160 x 160 m): a shipping yard with warehouses, a
## factory hall with smokestack, a control tower, container canyons, trucks, cranes, fuel
## tanks, perimeter wall, vegetation, puddles and balanced spawn points.

const HALF: float = 80.0

var _kit: MapKit
var _root: Node3D
var _rng := RandomNumberGenerator.new()
var spawn_positions: Array[Dictionary] = []
var light_poles: Array[Vector3] = []
var stats: Dictionary = {"buildings": 0, "containers": 0, "trucks": 0, "cranes": 0, "trees": 0, "props": 0}

func build(root: Node3D, kit: MapKit) -> void:
    _root = root
    _kit = kit
    _rng.seed = 20260518
    _build_ground_and_roads()
    _build_perimeter()
    _build_warehouse("WarehouseWest", Vector3(-52.0, 0.0, 30.0), Vector2(26.0, 16.0), 9.0, "south")
    _build_warehouse("WarehouseNorth", Vector3(-20.0, 0.0, -58.0), Vector2(30.0, 14.0), 8.5, "east")
    _build_warehouse("WarehouseEast", Vector3(55.0, 0.0, 38.0), Vector2(22.0, 18.0), 9.0, "west")
    _kit.force_core = true
    _build_factory(Vector3(46.0, 0.0, -42.0))
    _build_tower(Vector3(0.0, 0.0, -8.0))
    _kit.force_core = false
    _build_container_yard()
    _build_trucks()
    _kit.force_core = true
    _build_cranes()
    _kit.force_core = false
    _build_fuel_depot(Vector3(-60.0, 0.0, -30.0))
    _build_props()
    _build_light_poles()
    _build_vegetation()
    _build_puddles()
    _build_spawns()

# ---------------------------------------------------------------- terrain

func _build_ground_and_roads() -> void:
    var core := _root.get_node("Regions/Core") as Node3D
    _kit.solid_box("Ground", Vector3(0.0, -0.5, 0.0), Vector3(HALF * 2.0 + 20.0, 1.0, HALF * 2.0 + 20.0), "dirt", Vector3.ZERO, &"concrete", core)
    # Paved yard in the middle, asphalt roads on top (decor only, flush with the ground).
    _kit.decor_box("YardPad", Vector3(0.0, 0.012, 0.0), Vector3(150.0, 0.02, 150.0), "concrete", Vector3.ZERO, false, core)
    _kit.decor_box("RoadEastWest", Vector3(0.0, 0.025, 6.0), Vector3(150.0, 0.02, 10.0), "asphalt", Vector3.ZERO, false, core)
    _kit.decor_box("RoadNorthSouth", Vector3(-2.0, 0.026, 0.0), Vector3(9.0, 0.02, 150.0), "asphalt", Vector3.ZERO, false, core)
    _kit.decor_box("RoadLoopNorth", Vector3(0.0, 0.027, -68.0), Vector3(140.0, 0.02, 7.0), "asphalt", Vector3.ZERO, false, core)
    _kit.decor_box("RoadLoopSouth", Vector3(0.0, 0.027, 68.0), Vector3(140.0, 0.02, 7.0), "asphalt", Vector3.ZERO, false, core)
    # Dashed centre lines.
    for index in range(-14, 15):
        _kit.decor_box("LineEW_%d" % index, Vector3(float(index) * 5.0, 0.04, 6.0), Vector3(2.4, 0.01, 0.22), "warning", Vector3.ZERO, false, core)
        _kit.decor_box("LineNS_%d" % index, Vector3(-2.0, 0.04, float(index) * 5.0), Vector3(0.22, 0.01, 2.4), "warning", Vector3.ZERO, false, core)
    # Grass strips along the edge.
    for side in [-1.0, 1.0]:
        _kit.decor_box("GrassStrip_X_%d" % int(side), Vector3(0.0, 0.02, side * 76.0), Vector3(158.0, 0.03, 8.0), "grass", Vector3.ZERO, false, core)
        _kit.decor_box("GrassStrip_Z_%d" % int(side), Vector3(side * 76.0, 0.02, 0.0), Vector3(8.0, 0.03, 158.0), "grass", Vector3.ZERO, false, core)

func _build_perimeter() -> void:
    var core := _root.get_node("Regions/Core") as Node3D
    var length := HALF * 2.0 + 4.0
    _kit.solid_box("WallNorth", Vector3(0.0, 3.0, -HALF - 1.0), Vector3(length, 6.0, 1.2), "wall", Vector3.ZERO, &"concrete", core)
    _kit.solid_box("WallSouth", Vector3(0.0, 3.0, HALF + 1.0), Vector3(length, 6.0, 1.2), "wall", Vector3.ZERO, &"concrete", core)
    _kit.solid_box("WallWest", Vector3(-HALF - 1.0, 3.0, 0.0), Vector3(1.2, 6.0, length), "wall", Vector3.ZERO, &"concrete", core)
    _kit.solid_box("WallEast", Vector3(HALF + 1.0, 3.0, 0.0), Vector3(1.2, 6.0, length), "wall", Vector3.ZERO, &"concrete", core)
    # Warning stripe along the top of the wall so the boundary reads clearly.
    for wall in [Vector3(0.0, 5.8, -HALF - 0.38), Vector3(0.0, 5.8, HALF + 0.38)]:
        _kit.decor_box("WallStripe", wall, Vector3(length, 0.3, 0.05), "warning", Vector3.ZERO, false, core)

# ---------------------------------------------------------------- buildings

func _build_warehouse(building_name: String, center: Vector3, footprint: Vector2, wall_height: float, door_side: String) -> void:
    stats["buildings"] = int(stats["buildings"]) + 1
    var thickness := 0.5
    var door_width := 6.0
    var door_height := 4.6
    var half_x := footprint.x * 0.5
    var half_z := footprint.y * 0.5
    var roof_y := wall_height + 0.25
    # Four walls; the door side is split into two pieces with a lintel above the opening.
    for side in ["north", "south", "east", "west"]:
        var along_x: bool = side == "north" or side == "south"
        var wall_length: float = footprint.x if along_x else footprint.y
        var offset: Vector3 = Vector3.ZERO
        match side:
            "north": offset = Vector3(0.0, 0.0, -half_z)
            "south": offset = Vector3(0.0, 0.0, half_z)
            "east": offset = Vector3(half_x, 0.0, 0.0)
            "west": offset = Vector3(-half_x, 0.0, 0.0)
        var size := Vector3(wall_length, wall_height, thickness) if along_x else Vector3(thickness, wall_height, wall_length)
        if side == door_side:
            var segment: float = (wall_length - door_width) * 0.5
            var shift: float = (door_width + segment) * 0.5
            for sign_value in [-1.0, 1.0]:
                var piece_center: Vector3 = center + offset + (Vector3(sign_value * shift, wall_height * 0.5, 0.0) if along_x else Vector3(0.0, wall_height * 0.5, sign_value * shift))
                var piece_size := Vector3(segment, wall_height, thickness) if along_x else Vector3(thickness, wall_height, segment)
                _kit.solid_box("%s_Wall_%s_%d" % [building_name, side, int(sign_value)], piece_center, piece_size, "brick")
            var lintel_height := wall_height - door_height
            var lintel_center: Vector3 = center + offset + Vector3(0.0, door_height + lintel_height * 0.5, 0.0)
            var lintel_size := Vector3(door_width, lintel_height, thickness) if along_x else Vector3(thickness, lintel_height, door_width)
            _kit.solid_box("%s_Lintel_%s" % [building_name, side], lintel_center, lintel_size, "brick")
            # Hazard stripes on the door frame.
            var frame_size := Vector3(door_width + 0.4, 0.35, thickness + 0.1) if along_x else Vector3(thickness + 0.1, 0.35, door_width + 0.4)
            _kit.decor_box("%s_DoorFrame_%s" % [building_name, side], center + offset + Vector3(0.0, door_height + 0.2, 0.0), frame_size, "warning")
        else:
            _kit.solid_box("%s_Wall_%s" % [building_name, side], center + offset + Vector3(0.0, wall_height * 0.5, 0.0), size, "brick")
            # High clerestory windows: dark glass strips, decor only.
            var window_size := Vector3(wall_length * 0.8, 0.9, thickness + 0.06) if along_x else Vector3(thickness + 0.06, 0.9, wall_length * 0.8)
            _kit.decor_box("%s_Windows_%s" % [building_name, side], center + offset + Vector3(0.0, wall_height - 1.4, 0.0), window_size, "glass")
    _kit.solid_box("%s_Roof" % building_name, center + Vector3(0.0, roof_y, 0.0), Vector3(footprint.x + 1.0, 0.5, footprint.y + 1.0), "roof", Vector3.ZERO, &"metal")
    for rib in range(int(footprint.x / 4.0)):
        _kit.decor_box("%s_RoofRib_%d" % [building_name, rib], center + Vector3(-half_x + 2.0 + float(rib) * 4.0, roof_y + 0.4, 0.0), Vector3(0.3, 0.35, footprint.y + 1.0), "dark_steel")
    # Interior: shelving racks and pallets so the inside plays like a real warehouse.
    var rack_count := 3
    for rack in range(rack_count):
        var rack_x: float = -half_x + 4.0 + float(rack) * (footprint.x - 8.0) / float(rack_count - 1)
        _kit.solid_box("%s_Rack_%d" % [building_name, rack], center + Vector3(rack_x, 1.6, -half_z * 0.35), Vector3(1.4, 3.2, 6.0), "steel", Vector3.ZERO, &"metal")
        _kit.solid_box("%s_Pallet_%d" % [building_name, rack], center + Vector3(rack_x + 2.0, 0.55, half_z * 0.35), Vector3(1.6, 1.1, 1.6), "wood", Vector3.ZERO, &"crate")
    # Interior lamp strip.
    _kit.decor_box("%s_LampStrip" % building_name, center + Vector3(0.0, wall_height - 0.4, 0.0), Vector3(footprint.x * 0.6, 0.12, 0.3), "lamp")

func _build_factory(center: Vector3) -> void:
    stats["buildings"] = int(stats["buildings"]) + 1
    var size := Vector2(40.0, 24.0)
    var height := 14.0
    var thickness := 0.7
    var half_x := size.x * 0.5
    var half_z := size.y * 0.5
    # Walls with two doors on the south side.
    var door := 6.0
    var segment := (size.x - door * 2.0) / 3.0
    var cursor := -half_x
    for index in range(3):
        _kit.solid_box("Factory_SouthWall_%d" % index, center + Vector3(cursor + segment * 0.5, height * 0.5, half_z), Vector3(segment, height, thickness), "steel")
        cursor += segment + door
    for index in range(2):
        var door_center_x := -half_x + segment * float(index + 1) + door * (float(index) + 0.5)
        _kit.solid_box("Factory_SouthLintel_%d" % index, center + Vector3(door_center_x, 4.6 + (height - 4.6) * 0.5, half_z), Vector3(door, height - 4.6, thickness), "steel")
    _kit.solid_box("Factory_NorthWall", center + Vector3(0.0, height * 0.5, -half_z), Vector3(size.x, height, thickness), "steel")
    _kit.solid_box("Factory_EastWall", center + Vector3(half_x, height * 0.5, 0.0), Vector3(thickness, height, size.y), "steel")
    _kit.solid_box("Factory_WestWall", center + Vector3(-half_x, height * 0.5, 0.0), Vector3(thickness, height, size.y), "steel")
    _kit.solid_box("Factory_Roof", center + Vector3(0.0, height + 0.3, 0.0), Vector3(size.x + 1.0, 0.6, size.y + 1.0), "roof", Vector3.ZERO, &"metal")
    # Interior catwalk reached by a staircase, with railings.
    _kit.solid_box("Factory_Catwalk", center + Vector3(0.0, 5.0, -half_z + 4.0), Vector3(size.x - 4.0, 0.4, 5.0), "dark_steel", Vector3.ZERO, &"grate")
    _kit.stairs("Factory_Stairs", center + Vector3(-half_x + 3.2, 0.0, half_z - 3.0), Vector3(0.0, 0.0, -1.0), 25, 0.2, 0.7, 2.2)
    _kit.solid_box("Factory_StairLanding", center + Vector3(-half_x + 3.2, 4.8, -half_z + 7.5), Vector3(3.0, 0.4, 4.0), "dark_steel", Vector3.ZERO, &"grate")
    _kit.decor_box("Factory_CatwalkRail", center + Vector3(0.0, 5.8, -half_z + 6.4), Vector3(size.x - 8.0, 0.1, 0.1), "warning")
    # Production machinery in the hall.
    for index in range(4):
        _kit.solid_box("Factory_Press_%d" % index, center + Vector3(-12.0 + float(index) * 8.0, 1.9, 2.0), Vector3(3.2, 3.8, 3.2), "rust", Vector3.ZERO, &"metal")
        _kit.decor_box("Factory_PressLight_%d" % index, center + Vector3(-12.0 + float(index) * 8.0, 4.0, 2.0), Vector3(0.6, 0.3, 0.6), "red_lamp")
    for index in range(3):
        _kit.solid_box("Factory_Conveyor_%d" % index, center + Vector3(-10.0 + float(index) * 10.0, 0.5, 8.0), Vector3(9.0, 1.0, 1.4), "dark_steel", Vector3.ZERO, &"rubber")
    # Smokestack and exhaust ducts outside.
    _kit.cylinder("Factory_Smokestack", center + Vector3(half_x + 5.0, 16.0, -half_z + 4.0), 2.2, 32.0, "brick", true, Vector3.ZERO, 1.6)
    _kit.cylinder("Factory_StackRing", center + Vector3(half_x + 5.0, 31.0, -half_z + 4.0), 1.8, 0.6, "warning", false)
    _kit.decor_box("Factory_Duct", center + Vector3(half_x + 2.5, 11.0, -half_z + 4.0), Vector3(6.0, 1.4, 1.4), "dark_steel")
    # Rooftop access ladder pipes (decor).
    for index in range(5):
        _kit.cylinder("Factory_Pipe_%d" % index, center + Vector3(-half_x - 0.9, 3.0 + float(index) * 2.2, 3.0), 0.12, 10.0, "steel", false, Vector3(PI * 0.5, 0.0, 0.0))

func _build_tower(center: Vector3) -> void:
    stats["buildings"] = int(stats["buildings"]) + 1
    var deck_top := 16.0
    _kit.solid_box("Tower_Base", center + Vector3(0.0, 3.0, 0.0), Vector3(8.0, 6.0, 8.0), "wall")
    _kit.solid_box("Tower_Shaft", center + Vector3(0.0, deck_top * 0.5 - 0.25, 0.0), Vector3(5.0, deck_top - 0.5, 5.0), "steel", Vector3.ZERO, &"metal")
    _kit.solid_box("Tower_Deck", center + Vector3(0.0, deck_top - 0.25, 0.0), Vector3(11.0, 0.5, 11.0), "dark_steel", Vector3.ZERO, &"grate")
    _kit.solid_box("Tower_Cabin", center + Vector3(0.0, deck_top + 2.0, -1.5), Vector3(5.0, 4.0, 4.0), "wall")
    _kit.decor_box("Tower_CabinGlass", center + Vector3(0.0, deck_top + 2.3, 0.55), Vector3(4.2, 1.6, 0.08), "glass")
    _kit.solid_box("Tower_CabinRoof", center + Vector3(0.0, deck_top + 4.2, -1.5), Vector3(6.0, 0.4, 5.0), "roof", Vector3.ZERO, &"metal")
    for corner in [Vector3(5.3, 0.6, 5.3), Vector3(-5.3, 0.6, 5.3), Vector3(5.3, 0.6, -5.3), Vector3(-5.3, 0.6, -5.3)]:
        _kit.solid_box("Tower_RailPost", center + corner + Vector3(0.0, deck_top, 0.0), Vector3(0.2, 1.2, 0.2), "warning")
    _kit.decor_box("Tower_Beacon", center + Vector3(0.0, deck_top + 4.8, -1.5), Vector3(0.6, 0.6, 0.6), "red_lamp")
    # Long ramp (single collider) from the road up to the observation deck, with support pillars.
    var run := 25.0
    var rise := deck_top
    var angle := atan2(rise, run)
    var normal := Vector3(0.0, cos(angle), sin(angle))
    var mid := center + Vector3(0.0, rise * 0.5, 5.5 + run * 0.5)
    _kit.solid_box("Tower_Ramp", mid - normal * 0.2, Vector3(4.0, 0.4, sqrt(run * run + rise * rise)), "dark_steel", Vector3(angle, 0.0, 0.0), &"grate")
    for index in range(1, 4):
        var fraction := float(index) * 0.25
        var pillar_height := rise * (1.0 - fraction) - 0.4
        var pillar_z := 5.5 + run * fraction
        _kit.solid_box("Tower_RampPillar_%d" % index, center + Vector3(0.0, pillar_height * 0.5, pillar_z), Vector3(0.6, pillar_height, 0.6), "steel", Vector3.ZERO, &"metal")
    for side in [-2.1, 2.1]:
        _kit.decor_box("Tower_RampRail", mid + Vector3(side, 0.9, 0.0) , Vector3(0.08, 0.08, sqrt(run * run + rise * rise)), "warning", Vector3(angle, 0.0, 0.0))

# ---------------------------------------------------------------- yard objects

func _build_container_yard() -> void:
    var rows: Array[Dictionary] = [
        {"origin": Vector3(-70.0, 0.0, 52.0), "along": Vector3(1.0, 0.0, 0.0), "count": 6, "stack": 3},
        {"origin": Vector3(-70.0, 0.0, 56.0), "along": Vector3(1.0, 0.0, 0.0), "count": 6, "stack": 2},
        {"origin": Vector3(10.0, 0.0, 56.0), "along": Vector3(1.0, 0.0, 0.0), "count": 5, "stack": 2},
        {"origin": Vector3(10.0, 0.0, 52.0), "along": Vector3(1.0, 0.0, 0.0), "count": 5, "stack": 3},
        {"origin": Vector3(30.0, 0.0, -10.0), "along": Vector3(0.0, 0.0, 1.0), "count": 5, "stack": 2},
        {"origin": Vector3(34.0, 0.0, -10.0), "along": Vector3(0.0, 0.0, 1.0), "count": 5, "stack": 1},
        {"origin": Vector3(-34.0, 0.0, -20.0), "along": Vector3(0.0, 0.0, 1.0), "count": 4, "stack": 2},
        {"origin": Vector3(-38.0, 0.0, -20.0), "along": Vector3(0.0, 0.0, 1.0), "count": 4, "stack": 3},
        {"origin": Vector3(-20.0, 0.0, 22.0), "along": Vector3(1.0, 0.0, 0.0), "count": 3, "stack": 2},
        {"origin": Vector3(20.0, 0.0, -28.0), "along": Vector3(1.0, 0.0, 0.0), "count": 3, "stack": 1},
    ]
    var color_index := 0
    for row in rows:
        var origin: Vector3 = row["origin"]
        var along: Vector3 = row["along"]
        var yaw := 0.0 if absf(along.x) > 0.5 else PI * 0.5
        for index in range(int(row["count"])):
            var stack_height := 1 + (_rng.randi() % int(row["stack"]))
            for level in range(stack_height):
                var position := origin + along * (13.0 * float(index)) + Vector3(0.0, 1.3 + 2.6 * float(level), 0.0)
                var body := _kit.solid_box("Container_%d" % int(stats["containers"]), position, Vector3(12.2, 2.6, 2.44), "container_0", Vector3(0.0, yaw, 0.0), &"metal")
                (body.get_child(1) as MeshInstance3D).material_override = _kit.container_material(color_index)
                stats["containers"] = int(stats["containers"]) + 1
                color_index += 1
                # Corrugation hint: two dark door lines on the short end.
                var end_offset := along * 6.15
                _kit.decor_box("ContainerDoor", position + end_offset, Vector3(0.05, 2.3, 0.06) if yaw == 0.0 else Vector3(0.06, 2.3, 0.05), "black", Vector3(0.0, yaw, 0.0))

func _build_trucks() -> void:
    var spots: Array[Dictionary] = [
        {"pos": Vector3(-28.0, 0.0, 10.5), "yaw": 0.0},
        {"pos": Vector3(24.0, 0.0, 1.5), "yaw": PI},
        {"pos": Vector3(-8.0, 0.0, 66.0), "yaw": 0.0},
        {"pos": Vector3(60.0, 0.0, -14.0), "yaw": PI * 0.5},
    ]
    for spot in spots:
        _build_truck(spot["pos"], float(spot["yaw"]))

func _build_truck(origin: Vector3, yaw: float) -> void:
    stats["trucks"] = int(stats["trucks"]) + 1
    var root := Node3D.new()
    root.name = "Truck_%d" % int(stats["trucks"])
    root.position = origin
    root.rotation.y = yaw
    var host := _kit._parent_for(origin)
    host.add_child(root)
    var color_index: int = int(stats["trucks"]) * 3
    _kit.solid_box("Cab", Vector3(0.0, 1.6, -5.4), Vector3(2.5, 2.4, 2.6), "container_0", Vector3.ZERO, &"metal", root).get_child(1).set("material_override", _kit.container_material(color_index))
    _kit.decor_box("CabGlass", Vector3(0.0, 2.3, -6.72), Vector3(2.2, 0.9, 0.06), "glass", Vector3.ZERO, false, root)
    _kit.solid_box("Chassis", Vector3(0.0, 0.85, -0.5), Vector3(2.2, 0.5, 11.0), "dark_steel", Vector3.ZERO, &"metal", root)
    _kit.solid_box("Trailer", Vector3(0.0, 2.2, 0.8), Vector3(2.5, 2.7, 8.2), "container_0", Vector3.ZERO, &"metal", root).get_child(1).set("material_override", _kit.container_material(color_index + 1))
    for wheel_z in [-5.4, -1.2, 0.4, 2.0, 3.6]:
        for wheel_x in [-1.15, 1.15]:
            var wheel := MeshInstance3D.new()
            var wheel_mesh := CylinderMesh.new()
            wheel_mesh.top_radius = 0.5
            wheel_mesh.bottom_radius = 0.5
            wheel_mesh.height = 0.4
            wheel_mesh.radial_segments = 12
            wheel_mesh.rings = 1
            wheel.mesh = wheel_mesh
            wheel.material_override = _kit.mat("rubber")
            wheel.position = Vector3(wheel_x, 0.5, wheel_z)
            wheel.rotation.z = PI * 0.5
            wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            root.add_child(wheel)
    _kit.decor_box("Headlights", Vector3(0.0, 1.1, -6.72), Vector3(2.0, 0.2, 0.06), "lamp", Vector3.ZERO, false, root)

func _build_cranes() -> void:
    # Gantry crane over the container yard.
    stats["cranes"] = int(stats["cranes"]) + 1
    var gantry := Vector3(-40.0, 0.0, 54.0)
    for corner in [Vector3(-12.0, 0.0, -5.0), Vector3(12.0, 0.0, -5.0), Vector3(-12.0, 0.0, 5.0), Vector3(12.0, 0.0, 5.0)]:
        _kit.solid_box("GantryLeg", gantry + corner + Vector3(0.0, 9.0, 0.0), Vector3(1.0, 18.0, 1.0), "warning", Vector3.ZERO, &"metal")
    _kit.solid_box("GantryBeamA", gantry + Vector3(0.0, 18.5, -5.0), Vector3(26.0, 1.2, 1.2), "steel", Vector3.ZERO, &"metal")
    _kit.solid_box("GantryBeamB", gantry + Vector3(0.0, 18.5, 5.0), Vector3(26.0, 1.2, 1.2), "steel", Vector3.ZERO, &"metal")
    _kit.decor_box("GantryTrolley", gantry + Vector3(3.0, 17.2, 0.0), Vector3(3.0, 1.4, 10.0), "dark_steel")
    _kit.decor_box("GantryCable", gantry + Vector3(3.0, 12.0, 0.0), Vector3(0.1, 10.0, 0.1), "black")
    _kit.decor_box("GantryHook", gantry + Vector3(3.0, 6.8, 0.0), Vector3(1.0, 0.5, 1.0), "warning")
    # Tower crane near the factory.
    stats["cranes"] = int(stats["cranes"]) + 1
    var tower := Vector3(18.0, 0.0, -50.0)
    _kit.solid_box("TowerCraneBase", tower + Vector3(0.0, 1.0, 0.0), Vector3(5.0, 2.0, 5.0), "concrete")
    _kit.solid_box("TowerCraneMast", tower + Vector3(0.0, 17.0, 0.0), Vector3(1.8, 30.0, 1.8), "warning", Vector3.ZERO, &"metal")
    _kit.decor_box("TowerCraneJib", tower + Vector3(10.0, 31.0, 0.0), Vector3(30.0, 1.0, 1.4), "warning")
    _kit.decor_box("TowerCraneCounter", tower + Vector3(-9.0, 30.4, 0.0), Vector3(3.0, 2.2, 3.0), "dark_steel")
    _kit.decor_box("TowerCraneCab", tower + Vector3(1.5, 28.8, 1.8), Vector3(2.0, 2.0, 2.0), "glass")
    _kit.decor_box("TowerCraneHook", tower + Vector3(18.0, 22.0, 0.0), Vector3(0.12, 17.0, 0.12), "black")

func _build_fuel_depot(center: Vector3) -> void:
    for index in range(4):
        var tank_pos := center + Vector3(float(index % 2) * 9.0, 3.0, float(index / 2) * 9.0)
        _kit.cylinder("FuelTank_%d" % index, tank_pos, 3.4, 6.0, "steel", true)
        _kit.cylinder("FuelTankCap_%d" % index, tank_pos + Vector3(0.0, 3.1, 0.0), 3.0, 0.4, "dark_steel", false)
        _kit.decor_box("TankLadder_%d" % index, tank_pos + Vector3(3.5, 0.0, 0.0), Vector3(0.1, 6.0, 0.5), "warning")
    for index in range(3):
        _kit.cylinder("TankPipe_%d" % index, center + Vector3(4.5, 0.6 + float(index) * 0.3, 4.5), 0.2, 9.0, "rust", false, Vector3(0.0, 0.0, PI * 0.5))
    _kit.solid_box("FuelDepotBund", center + Vector3(4.5, 0.2, -5.6), Vector3(20.0, 0.4, 0.6), "concrete")
    stats["props"] = int(stats["props"]) + 6

func _build_props() -> void:
    # Concrete barriers forming lanes, barrels, crate stacks and stockpiles spread across the yard.
    for index in range(26):
        var angle := float(index) * 0.7
        var barrier_pos := Vector3(_rng.randf_range(-60.0, 60.0), 0.5, _rng.randf_range(-45.0, 45.0))
        if _is_reserved(barrier_pos):
            continue
        _kit.solid_box("Barrier_%d" % index, barrier_pos, Vector3(3.0, 1.0, 0.7), "concrete", Vector3(0.0, angle, 0.0))
        stats["props"] = int(stats["props"]) + 1
    for index in range(30):
        var pos := Vector3(_rng.randf_range(-62.0, 62.0), 0.0, _rng.randf_range(-48.0, 48.0))
        if _is_reserved(pos):
            continue
        var crate_size := _rng.randf_range(1.1, 1.8)
        var crate_stack := 1 + (_rng.randi() % 2)
        for level in range(crate_stack):
            _kit.solid_box("CrateStack_%d_%d" % [index, level], pos + Vector3(0.0, crate_size * 0.5 + crate_size * float(level), 0.0), Vector3(crate_size, crate_size, crate_size), "wood", Vector3(0.0, _rng.randf() * PI, 0.0), &"crate")
        stats["props"] = int(stats["props"]) + 1
    for index in range(22):
        var pos := Vector3(_rng.randf_range(-62.0, 62.0), 0.0, _rng.randf_range(-48.0, 48.0))
        if _is_reserved(pos):
            continue
        var barrel_color := "rust" if index % 3 == 0 else ("warning" if index % 3 == 1 else "steel")
        for cluster in range(3):
            _kit.cylinder("Barrel_%d_%d" % [index, cluster], pos + Vector3(float(cluster) * 0.85, 0.5, float(cluster % 2) * 0.6), 0.36, 1.0, barrel_color, true)
        stats["props"] = int(stats["props"]) + 1
    # Gravel stockpiles (cone visuals with a low collider).
    for stock in [Vector3(-8.0, 0.0, 40.0), Vector3(38.0, 0.0, 18.0), Vector3(-66.0, 0.0, 6.0)]:
        _kit.cylinder("Stockpile", stock + Vector3(0.0, 1.6, 0.0), 4.2, 3.2, "dirt", false, Vector3.ZERO, 0.4)
        _kit.solid_box("StockpileCollider", stock + Vector3(0.0, 0.8, 0.0), Vector3(5.0, 1.6, 5.0), "dirt")
        stats["props"] = int(stats["props"]) + 1
    # Pipe rack along the north edge of the yard.
    for index in range(8):
        _kit.solid_box("PipeRackPost_%d" % index, Vector3(-40.0 + float(index) * 10.0, 1.8, -72.0), Vector3(0.5, 3.6, 0.5), "steel", Vector3.ZERO, &"metal")
    for pipe in range(3):
        _kit.cylinder("PipeRackPipe_%d" % pipe, Vector3(-5.0, 3.0 + float(pipe) * 0.45, -72.0), 0.22, 72.0, "rust", false, Vector3(0.0, 0.0, PI * 0.5))
    # Fences and lane markings near the entrance.
    for index in range(10):
        _kit.decor_box("FenceSegment_%d" % index, Vector3(-50.0 + float(index) * 2.2, 1.0, 76.0), Vector3(2.0, 2.0, 0.06), "dark_steel")

func _is_reserved(pos: Vector3) -> bool:
    # Keep roads, building footprints and the tower base free of random clutter.
    if absf(pos.z - 6.0) < 7.0 or absf(pos.x + 2.0) < 6.0:
        return true
    var zones: Array[Rect2] = [
        Rect2(-67.0, 20.0, 30.0, 20.0), Rect2(-37.0, -67.0, 34.0, 18.0), Rect2(42.0, 27.0, 26.0, 22.0),
        Rect2(24.0, -56.0, 44.0, 28.0), Rect2(-6.0, -14.0, 12.0, 12.0), Rect2(-72.0, -42.0, 24.0, 24.0),
        Rect2(-72.0, 48.0, 30.0, 16.0), Rect2(6.0, 46.0, 40.0, 16.0),
    ]
    for zone in zones:
        if zone.grow(2.0).has_point(Vector2(pos.x, pos.z)):
            return true
    return false

func _build_light_poles() -> void:
    var positions: Array[Vector3] = [
        Vector3(-30.0, 0.0, 0.0), Vector3(30.0, 0.0, 12.0), Vector3(-30.0, 0.0, 34.0), Vector3(30.0, 0.0, -26.0),
        Vector3(-12.0, 0.0, -34.0), Vector3(14.0, 0.0, 30.0), Vector3(-58.0, 0.0, -10.0), Vector3(60.0, 0.0, 12.0),
        Vector3(0.0, 0.0, 40.0), Vector3(-48.0, 0.0, 58.0), Vector3(48.0, 0.0, 60.0), Vector3(-6.0, 0.0, -60.0),
    ]
    for pole_pos in positions:
        _kit.solid_box("LightPolePost", pole_pos + Vector3(0.0, 4.5, 0.0), Vector3(0.3, 9.0, 0.3), "dark_steel", Vector3.ZERO, &"metal")
        _kit.decor_box("LightPoleArm", pole_pos + Vector3(0.7, 9.0, 0.0), Vector3(1.6, 0.15, 0.2), "dark_steel")
        _kit.decor_box("LightPoleLamp", pole_pos + Vector3(1.3, 8.88, 0.0), Vector3(0.8, 0.14, 0.4), "lamp")
        light_poles.append(pole_pos + Vector3(1.3, 8.6, 0.0))

func _build_vegetation() -> void:
    # Trees: trunk collider + two stacked canopy cones. Placed along the grass strips and corners.
    var tree_positions: Array[Vector3] = []
    for index in range(34):
        var side := index % 4
        var along := _rng.randf_range(-74.0, 74.0)
        var pos := Vector3.ZERO
        match side:
            0: pos = Vector3(along, 0.0, -76.0 + _rng.randf_range(-1.5, 1.5))
            1: pos = Vector3(along, 0.0, 76.0 + _rng.randf_range(-1.5, 1.5))
            2: pos = Vector3(-76.0 + _rng.randf_range(-1.5, 1.5), 0.0, along)
            3: pos = Vector3(76.0 + _rng.randf_range(-1.5, 1.5), 0.0, along)
        tree_positions.append(pos)
    for tree_pos in tree_positions:
        var scale_factor := _rng.randf_range(0.8, 1.4)
        _kit.cylinder("TreeTrunk", tree_pos + Vector3(0.0, 1.6 * scale_factor, 0.0), 0.28 * scale_factor, 3.2 * scale_factor, "trunk", true)
        _kit.cylinder("TreeCanopyLow", tree_pos + Vector3(0.0, 4.0 * scale_factor, 0.0), 2.2 * scale_factor, 3.4 * scale_factor, "leaf", false, Vector3.ZERO, 0.2)
        _kit.cylinder("TreeCanopyHigh", tree_pos + Vector3(0.0, 6.0 * scale_factor, 0.0), 1.6 * scale_factor, 3.0 * scale_factor, "leaf_dark", false, Vector3.ZERO, 0.1)
        stats["trees"] = int(stats["trees"]) + 1
    # Bushes and weeds along fences and building corners.
    for index in range(50):
        var bush_pos := Vector3(_rng.randf_range(-74.0, 74.0), 0.0, _rng.randf_range(-74.0, 74.0))
        if _is_reserved(bush_pos) or (absf(bush_pos.x) < 70.0 and absf(bush_pos.z) < 70.0 and index % 3 != 0):
            continue
        var bush := MeshInstance3D.new()
        var bush_mesh := SphereMesh.new()
        var bush_radius := _rng.randf_range(0.5, 1.0)
        bush_mesh.radius = bush_radius
        bush_mesh.height = bush_radius * 1.4
        bush_mesh.radial_segments = 8
        bush_mesh.rings = 4
        bush.mesh = bush_mesh
        bush.material_override = _kit.mat("leaf")
        bush.position = bush_pos + Vector3(0.0, bush_radius * 0.45, 0.0)
        bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _kit._parent_for(bush_pos).add_child(bush)

func _build_puddles() -> void:
    for index in range(14):
        var pos := Vector3(_rng.randf_range(-60.0, 60.0), 0.05, _rng.randf_range(-60.0, 60.0))
        var puddle := MeshInstance3D.new()
        var disc := CylinderMesh.new()
        var radius := _rng.randf_range(0.9, 2.6)
        disc.top_radius = radius
        disc.bottom_radius = radius
        disc.height = 0.01
        disc.radial_segments = 16
        disc.rings = 1
        puddle.mesh = disc
        puddle.material_override = _kit.mat("puddle")
        puddle.position = pos
        puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        puddle.name = "Puddle_%d" % index
        _kit._parent_for(pos).add_child(puddle)

# ---------------------------------------------------------------- spawns

func _build_spawns() -> void:
    # Two balanced teams on opposite ends of the map (south = alpha, north = bravo) plus
    # four neutral points for free-for-all. Every point faces the map centre.
    var layout: Array[Dictionary] = []
    for index in range(6):
        layout.append({"pos": Vector3(-30.0 + float(index) * 12.0, 0.1, 64.0 - float(index % 2) * 4.0), "team": "alpha"})
        layout.append({"pos": Vector3(-30.0 + float(index) * 12.0, 0.1, -66.0 + float(index % 2) * 4.0), "team": "bravo"})
    layout.append({"pos": Vector3(-68.0, 0.1, 0.0), "team": ""})
    layout.append({"pos": Vector3(68.0, 0.1, 0.0), "team": ""})
    layout.append({"pos": Vector3(-66.0, 0.1, -50.0), "team": ""})
    layout.append({"pos": Vector3(66.0, 0.1, 52.0), "team": ""})
    spawn_positions = layout
