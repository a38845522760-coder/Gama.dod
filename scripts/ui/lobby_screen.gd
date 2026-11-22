extends Control
class_name LobbyScreen

## LAN lobby: make a room (host) or find / join one (guest), then start the match together.
## Works over a phone hotspot or any shared Wi-Fi.

signal closed

var _dynamic: VBoxContainer
var _status: Label
var _name_edit: LineEdit
var _ip_text: String = ""

func _ready() -> void:
    theme = UIStyle.get_theme()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.06, 0.97)
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
    var title := UIStyle.make_label(Loc.t("multiplayer"), 38, UIStyle.COLOR_ACCENT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var back := UIStyle.make_button(Loc.t("back"), false, Vector2(150, 56))
    back.pressed.connect(_on_back)
    header.add_child(back)

    var name_row := HBoxContainer.new()
    name_row.add_theme_constant_override("separation", 8)
    column.add_child(name_row)
    name_row.add_child(UIStyle.make_label(Loc.t("mp_your_name"), 22, UIStyle.COLOR_TEXT_DIM))
    _name_edit = LineEdit.new()
    _name_edit.text = NetGame.local_name
    _name_edit.max_length = 14
    _name_edit.custom_minimum_size = Vector2(240, 52)
    _name_edit.text_changed.connect(func(value: String) -> void: NetGame.set_local_name(value))
    name_row.add_child(_name_edit)

    var hint := UIStyle.make_label(Loc.t("mp_hint"), 18, UIStyle.COLOR_TEXT_DIM)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(hint)
    _status = UIStyle.make_label("", 22, UIStyle.COLOR_CYAN)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_status)

    var scroll := TouchScroll.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    _dynamic = VBoxContainer.new()
    _dynamic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _dynamic.add_theme_constant_override("separation", 10)
    scroll.add_child(_dynamic)

    NetGame.lobby_changed.connect(_rebuild)
    NetGame.rooms_changed.connect(_rebuild)
    NetGame.status_changed.connect(_on_status)
    if NetGame.role == "offline":
        NetGame.start_search()
    _on_status(NetGame.status_text)
    _rebuild()

func _exit_tree() -> void:
    if NetGame.lobby_changed.is_connected(_rebuild):
        NetGame.lobby_changed.disconnect(_rebuild)
    if NetGame.rooms_changed.is_connected(_rebuild):
        NetGame.rooms_changed.disconnect(_rebuild)
    if NetGame.status_changed.is_connected(_on_status):
        NetGame.status_changed.disconnect(_on_status)
    if not NetGame.match_running:
        NetGame.stop_search()

func _on_status(text: String) -> void:
    if _status != null:
        _status.text = text

func _on_back() -> void:
    if not NetGame.match_running:
        NetGame.leave(false)
    closed.emit()

func _rebuild() -> void:
    if _dynamic == null:
        return
    for child in _dynamic.get_children():
        child.queue_free()
    match NetGame.role:
        "host":
            _build_host()
        "guest":
            _build_guest()
        _:
            _build_offline()

func _build_offline() -> void:
    var host_button := UIStyle.make_button(Loc.t("mp_host"), true, Vector2(0, 72))
    host_button.pressed.connect(func() -> void:
        NetGame.stop_search()
        NetGame.host_room())
    _dynamic.add_child(host_button)

    _dynamic.add_child(UIStyle.make_label(Loc.t("mp_rooms_found"), 22, UIStyle.COLOR_TEXT_DIM))
    if NetGame.rooms.is_empty():
        _dynamic.add_child(UIStyle.make_label(Loc.t("mp_no_rooms"), 20, UIStyle.COLOR_TEXT_DIM))
    for ip in NetGame.rooms.keys():
        var room: Dictionary = NetGame.rooms[ip]
        var label: String = "%s   —   %s   (%d)" % [str(room["name"]), Loc.t("mode_" + str(room["mode"])), int(room["players"])]
        var room_button := UIStyle.make_button(label, false, Vector2(0, 64))
        var address: String = str(ip)
        room_button.pressed.connect(func() -> void: NetGame.join_room(address))
        _dynamic.add_child(room_button)

    _dynamic.add_child(UIStyle.make_label(Loc.t("mp_enter_ip"), 22, UIStyle.COLOR_TEXT_DIM))
    var ip_row := HBoxContainer.new()
    ip_row.add_theme_constant_override("separation", 8)
    _dynamic.add_child(ip_row)
    var ip_edit := LineEdit.new()
    ip_edit.placeholder_text = "192.168.43.1"
    ip_edit.text = _ip_text
    ip_edit.custom_minimum_size = Vector2(0, 56)
    ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ip_edit.text_changed.connect(func(value: String) -> void: _ip_text = value)
    ip_row.add_child(ip_edit)
    var connect_button := UIStyle.make_button(Loc.t("mp_connect"), false, Vector2(150, 56))
    connect_button.pressed.connect(func() -> void:
        NetGame.stop_search()
        NetGame.join_room(_ip_text))
    ip_row.add_child(connect_button)

func _build_host() -> void:
    var addresses: PackedStringArray = NetGame.local_addresses()
    var ip_text: String = ", ".join(addresses) if not addresses.is_empty() else "—"
    var ip_label := UIStyle.make_label("%s: %s" % [Loc.t("mp_your_ip"), ip_text], 22, UIStyle.COLOR_ACCENT)
    ip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _dynamic.add_child(ip_label)
    var mode_label := UIStyle.make_label("%s: %s" % [Loc.t("choose_mode"), Loc.t("mode_" + AppState.pending_mode)], 20, UIStyle.COLOR_TEXT_DIM)
    _dynamic.add_child(mode_label)
    _add_players()
    var start := UIStyle.make_button(Loc.t("mp_start"), true, Vector2(0, 76))
    start.add_theme_font_size_override("font_size", 30)
    start.pressed.connect(func() -> void: NetGame.start_match())
    _dynamic.add_child(start)
    var close_button := UIStyle.make_button(Loc.t("mp_close_room"), false, Vector2(0, 60))
    UIStyle.style_danger(close_button)
    close_button.pressed.connect(func() -> void: NetGame.leave(false))
    _dynamic.add_child(close_button)

func _build_guest() -> void:
    _add_players()
    _dynamic.add_child(UIStyle.make_label(Loc.t("mp_waiting_host"), 22, UIStyle.COLOR_CYAN))
    var leave_button := UIStyle.make_button(Loc.t("mp_leave"), false, Vector2(0, 60))
    UIStyle.style_danger(leave_button)
    leave_button.pressed.connect(func() -> void: NetGame.leave(false))
    _dynamic.add_child(leave_button)

func _add_players() -> void:
    _dynamic.add_child(UIStyle.make_label(Loc.t("mp_players"), 22, UIStyle.COLOR_TEXT_DIM))
    for id in NetGame.players.keys():
        var line: String = str(NetGame.players[id])
        if int(id) == 1:
            line += "   (" + Loc.t("mp_host_tag") + ")"
        _dynamic.add_child(UIStyle.make_label("•  " + line, 24, UIStyle.COLOR_TEXT))
