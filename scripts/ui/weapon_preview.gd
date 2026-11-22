extends SubViewportContainer
class_name WeaponPreview

## Small rotating 3D showcase of a gun, used on shop cards.

var weapon_id: String = "rifle"
var _pivot: Node3D

func _ready() -> void:
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var viewport := SubViewport.new()
    viewport.own_world_3d = true
    viewport.transparent_bg = true
    viewport.msaa_3d = Viewport.MSAA_2X
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.size = Vector2i(320, 170)
    add_child(viewport)
    var environment := Environment.new()
    environment.background_mode = Environment.BG_CLEAR_COLOR
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.55, 0.62, 0.7)
    environment.ambient_light_energy = 0.9
    var world_environment := WorldEnvironment.new()
    world_environment.environment = environment
    viewport.add_child(world_environment)
    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-35.0, -40.0, 0.0)
    key_light.light_energy = 1.6
    viewport.add_child(key_light)
    var rim := DirectionalLight3D.new()
    rim.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
    rim.light_energy = 0.8
    rim.light_color = Color(0.5, 0.8, 1.0)
    viewport.add_child(rim)
    var camera := Camera3D.new()
    camera.fov = 34.0
    camera.position = Vector3(0.0, 0.08, 1.9)
    viewport.add_child(camera)
    _pivot = Node3D.new()
    viewport.add_child(_pivot)
    var gun: Node3D = WeaponModels.build(weapon_id)
    gun.position = Vector3(0.0, -0.02, 0.26)
    _pivot.add_child(gun)
    _pivot.rotation.y = 0.6

func _process(delta: float) -> void:
    if _pivot != null:
        _pivot.rotation.y += delta * 0.7
