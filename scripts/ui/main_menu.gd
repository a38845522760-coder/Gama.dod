extends Control

## Main menu: Play / Settings / Quit with live save stats and an industrial backdrop.

const ARENA_SCENE := "res://scenes/world/core_test_arena.tscn"
const MAP_SCENE := "res://scenes/world/iron_yard_map.tscn"

var _settings_screen: Control
var _content_screen: Control
var _mode_screen: Control
var _shop_screen: Control
var _stripe_shift: float = 0.0

func _ready() -> void:
    theme = UIStyle.get_theme()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    Loc.language_changed.connect(func(_language: String) -> void: _build())
    AppState.set_active_screen("main_menu")
    if not (OS.has_feature("android") or OS.has_feature("ios")):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _build()

func _process(delta: float) -> void:
    _stripe_shift = fposmod(_stripe_shift + delta * 18.0, 96.0)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), UIStyle.COLOR_BG)
    # Warm horizon glow and moving hazard stripes along the bottom edge.
    for band in range(10):
        var alpha := 0.05 * float(10 - band) / 10.0
        draw_rect(Rect2(0, size.y - 260.0 + float(band) * 26.0, size.x, 26.0), Color(0.91, 0.58, 0.23, alpha * 0.6))
    var stripe_y := size.y - 46.0
    draw_rect(Rect2(0, stripe_y, size.x, 46.0), Color(0.05, 0.07, 0.09, 1.0))
    var x := -96.0 + _stripe_shift
    while x < size.x + 96.0:
        var polygon := PackedVector2Array([
            Vector2(x, stripe_y + 46.0), Vector2(x + 36.0, stripe_y + 46.0),
            Vector2(x + 66.0, stripe_y), Vector2(x + 30.0, stripe_y)])
        draw_colored_polygon(polygon, Color(0.91, 0.58, 0.23, 0.9))
        x += 96.0

func _build() -> void:
    for child in get_children():
        child.queue_free()
    Loc.apply_direction(self)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 18)
    column.custom_minimum_size = Vector2(420, 0)
    center.add_child(column)

    var title := UIStyle.make_label(Loc.t("app_title"), 84, UIStyle.COLOR_TEXT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var tagline := UIStyle.make_label(Loc.t("tagline"), 24, UIStyle.COLOR_CYAN)
    tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(tagline)
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 14)
    column.add_child(spacer)

    var play_button := UIStyle.make_button(Loc.t("play"), true, Vector2(0, 80))
    play_button.add_theme_font_size_override("font_size", 30)
    play_button.pressed.connect(_on_play)
    column.add_child(play_button)
    var shop_button := UIStyle.make_button(Loc.t("shop") + "   (" + str(SaveManager.get_credits()) + ")")
    shop_button.pressed.connect(_on_shop)
    column.add_child(shop_button)
    var training_button := UIStyle.make_button(Loc.t("map_training"))
    training_button.pressed.connect(_on_training)
    column.add_child(training_button)
    var content_button := UIStyle.make_button(Loc.t("content"))
    content_button.pressed.connect(_on_content)
    column.add_child(content_button)
    var settings_button := UIStyle.make_button(Loc.t("settings"))
    settings_button.pressed.connect(_on_settings)
    column.add_child(settings_button)
    if not (OS.has_feature("android") or OS.has_feature("ios")):
        var quit_button := UIStyle.make_button(Loc.t("quit"))
        quit_button.pressed.connect(func() -> void: get_tree().quit())
        column.add_child(quit_button)

    var stats := UIStyle.make_label("%s: %d     %s: %d     %s: %d" % [
        Loc.t("credits"), SaveManager.get_credits(),
        Loc.t("best_score"), int(SaveManager.get_value("best_score", 0)),
        Loc.t("kills"), SaveManager.get_stat("kills")], 20, UIStyle.COLOR_TEXT_DIM)
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(stats)

func _on_play() -> void:
    if _mode_screen != null and is_instance_valid(_mode_screen):
        return
    _mode_screen = ModeSelectScreen.new()
    _mode_screen.closed.connect(func() -> void:
        _mode_screen.queue_free()
        _mode_screen = null)
    add_child(_mode_screen)

func _on_shop() -> void:
    if _shop_screen != null and is_instance_valid(_shop_screen):
        return
    _shop_screen = ShopScreen.new()
    _shop_screen.closed.connect(func() -> void:
        _shop_screen.queue_free()
        _shop_screen = null
        _build())
    add_child(_shop_screen)

func _on_training() -> void:
    SaveManager.set_progress("last_map", "core_test_arena")
    get_tree().change_scene_to_file(ARENA_SCENE)

func _on_settings() -> void:
    if _settings_screen != null and is_instance_valid(_settings_screen):
        return
    _settings_screen = SettingsScreen.new()
    _settings_screen.closed.connect(func() -> void:
        _settings_screen.queue_free()
        _settings_screen = null)
    add_child(_settings_screen)

func _on_content() -> void:
    if _content_screen != null and is_instance_valid(_content_screen):
        return
    _content_screen = ContentScreen.new()
    _content_screen.closed.connect(func() -> void:
        _content_screen.queue_free()
        _content_screen = null)
    add_child(_content_screen)
