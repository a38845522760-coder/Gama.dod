extends CanvasLayer
class_name TouchHUD

## Mobile controls: joystick, look area and round icon buttons laid out around the
## thumbs. Positions scale with the screen and with the user's "button size" setting.

@export var always_show_for_testing: bool = false
const JOYSTICK_SCRIPT := preload("res://scripts/input/virtual_joystick.gd")
const LOOK_SCRIPT := preload("res://scripts/input/touch_look_area.gd")
const BUTTON_SCRIPT := preload("res://scripts/input/touch_button.gd")

var _root: Control
var _look_area: TouchLookArea
var _joystick: TouchJoystick
var _buttons: Dictionary = {}
var _player: Node
var _move_actions: Array[String] = ["move_left", "move_right", "move_forward", "move_backward"]


func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_PAUSABLE
    var is_mobile := OS.has_feature("android") or OS.has_feature("ios")
    if not is_mobile and not always_show_for_testing:
        return
    var players := get_tree().get_nodes_in_group("player_controller")
    if not players.is_empty():
        _player = players[0]
    _build_controls()
    get_viewport().size_changed.connect(_layout)
    SettingsManager.settings_changed.connect(func(_settings: Dictionary) -> void: _layout())
    _layout()

func _build_controls() -> void:
    add_to_group("touch_controls")
    _root = Control.new()
    _root.name = "TouchRoot"
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    _look_area = LOOK_SCRIPT.new()
    _look_area.name = "LookArea"
    _look_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _look_area.look_delta.connect(_on_look_delta)
    _root.add_child(_look_area)

    _joystick = JOYSTICK_SCRIPT.new()
    _joystick.name = "MoveJoystick"
    _joystick.vector_changed.connect(_on_joystick_changed)
    _root.add_child(_joystick)

    _make_button("fire", "fire", "fire", Color("#ff7a3c"), true, 0)
    _make_button("jump", "jump", "jump", Color("#41d9ee"), false, 14)
    _make_button("crouch", "crouch", "", Color("#9bb8ff"), false, 10)
    _make_button("zoom", "zoom", "", Color("#7be0a0"), false, 8)
    _make_button("reload", "reload", "reload", Color("#ffd166"), false, 0)
    _make_button("use", "use", "interact", Color("#c7a6ff"), false, 8)
    _make_button("camera", "camera", "", Color("#ffb86b"), false, 0)
    _make_button("pause", "pause", "", Color("#8fa6b0"), false, 0)
    _make_button("grenade", "grenade", "throw_grenade", Color("#ff7a5c"), false, 12)
    _make_button("trap", "trap", "place_trap", Color("#ff5ca8"), false, 8)
    (_buttons["crouch"] as TouchButton).tapped.connect(_on_crouch_tapped)
    (_buttons["pause"] as TouchButton).tapped.connect(_on_pause_tapped)
    (_buttons["camera"] as TouchButton).tapped.connect(_on_camera_tapped)
    (_buttons["zoom"] as TouchButton).tapped.connect(_on_zoom_tapped)

func _make_button(key: String, kind: String, action_name: String, tint: Color, look: bool, haptic: int) -> void:
    var button: TouchButton = BUTTON_SCRIPT.new()
    button.name = "Btn_" + key
    button.icon_kind = kind
    button.action = action_name
    button.tint = tint
    button.forward_look = look
    button.haptic_ms = haptic
    if look:
        button.look_delta.connect(_on_look_delta)
    _root.add_child(button)
    _buttons[key] = button

func _layout() -> void:
    if _root == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var scale_factor := float(SettingsManager.get_setting("touch_scale", 1.0))
    var opacity := float(SettingsManager.get_setting("touch_opacity", 0.85))
    var inset := _safe_inset(viewport_size)
    var margin := 30.0 * scale_factor

    _joystick.opacity = opacity
    _joystick.set_radius(80.0 * scale_factor)
    _joystick.position = Vector2(inset.x + margin, viewport_size.y - inset.w - margin) - Vector2(0.0, _joystick.size.y)
    _joystick.position.x += 0.0

    var fire_center := Vector2(viewport_size.x - inset.z - 130.0 * scale_factor, viewport_size.y - inset.w - 140.0 * scale_factor)
    _place("fire", fire_center, 56.0, scale_factor, opacity)
    _place("jump", fire_center + Vector2(-132.0, -50.0) * scale_factor, 40.0, scale_factor, opacity)
    _place("crouch", fire_center + Vector2(-112.0, 66.0) * scale_factor, 34.0, scale_factor, opacity)
    _place("reload", fire_center + Vector2(-22.0, -146.0) * scale_factor, 33.0, scale_factor, opacity)
    _place("use", fire_center + Vector2(-124.0, -150.0) * scale_factor, 33.0, scale_factor, opacity)
    _place("zoom", fire_center + Vector2(-244.0, 6.0) * scale_factor, 36.0, scale_factor, opacity)
    _place("camera", Vector2(viewport_size.x - inset.z - 330.0 * scale_factor, inset.y + 52.0 * scale_factor), 26.0, scale_factor, opacity)
    _place("pause", Vector2(inset.x + 56.0 * scale_factor, inset.y + 52.0 * scale_factor), 26.0, scale_factor, opacity)
    _place("grenade", fire_center + Vector2(-236.0, -96.0) * scale_factor, 30.0, scale_factor, opacity)
    _place("trap", fire_center + Vector2(-214.0, -186.0) * scale_factor, 30.0, scale_factor, opacity)

    # The look area covers the whole screen; buttons and the joystick sit on top and
    # take their own touches first.
    _look_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _place(key: String, center: Vector2, base_radius: float, scale_factor: float, opacity: float) -> void:
    var button: TouchButton = _buttons[key]
    button.set_radius(base_radius * scale_factor)
    button.opacity = opacity
    button.position = center - button.size * 0.5
    button.queue_redraw()

