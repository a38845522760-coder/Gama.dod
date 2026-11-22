extends Control
class_name SettingsScreen

## Full settings page (graphics, audio, controls, language). Built in code so every
## label can be re-created when the language changes. Emits `closed` on Back.

signal closed

const TABS: Array[String] = ["graphics", "audio", "controls", "language"]
const QUALITY_KEYS: Array[String] = ["low", "medium", "high", "ultra"]

var _tab_index: int = 0
var _content: VBoxContainer
var _tab_buttons: Array[Button] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    theme = UIStyle.get_theme()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    Loc.language_changed.connect(func(_language: String) -> void: _build())
    _build()

func _build() -> void:
    for child in get_children():
        child.queue_free()
    _tab_buttons.clear()
    Loc.apply_direction(self)

    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.06, 0.88)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(880, 600)
    center.add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    panel.add_child(column)

    var title := UIStyle.make_label(Loc.t("settings"), 36, UIStyle.COLOR_ACCENT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)

    var tab_row := HBoxContainer.new()
    tab_row.add_theme_constant_override("separation", 10)
    column.add_child(tab_row)
    for index in range(TABS.size()):
        var tab_button := UIStyle.make_button(Loc.t(TABS[index]), false, Vector2(0, 58))
        tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab_button.toggle_mode = true
        tab_button.button_pressed = index == _tab_index
        var tab_number := index
        tab_button.pressed.connect(func() -> void: _select_tab(tab_number))
        tab_row.add_child(tab_button)
        _tab_buttons.append(tab_button)

    var scroll := TouchScroll.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)

    _content = VBoxContainer.new()
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 16)
    scroll.add_child(_content)
    _fill_tab()

    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 14)
    column.add_child(footer)
    var reset_button := UIStyle.make_button(Loc.t("reset_defaults"))
    reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reset_button.pressed.connect(func() -> void:
        SettingsManager.reset_to_defaults()
        _build())
    footer.add_child(reset_button)
    var back_button := UIStyle.make_button(Loc.t("back"), true)
    back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back_button.pressed.connect(_close)
    footer.add_child(back_button)

func _select_tab(index: int) -> void:
    _tab_index = index
    for tab_number in range(_tab_buttons.size()):
        _tab_buttons[tab_number].button_pressed = tab_number == index
    _fill_tab()

func _fill_tab() -> void:
    for child in _content.get_children():
        child.queue_free()
    match TABS[_tab_index]:
        "graphics":
            _add_choice_row("quality", _quality_options(), SettingsManager.get_quality_preset(), func(value: Variant) -> void: SettingsManager.set_quality_preset(str(value)))
            _add_toggle_row("dynamic_quality")
            _add_slider_row("fov", "fov", 60.0, 110.0, 1.0, "%d°")
            _add_toggle_row("show_debug")
        "audio":
            _add_slider_row("master_volume", "master_volume", 0.0, 1.0, 0.05, "%d%%", 100.0)
            _add_slider_row("music_volume", "music_volume", 0.0, 1.0, 0.05, "%d%%", 100.0)
            _add_slider_row("sfx_volume", "sfx_volume", 0.0, 1.0, 0.05, "%d%%", 100.0)
        "controls":
            _add_slider_row("touch_look_sensitivity", "touch_look_sensitivity", 0.1, 3.0, 0.05, "%.2f")
            _add_slider_row("look_sensitivity", "look_sensitivity", 0.1, 3.0, 0.05, "%.2f")
            _add_slider_row("touch_scale", "touch_scale", 0.7, 1.5, 0.05, "%.2f×")
            _add_slider_row("touch_opacity", "touch_opacity", 0.3, 1.0, 0.05, "%d%%", 100.0)
            _add_toggle_row("invert_y")
            _add_toggle_row("haptics")
            var layout_button := UIStyle.make_button(Loc.t("edit_layout"), true, Vector2(0, 66))
            layout_button.pressed.connect(_open_layout_editor)
            _content.add_child(layout_button)
        "language":
            _add_choice_row("language", [["fa", Loc.t("lang_fa")], ["en", Loc.t("lang_en")]], str(SettingsManager.get_setting("language", "fa")), func(value: Variant) -> void: SettingsManager.set_setting("language", str(value)))

func _quality_options() -> Array:
    var options: Array = []
    for key in QUALITY_KEYS:
        options.append([key, Loc.t("quality_" + key)])
    return options

func _add_row(label_key: String) -> VBoxContainer:
    var row := VBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    _content.add_child(row)
    row.add_child(UIStyle.make_label(Loc.t(label_key), 22, UIStyle.COLOR_TEXT_DIM))
    return row

func _add_slider_row(label_key: String, setting_key: String, min_value: float, max_value: float, step: float, format: String, display_scale: float = 1.0) -> void:
    var row := _add_row(label_key)
    var line := HBoxContainer.new()
    line.add_theme_constant_override("separation", 16)
    row.add_child(line)
    var slider := HSlider.new()
    slider.min_value = min_value
    slider.max_value = max_value
    slider.step = step
    slider.value = float(SettingsManager.get_setting(setting_key, min_value))
    slider.custom_minimum_size = Vector2(0, 52)
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    slider.layout_direction = Control.LAYOUT_DIRECTION_LTR
    line.add_child(slider)
    var value_label := UIStyle.make_label(format % (slider.value * display_scale), 22, UIStyle.COLOR_CYAN)
    value_label.custom_minimum_size = Vector2(90, 0)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    line.add_child(value_label)
    slider.value_changed.connect(func(value: float) -> void:
        SettingsManager.set_setting(setting_key, value)
        value_label.text = format % (value * display_scale))

func _add_toggle_row(setting_key: String) -> void:
    var row := _add_row(setting_key)
    var button := UIStyle.make_button("", false, Vector2(0, 58))
    button.toggle_mode = true
    button.button_pressed = bool(SettingsManager.get_setting(setting_key, false))
    button.text = Loc.t("on") if button.button_pressed else Loc.t("off")
    button.toggled.connect(func(pressed: bool) -> void:
        SettingsManager.set_setting(setting_key, pressed)
        button.text = Loc.t("on") if pressed else Loc.t("off"))
    row.add_child(button)

func _add_choice_row(label_key: String, options: Array, current: String, on_pick: Callable) -> void:
    var row := _add_row(label_key)
    var line := HBoxContainer.new()
    line.add_theme_constant_override("separation", 10)
    row.add_child(line)
    var group: Array[Button] = []
    for option in options:
        var pair: Array = option
        var button := UIStyle.make_button(str(pair[1]), false, Vector2(0, 58))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.toggle_mode = true
        button.button_pressed = str(pair[0]) == current
        var option_value: String = str(pair[0])
        button.pressed.connect(func() -> void:
            for other in group:
                other.button_pressed = other == button
            on_pick.call(option_value))
        line.add_child(button)
        group.append(button)

func _open_layout_editor() -> void:
    var editor := HudLayoutEditor.new()
    editor.closed.connect(func() -> void: editor.queue_free())
    add_child(editor)

func _close() -> void:
    closed.emit()

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("pause"):
        get_viewport().set_input_as_handled()
        _close()
