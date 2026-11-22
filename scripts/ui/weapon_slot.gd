extends Control
class_name WeaponSlot

## One tappable weapon slot in the weapon bar. Handles real multi-touch (a finger can be on
## the joystick while another taps here) as well as the mouse.

signal chosen(weapon_id: String)

const ABBREVIATIONS: Dictionary = {
    "pistol": "PST", "revolver": "REV", "smg": "SMG", "rifle": "AR",
    "shotgun": "SG", "lmg": "LMG", "sniper": "SNP",
}

var weapon_id: String = "rifle"
var slot_number: int = 1
var selected: bool = false : set = _set_selected
var ammo_text: String = ""

var _touch_index: int = -1

func _ready() -> void:
    custom_minimum_size = Vector2(78, 50)
    mouse_filter = Control.MOUSE_FILTER_STOP

func _set_selected(value: bool) -> void:
    selected = value
    queue_redraw()

func set_ammo_text(value: String) -> void:
    if value != ammo_text:
        ammo_text = value
        queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _touch_index == -1:
            _touch_index = touch.index
            chosen.emit(weapon_id)
        elif not touch.pressed and touch.index == _touch_index:
            _touch_index = -1
        accept_event()
    elif event is InputEventMouseButton:
        var click := event as InputEventMouseButton
        if click.device == InputEvent.DEVICE_ID_EMULATION or click.button_index != MOUSE_BUTTON_LEFT:
            return
        if click.pressed:
            chosen.emit(weapon_id)
        accept_event()

func _draw() -> void:
    var accent: Color = WeaponDefinitions.get_accent(weapon_id)
    var fill := Color(0.04, 0.07, 0.1, 0.78)
    var border := Color(accent.r, accent.g, accent.b, 0.95 if selected else 0.35)
    draw_rect(Rect2(Vector2.ZERO, size), fill, true)
    draw_rect(Rect2(Vector2.ZERO, size), border, false, 3.0 if selected else 1.5)
    draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 5.0)), Color(accent.r, accent.g, accent.b, 0.95 if selected else 0.5), true)
    var font: Font = ThemeDB.fallback_font
    var label: String = "%d  %s" % [slot_number, str(ABBREVIATIONS.get(weapon_id, "GUN"))]
    draw_string(font, Vector2(8.0, 25.0), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 16, Color(1, 1, 1, 0.98 if selected else 0.7))
    draw_string(font, Vector2(8.0, 43.0), ammo_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 14, Color(1.0, 0.88, 0.5, 0.95 if selected else 0.6))