func _safe_inset(viewport_size: Vector2) -> Vector4:
    # Returns left, top, right, bottom insets in viewport units (notches / rounded corners).
    var screen_size := Vector2(DisplayServer.screen_get_size())
    var safe := DisplayServer.get_display_safe_area()
    if screen_size.x <= 0.0 or screen_size.y <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
        return Vector4.ZERO
    var ratio := Vector2(viewport_size.x / screen_size.x, viewport_size.y / screen_size.y)
    var left := float(safe.position.x) * ratio.x
    var top := float(safe.position.y) * ratio.y
    var right := (screen_size.x - float(safe.position.x + safe.size.x)) * ratio.x
    var bottom := (screen_size.y - float(safe.position.y + safe.size.y)) * ratio.y
    return Vector4(maxf(left, 0.0), maxf(top, 0.0), maxf(right, 0.0), maxf(bottom, 0.0))

func _process(_delta: float) -> void:
    if _root == null:
        return
    var player := _get_player()
    # Crouch button glows while the player is crouched / lying down / sliding.
    if player != null and player.has_method("is_crouch_active"):
        (_buttons["crouch"] as TouchButton).latched = bool(player.call("is_crouch_active"))
    # Zoom button glows while zoomed; camera button in third person.
    if player != null and player.has_method("is_zoomed"):
        (_buttons["zoom"] as TouchButton).latched = bool(player.call("is_zoomed"))
    if player != null and player.has_method("is_third_person"):
        (_buttons["camera"] as TouchButton).latched = bool(player.call("is_third_person"))
    # Grenade / trap buttons only exist in wave modes that carry gadgets.
    var manager: Node = get_tree().get_first_node_in_group("mode_manager")
    var has_gadgets: bool = manager != null and manager.has_method("get_gadgets") and manager.call("get_gadgets") != null
    (_buttons["grenade"] as TouchButton).visible = has_gadgets
    (_buttons["trap"] as TouchButton).visible = has_gadgets

func _get_player() -> Node:
    ## The player can be created after this HUD (or replaced on respawn); look it up when needed.
    if is_instance_valid(_player):
        return _player
    var players := get_tree().get_nodes_in_group("player_controller")
    _player = players[0] if not players.is_empty() else null
    return _player

func _on_look_delta(delta: Vector2) -> void:
    var player := _get_player()
    if player != null and player.has_method("add_look_delta"):
        var sensitivity := float(SettingsManager.get_setting("touch_look_sensitivity", 1.0))
        player.call("add_look_delta", delta * sensitivity * 1.7)

func _on_joystick_changed(value: Vector2) -> void:
    var dead_zone := 0.14
    var strengths := {
        "move_left": maxf(0.0, -value.x),
        "move_right": maxf(0.0, value.x),
        "move_forward": maxf(0.0, -value.y),
        "move_backward": maxf(0.0, value.y),
    }
    for action_name in _move_actions:
        var strength: float = float(strengths[action_name])
        if strength > dead_zone:
            Input.action_press(action_name, clampf((strength - dead_zone) / (1.0 - dead_zone), 0.0, 1.0))
        else:
            Input.action_release(action_name)

func _on_zoom_tapped() -> void:
    var player := _get_player()
    if player != null and player.has_method("toggle_zoom"):
        player.call("toggle_zoom")

func _on_crouch_tapped() -> void:
    var player := _get_player()
    if player != null and player.has_method("request_crouch_tap"):
        player.call("request_crouch_tap")

func _on_camera_tapped() -> void:
    var player := _get_player()
    if player != null and player.has_method("toggle_camera_view"):
        player.call("toggle_camera_view")

func _on_pause_tapped() -> void:
    var menus := get_tree().get_nodes_in_group("pause_menu")
    if not menus.is_empty() and menus[0].has_method("toggle"):
        menus[0].call("toggle")

func _exit_tree() -> void:
    for action_name in _move_actions:
        Input.action_release(action_name)
