extends CanvasLayer
class_name ArsenalHUD

## In-match controls for the loadout: weapon bar (tap or press 1-7 / F / mouse wheel),
## quick-use supplies (H medkit, J armor plate, K ammo pack) and the shop (B).
## On phones the supplies and shop are round touch buttons on the left edge.

const BUTTON_SCRIPT := preload("res://scripts/input/touch_button.gd")
const SUPPLY_KEYS: Array[String] = ["medkit", "armor", "ammo"]

var _player: Node
var _weapon: Node
var _root: Control
var _bar: HBoxContainer
var _slots: Array[WeaponSlot] = []
var _quick_buttons: Dictionary = {}
var _count_labels: Dictionary = {}
var _shop_layer: CanvasLayer
var _shop: ShopScreen
var _shop_was_paused: bool = false
var _refresh_left: float = 0.0
var _is_mobile: bool = false

static func attach(parent: Node) -> ArsenalHUD:
    var hud := ArsenalHUD.new()
    hud.name = "ArsenalHUD"
    parent.add_child(hud)
    return hud

func _ready() -> void:
    layer = 12
    _is_mobile = OS.has_feature("android") or OS.has_feature("ios")
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.layout_direction = Control.LAYOUT_DIRECTION_LTR
    add_child(_root)
    _bar = HBoxContainer.new()
    _bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _bar.add_theme_constant_override("separation", 6)
    _bar.anchor_left = 0.5
    _bar.anchor_right = 0.5
    _bar.offset_top = 8.0
    _bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _root.add_child(_bar)
    if _is_mobile:
        _build_quick_buttons()
        get_viewport().size_changed.connect(_layout_quick_buttons)
    EventBus.shop_requested.connect(open_shop)
    call_deferred("_find_nodes")

func _exit_tree() -> void:
    if EventBus.shop_requested.is_connected(open_shop):
        EventBus.shop_requested.disconnect(open_shop)

func _find_nodes() -> void:
    var players := get_tree().get_nodes_in_group("player_controller")
    if not players.is_empty():
        _player = players[0]
    var weapons := get_tree().get_nodes_in_group("weapon_controller")
    if not weapons.is_empty():
        _weapon = weapons[0]
        _weapon.connect("loadout_changed", Callable(self, "_rebuild_slots"))
        _weapon.connect("weapon_changed", Callable(self, "_on_weapon_changed"))
    _rebuild_slots()

func _rebuild_slots() -> void:
    for child in _bar.get_children():
        child.queue_free()
    _slots.clear()
    if _weapon == null or not is_instance_valid(_weapon):
        return
    var ids: Array = _weapon.call("get_weapon_ids")
    var current: String = str(_weapon.call("get_weapon_id"))
    var number: int = 1
    for id in ids:
        var slot := WeaponSlot.new()
        slot.weapon_id = str(id)
        slot.slot_number = number
        slot.selected = str(id) == current
        slot.chosen.connect(_on_slot_chosen)
        _bar.add_child(slot)
        _slots.append(slot)
        number += 1
    _refresh_ammo()

func _on_weapon_changed(_id: String, _name: String) -> void:
    var current: String = str(_weapon.call("get_weapon_id"))
    for slot in _slots:
        slot.selected = slot.weapon_id == current

func _on_slot_chosen(id: String) -> void:
    if _weapon != null and is_instance_valid(_weapon):
        _weapon.call("equip", id)

func _refresh_ammo() -> void:
    if _weapon == null or not is_instance_valid(_weapon):
        return
    for slot in _slots:
        var ammo: Vector2i = _weapon.call("get_ammo_for", slot.weapon_id)
        slot.set_ammo_text("%d/%d" % [ammo.x, ammo.y])
    for key in _count_labels.keys():
        (_count_labels[key] as Label).text = str(SaveManager.get_inventory(str(key)))

func _process(delta: float) -> void:
    _refresh_left -= delta
    if _refresh_left <= 0.0:
        _refresh_left = 0.2
        _refresh_ammo()

# ---------------------------------------------------------------- touch quick buttons

func _build_quick_buttons() -> void:
    var specs: Array = [["medkit", "medkit", Color("#3ddc84")], ["armor", "armor", Color("#44b5ee")], ["ammo", "ammo", Color("#ffc94a")], ["shop", "shop", Color("#ffd166")]]
    for spec in specs:
        var key: String = str((spec as Array)[0])
        var button: TouchButton = BUTTON_SCRIPT.new()
        button.name = "Quick_" + key
        button.icon_kind = str((spec as Array)[1])
        button.tint = (spec as Array)[2]
        button.haptic_ms = 8
        button.set_radius(30.0)
        button.opacity = 0.85
        _root.add_child(button)
        _quick_buttons[key] = button
        button.tapped.connect(_on_quick_tapped.bind(key))
        if key != "shop":
            var count := UIStyle.make_label("0", 16, Color.WHITE)
            count.mouse_filter = Control.MOUSE_FILTER_IGNORE
            count.add_theme_color_override("font_outline_color", Color.BLACK)
            count.add_theme_constant_override("outline_size", 4)
            _root.add_child(count)
            _count_labels[key] = count
    _layout_quick_buttons()

func _layout_quick_buttons() -> void:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var index: int = 0
    for key in ["medkit", "armor", "ammo", "shop"]:
        if not _quick_buttons.has(key):
            continue
        var button: TouchButton = _quick_buttons[key]
        var center := Vector2(52.0, viewport_size.y * 0.26 + float(index) * 76.0)
        button.position = center - button.size * 0.5
        if _count_labels.has(key):
            (_count_labels[key] as Label).position = center + Vector2(14.0, 10.0)
        index += 1

func _on_quick_tapped(key: String) -> void:
    if key == "shop":
        open_shop()
    else:
        use_supply(key)

# ---------------------------------------------------------------- keyboard

func _unhandled_input(event: InputEvent) -> void:
    if _player == null:
        return
    if InputMap.has_action("use_medkit") and event.is_action_pressed("use_medkit"):
        use_supply("medkit")
    elif InputMap.has_action("use_armor") and event.is_action_pressed("use_armor"):
        use_supply("armor")
    elif InputMap.has_action("use_ammo") and event.is_action_pressed("use_ammo"):
        use_supply("ammo")
    elif InputMap.has_action("open_shop") and event.is_action_pressed("open_shop"):
        open_shop()

func use_supply(item_id: String) -> void:
    if ShopCatalog.use_supply(item_id, _player):
        var sound := AudioStreamPlayer.new()
        sound.stream = WeaponAudio.get_stream("pickup")
        sound.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
        add_child(sound)
        sound.finished.connect(sound.queue_free)
        sound.play()
        _refresh_ammo()

# ---------------------------------------------------------------- shop

func open_shop() -> void:
    if _shop != null:
        return
    _shop_was_paused = get_tree().paused
    _shop_layer = CanvasLayer.new()
    _shop_layer.layer = 40
    _shop_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_shop_layer)
    _shop = ShopScreen.new()
    _shop.setup(_player)
    _shop.closed.connect(close_shop)
    _shop_layer.add_child(_shop)
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_shop() -> void:
    if _shop == null:
        return
    _shop_layer.queue_free()
    _shop_layer = null
    _shop = null
    get_tree().paused = _shop_was_paused
    if not _shop_was_paused and not _is_mobile:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _refresh_ammo()
