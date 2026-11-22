extends Control

## Scope vignette shown while zoomed: dark ring around a clear circle plus a thin crosshair.
## `amount` (0..1) is driven by the player's zoom blend. No class_name on purpose.

var amount: float = 0.0:
    set(value):
        amount = clampf(value, 0.0, 1.0)
        visible = amount > 0.02
        queue_redraw()

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false

func _draw() -> void:
    if amount <= 0.02:
        return
    var c := size * 0.5
    var r := minf(size.x, size.y) * 0.46
    var width := c.length() - r + 8.0
    draw_arc(c, r + width * 0.5, 0.0, TAU, 96, Color(0, 0, 0, 0.92 * amount), width, true)
    draw_arc(c, r, 0.0, TAU, 96, Color(0, 0, 0, 0.9 * amount), 3.0, true)
    var line := Color(0.05, 0.05, 0.05, 0.75 * amount)
    draw_line(c + Vector2(-r, 0.0), c + Vector2(-18.0, 0.0), line, 2.0, true)
    draw_line(c + Vector2(18.0, 0.0), c + Vector2(r, 0.0), line, 2.0, true)
    draw_line(c + Vector2(0.0, -r), c + Vector2(0.0, -18.0), line, 2.0, true)
    draw_line(c + Vector2(0.0, 18.0), c + Vector2(0.0, r), line, 2.0, true)
    draw_circle(c, 2.0, Color(1.0, 0.25, 0.2, 0.9 * amount))
