extends CanvasLayer
class_name PauseMenu

## Pause overlay: Resume / Settings / Main menu. The game tree is really paused while open.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var _panel_root: Control
var _settings_screen: Control
var _open: bool = false

func _ready() -> void:
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("pause_menu")
    _panel_root = Control.new()
    _panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _panel_root.theme = UIStyle.get_theme()
    _panel_root.visible = false
    add_child(_panel_root)
    Loc.language_changed.connect(func(_language: String) -> void:
        if _open and _settings_screen == null:
            _build())

func toggle() -> void:
    if _open:
        close()
    else:
        open()

func is_open() -> bool:
    return _open

func open() -> void:
    if _open:
        return
    _open = true
    # In a LAN match the game keeps running so the other players are not frozen.
    get_tree().paused = not AppState.multiplayer_active
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _build()
    _panel_root.visible = true

func close() -> void:
    if not _open:
        return
    if _settings_screen != null:
        _settings_screen.queue_free()
        _settings_screen = null
    _open = false
    _panel_root.visible = false
    get_tree().paused = false
    if not (OS.has_feature("android") or OS.has_feature("ios")):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build() -> void:
    for child in _panel_root.get_children():
        child.queue_free()
    Loc.apply_direction(_panel_root)
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.06, 0.78)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _panel_root.add_child(dim)
    var scroll := TouchScroll.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _panel_root.add_child(scroll)
    var center := CenterContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.add_child(center)
    var panel := PanelContainer.new()
    center.add_child(panel)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(420, 0)
    column.add_theme_constant_override("separation", 16)
    panel.add_child(column)
    var title := UIStyle.make_label(Loc.t("paused"), 44, UIStyle.COLOR_ACCENT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var resume_button := UIStyle.make_button(Loc.t("resume"), true, Vector2(0, 74))
    resume_button.pressed.connect(close)
    column.add_child(resume_button)
    var weather_nodes := get_tree().get_nodes_in_group("weather_system")
    if not weather_nodes.is_empty():
        var weather: Node = weather_nodes[0]
        column.add_child(UIStyle.make_label(Loc.t("weather"), 20, UIStyle.COLOR_TEXT_DIM))
        var flow := HFlowContainer.new()
        flow.add_theme_constant_override("h_separation", 8)
        flow.add_theme_constant_override("v_separation", 8)
        column.add_child(flow)
        var current_id: String = str(weather.call("get_current_id"))
        for weather_id in WeatherSystem.ORDER:
            var weather_button := UIStyle.make_button(Loc.t("weather_" + weather_id), false, Vector2(0, 52))
            weather_button.toggle_mode = true
            weather_button.button_pressed = weather_id == current_id
            weather_button.add_theme_font_size_override("font_size", 20)
            var chosen: String = weather_id
            weather_button.pressed.connect(func() -> void:
                weather.call("set_weather", chosen)
                _build())
            flow.add_child(weather_button)
    var settings_button := UIStyle.make_button(Loc.t("settings"))
    settings_button.pressed.connect(_open_settings)
    column.add_child(settings_button)
    var menu_button := UIStyle.make_button(Loc.t("main_menu"))
    UIStyle.style_danger(menu_button)
    menu_button.pressed.connect(_to_main_menu)
    column.add_child(menu_button)

func _open_settings() -> void:
    if _settings_screen != null:
        return
    _settings_screen = SettingsScreen.new()
    _settings_screen.closed.connect(func() -> void:
        _settings_screen.queue_free()
        _settings_screen = null
        _build())
    _panel_root.add_child(_settings_screen)

func _to_main_menu() -> void:
    SaveManager.flush()
    SettingsManager.save_settings()
    _open = false
    get_tree().paused = false
    AppState.end_session()
    get_tree().change_scene_to_file(MENU_SCENE)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause") and _settings_screen == null:
        get_viewport().set_input_as_handled()
        toggle()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and _settings_screen == null:
        toggle()
    elif what == NOTIFICATION_APPLICATION_PAUSED and not _open and get_tree().current_scene != null:
        open()
