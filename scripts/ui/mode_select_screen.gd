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

    var scroll := ScrollContainer.new()
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

    var start := UIStyle.make_button(Loc.t("start"), true, Vector2(0, 76))
    start.add_theme_font_size_override("font_size", 30)
    start.pressed.connect(_on_start)
    column.add_child(start)
    _refresh()

func _refresh() -> void:
    for mode_id in _mode_buttons.keys():
        (_mode_buttons[mode_id] as Button).button_pressed = (mode_id == _selected_mode)
    for index in range(_difficulty_buttons.size()):
        _difficulty_buttons[index].button_pressed = (index == _difficulty)

func _on_start() -> void:
    AppState.pending_mode = _selected_mode
    AppState.pending_difficulty = _difficulty
    var zombie_map: bool = _selected_mode == "zombie"
    SaveManager.set_progress("last_map", "dead_city" if zombie_map else "iron_yard")
    SaveManager.set_progress("last_mode", _selected_mode)
    SaveManager.flush()
    get_tree().change_scene_to_file(ZOMBIE_MAP_SCENE if zombie_map else MAP_SCENE)
