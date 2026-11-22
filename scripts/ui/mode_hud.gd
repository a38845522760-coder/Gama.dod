extends CanvasLayer
class_name ModeHUD

## Match overlay: score strip, big banners ("WAVE 3"), kill feed and the results screen.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var manager: Node
var _root: Control
var _header_panel: PanelContainer
var _header: Label
var _banner: Label
var _feed: VBoxContainer
var _results: Control
var _banner_left: float = 0.0

func _ready() -> void:
    layer = 7
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.theme = UIStyle.get_theme()
    _root.layout_direction = Control.LAYOUT_DIRECTION_LTR
    add_child(_root)

    _header_panel = PanelContainer.new()
    _header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _header_panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.03, 0.06, 0.09, 0.72), Color(0.4, 0.55, 0.65, 0.5), 18, 1))
    _header_panel.anchor_left = 0.5
    _header_panel.anchor_right = 0.5
    _header_panel.offset_top = 66.0
    _header_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _root.add_child(_header_panel)
    _header = UIStyle.make_label("", 24, Color("#ffe08a"))
    _header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _header_panel.add_child(_header)

    _banner = UIStyle.make_label("", 58, Color.WHITE)
    _banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _banner.anchor_left = 0.0
    _banner.anchor_right = 1.0
    _banner.anchor_top = 0.22
    _banner.anchor_bottom = 0.22
    _banner.offset_bottom = 80.0
    _banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    _banner.add_theme_constant_override("outline_size", 10)
    _banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _banner.modulate.a = 0.0
    _root.add_child(_banner)

    _feed = VBoxContainer.new()
    _feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _feed.position = Vector2(16.0, 104.0)
    _feed.add_theme_constant_override("separation", 3)
    _root.add_child(_feed)

func _process(delta: float) -> void:
    if _banner_left > 0.0:
        _banner_left -= delta
        _banner.modulate.a = clampf(_banner_left / 0.6, 0.0, 1.0) if _banner_left < 0.6 else 1.0

func set_header(text: String) -> void:
    if _header != null:
        _header.text = text

func banner(text: String, seconds: float) -> void:
    if _banner == null:
        return
    _banner.text = text
    _banner_left = seconds
    _banner.modulate.a = 1.0

func add_feed(text: String, color: Color) -> void:
    if _feed == null:
        return
    var label := UIStyle.make_label(text, 18, color)
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    label.add_theme_constant_override("outline_size", 5)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _feed.add_child(label)
    while _feed.get_child_count() > 5:
        var oldest: Node = _feed.get_child(0)
        _feed.remove_child(oldest)
        oldest.queue_free()
    var tween := label.create_tween()
    tween.tween_interval(4.5)
    tween.tween_property(label, "modulate:a", 0.0, 0.8)
    tween.tween_callback(label.queue_free)

func show_results(title: String, lines: Array[String], victory: bool) -> void:
    if _results != null:
        return
    _results = Control.new()
    _results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(_results)
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.06, 0.82)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _results.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _results.add_child(center)
    var panel := PanelContainer.new()
    center.add_child(panel)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(460, 0)
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)
    var heading := UIStyle.make_label(title, 52, Color("#7be0a0") if victory else Color("#ff6b57"))
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    for line in lines:
        var row := UIStyle.make_label(line, 24, UIStyle.COLOR_TEXT)
        row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        column.add_child(row)
    var again := UIStyle.make_button(Loc.t("play_again"), true, Vector2(0, 70))
    again.pressed.connect(_on_again)
    column.add_child(again)
    var shop := UIStyle.make_button(Loc.t("shop"))
    shop.pressed.connect(func() -> void: EventBus.shop_requested.emit())
    column.add_child(shop)
    var menu := UIStyle.make_button(Loc.t("main_menu"))
    UIStyle.style_danger(menu)
    menu.pressed.connect(_on_menu)
    column.add_child(menu)
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_again() -> void:
    get_tree().paused = false
    AppState.end_session()
    get_tree().reload_current_scene()

func _on_menu() -> void:
    get_tree().paused = false
    SaveManager.flush()
    AppState.end_session()
    get_tree().change_scene_to_file(MENU_SCENE)
