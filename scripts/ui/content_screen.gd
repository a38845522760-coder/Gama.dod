extends Control
class_name ContentScreen

## "Content" page: browse and download maps, weapons and characters (see ContentManager).
## Built in code like SettingsScreen so it rebuilds when the language changes.

signal closed

const TABS: Array[String] = ["map", "weapon", "character", "other", "import"]
const TAB_LABELS: Dictionary = {
    "map": "content_maps", "weapon": "content_weapons", "character": "content_characters",
    "other": "content_other", "import": "content_import"}

var _tab_index: int = 0
var _list: VBoxContainer
var _status_label: Label
var _tab_buttons: Array[Button] = []
var _bars: Dictionary = {}
var _error_text: String = ""
var _file_dialog: FileDialog = null

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    theme = UIStyle.get_theme()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    Loc.language_changed.connect(_on_language_changed)
    ContentManager.manifest_loaded.connect(_on_manifest_loaded)
    ContentManager.manifest_failed.connect(_on_manifest_failed)
    ContentManager.pack_progress.connect(_on_pack_progress)
    ContentManager.pack_installed.connect(_on_pack_changed)
    ContentManager.pack_removed.connect(_on_pack_changed)
    ContentManager.pack_failed.connect(_on_pack_failed)
    _build()
    ContentManager.refresh_manifest()

func _exit_tree() -> void:
    _disconnect(Loc.language_changed, _on_language_changed)
    _disconnect(ContentManager.manifest_loaded, _on_manifest_loaded)
    _disconnect(ContentManager.manifest_failed, _on_manifest_failed)
    _disconnect(ContentManager.pack_progress, _on_pack_progress)
    _disconnect(ContentManager.pack_installed, _on_pack_changed)
    _disconnect(ContentManager.pack_removed, _on_pack_changed)
    _disconnect(ContentManager.pack_failed, _on_pack_failed)

func _disconnect(source: Signal, target: Callable) -> void:
    if source.is_connected(target):
        source.disconnect(target)

# ---- layout -------------------------------------------------------------------------------

func _build() -> void:
    for child in get_children():
        child.queue_free()
    _tab_buttons.clear()
    _bars.clear()
    Loc.apply_direction(self)

    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.06, 0.88)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(900, 620)
    center.add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    panel.add_child(column)

    var title := UIStyle.make_label(Loc.t("content"), 36, UIStyle.COLOR_ACCENT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)

    _status_label = UIStyle.make_label("", 20, UIStyle.COLOR_TEXT_DIM)
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_status_label)

    var tab_row := HBoxContainer.new()
    tab_row.add_theme_constant_override("separation", 12)
    column.add_child(tab_row)
    for index in range(TABS.size()):
        var tab_button := UIStyle.make_button(Loc.t(str(TAB_LABELS[TABS[index]])), false, Vector2(0, 58))
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

    _list = VBoxContainer.new()
    _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list.add_theme_constant_override("separation", 14)
    scroll.add_child(_list)

    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 14)
    column.add_child(footer)
    var refresh_button := UIStyle.make_button(Loc.t("content_refresh"), false, Vector2(0, 62))
    refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    refresh_button.pressed.connect(func() -> void:
        _error_text = ""
        ContentManager.refresh_manifest()
        _update_status())
    footer.add_child(refresh_button)
    var back_button := UIStyle.make_button(Loc.t("back"), true, Vector2(0, 62))
    back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back_button.pressed.connect(func() -> void: closed.emit())
    footer.add_child(back_button)

    _populate()
    _update_status()

func _select_tab(index: int) -> void:
    _tab_index = index
    for button_index in range(_tab_buttons.size()):
        _tab_buttons[button_index].button_pressed = button_index == index
    _populate()

func _populate() -> void:
    if _list == null:
        return
    for child in _list.get_children():
        child.queue_free()
    _bars.clear()
    if TABS[_tab_index] == "import":
        _populate_import()
        return
    var packs := ContentManager.get_packs_of_type(TABS[_tab_index])
    if packs.is_empty():
        var empty := UIStyle.make_label(Loc.t("content_empty"), 22, UIStyle.COLOR_TEXT_DIM)
        empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _list.add_child(empty)
        return
    for pack in packs:
        _list.add_child(_make_row(pack))

