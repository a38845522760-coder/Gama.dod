extends CanvasLayer

## In-game HUD: health / armor bars, ammo counter, dynamic crosshair, hit markers,
## damage vignette, score pop-ups, death overlay and optional debug telemetry.

var _root: Control
var _debug_label: Label
var _health_bar: ProgressBar
var _armor_bar: ProgressBar
var _health_label: Label
var _armor_label: Label
var _ammo_label: Label
var _reserve_label: Label
var _weapon_label: Label
var _prompt_label: Label
var _status_label: Label
var _popup_label: Label
var _death_panel: Control
var _death_title: Label
var _death_count: Label
var _vignette: TextureRect
var _crosshair: Crosshair
var _player: Node
var _weapon: Node
var _elapsed: float = 0.0
var _vignette_alpha: float = 0.0
var _health_vignette: float = 0.0
var _health_vignette_target: float = 0.0
var _popup_left: float = 0.0
var _death_left: float = 0.0
var _is_mobile: bool = false

func _ready() -> void:
    layer = 5
    _is_mobile = OS.has_feature("android") or OS.has_feature("ios")
    _root = Control.new()
    _root.name = "HudRoot"
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.theme = UIStyle.get_theme()
    add_child(_root)
    _build_vignette()
    _build_debug()
    _build_bars()
    _build_ammo()
    _build_center()
    _build_death()
    Loc.language_changed.connect(func(_language: String) -> void: _refresh_texts())
    SettingsManager.settings_changed.connect(func(_settings: Dictionary) -> void: _debug_label.visible = bool(SettingsManager.get_setting("show_debug", false)))
    EventBus.target_destroyed.connect(_on_target_destroyed)

    var players := get_tree().get_nodes_in_group("player_controller")
    if not players.is_empty():
        _player = players[0]
        _hook_player()
    var weapons := get_tree().get_nodes_in_group("weapon_controller")
    if not weapons.is_empty():
        _weapon = weapons[0]
        _hook_weapon()
    _refresh_texts()

func _hook_player() -> void:
    var health := _player.get_node_or_null("HealthComponent") as HealthComponent
    if health != null:
        health.health_changed.connect(_on_health_changed)
        health.armor_changed.connect(_on_armor_changed)
        health.damaged.connect(_on_damaged)
        _on_health_changed(health.current_health, health.max_health)
        _on_armor_changed(health.current_armor, health.max_armor)
    if _player.has_signal("interaction_prompt_changed"):
        _player.connect("interaction_prompt_changed", Callable(self, "_on_interaction_prompt_changed"))
    if _player.has_signal("died"):
        _player.connect("died", Callable(self, "_on_player_died"))
    if _player.has_signal("respawned"):
        _player.connect("respawned", Callable(self, "_on_player_respawned"))

func _hook_weapon() -> void:
    _weapon.connect("ammo_changed", Callable(self, "_on_ammo_changed"))
    _weapon.connect("reload_state_changed", Callable(self, "_on_reload_state"))
    _weapon.connect("hit_confirmed", Callable(self, "_on_hit_confirmed"))
    if _weapon.has_signal("weapon_changed"):
        _weapon.connect("weapon_changed", Callable(self, "_on_weapon_changed"))
    _on_ammo_changed(int(_weapon.call("get_magazine")), int(_weapon.call("get_reserve")), int(_weapon.call("get_magazine_size")))
    _weapon_label.text = str(_weapon.call("get_weapon_name"))

func _build_vignette() -> void:
    var gradient := Gradient.new()
    gradient.set_color(0, Color(0.8, 0.05, 0.03, 0.0))
    gradient.set_color(1, Color(0.8, 0.05, 0.03, 0.85))
    gradient.set_offset(0, 0.45)
    gradient.set_offset(1, 1.0)
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(1.0, 0.5)
    texture.width = 256
    texture.height = 256
    _vignette = TextureRect.new()
    _vignette.texture = texture
    _vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _vignette.stretch_mode = TextureRect.STRETCH_SCALE
    _vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _vignette.modulate.a = 0.0
    _root.add_child(_vignette)

func _build_debug() -> void:
    _debug_label = Label.new()
    _debug_label.position = Vector2(110, 14) if _is_mobile else Vector2(16, 12)
    _debug_label.add_theme_font_size_override("font_size", 14)
    _debug_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.95, 0.85))
    _debug_label.visible = bool(SettingsManager.get_setting("show_debug", false))
    _root.add_child(_debug_label)

func _anchor(control: Control, anchor_x: float, anchor_y: float, left: float, top: float, right: float, bottom: float) -> void:
    control.anchor_left = anchor_x
    control.anchor_right = anchor_x
    control.anchor_top = anchor_y
    control.anchor_bottom = anchor_y
    control.offset_left = left
    control.offset_right = right
    control.offset_top = top
    control.offset_bottom = bottom

