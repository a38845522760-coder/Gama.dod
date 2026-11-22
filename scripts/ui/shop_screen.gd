extends Control
class_name ShopScreen

## The shop: guns, supplies (medkits, armor plates, ammo) and permanent upgrades.
## Works from the main menu and in the middle of a match (pass the player to equip at once).

signal closed

var _player: Node = null
var _tab: String = "weapons"
var _grid: GridContainer
var _credits_label: Label
var _tab_buttons: Dictionary = {}
var _sfx: AudioStreamPlayer

func setup(player: Node) -> void:
    _player = player

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    theme = UIStyle.get_theme()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
    _sfx = AudioStreamPlayer.new()
    _sfx.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
    add_child(_sfx)
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.06, 0.9)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dim)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 18)
    add_child(margin)
    var panel := PanelContainer.new()
    margin.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    panel.add_child(column)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 14)
    column.add_child(header)
    var title := UIStyle.make_label(Loc.t("shop"), 40, UIStyle.COLOR_ACCENT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    _credits_label = UIStyle.make_label("", 28, Color("#ffe08a"))
    header.add_child(_credits_label)
    var close_button := UIStyle.make_button(Loc.t("back"), false, Vector2(150, 56))
    close_button.pressed.connect(func() -> void: closed.emit())
    header.add_child(close_button)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    column.add_child(tabs)
    for tab_id in ["weapons", "supplies", "upgrades"]:
        var tab_button := UIStyle.make_button(Loc.t("tab_" + tab_id), false, Vector2(0, 56))
        tab_button.toggle_mode = true
        tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var chosen: String = tab_id
        tab_button.pressed.connect(func() -> void:
            _tab = chosen
            _refresh())
        tabs.add_child(tab_button)
        _tab_buttons[tab_id] = tab_button

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    _grid = GridContainer.new()
    _grid.columns = 3 if get_viewport_rect().size.x >= 1100.0 else 2
    _grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid.add_theme_constant_override("h_separation", 12)
    _grid.add_theme_constant_override("v_separation", 12)
    scroll.add_child(_grid)
    _refresh()

func _language() -> String:
    return "fa" if Loc.language == "fa" else "en"

func _refresh() -> void:
    _credits_label.text = "%s: %d" % [Loc.t("credits"), SaveManager.get_credits()]
    for tab_id in _tab_buttons.keys():
        (_tab_buttons[tab_id] as Button).button_pressed = (tab_id == _tab)
    for child in _grid.get_children():
        child.queue_free()
    match _tab:
        "weapons":
            for weapon_id in WeaponDefinitions.ORDER:
                if bool(WeaponDefinitions.get_definition(weapon_id).get("map_shop_only", false)):
                    continue
                _grid.add_child(_weapon_card(weapon_id))
        "supplies":
            for item_id in ShopCatalog.SUPPLIES.keys():
                _grid.add_child(_supply_card(str(item_id)))
        _:
            for upgrade_id in ShopCatalog.UPGRADES.keys():
                _grid.add_child(_upgrade_card(str(upgrade_id)))

func _card() -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.COLOR_PANEL_LIGHT, UIStyle.COLOR_BORDER, 18, 2))
    var inner := VBoxContainer.new()
    inner.add_theme_constant_override("separation", 6)
    panel.add_child(inner)
    # The panel is returned through its single child; the caller adds the panel to the grid
    # via get_parent(), so keep a reference on the child.
    inner.set_meta("panel", panel)
    return inner

func _add_card(inner: VBoxContainer) -> Control:
    return inner.get_meta("panel") as Control

func _stat_row(label_text: String, fraction: float, color: Color) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var label := UIStyle.make_label(label_text, 15, UIStyle.COLOR_TEXT_DIM)
    label.custom_minimum_size = Vector2(70, 0)
    row.add_child(label)
    var bar := ProgressBar.new()
    bar.max_value = 1.0
    bar.value = clampf(fraction, 0.0, 1.0)
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 10)
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    bar.add_theme_stylebox_override("background", UIStyle.box(Color(0.03, 0.05, 0.07, 0.8), Color(0, 0, 0, 0), 5, 0))
    bar.add_theme_stylebox_override("fill", UIStyle.box(color, Color(0, 0, 0, 0), 5, 0))
    row.add_child(bar)
    return row

