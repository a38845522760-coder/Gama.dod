extends Control
class_name HudLayoutEditor

## Full-screen editor: drag any touch button to a new place and resize it with the slider.

signal closed

const BUTTON_SCRIPT := preload("res://scripts/input/touch_button.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/input/virtual_joystick.gd")
const ICONS: Dictionary = {
    "fire": "fire", "jump": "jump", "crouch": "crouch", "reload": "reload", "use": "use", "zoom": "zoom",
    "camera": "camera", "pause": "pause", "grenade": "grenade", "trap": "trap",
}
const TINTS: Dictionary = {
    "fire": "#ff7a3c", "jump": "#41d9ee", "crouch": "#9bb8ff", "zoom": "#7be0a0", "reload": "#ffd166",
    "use": "#c7a6ff", "camera": "#ffb86b", "pause": "#8fa6b0", "grenade": "#ff7a5c", "trap": "#ff5ca8",
}

var _layout: Dictionary = {}
var _nodes: Dictionary = {}
var _centers: Dictionary = {}
var _scales: Dictionary = {}
var _selected: String = "fire"
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _slider: HSlider
var _name_label: Label
var _canvas: Control

func _ready() -> void:
    theme = UIStyle.get_theme()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _layout = HudLayout.load_layout()
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.06, 0.96)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    _canvas = Control.new()
    _canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_canvas)
    _build_items()
    _build_panel()
    resized.connect(_apply_all)
    _apply_all()
    _select(_selected)

func _build_items() -> void:
    var joystick: TouchJoystick = JOYSTICK_SCRIPT.new()
    joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _canvas.add_child(joystick)
    _nodes["joystick"] = joystick
    for key in HudLayout.KEYS:
        if key == "joystick":
            continue
        var button: TouchButton = BUTTON_SCRIPT.new()
        button.icon_kind = str(ICONS.get(key, key))
        button.tint = Color(str(TINTS.get(key, "#41d9ee")))
        button.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _canvas.add_child(button)
        _nodes[key] = button

func _build_panel() -> void:
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.position.y = 10.0
    add_child(panel)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    panel.add_child(row)
    _name_label = UIStyle.make_label("", 22, UIStyle.COLOR_ACCENT)
    _name_label.custom_minimum_size = Vector2(130, 0)
    row.add_child(_name_label)
    _slider = HSlider.new()
    _slider.min_value = 0.5
    _slider.max_value = 2.2
    _slider.step = 0.05
    _slider.custom_minimum_size = Vector2(220, 40)
    _slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _slider.value_changed.connect(_on_size_changed)
    row.add_child(_slider)
    var reset_button := UIStyle.make_button(Loc.t("layout_reset"), false, Vector2(120, 52))
    reset_button.pressed.connect(_on_reset)
    row.add_child(reset_button)
    var save_button := UIStyle.make_button(Loc.t("layout_save"), true, Vector2(120, 52))
    save_button.pressed.connect(_on_save)
    row.add_child(save_button)
    var cancel_button := UIStyle.make_button(Loc.t("back"), false, Vector2(110, 52))
    cancel_button.pressed.connect(func() -> void: closed.emit())
    row.add_child(cancel_button)

func _apply_all() -> void:
    var viewport_size: Vector2 = size
    if viewport_size.x < 10.0:
        viewport_size = get_viewport_rect().size
    var inset: Vector4 = HudLayout.safe_inset(viewport_size)
    var defaults: Dictionary = HudLayout.default_centers(viewport_size, inset, 1.0)
    for key in HudLayout.KEYS:
        _centers[key] = HudLayout.resolve_center(key, _layout, defaults, viewport_size)
        _scales[key] = HudLayout.resolve_scale(key, _layout)
        _place(key)
    queue_redraw()

func _place(key: String) -> void:
    var radius: float = float(HudLayout.BASE_RADIUS[key]) * float(_scales[key])
    var node: Control = _nodes[key]
    if key == "joystick":
        (node as TouchJoystick).set_radius(radius)
    else:
        (node as TouchButton).set_radius(radius)
    node.position = (_centers[key] as Vector2) - node.size * 0.5

func _select(key: String) -> void:
    _selected = key
    _name_label.text = Loc.t("btn_" + key)
    _slider.set_value_no_signal(float(_scales[key]))
    queue_redraw()

func _on_size_changed(value: float) -> void:
    _scales[_selected] = value
    _place(_selected)
    queue_redraw()

func _on_reset() -> void:
    _layout = {}
    _apply_all()
    _select(_selected)

func _on_save() -> void:
    var out: Dictionary = {}
    var viewport_size: Vector2 = size
    for key in HudLayout.KEYS:
        var center: Vector2 = _centers[key]
        out[key] = {"x": center.x / maxf(viewport_size.x, 1.0), "y": center.y / maxf(viewport_size.y, 1.0), "s": float(_scales[key])}
    HudLayout.save_layout(out)
    for node in get_tree().get_nodes_in_group("touch_controls"):
        if node.has_method("reload_layout"):
            node.call("reload_layout")
    closed.emit()

func _pick(point: Vector2) -> String:
    var best: String = ""
    var best_distance: float = INF
    for key in HudLayout.KEYS:
        var radius: float = float(HudLayout.BASE_RADIUS[key]) * float(_scales[key]) * 1.15
        var distance: float = point.distance_to(_centers[key])
        if distance <= radius and distance < best_distance:
            best = key
            best_distance = distance
    return best

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var click := event as InputEventMouseButton
        if click.button_index != MOUSE_BUTTON_LEFT:
            return
        if click.pressed:
            var key: String = _pick(click.position)
            if key != "":
                _select(key)
                _dragging = true
                _drag_offset = (_centers[key] as Vector2) - click.position
        else:
            _dragging = false
        accept_event()
    elif event is InputEventMouseMotion and _dragging:
        var motion := event as InputEventMouseMotion
        var target: Vector2 = motion.position + _drag_offset
        target.x = clampf(target.x, 20.0, size.x - 20.0)
        target.y = clampf(target.y, 20.0, size.y - 20.0)
        _centers[_selected] = target
        _place(_selected)
        queue_redraw()
        accept_event()

func _draw() -> void:
    if not _centers.has(_selected):
        return
    var radius: float = float(HudLayout.BASE_RADIUS[_selected]) * float(_scales[_selected])
    draw_arc(_centers[_selected], radius + 8.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.3, 0.95), 4.0, true)
