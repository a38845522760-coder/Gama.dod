extends Control
class_name Crosshair

## Dynamic crosshair: the gap grows with weapon spread, hit markers flash on damage,
## and a ring fills while reloading.

var spread_pixels: float = 8.0
var _display_gap: float = 8.0
var _hit_alpha: float = 0.0
var _hit_kill: bool = false
var reload_progress: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_hit(killed: bool) -> void:
    _hit_alpha = 1.0
    _hit_kill = killed

func _process(delta: float) -> void:
    _display_gap = lerpf(_display_gap, spread_pixels, 1.0 - exp(-18.0 * delta))
    _hit_alpha = maxf(0.0, _hit_alpha - delta * 5.0)
    queue_redraw()

func _draw() -> void:
    var c := size * 0.5
    var col := Color(0.92, 0.98, 1.0, 0.9)
    var shadow := Color(0, 0, 0, 0.45)
    var gap := _display_gap + 4.0
    for k in range(4):
        var dir := Vector2.from_angle(float(k) * PI * 0.5)
        draw_line(c + dir * gap + Vector2(1, 1), c + dir * (gap + 11.0) + Vector2(1, 1), shadow, 4.0, true)
        draw_line(c + dir * gap, c + dir * (gap + 11.0), col, 2.5, true)
    draw_circle(c, 2.0, col)
    if reload_progress > 0.0:
        draw_arc(c, 30.0, -PI * 0.5, -PI * 0.5 + TAU * reload_progress, 40, Color(1.0, 0.82, 0.4, 0.95), 4.0, true)
    if _hit_alpha > 0.0:
        var hit_color := Color(1.0, 0.25, 0.2, _hit_alpha) if _hit_kill else Color(1, 1, 1, _hit_alpha)
        for k in range(4):
            var dir := Vector2.from_angle(float(k) * PI * 0.5 + PI * 0.25)
            draw_line(c + dir * 12.0, c + dir * 22.0, hit_color, 3.5, true)
