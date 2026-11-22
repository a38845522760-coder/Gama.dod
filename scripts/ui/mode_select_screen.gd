extends Control
class_name ModeSelectScreen

## Pick a game mode and difficulty, then start the match on the Iron Yard map.

signal closed

const MAP_SCENE := "res://scenes/world/iron_yard_map.tscn"
const ZOMBIE_MAP_SCENE := "res://scenes/world/zombie_map.tscn"
const MODE_ORDER: Array[String] = ["ffa", "tdm", "zombie", "assault", "practice"]
const MODE_COLORS: Dictionary = {
    "ffa": "#ff7a3c", "tdm": "#3d8bff", "zombie": "#7bc24a", "assault": "#d4503a", "practice": "#8fa6b0",
}

var _selected_mode: String = "ffa"
var _difficulty: int = 1
var _mode_buttons: Dictionary = {}
var _difficulty_buttons: Array[Button] = []
var _allies: int = 0
var _enemies: int = 0
var _allies_row: HBoxContainer
var _enemies_row: HBoxContainer
var _allies_label: Label
var _enemies_label: Label
var _lobby_screen: Control

func _ready() -> void:
    theme = UIStyle.get_theme()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
    _selected_mode = str(SaveManager.get_progress("last_mode", "ffa"))
    if not MODE_ORDER.has(_selected_mode):
        _selected_mode = "ffa"
    _difficulty = AppState.pending_difficulty
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.06, 0.94)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dim)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 18)
    add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)

    var header := HBoxContainer.new()
    column.add_child(header)
    var title := UIStyle.make_label(Loc.t("choose_mode"), 38, UIStyle.COLOR_ACCENT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var back := UIStyle.make_button(Loc.t("back"), false, Vector2(150, 56))
    back.pressed.connect(func() -> void: closed.emit())
    header.add_child(back)

    var scroll := TouchScroll.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 8)
    scroll.add_child(list)
    for mode_id in MODE_ORDER:
        var button := Button.new()
        button.toggle_mode = true
        button.focus_mode = Control.FOCUS_NONE
        button.custom_minimum_size = Vector2(0, 92)
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.text = "%s\n%s" % [Loc.t("mode_" + mode_id), Loc.t("mode_" + mode_id + "_desc")]
        button.add_theme_font_size_override("font_size", 21)
        var accent := Color(str(MODE_COLORS[mode_id]))
        button.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.COLOR_PANEL_LIGHT, accent.darkened(0.3), 20, 2))
        button.add_theme_stylebox_override("hover", UIStyle.box(Color(0.16, 0.22, 0.27, 1.0), accent, 20, 2))
        button.add_theme_stylebox_override("pressed", UIStyle.box(accent.darkened(0.55), accent.lightened(0.2), 20, 4))
        var chosen: String = mode_id
        button.pressed.connect(func() -> void:
            _selected_mode = chosen
            _load_counts()
            _refresh())
        list.add_child(button)
        _mode_buttons[mode_id] = button

    var diff_row := HBoxContainer.new()
    diff_row.add_theme_constant_override("separation", 8)
    column.add_child(diff_row)
    diff_row.add_child(UIStyle.make_label(Loc.t("difficulty"), 24, UIStyle.COLOR_TEXT_DIM))
    for index in range(3):
        var diff_button := UIStyle.make_button(Loc.t("diff_" + BotDefinitions.DIFFICULTY_NAMES[index]), false, Vector2(0, 56))
        diff_button.toggle_mode = true
        diff_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var level: int = index
        diff_button.pressed.connect(func() -> void:
            _difficulty = level
            _refresh())
        diff_row.add_child(diff_button)
        _difficulty_buttons.append(diff_button)

    _allies_row = _make_counter_row("allies", true)
    column.add_child(_allies_row)
    _enemies_row = _make_counter_row("enemies", false)
    column.add_child(_enemies_row)

    var start_row := HBoxContainer.new()
    start_row.add_theme_constant_override("separation", 10)
    column.add_child(start_row)
    var start := UIStyle.make_button(Loc.t("start"), true, Vector2(0, 76))
    start.add_theme_font_size_override("font_size", 30)
    start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start.pressed.connect(_on_start)
    start_row.add_child(start)
    var multi := UIStyle.make_button(Loc.t("multiplayer"), false, Vector2(0, 76))
    multi.add_theme_font_size_override("font_size", 26)
    multi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    multi.pressed.connect(_on_multiplayer)
    start_row.add_child(multi)
    _load_counts()
    _refresh()

