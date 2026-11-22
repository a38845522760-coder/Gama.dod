extends RefCounted
class_name BotNav

## Runtime navigation mesh for the Iron Yard map. The map is built from code, so the nav mesh
## is baked from the static colliders when a match starts. Until the bake finishes (or if it
## fails) bots fall back to simple steering with obstacle feelers.

static var ready: bool = false
## Larger maps use coarser cells so the bake stays fast and light on memory.
static var cell_size: float = 0.3
static var _region: NavigationRegion3D = null

static func reset() -> void:
    ready = false
    _region = null

## Starts an asynchronous bake of every static collider under `geometry_root`.
static func bake(geometry_root: Node3D, parent: Node) -> void:
    reset()
    var nav_mesh := NavigationMesh.new()
    nav_mesh.cell_size = cell_size
    nav_mesh.cell_height = 0.25
    nav_mesh.agent_radius = 0.45
    nav_mesh.agent_height = 1.8
    nav_mesh.agent_max_climb = 0.35
    nav_mesh.agent_max_slope = 45.0
    nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
    nav_mesh.geometry_collision_mask = 1
    nav_mesh.region_min_size = 2.0
    var source := NavigationMeshSourceGeometryData3D.new()
    NavigationServer3D.parse_source_geometry_data(nav_mesh, source, geometry_root)
    var region := NavigationRegion3D.new()
    region.name = "BotNavRegion"
    parent.add_child(region)
    _region = region
    NavigationServer3D.bake_from_source_geometry_data_async(nav_mesh, source, BotNav._on_baked.bind(nav_mesh, region))

static func _on_baked(nav_mesh: NavigationMesh, region: NavigationRegion3D) -> void:
    if not is_instance_valid(region):
        return
    if nav_mesh.get_polygon_count() <= 0:
        push_warning("Bot navigation bake produced no polygons; bots will use steering only.")
        return
    region.navigation_mesh = nav_mesh
    ready = true

static func find_path(world: World3D, from_point: Vector3, to_point: Vector3) -> PackedVector3Array:
    if not ready or world == null:
        return PackedVector3Array()
    var map: RID = world.navigation_map
    return NavigationServer3D.map_get_path(map, from_point, to_point, true)

static func closest_point(world: World3D, point: Vector3) -> Vector3:
    if not ready or world == null:
        return point
    return NavigationServer3D.map_get_closest_point(world.navigation_map, point)
