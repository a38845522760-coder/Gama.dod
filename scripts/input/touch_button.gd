extends Control
class_name TouchButton

## Round, icon-only touch button drawn in code (no text, no rectangles).
## Hold mode: presses `action` while a finger is down. Tap mode (empty action): emits `tapped`.
## The circular hit area is real, so neighbouring controls/look area get touches that miss the circle.

signal tapped
signal look_delta(delta: Vector2)

@export var icon_kind: String = "fire"
@export var action: String = ""
@export var radius: float = 40.0
@export var tint: Color = Color("#41d9ee")
@export var forward_look: bool = false
@export var haptic_ms: int = 0

var opacity: float = 0.85
var held: bool = false
var latched: bool = false : set = _set_latched

var _touch_index: int = -1
var _mouse_down: bool = false
var _press_scale: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    _apply_size()

func set_radius(value: float) -> void:
    radius = value
    _apply_size()

func _apply_size() -> void:
    custom_minimum_size = Vector2.ONE * radius * 2.0
    size = custom_minimum_size
    pivot_offset = size * 0.5
    queue_redraw()

func _set_latched(value: bool) -> void:
    latched = value
    queue_redraw()

func _has_point(point: Vector2) -> bool:
    return point.distance_to(size * 0.5) <= radius * 1.12

func _process(delta: float) -> void:
    var target := 0.9 if held else 1.0
    if not is_equal_approx(_press_scale, target):
        _press_scale = move_toward(_press_scale, target, delta * 5.0)
        queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _touch_index == -1:
            _touch_index = touch.index
            _press()
        elif not touch.pressed and touch.index == _touch_index:
            _touch_index = -1
            _release()
        accept_event()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _touch_index:
            if forward_look:
                look_delta.emit(drag.relative)
            accept_event()
    elif event is InputEventMouseButton:
        var click := event as InputEventMouseButton
        if click.device == InputEvent.DEVICE_ID_EMULATION or click.button_index != MOUSE_BUTTON_LEFT:
            return
        if click.pressed and not _mouse_down:
            _mouse_down = true
            _press()
        elif not click.pressed and _mouse_down:
            _mouse_down = false
            _release()
        accept_event()
    elif event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        if _mouse_down and forward_look and motion.device != InputEvent.DEVICE_ID_EMULATION:
            look_delta.emit(motion.relative)

func _press() -> void:
    held = true
    if not action.is_empty():
        Input.action_press(action)
    if haptic_ms > 0 and bool(SettingsManager.get_setting("haptics", true)):
        Input.vibrate_handheld(haptic_ms)
    queue_redraw()

func _release() -> void:
    var was_held := held
    held = false
    if not action.is_empty():
        Input.action_release(action)
    elif was_held:
        tapped.emit()
    queue_redraw()

func release_all() -> void:
    _touch_index = -1
    _mouse_down = false
    if held:
        held = false
        if not action.is_empty():
            Input.action_release(action)
        queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
        release_all()

func _exit_tree() -> void:
    release_all()

func _draw() -> void:
    var c := size * 0.5
    var r := radius * _press_scale
    var a := opacity * (1.0 if held else 0.9)
    var lit := held or latched
    var glow := Color(tint.r, tint.g, tint.b, 1.0)
    if lit:
        for ring in range(4):
            draw_circle(c, r + 9.0 - float(ring) * 2.5, Color(glow.r, glow.g, glow.b, 0.07 * float(ring + 1) * a))
    draw_circle(c, r, Color(0.04, 0.07, 0.1, 0.66 * a))
    draw_circle(c, r * 0.9, Color(glow.r, glow.g, glow.b, (0.42 if lit else 0.17) * a))
    draw_circle(c + Vector2(0.0, -r * 0.16), r * 0.62, Color(1, 1, 1, 0.05 * a))
    draw_arc(c, r - 1.5, 0.0, TAU, 64, Color(glow.lightened(0.25).r, glow.lightened(0.25).g, glow.lightened(0.25).b, 0.95 * a), 3.0, true)
    draw_arc(c, r - 6.0, PI * 1.12, PI * 1.88, 28, Color(1, 1, 1, 0.32 * a), 2.0, true)
    _draw_icon(c, r * 0.5, Color(1, 1, 1, 0.97 * a))