func _make_counter_row(kind: String, is_allies: bool) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var title := UIStyle.make_label(Loc.t(kind), 24, UIStyle.COLOR_TEXT_DIM)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    var minus := UIStyle.make_button("−", false, Vector2(64, 56))
    minus.pressed.connect(func() -> void: _change_count(is_allies, -1))
    row.add_child(minus)
    var value := UIStyle.make_label("0", 28, UIStyle.COLOR_ACCENT)
    value.custom_minimum_size = Vector2(56, 0)
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    row.add_child(value)
    var plus := UIStyle.make_button("+", false, Vector2(64, 56))
    plus.pressed.connect(func() -> void: _change_count(is_allies, 1))
    row.add_child(plus)
    if is_allies:
        _allies_label = value
    else:
        _enemies_label = value
    return row

func _count_range(kind: String) -> Array:
    var rules: Dictionary = ModeManager.COUNT_RULES.get(_selected_mode, ModeManager.COUNT_RULES["ffa"])
    return rules[kind]

func _load_counts() -> void:
    _allies = ModeManager.get_count("allies", _selected_mode, int(SaveManager.get_progress("allies_" + _selected_mode, -1)))
    _enemies = ModeManager.get_count("enemies", _selected_mode, int(SaveManager.get_progress("enemies_" + _selected_mode, -1)))

func _change_count(is_allies: bool, step: int) -> void:
    var kind: String = "allies" if is_allies else "enemies"
    var range_info: Array = _count_range(kind)
    if is_allies:
        _allies = clampi(_allies + step, int(range_info[1]), int(range_info[2]))
        SaveManager.set_progress("allies_" + _selected_mode, _allies)
    else:
        _enemies = clampi(_enemies + step, int(range_info[1]), int(range_info[2]))
        SaveManager.set_progress("enemies_" + _selected_mode, _enemies)
    _refresh()

func _refresh() -> void:
    for mode_id in _mode_buttons.keys():
        (_mode_buttons[mode_id] as Button).button_pressed = (mode_id == _selected_mode)
    var has_ai: bool = ModeManager.COUNT_RULES.has(_selected_mode)
    if _allies_row != null:
        var ally_range: Array = _count_range("allies")
        _allies_row.visible = has_ai and int(ally_range[2]) > 0
        _enemies_row.visible = has_ai
        _allies = clampi(_allies, int(ally_range[1]), int(ally_range[2]))
        var enemy_range: Array = _count_range("enemies")
        _enemies = clampi(_enemies, int(enemy_range[1]), int(enemy_range[2]))
        _allies_label.text = str(_allies)
        _enemies_label.text = str(_enemies)
    for index in range(_difficulty_buttons.size()):
        _difficulty_buttons[index].button_pressed = (index == _difficulty)

func _on_start() -> void:
    AppState.pending_mode = _selected_mode
    AppState.pending_difficulty = _difficulty
    AppState.pending_allies = _allies if ModeManager.COUNT_RULES.has(_selected_mode) else -1
    AppState.pending_enemies = _enemies if ModeManager.COUNT_RULES.has(_selected_mode) else -1
    var zombie_map: bool = _selected_mode == "zombie"
    SaveManager.set_progress("last_map", "dead_city" if zombie_map else "iron_yard")
    SaveManager.set_progress("last_mode", _selected_mode)
    SaveManager.flush()
    get_tree().change_scene_to_file(ZOMBIE_MAP_SCENE if zombie_map else MAP_SCENE)

func _on_multiplayer() -> void:
    if _lobby_screen != null and is_instance_valid(_lobby_screen):
        return
    AppState.pending_mode = _selected_mode
    AppState.pending_difficulty = _difficulty
    AppState.pending_allies = _allies if ModeManager.COUNT_RULES.has(_selected_mode) else -1
    AppState.pending_enemies = _enemies if ModeManager.COUNT_RULES.has(_selected_mode) else -1
    _lobby_screen = LobbyScreen.new()
    _lobby_screen.closed.connect(func() -> void:
        _lobby_screen.queue_free()
        _lobby_screen = null)
    add_child(_lobby_screen)