func _make_bar(fill_color: Color, bar_size: Vector2) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.custom_minimum_size = bar_size
    bar.size = bar_size
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_theme_stylebox_override("background", UIStyle.box(Color(0.03, 0.05, 0.07, 0.7), Color(1, 1, 1, 0.12), 8, 1))
    bar.add_theme_stylebox_override("fill", UIStyle.box(fill_color, Color(0, 0, 0, 0), 8, 0))
    return bar

func _build_bars() -> void:
    var box := VBoxContainer.new()
    box.name = "Bars"
    _anchor(box, 0.5, 1.0, -150.0, -118.0, 150.0, -26.0)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_theme_constant_override("separation", 5)
    box.layout_direction = Control.LAYOUT_DIRECTION_LTR
    _root.add_child(box)

    var health_row := HBoxContainer.new()
    health_row.add_theme_constant_override("separation", 8)
    box.add_child(health_row)
    _health_label = UIStyle.make_label("", 16, Color("#ff8b7d"))
    _health_label.custom_minimum_size = Vector2(62, 0)
    health_row.add_child(_health_label)
    _health_bar = _make_bar(Color("#e5483c"), Vector2(220, 16))
    health_row.add_child(_health_bar)

    var armor_row := HBoxContainer.new()
    armor_row.add_theme_constant_override("separation", 8)
    box.add_child(armor_row)
    _armor_label = UIStyle.make_label("", 16, Color("#7fd6ff"))
    _armor_label.custom_minimum_size = Vector2(62, 0)
    armor_row.add_child(_armor_label)
    _armor_bar = _make_bar(Color("#44b5ee"), Vector2(220, 12))
    armor_row.add_child(_armor_bar)

func _build_ammo() -> void:
    var box := VBoxContainer.new()
    _anchor(box, 1.0, 0.0, -250.0, 12.0, -20.0, 102.0)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.layout_direction = Control.LAYOUT_DIRECTION_LTR
    box.alignment = BoxContainer.ALIGNMENT_BEGIN
    _root.add_child(box)
    var line := HBoxContainer.new()
    line.alignment = BoxContainer.ALIGNMENT_END
    line.add_theme_constant_override("separation", 8)
    box.add_child(line)
    _ammo_label = UIStyle.make_label("30", 46, Color.WHITE)
    line.add_child(_ammo_label)
    _reserve_label = UIStyle.make_label("/ 150", 24, UIStyle.COLOR_TEXT_DIM)
    _reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
    line.add_child(_reserve_label)
    _weapon_label = UIStyle.make_label("", 15, UIStyle.COLOR_TEXT_DIM)
    _weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    box.add_child(_weapon_label)

func _build_center() -> void:
    _crosshair = Crosshair.new()
    _crosshair.name = "Crosshair"
    _root.add_child(_crosshair)
    _anchor(_crosshair, 0.5, 0.5, -80.0, -80.0, 80.0, 80.0)

    _prompt_label = UIStyle.make_label("", 20, Color(0.9, 0.97, 1.0))
    _anchor(_prompt_label, 0.5, 1.0, -220.0, -176.0, 220.0, -142.0)
    _prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _root.add_child(_prompt_label)

    _status_label = UIStyle.make_label("", 22, Color(1.0, 0.82, 0.4))
    _anchor(_status_label, 0.5, 0.5, -150.0, 62.0, 150.0, 92.0)
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _root.add_child(_status_label)

    _popup_label = UIStyle.make_label("", 28, Color(1.0, 0.9, 0.5))
    _anchor(_popup_label, 0.5, 0.0, -200.0, 70.0, 200.0, 110.0)
    _popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _popup_label.modulate.a = 0.0
    _root.add_child(_popup_label)

func _build_death() -> void:
    _death_panel = Control.new()
    _death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _death_panel.visible = false
    _root.add_child(_death_panel)
    var shade := ColorRect.new()
    shade.color = Color(0.1, 0.0, 0.0, 0.45)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _death_panel.add_child(shade)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _death_panel.add_child(center)
    var column := VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(column)
    _death_title = UIStyle.make_label("", 64, Color("#ff5a4a"))
    _death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(_death_title)
    _death_count = UIStyle.make_label("", 28, Color.WHITE)
    _death_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(_death_count)

func _refresh_texts() -> void:
    Loc.apply_direction(_root)
    _health_label.text = Loc.t("health")
    _armor_label.text = Loc.t("armor")
    _death_title.text = Loc.t("you_died")
    _root.layout_direction = Control.LAYOUT_DIRECTION_LTR