func _draw_icon(c: Vector2, u: float, col: Color) -> void:
    match icon_kind:
        "fire":
            draw_arc(c, u * 0.9, 0.0, TAU, 40, col, 3.5, true)
            for k in range(4):
                var dir := Vector2.from_angle(float(k) * PI * 0.5)
                draw_line(c + dir * u * 1.25, c + dir * u * 0.58, col, 3.5, true)
            draw_circle(c, u * 0.24, col)
        "jump":
            draw_line(c + Vector2(0, u * 0.7), c + Vector2(0, -u * 0.5), col, 5.0, true)
            draw_polyline(PackedVector2Array([c + Vector2(-u * 0.62, -u * 0.02), c + Vector2(0, -u * 0.72), c + Vector2(u * 0.62, -u * 0.02)]), col, 5.0, true)
        "crouch":
            draw_polyline(PackedVector2Array([c + Vector2(-u * 0.68, -u * 0.42), c + Vector2(0, u * 0.28), c + Vector2(u * 0.68, -u * 0.42)]), col, 5.0, true)
            draw_line(c + Vector2(-u * 0.68, u * 0.7), c + Vector2(u * 0.68, u * 0.7), col, 5.0, true)
        "slide":
            draw_circle(c + Vector2(u * 0.55, -u * 0.12), u * 0.2, col)
            draw_line(c + Vector2(u * 0.4, u * 0.1), c + Vector2(-u * 0.5, u * 0.42), col, 5.0, true)
            draw_line(c + Vector2(-u * 0.5, u * 0.42), c + Vector2(-u * 0.95, u * 0.42), col, 5.0, true)
            draw_line(c + Vector2(-u * 0.9, -u * 0.15), c + Vector2(-u * 0.2, -u * 0.15), Color(col.r, col.g, col.b, col.a * 0.6), 3.0, true)
            draw_line(c + Vector2(-u * 1.1, u * 0.1), c + Vector2(-u * 0.55, u * 0.1), Color(col.r, col.g, col.b, col.a * 0.6), 3.0, true)
        "sprint":
            for k in range(2):
                var y := float(k) * u * 0.62
                draw_polyline(PackedVector2Array([c + Vector2(-u * 0.66, y), c + Vector2(0, y - u * 0.62), c + Vector2(u * 0.66, y)]), col, 5.0, true)
        "zoom":
            draw_arc(c, u * 0.82, 0.0, TAU, 40, col, 3.5, true)
            draw_line(c + Vector2(-u * 1.2, 0), c + Vector2(-u * 0.3, 0), col, 3.0, true)
            draw_line(c + Vector2(u * 0.3, 0), c + Vector2(u * 1.2, 0), col, 3.0, true)
            draw_line(c + Vector2(0, -u * 1.2), c + Vector2(0, -u * 0.3), col, 3.0, true)
            draw_line(c + Vector2(0, u * 0.3), c + Vector2(0, u * 1.2), col, 3.0, true)
            draw_circle(c, u * 0.1, col)
        "reload":
            draw_arc(c, u * 0.78, PI * 0.15, PI * 1.5, 32, col, 4.0, true)
            var angle := PI * 1.5
            var p := c + Vector2.from_angle(angle) * u * 0.78
            var tangent := Vector2(-sin(angle), cos(angle))
            var normal := Vector2(cos(angle), sin(angle))
            draw_colored_polygon(PackedVector2Array([p + tangent * u * 0.5, p + normal * u * 0.34, p - normal * u * 0.34]), col)
        "use":
            draw_arc(c, u * 0.52, 0.0, TAU, 28, col, 3.5, true)
            draw_circle(c, u * 0.2, col)
            for k in range(8):
                var dir := Vector2.from_angle(float(k) * PI * 0.25)
                draw_line(c + dir * u * 0.82, c + dir * u * 1.08, col, 3.0, true)
        "camera":
            draw_arc(c, u * 0.42, 0.0, TAU, 24, col, 3.5, true)
            draw_circle(c + Vector2(0, u * 0.08), u * 0.14, col)
            draw_polyline(PackedVector2Array([c + Vector2(-u * 0.86, -u * 0.3), c + Vector2(-u * 0.86, u * 0.62), c + Vector2(u * 0.86, u * 0.62), c + Vector2(u * 0.86, -u * 0.3), c + Vector2(u * 0.42, -u * 0.3), c + Vector2(u * 0.28, -u * 0.62), c + Vector2(-u * 0.28, -u * 0.62), c + Vector2(-u * 0.42, -u * 0.3), c + Vector2(-u * 0.86, -u * 0.3)]), col, 3.0, true)
        "medkit":
            draw_rect(Rect2(c + Vector2(-u * 0.25, -u * 0.8), Vector2(u * 0.5, u * 1.6)), col)
            draw_rect(Rect2(c + Vector2(-u * 0.8, -u * 0.25), Vector2(u * 1.6, u * 0.5)), col)
        "armor":
            draw_polyline(PackedVector2Array([c + Vector2(-u * 0.75, -u * 0.7), c + Vector2(u * 0.75, -u * 0.7), c + Vector2(u * 0.75, u * 0.1), c + Vector2(0, u * 0.85), c + Vector2(-u * 0.75, u * 0.1), c + Vector2(-u * 0.75, -u * 0.7)]), col, 4.0, true)
        "ammo":
            for k in range(3):
                var x := (float(k) - 1.0) * u * 0.52
                draw_rect(Rect2(c + Vector2(x - u * 0.15, -u * 0.2), Vector2(u * 0.3, u * 0.95)), col)
                draw_colored_polygon(PackedVector2Array([c + Vector2(x - u * 0.15, -u * 0.2), c + Vector2(x + u * 0.15, -u * 0.2), c + Vector2(x, -u * 0.8)]), col)
        "shop":
            draw_arc(c, u * 0.8, 0.0, TAU, 32, col, 3.5, true)
            draw_line(c + Vector2(0, -u * 0.5), c + Vector2(0, u * 0.5), col, 3.5, true)
            draw_polyline(PackedVector2Array([c + Vector2(u * 0.3, -u * 0.35), c + Vector2(-u * 0.3, -u * 0.35), c + Vector2(-u * 0.3, 0), c + Vector2(u * 0.3, 0), c + Vector2(u * 0.3, u * 0.35), c + Vector2(-u * 0.3, u * 0.35)]), col, 3.0, true)
        "grenade":
            draw_circle(c + Vector2(0.0, u * 0.15), u * 0.62, col)
            draw_line(c + Vector2(0.0, -u * 0.5), c + Vector2(u * 0.35, -u * 0.95), col, 4.0, true)
            draw_line(c + Vector2(-u * 0.2, -u * 0.5), c + Vector2(u * 0.3, -u * 0.5), col, 4.0, true)
        "trap":
            draw_arc(c, u * 0.8, 0.0, TAU, 32, col, 3.5, true)
            for k in range(6):
                var spike := Vector2.from_angle(float(k) * PI / 3.0)
                draw_line(c + spike * u * 0.25, c + spike * u * 0.72, col, 3.5, true)
        "pause":
            draw_rect(Rect2(c + Vector2(-u * 0.5, -u * 0.55), Vector2(u * 0.32, u * 1.1)), col)
            draw_rect(Rect2(c + Vector2(u * 0.18, -u * 0.55), Vector2(u * 0.32, u * 1.1)), col)