func _populate_import() -> void:
    var hint := UIStyle.make_label(Loc.t("content_import_hint"), 20, UIStyle.COLOR_TEXT_DIM)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _list.add_child(hint)

    var choose_button := UIStyle.make_button(Loc.t("content_choose_file"), true, Vector2(0, 70))
    choose_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choose_button.pressed.connect(_choose_file)
    _list.add_child(choose_button)

    var tools := HBoxContainer.new()
    tools.add_theme_constant_override("separation", 14)
    _list.add_child(tools)
    var access_button := UIStyle.make_button(Loc.t("content_allow_access"), false, Vector2(0, 62))
    access_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    access_button.pressed.connect(func() -> void:
        OS.request_permissions()
        _populate())
    tools.add_child(access_button)
    var rescan_button := UIStyle.make_button(Loc.t("content_rescan"), false, Vector2(0, 62))
    rescan_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rescan_button.pressed.connect(_populate)
    tools.add_child(rescan_button)

    var files := ContentManager.scan_phone_folder()
    if files.is_empty():
        var empty := UIStyle.make_label(Loc.t("content_import_empty"), 22, UIStyle.COLOR_TEXT_DIM)
        empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _list.add_child(empty)
        return
    for entry in files:
        _list.add_child(_make_import_row(entry))

func _choose_file() -> void:
    _error_text = ""
    if ContentManager.pick_file_to_import():
        return
    # No native picker on this device: fall back to Godot's own file dialog.
    if _file_dialog == null or not is_instance_valid(_file_dialog):
        _file_dialog = FileDialog.new()
        _file_dialog.access = FileDialog.ACCESS_FILESYSTEM
        _file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
        _file_dialog.filters = PackedStringArray(["*.pck, *.zip ; Iron Yard content"])
        _file_dialog.file_selected.connect(func(path: String) -> void:
            ContentManager.import_from_file(path)
            _populate())
        add_child(_file_dialog)
    _file_dialog.popup_centered_ratio(0.8)

func _make_import_row(entry: Dictionary) -> Control:
    var pack_id := str(entry["id"])
    var panel := PanelContainer.new()
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    panel.add_child(row)
    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 4)
    row.add_child(info)
    info.add_child(UIStyle.make_label(str(entry["file"]), 24))
    info.add_child(UIStyle.make_label(ContentCatalog.format_size(int(entry["size"])), 19, UIStyle.COLOR_TEXT_DIM))
    if ContentManager.get_status(pack_id) == "verifying":
        row.add_child(UIStyle.make_label(Loc.t("content_verifying"), 20, UIStyle.COLOR_CYAN))
    else:
        var import_button := UIStyle.make_button(Loc.t("content_import_btn"), true, Vector2(190, 62))
        var path := str(entry["path"])
        import_button.pressed.connect(func() -> void:
            _error_text = ""
            ContentManager.import_from_file(path)
            _populate())
        row.add_child(import_button)
    return panel