func _process(delta: float) -> void:
    _vignette_alpha = maxf(0.0, _vignette_alpha - delta * 1.4)
    # The lower the health, the redder the screen; it fades again while health regenerates.
    _health_vignette = move_toward(_health_vignette, _health_vignette_target, delta * 0.9)
    _vignette.modulate.a = maxf(_vignette_alpha, _health_vignette)
    if _popup_left > 0.0:
        _popup_left -= delta
        _popup_label.modulate.a = clampf(_popup_left / 0.5, 0.0, 1.0)
        var rise := 70.0 - (1.0 - clampf(_popup_left / 1.4, 0.0, 1.0)) * 14.0
        _popup_label.offset_top = rise
        _popup_label.offset_bottom = rise + 40.0
    if _death_panel.visible:
        _death_left = maxf(0.0, _death_left - delta)
        _death_count.text = "%s %d" % [Loc.t("respawn_in"), int(ceil(_death_left))]
    if _weapon != null and is_instance_valid(_weapon):
        _crosshair.reload_progress = float(_weapon.call("get_reload_progress"))
        var spread_rad: float = float(_weapon.call("get_current_spread"))
        _crosshair.spread_pixels = 4.0 + spread_rad * 1100.0
    _elapsed += delta
    if _elapsed < 0.12:
        return
    _elapsed = 0.0
    if is_instance_valid(_player) and _player.has_method("get_movement_snapshot"):
        var movement: Dictionary = _player.call("get_movement_snapshot")
        if _debug_label.visible:
            var snapshot := PerformanceManager.get_performance_snapshot()
            _debug_label.text = "%s | %d FPS | %.1f ms p95 | %.0f MB\n%s | %.1f m/s | %s" % [
                str(snapshot["quality_preset"]).to_upper(), int(snapshot["fps"]),
                float(snapshot["p95_frame_time_ms"]), float(snapshot["memory_static_mb"]),
                str(movement.get("state", "idle")).to_upper(), float(movement.get("horizontal_speed", 0.0)),
                str(movement.get("surface_type", "concrete")).to_upper()]

func _on_health_changed(current: float, maximum: float) -> void:
    _health_bar.max_value = maximum
    _health_bar.value = current
    var fraction: float = current / maxf(maximum, 1.0)
    _health_vignette_target = clampf((1.0 - fraction) * 1.2 - 0.08, 0.0, 0.88) if current > 0.0 else 0.0
    var low := fraction < 0.3
    _health_label.add_theme_color_override("font_color", Color("#ff3b2e") if low else Color("#ff8b7d"))

func _on_armor_changed(current: float, maximum: float) -> void:
    _armor_bar.max_value = maximum
    _armor_bar.value = current

func _on_damaged(amount: float, _source: Node) -> void:
    _vignette_alpha = clampf(_vignette_alpha + amount * 0.02, 0.25, 0.9)

func _on_ammo_changed(magazine: int, reserve: int, magazine_size: int) -> void:
    _ammo_label.text = str(magazine)
    _reserve_label.text = "/ %d" % reserve
    var low := magazine <= int(float(magazine_size) * 0.25)
    _ammo_label.add_theme_color_override("font_color", Color("#ff5a4a") if low else Color.WHITE)
    if magazine == 0 and reserve == 0:
        _status_label.text = Loc.t("no_ammo")

func _on_reload_state(is_reloading: bool, _duration: float) -> void:
    _status_label.text = Loc.t("reloading") if is_reloading else ""

func _on_weapon_changed(_weapon_id: String, display_name: String) -> void:
    _weapon_label.text = display_name

func _on_hit_confirmed(_headshot: bool, killed: bool) -> void:
    _crosshair.show_hit(killed)

func _on_target_destroyed(points: int, headshot: bool) -> void:
    _popup_label.text = "+%d" % points + ("  " + Loc.t("headshot") if headshot else "")
    _popup_label.add_theme_color_override("font_color", Color("#ff6b57") if headshot else Color("#ffe08a"))
    _popup_left = 1.4

func _on_interaction_prompt_changed(prompt: String) -> void:
    if prompt.is_empty():
        _prompt_label.text = ""
    elif _is_mobile:
        _prompt_label.text = "%s  ●  %s" % [prompt, Loc.t("hint_use")]
    else:
        _prompt_label.text = "[E] " + prompt

func _on_player_died() -> void:
    _death_left = 3.0
    if _player != null and "respawn_delay" in _player:
        _death_left = float(_player.get("respawn_delay"))
    _death_panel.visible = true
    _vignette_alpha = 0.9

func _on_player_respawned() -> void:
    _death_panel.visible = false
    _status_label.text = ""