func _weapon_card(weapon_id: String) -> Control:
    var inner := _card()
    var def: Dictionary = WeaponDefinitions.get_definition(weapon_id)
    var accent: Color = WeaponDefinitions.get_accent(weapon_id)
    var preview := WeaponPreview.new()
    preview.weapon_id = weapon_id
    preview.custom_minimum_size = Vector2(0, 150)
    preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inner.add_child(preview)
    var name_label := UIStyle.make_label(WeaponDefinitions.get_display_name(weapon_id, _language()), 24, accent.lightened(0.25))
    inner.add_child(name_label)
    var desc := UIStyle.make_label(str(def.get("description_" + _language(), "")), 16, UIStyle.COLOR_TEXT_DIM)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.custom_minimum_size = Vector2(200, 0)
    inner.add_child(desc)
    var shot_damage: float = float(def["damage"]) * float(def["pellets"])
    inner.add_child(_stat_row(Loc.t("stat_damage"), shot_damage / 110.0, Color("#ff7a6b")))
    inner.add_child(_stat_row(Loc.t("stat_rate"), float(def["rounds_per_minute"]) / 900.0, Color("#ffd166")))
    inner.add_child(_stat_row(Loc.t("stat_range"), float(def["range"]) / 300.0, Color("#7fd6ff")))
    inner.add_child(_stat_row(Loc.t("stat_ammo"), float(def["magazine_size"]) / 100.0, Color("#7be0a0")))
    var owned: bool = SaveManager.owns_weapon(weapon_id)
    var price: int = int(def["price"])
    var button: Button
    if owned:
        var equipped: bool = false
        var controller: Node = _player.get_node_or_null("WeaponController") if _player != null else null
        if controller != null and controller.has_method("get_weapon_id"):
            equipped = str(controller.call("get_weapon_id")) == weapon_id
        if _player != null and not equipped:
            button = UIStyle.make_button(Loc.t("equip"), false, Vector2(0, 56))
            button.pressed.connect(func() -> void:
                if controller != null and controller.has_method("equip"):
                    controller.call("equip", weapon_id)
                _refresh())
        else:
            button = UIStyle.make_button(Loc.t("equipped") if equipped else Loc.t("owned"), false, Vector2(0, 56))
            button.disabled = true
    else:
        button = UIStyle.make_button("%s  —  %d" % [Loc.t("buy"), price], true, Vector2(0, 56))
        button.disabled = SaveManager.get_credits() < price
        button.pressed.connect(func() -> void:
            if ShopCatalog.buy_weapon(weapon_id, _player):
                _play_buy()
            _refresh())
    inner.add_child(button)
    return _add_card(inner)

func _supply_card(item_id: String) -> Control:
    var inner := _card()
    var item: Dictionary = ShopCatalog.SUPPLIES[item_id]
    var color := Color(str(item["color"]))
    var swatch := ColorRect.new()
    swatch.color = color
    swatch.custom_minimum_size = Vector2(0, 14)
    inner.add_child(swatch)
    inner.add_child(UIStyle.make_label(ShopCatalog.supply_name(item_id, _language()), 26, color.lightened(0.2)))
    var desc := UIStyle.make_label(ShopCatalog.supply_desc(item_id, _language()), 17, UIStyle.COLOR_TEXT_DIM)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.custom_minimum_size = Vector2(200, 0)
    inner.add_child(desc)
    inner.add_child(UIStyle.make_label("%s: %d" % [Loc.t("owned_count"), SaveManager.get_inventory(item_id)], 18, UIStyle.COLOR_TEXT))
    var price: int = int(item["price"])
    var button := UIStyle.make_button("%s  —  %d" % [Loc.t("buy"), price], true, Vector2(0, 56))
    button.disabled = SaveManager.get_credits() < price
    button.pressed.connect(func() -> void:
        if ShopCatalog.buy_supply(item_id):
            _play_buy()
        _refresh())
    inner.add_child(button)
    if _player != null and SaveManager.get_inventory(item_id) > 0:
        var use_button := UIStyle.make_button(Loc.t("use_now"), false, Vector2(0, 50))
        use_button.pressed.connect(func() -> void:
            ShopCatalog.use_supply(item_id, _player)
            _refresh())
        inner.add_child(use_button)
    return _add_card(inner)

func _upgrade_card(upgrade_id: String) -> Control:
    var inner := _card()
    var item: Dictionary = ShopCatalog.UPGRADES[upgrade_id]
    var color := Color(str(item["color"]))
    var level: int = SaveManager.get_upgrade_level(upgrade_id)
    var max_level: int = ShopCatalog.upgrade_max_level(upgrade_id)
    inner.add_child(UIStyle.make_label(ShopCatalog.upgrade_name(upgrade_id, _language()), 26, color.lightened(0.2)))
    var pips: String = ""
    for index in range(max_level):
        pips += "●  " if index < level else "○  "
    inner.add_child(UIStyle.make_label(pips, 24, color))
    var desc := UIStyle.make_label(ShopCatalog.upgrade_desc(upgrade_id, _language()), 17, UIStyle.COLOR_TEXT_DIM)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.custom_minimum_size = Vector2(200, 0)
    inner.add_child(desc)
    var cost: int = ShopCatalog.upgrade_next_cost(upgrade_id)
    var button: Button
    if cost < 0:
        button = UIStyle.make_button(Loc.t("max_level"), false, Vector2(0, 56))
        button.disabled = true
    else:
        button = UIStyle.make_button("%s  —  %d" % [Loc.t("upgrade"), cost], true, Vector2(0, 56))
        button.disabled = SaveManager.get_credits() < cost
        button.pressed.connect(func() -> void:
            if ShopCatalog.buy_upgrade(upgrade_id):
                _play_buy()
                _apply_upgrade_live(upgrade_id)
            _refresh())
    inner.add_child(button)
    return _add_card(inner)

func _apply_upgrade_live(upgrade_id: String) -> void:
    if _player == null:
        return
    var health := _player.get_node_or_null("HealthComponent") as HealthComponent
    if upgrade_id == "health" and health != null:
        health.max_health += 25.0
        health.restore(25.0)

func _play_buy() -> void:
    _sfx.stream = WeaponAudio.get_stream("buy")
    _sfx.volume_db = -4.0
    _sfx.play()
