extends RefCounted
class_name UIStyle

## Shared look for every menu: rounded pill buttons, touch-sized sliders and dark steel panels.

const COLOR_BG := Color("#0a1116")
const COLOR_PANEL := Color(0.075, 0.11, 0.14, 0.96)
const COLOR_PANEL_LIGHT := Color(0.12, 0.17, 0.21, 1.0)
const COLOR_BORDER := Color(0.28, 0.40, 0.47, 1.0)
const COLOR_ACCENT := Color("#e8943a")
const COLOR_ACCENT_DARK := Color("#b96d1f")
const COLOR_CYAN := Color("#41d9ee")
const COLOR_TEXT := Color("#e7f0f4")
const COLOR_TEXT_DIM := Color("#8fa6b0")
const COLOR_DANGER := Color("#e04a3c")

static var _theme: Theme = null
static var _grabber: Texture2D = null

static func box(fill: Color, border: Color = Color(0, 0, 0, 0), radius: int = 16, border_width: int = 0) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 22
    style.content_margin_right = 22
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    style.anti_aliasing = true
    return style

static func get_theme() -> Theme:
    if _theme != null:
        return _theme
    var theme := Theme.new()
    theme.default_font_size = 22
    theme.set_color("font_color", "Label", COLOR_TEXT)
    theme.set_color("font_color", "Button", COLOR_TEXT)
    theme.set_color("font_hover_color", "Button", Color.WHITE)
    theme.set_color("font_pressed_color", "Button", Color.WHITE)
    theme.set_color("font_focus_color", "Button", Color.WHITE)
    theme.set_color("font_disabled_color", "Button", COLOR_TEXT_DIM)
    theme.set_stylebox("normal", "Button", box(COLOR_PANEL_LIGHT, COLOR_BORDER, 30, 2))
    theme.set_stylebox("hover", "Button", box(Color(0.16, 0.22, 0.27, 1.0), COLOR_CYAN, 30, 2))
    theme.set_stylebox("pressed", "Button", box(COLOR_ACCENT_DARK, COLOR_ACCENT, 30, 2))
    theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), COLOR_CYAN, 30, 2))
    theme.set_stylebox("disabled", "Button", box(Color(0.1, 0.13, 0.16, 0.8), COLOR_BORDER, 30, 1))
    var track := box(Color(0.16, 0.22, 0.27, 1.0), Color(0, 0, 0, 0), 8, 0)
    track.content_margin_top = 6
    track.content_margin_bottom = 6
    var fill := box(COLOR_ACCENT, Color(0, 0, 0, 0), 8, 0)
    fill.content_margin_top = 6
    fill.content_margin_bottom = 6
    theme.set_stylebox("slider", "HSlider", track)
    theme.set_stylebox("grabber_area", "HSlider", fill)
    theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
    var grabber := _make_grabber()
    theme.set_icon("grabber", "HSlider", grabber)
    theme.set_icon("grabber_highlight", "HSlider", grabber)
    theme.set_icon("grabber_disabled", "HSlider", grabber)
    theme.set_constant("center_grabber", "HSlider", 0)
    theme.set_stylebox("panel", "PanelContainer", box(COLOR_PANEL, COLOR_BORDER, 26, 2))
    _theme = theme
    return theme

static func _make_grabber() -> Texture2D:
    if _grabber != null:
        return _grabber
    var size := 56
    var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
    var center := Vector2(size * 0.5, size * 0.5)
    for y in range(size):
        for x in range(size):
            var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
            var color := Color(0, 0, 0, 0)
            if distance <= 26.0:
                color = Color("#f4f9fb") if distance <= 20.0 else COLOR_ACCENT
                color.a = clampf(27.0 - distance, 0.0, 1.0)
            image.set_pixel(x, y, color)
    _grabber = ImageTexture.create_from_image(image)
    return _grabber

static func style_primary(button: Button) -> void:
    button.add_theme_stylebox_override("normal", box(COLOR_ACCENT, Color("#ffd199"), 34, 2))
    button.add_theme_stylebox_override("hover", box(Color("#f2a54f"), Color.WHITE, 34, 2))
    button.add_theme_stylebox_override("pressed", box(COLOR_ACCENT_DARK, Color.WHITE, 34, 2))
    button.add_theme_color_override("font_color", Color("#1b1006"))
    button.add_theme_color_override("font_hover_color", Color("#1b1006"))
    button.add_theme_color_override("font_pressed_color", Color.WHITE)

static func style_danger(button: Button) -> void:
    button.add_theme_stylebox_override("normal", box(Color(0.30, 0.10, 0.09, 1.0), COLOR_DANGER, 30, 2))
    button.add_theme_stylebox_override("hover", box(Color(0.42, 0.13, 0.11, 1.0), COLOR_DANGER, 30, 2))

static func make_button(text: String, primary: bool = false, min_size: Vector2 = Vector2(0, 66)) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = min_size
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 24)
    if primary:
        style_primary(button)
    return button

static func make_label(text: String, size: int = 22, color: Color = COLOR_TEXT) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label
