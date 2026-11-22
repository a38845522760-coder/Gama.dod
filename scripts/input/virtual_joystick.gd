extends Control
class_name TouchJoystick

signal vector_changed(value: Vector2)
## Fired once per touch when the knob is dragged far above the ring (sprint lock).
signal lock_requested

@export_range(40.0, 140.0, 1.0) var radius: float = 78.0
@export_range(10.0, 60.0, 1.0) var knob_radius: float = 32.0
var opacity: float = 0.85
var _touch_index: int = -1
var _mouse_active: bool = false
var _value: Vector2 = Vector2.ZERO
var _knob_position: Vector2 = Vector2.ZERO
var _lock_fired: bool = false
var sprint_locked: bool = false : set = _set_sprint_locked

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_radius(radius)

func set_radius(value: float) -> void:
    radius = value
    knob_radius = value * 0.42
    custom_minimum_size = Vector2.ONE * radius * 2.0
    size = custom_minimum_size
    _knob_position = size * 0.5 + _value * radius
    queue_redraw()

func _has_point(point: Vector2) -> bool:
    return point.distance_to(size * 0.5) <= radius * 1.25

func get_value() -> Vector2:
    return _value

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _touch_index == -1:
            _touch_index = touch.index
            _lock_fired = false
            _update_from_position(touch.position)
        elif not touch.pressed and touch.index == _touch_index:
            _touch_index = -1
            _lock_fired = false
            _set_value(Vector2.ZERO)
        accept_event()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _touch_index:
            _update_from_position(drag.position)
            accept_event()
    elif event is InputEventMouseButton:
        var click := event as InputEventMouseButton
        if click.device == InputEvent.DEVICE_ID_EMULATION or click.button_index != MOUSE_BUTTON_LEFT:
            return
        _mouse_active = click.pressed
        if _mouse_active:
            _update_from_position(click.position)
        else:
            _set_value(Vector2.ZERO)
        accept_event()
    elif event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        if _mouse_active and motion.device != InputEvent.DEVICE_ID_EMULATION:
            _update_from_position(motion.position)

func release_all() -> void:
    _touch_index = -1
    _mouse_active = false
    if _value != Vector2.ZERO:
        _set_value(Vector2.ZERO)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED:
        release_all()

func _exit_tree() -> void:
    release_all()

func _update_from_position(point: Vector2) -> void:
    var offset := point - size * 0.5
    var raw: Vector2 = offset / maxf(radius, 1.0)
    # Pulling the knob well past the top of the ring locks sprint (hands-free running).
    if not _lock_fired and raw.y < -1.45 and absf(raw.x) < 1.1:
        _lock_fired = true
        lock_requested.emit()
    _set_value(raw)

func _set_sprint_locked(value: bool) -> void:
    sprint_locked = value
    queue_redraw()

func _set_value(value: Vector2) -> void:
    _value = value.limit_length(1.0)
    _knob_position = size * 0.5 + _value * radius
    vector_changed.emit(_value)
    queue_redraw()

func _draw() -> void:
    var c := size * 0.5
    var a := opacity
    var active := _value.length() > 0.05
    draw_circle(c, radius, Color(0.04, 0.07, 0.1, 0.5 * a))
    draw_circle(c, radius * 0.72, Color(0.25, 0.8, 0.9, 0.06 * a))
    draw_arc(c, radius - 1.5, 0.0, TAU, 72, Color(0.55, 0.85, 0.95, 0.75 * a), 3.0, true)
    draw_arc(c, radius * 0.5, 0.0, TAU, 48, Color(0.55, 0.85, 0.95, 0.18 * a), 2.0, true)
    # Direction chevrons around the rim.
    for k in range(4):
        var dir := Vector2.from_angle(float(k) * PI * 0.5 - PI * 0.5)
        var side := Vector2(-dir.y, dir.x)
        var base := c + dir * radius * 0.8
        draw_polyline(PackedVector2Array([base - side * 9.0 - dir * 6.0, base + dir * 5.0, base + side * 9.0 - dir * 6.0]), Color(1, 1, 1, 0.4 * a), 3.0, true)
    # Lock hint above the ring: a small arrow-up with a padlock dot.
    var hint := c + Vector2(0.0, -radius - 20.0)
    var hint_color := Color(1.0, 0.85, 0.3, (0.95 if sprint_locked else 0.4) * a)
    draw_polyline(PackedVector2Array([hint + Vector2(-9, 5), hint + Vector2(0, -5), hint + Vector2(9, 5)]), hint_color, 3.0, true)
    if sprint_locked:
        draw_arc(c, radius + 6.0, 0.0, TAU, 72, Color(1.0, 0.85, 0.3, 0.9 * a), 4.0, true)
    if active:
        draw_circle(_knob_position, knob_radius + 8.0, Color(0.25, 0.85, 0.95, 0.14 * a))
    draw_circle(_knob_position, knob_radius, Color(0.45, 0.78, 0.88, (0.85 if active else 0.62) * a))
    draw_circle(_knob_position + Vector2(0, -knob_radius * 0.2), knob_radius * 0.6, Color(1, 1, 1, 0.14 * a))
    draw_arc(_knob_position, knob_radius - 1.5, 0.0, TAU, 40, Color(0.92, 0.98, 1.0, 0.95 * a), 3.0, true)
