extends InteractableBase
class_name WeaponShop

## A weapon kiosk placed at a fixed spot on a map. It sells a fixed list of guns for credits.
## Guns bought here belong to the current match only (they are not saved to the permanent
## arsenal), so e.g. the Tesla gun can only be had on the zombie map.

var stock: Array[String] = []
var title: String = "Weapon shop"
var accent: Color = Color("#ffb04a")
var _layer: CanvasLayer
var _list: VBoxContainer
var _credits_label: Label
var _player: Node
var _was_paused: bool = false
var _label: Label3D

func _ready() -> void:
    interaction_text = Loc.t("weapon_shop_prompt")
    collision_layer = 3
    collision_mask = 0
    _build_visual()
    interacted.connect(_on_interacted)

func _build_visual() -> void:
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(3.2, 1.2, 1.0)
    shape_node.shape = shape
    shape_node.position = Vector3(0.0, 0.6, 0.0)
    add_child(shape_node)
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color("#16191c")
    dark.metallic = 0.6
    dark.roughness = 0.5
    var glow := StandardMaterial3D.new()
    glow.albedo_color = accent
    glow.emission_enabled = true
    glow.emission = accent
    glow.emission_energy_multiplier = 2.2
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var counter := MeshInstance3D.new()
    var counter_mesh := BoxMesh.new()
    counter_mesh.size = Vector3(3.2, 1.2, 1.0)
    counter.mesh = counter_mesh
    counter.material_override = dark
    counter.position = Vector3(0.0, 0.6, 0.0)
    add_child(counter)
    var rack := MeshInstance3D.new()
    var rack_mesh := BoxMesh.new()
    rack_mesh.size = Vector3(3.0, 1.8, 0.2)
    rack.mesh = rack_mesh
    rack.material_override = dark
    rack.position = Vector3(0.0, 2.1, 0.55)
    add_child(rack)
    for index in range(maxi(stock.size(), 1)):
        var bar := MeshInstance3D.new()
        var bar_mesh := BoxMesh.new()
        bar_mesh.size = Vector3(0.9, 0.08, 0.08)
        bar.mesh = bar_mesh
        bar.material_override = glow
        bar.position = Vector3(-1.0 + float(index) * 1.0, 2.4 - float(index % 2) * 0.5, 0.42)
        add_child(bar)
    var strip := MeshInstance3D.new()
    var strip_mesh := BoxMesh.new()
    strip_mesh.size = Vector3(3.2, 0.08, 0.08)
    strip.mesh = strip_mesh
    strip.material_override = glow
    strip.position = Vector3(0.0, 1.22, -0.45)
    add_child(strip)
    _label = Label3D.new()
    _label.text = title
    _label.font_size = 72
    _label.pixel_size = 0.01
    _label.modulate = accent
    _label.outline_size = 12
    _label.position = Vector3(0.0, 3.4, 0.6)
    add_child(_label)
    var light := OmniLight3D.new()
    light.light_color = accent
    light.light_energy = 1.6
    light.omni_range = 11.0
    light.position = Vector3(0.0, 2.6, -1.2)
    light.shadow_enabled = false
    light.add_to_group("no_shadow")
    add_child(light)

func _on_interacted(actor: Node) -> void:
    if _layer != null:
        return
    _player = actor
    _was_paused = get_tree().paused
    _layer = CanvasLayer.new()
    _layer.layer = 41
    _layer.process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().root.add_child(_layer)
    var root := Control.new()
    root.theme = UIStyle.get_theme()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
    _layer.add_child(root)
    var dim := ColorRect.new()
    dim.color = Color(0.01, 0.02, 0.03, 0.9)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 18)
    root.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 14)
    column.add_child(header)
    var title_label := UIStyle.make_label("%s — %s" % [Loc.t("weapon_shop"), title], 34, accent)
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_label)
    _credits_label = UIStyle.make_label("", 26, Color("#ffe08a"))
    header.add_child(_credits_label)
    var close_button := UIStyle.make_button(Loc.t("back"), false, Vector2(150, 56))
    close_button.pressed.connect(_close)
    header.add_child(close_button)
    var scroll := TouchScroll.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    _list = VBoxContainer.new()
    _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list.add_theme_constant_override("separation", 10)
    scroll.add_child(_list)
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _refresh()

func _owned_now(weapon_id: String) -> bool:
    var controller := _player.get_node_or_null("WeaponController")
    if controller != null and controller.has_method("get_weapon_ids"):
        return (controller.call("get_weapon_ids") as Array).has(weapon_id)
    return SaveManager.owns_weapon(weapon_id)

func _refresh() -> void:
    _credits_label.text = "%s: %d" % [Loc.t("credits"), SaveManager.get_credits()]
    for child in _list.get_children():
        child.queue_free()
    var language: String = "fa" if Loc.language == "fa" else "en"
    for weapon_id in stock:
        var def: Dictionary = WeaponDefinitions.get_definition(weapon_id)
        var panel := PanelContainer.new()
        panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.COLOR_PANEL_LIGHT, WeaponDefinitions.get_accent(weapon_id), 18, 2))
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 14)
        panel.add_child(row)
        var info := VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(info)
        info.add_child(UIStyle.make_label(WeaponDefinitions.get_display_name(weapon_id, language), 28, WeaponDefinitions.get_accent(weapon_id)))
        var description := UIStyle.make_label(str(def.get("description_" + language, "")), 17, UIStyle.COLOR_TEXT_DIM)
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        info.add_child(description)
        info.add_child(UIStyle.make_label("%d / %d" % [int(def["magazine_size"]), int(def["reserve_ammo"])], 17, UIStyle.COLOR_TEXT_DIM))
        var owned: bool = _owned_now(weapon_id)
        var price: int = int(def.get("price", 0))
        var button := UIStyle.make_button(Loc.t("owned") if owned else "%s  %d" % [Loc.t("buy"), price], not owned, Vector2(190, 70))
        button.disabled = owned or SaveManager.get_credits() < price
        var chosen: String = weapon_id
        button.pressed.connect(func() -> void: _buy(chosen))
        row.add_child(button)
        _list.add_child(panel)

func _buy(weapon_id: String) -> void:
    if _owned_now(weapon_id):
        return
    var price: int = WeaponDefinitions.get_price(weapon_id)
    if not SaveManager.spend_credits(price):
        return
    var controller := _player.get_node_or_null("WeaponController")
    if controller != null and controller.has_method("add_weapon"):
        controller.call("add_weapon", weapon_id, true)
    SaveManager.flush()
    _refresh()

func _close() -> void:
    if _layer == null:
        return
    _layer.queue_free()
    _layer = null
    get_tree().paused = _was_paused
    if not _was_paused and not (OS.has_feature("android") or OS.has_feature("ios")):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
    if _layer != null:
        _layer.queue_free()
        _layer = null