func _make_row(pack: Dictionary) -> Control:
    var pack_id := str(pack["id"])
    var status := ContentManager.get_status(pack_id)
    var size_bytes := int(pack.get("size", 0))

    var panel := PanelContainer.new()
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    panel.add_child(row)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 4)
    row.add_child(info)
    info.add_child(UIStyle.make_label(ContentCatalog.localized_name(pack, Loc.language), 26))
    var details := ContentCatalog.format_size(size_bytes)
    var mode_names: Array[String] = []
    for mode in (pack.get("modes", []) as Array):
        mode_names.append(Loc.t("content_mode_" + str(mode)))
    if not mode_names.is_empty():
        details += "  |  %s (%d)" % ["/".join(PackedStringArray(mode_names)), int(pack.get("max_players", 1))]
    var big := size_bytes >= ContentCatalog.BIG_DOWNLOAD_BYTES and status == "missing"
    if big:
        details += "  |  " + Loc.t("content_big_hint")
    info.add_child(UIStyle.make_label(details, 19, UIStyle.COLOR_ACCENT if big else UIStyle.COLOR_TEXT_DIM))

    match status:
        "downloading", "verifying":
            var bar := ProgressBar.new()
            bar.custom_minimum_size = Vector2(260, 34)
            bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            bar.max_value = 100.0
            bar.show_percentage = true
            bar.add_theme_stylebox_override("background", UIStyle.box(Color(0.16, 0.22, 0.27, 1.0), Color(0, 0, 0, 0), 10, 0))
            bar.add_theme_stylebox_override("fill", UIStyle.box(UIStyle.COLOR_ACCENT, Color(0, 0, 0, 0), 10, 0))
            var progress := ContentManager.get_progress(pack_id)
            bar.value = _percent(progress.x, progress.y)
            row.add_child(bar)
            _bars[pack_id] = bar
            if status == "downloading":
                var cancel := UIStyle.make_button(Loc.t("content_cancel"), false, Vector2(150, 62))
                cancel.pressed.connect(func() -> void: ContentManager.cancel_install(pack_id))
                row.add_child(cancel)
            else:
                row.add_child(UIStyle.make_label(Loc.t("content_verifying"), 20, UIStyle.COLOR_CYAN))
        "installed":
            if str(pack.get("type", "")) == "map":
                var play_button := UIStyle.make_button(Loc.t("content_play"), true, Vector2(150, 62))
                play_button.pressed.connect(func() -> void: _play_map(pack_id))
                row.add_child(play_button)
            var delete_button := UIStyle.make_button(Loc.t("content_delete"), false, Vector2(170, 62))
            UIStyle.style_danger(delete_button)
            delete_button.pressed.connect(func() -> void: ContentManager.remove_pack(pack_id))
            row.add_child(delete_button)
        "update":
            var update_button := UIStyle.make_button(Loc.t("content_update"), true, Vector2(190, 62))
            update_button.pressed.connect(func() -> void: _start_install(pack_id))
            row.add_child(update_button)
        _:
            var download_button := UIStyle.make_button(Loc.t("content_download"), true, Vector2(190, 62))
            download_button.pressed.connect(func() -> void: _start_install(pack_id))
            row.add_child(download_button)
    return panel

func _play_map(pack_id: String) -> void:
    if not PackMap.open(pack_id, get_tree()):
        _error_text = "%s: %s" % [Loc.t("content_failed"), pack_id]
        _update_status()

func _start_install(pack_id: String) -> void:
    _error_text = ""
    ContentManager.install_pack(pack_id)
    _populate()
    _update_status()

func _percent(received: int, total: int) -> float:
    if total <= 0:
        return 0.0
    return clampf(float(received) * 100.0 / float(total), 0.0, 100.0)

func _update_status() -> void:
    if _status_label == null:
        return
    var parts: Array[String] = []
    parts.append(Loc.t("content_online") if ContentManager.manifest_online else Loc.t("content_offline"))
    parts.append("%s: %s" % [Loc.t("content_installed_size"), ContentCatalog.format_size(ContentManager.get_total_installed_bytes())])
    if ContentManager.restart_required:
        parts.append(Loc.t("content_restart"))
    var text := "   |   ".join(PackedStringArray(parts))
    var color := UIStyle.COLOR_TEXT_DIM
    if not _error_text.is_empty():
        text += "\n" + _error_text
        color = UIStyle.COLOR_DANGER
    _status_label.text = text
    _status_label.add_theme_color_override("font_color", color)

# ---- ContentManager callbacks ---------------------------------------------------------------

func _on_language_changed(_language: String) -> void:
    _build()

func _on_manifest_loaded(_count: int) -> void:
    _populate()
    _update_status()

func _on_manifest_failed(reason: String) -> void:
    _error_text = "%s (%s)\n%s" % [Loc.t("content_failed"), reason, ContentManager.get_base_url()]
    _populate()
    _update_status()

func _on_pack_progress(pack_id: String, received: int, total: int) -> void:
    var bar: ProgressBar = _bars.get(pack_id)
    if bar != null and is_instance_valid(bar):
        bar.value = _percent(received, total)
    if total > 0 and received >= total:
        _populate()

func _on_pack_changed(_pack_id: String) -> void:
    _populate()
    _update_status()

func _on_pack_failed(pack_id: String, reason: String) -> void:
    if reason != "cancelled":
        _error_text = "%s: %s (%s)" % [Loc.t("content_failed"), pack_id, reason]
    _populate()
    _update_status()
