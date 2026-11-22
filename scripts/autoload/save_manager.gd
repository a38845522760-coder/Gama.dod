extends Node

## Versioned, crash-safe save system: atomic writes, automatic .bak recovery,
## schema migration, debounced autosave and flush on pause/quit.

signal save_loaded(data: Dictionary)
signal save_written(data: Dictionary)
signal save_failed(error_code: int)
signal data_changed(data: Dictionary)

const SAVE_PATH := "user://iron_yard_save.json"
const SAVE_VERSION: int = 3
const AUTOSAVE_DELAY: float = 6.0

const DEFAULT_SAVE_DATA: Dictionary = {
    "credits": 0,
    "lifetime_score": 0,
    "best_score": 0,
    "unlocks": [],
    "statistics": {"kills": 0, "headshots": 0, "deaths": 0, "shots_fired": 0, "shots_hit": 0, "play_seconds": 0},
    "progress": {"last_map": "core_test_arena", "last_mode": "training", "matches_played": 0},
    "equipment": {"owned": ["pistol", "rifle"], "selected": "rifle"},
    "inventory": {"medkit": 0, "armor": 0, "ammo": 0},
    "upgrades": {"health": 0, "damage": 0, "armor": 0},
}
const PROTECTED_KEYS: Array[String] = ["schema_version", "data"]

var _data: Dictionary = {}
var _dirty: bool = false
var _autosave_left: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _data = _make_default()
    var error := load_game()
    if error != OK:
        push_warning("Save could not be loaded; a fresh save is active. Error: %s" % error)
    set_process(false)

func get_save_data() -> Dictionary:
    return _data.duplicate(true)

func get_value(key: String, fallback: Variant = null) -> Variant:
    return _data.get(key, fallback)

func set_value(key: String, value: Variant, save_now: bool = false) -> bool:
    if key.is_empty() or PROTECTED_KEYS.has(key):
        return false
    _data[key] = value
    _mark_dirty()
    if save_now:
        return flush() == OK
    return true

func get_credits() -> int:
    return int(_data.get("credits", 0))

func add_credits(amount: int) -> int:
    if amount == 0:
        return get_credits()
    _data["credits"] = maxi(0, get_credits() + amount)
    EventBus.currency_changed.emit("local", get_credits())
    _mark_dirty()
    return get_credits()

func spend_credits(amount: int) -> bool:
    if amount <= 0 or get_credits() < amount:
        return false
    add_credits(-amount)
    return true

func add_score(amount: int) -> int:
    if amount <= 0:
        return int(_data.get("lifetime_score", 0))
    _data["lifetime_score"] = int(_data.get("lifetime_score", 0)) + amount
    _mark_dirty()
    return int(_data["lifetime_score"])

func record_best_score(score: int) -> void:
    if score > int(_data.get("best_score", 0)):
        _data["best_score"] = score
        _mark_dirty()

func increment_stat(stat_name: String, amount: int = 1) -> void:
    var stats: Dictionary = _data.get("statistics", {})
    stats[stat_name] = int(stats.get(stat_name, 0)) + amount
    _data["statistics"] = stats
    _mark_dirty()

func get_stat(stat_name: String) -> int:
    var stats: Dictionary = _data.get("statistics", {})
    return int(stats.get(stat_name, 0))

func set_progress(key: String, value: Variant) -> void:
    var progress: Dictionary = _data.get("progress", {})
    progress[key] = value
    _data["progress"] = progress
    _mark_dirty()

func get_progress(key: String, fallback: Variant = null) -> Variant:
    var progress: Dictionary = _data.get("progress", {})
    return progress.get(key, fallback)

# ---------------------------------------------------------------- equipment / shop

func get_owned_weapons() -> Array[String]:
    var equipment: Dictionary = _data.get("equipment", {})
    var owned_raw: Array = equipment.get("owned", [])
    var result: Array[String] = []
    # Keep the canonical display order so the weapon bar is stable.
    for weapon_id in WeaponDefinitions.ORDER:
        if owned_raw.has(weapon_id):
            result.append(weapon_id)
    if result.is_empty():
        result.append("rifle")
    return result

func owns_weapon(weapon_id: String) -> bool:
    return get_owned_weapons().has(weapon_id)

func add_weapon(weapon_id: String) -> void:
    if not WeaponDefinitions.exists(weapon_id) or owns_weapon(weapon_id):
        return
    var equipment: Dictionary = _data.get("equipment", {})
    var owned_raw: Array = equipment.get("owned", [])
    owned_raw.append(weapon_id)
    equipment["owned"] = owned_raw
    _data["equipment"] = equipment
    _mark_dirty()

func get_selected_weapon() -> String:
    var equipment: Dictionary = _data.get("equipment", {})
    var selected := str(equipment.get("selected", "rifle"))
    if owns_weapon(selected):
        return selected
    return get_owned_weapons()[0]

func set_selected_weapon(weapon_id: String) -> void:
    if not owns_weapon(weapon_id):
        return
    var equipment: Dictionary = _data.get("equipment", {})
    equipment["selected"] = weapon_id
    _data["equipment"] = equipment
    _mark_dirty()

func get_inventory(item_id: String) -> int:
    var inventory: Dictionary = _data.get("inventory", {})
    return int(inventory.get(item_id, 0))

func add_inventory(item_id: String, amount: int = 1) -> void:
    var inventory: Dictionary = _data.get("inventory", {})
    inventory[item_id] = maxi(0, int(inventory.get(item_id, 0)) + amount)
    _data["inventory"] = inventory
    _mark_dirty()

func use_inventory(item_id: String) -> bool:
    if get_inventory(item_id) <= 0:
        return false
    add_inventory(item_id, -1)
    return true

func get_upgrade_level(upgrade_id: String) -> int:
    var upgrades: Dictionary = _data.get("upgrades", {})
    return int(upgrades.get(upgrade_id, 0))

func set_upgrade_level(upgrade_id: String, level: int) -> void:
    var upgrades: Dictionary = _data.get("upgrades", {})
    upgrades[upgrade_id] = maxi(0, level)
    _data["upgrades"] = upgrades
    _mark_dirty()

func reset_progress() -> void:
    _data = _make_default()
    _mark_dirty()
    flush()

func load_game() -> Error:
    var parsed: Dictionary = _read_file(SAVE_PATH)
    var from_backup := false
    if parsed.is_empty():
        parsed = _read_file(SAVE_PATH + ".bak")
        from_backup = not parsed.is_empty()
    if parsed.is_empty():
        if FileAccess.file_exists(SAVE_PATH):
            # Unreadable file: keep it for inspection instead of silently destroying it.
            FileUtil.rename_file(SAVE_PATH, SAVE_PATH + ".corrupt")
            _data = _make_default()
            save_loaded.emit(_data.duplicate(true))
            return ERR_FILE_CORRUPT
        _data = _make_default()
        save_loaded.emit(_data.duplicate(true))
        return OK
    _data = _migrate(parsed)
    if from_backup:
        push_warning("Main save was damaged; recovered from backup.")
        _mark_dirty()
    save_loaded.emit(_data.duplicate(true))
    return OK

func save_game() -> Error:
    return flush()

func flush() -> Error:
    _dirty = false
    set_process(false)
    var payload: Dictionary = _data.duplicate(true)
    payload["schema_version"] = SAVE_VERSION
    var error := FileUtil.write_text_atomic(SAVE_PATH, JSON.stringify(payload, "  "))
    if error != OK:
        push_warning("Save write failed: %s" % error)
        save_failed.emit(int(error))
        _dirty = true
        return error
    save_written.emit(_data.duplicate(true))
    return OK

func _mark_dirty() -> void:
    _dirty = true
    _autosave_left = AUTOSAVE_DELAY
    set_process(true)
    data_changed.emit(_data)

func _process(delta: float) -> void:
    if not _dirty:
        set_process(false)
        return
    _autosave_left -= delta
    if _autosave_left <= 0.0:
        flush()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        if _dirty:
            flush()

func _make_default() -> Dictionary:
    return DEFAULT_SAVE_DATA.duplicate(true)

func _read_file(path: String) -> Dictionary:
    var text := FileUtil.read_text(path)
    if text.is_empty():
        return {}
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed

func _migrate(raw: Dictionary) -> Dictionary:
    var version: int = int(raw.get("schema_version", 1))
    var result: Dictionary = raw.duplicate(true)
    if version < 2:
        # v1 only stored a few flat keys; v2 introduces statistics, progress and equipment.
        if result.has("score") and not result.has("lifetime_score"):
            result["lifetime_score"] = int(result["score"])
    if version < 3:
        # v3 adds the shop: every player starts with the pistol next to the rifle.
        var equipment_v2: Dictionary = result.get("equipment", {})
        var owned_v2: Array = equipment_v2.get("owned", ["rifle"])
        if not owned_v2.has("pistol"):
            owned_v2.append("pistol")
        equipment_v2["owned"] = owned_v2
        result["equipment"] = equipment_v2
    # Fill any missing key from defaults (also protects against partial files).
    for key in DEFAULT_SAVE_DATA.keys():
        var default_value: Variant = DEFAULT_SAVE_DATA[key]
        if not result.has(key):
            result[key] = default_value.duplicate(true) if (default_value is Dictionary or default_value is Array) else default_value
        elif default_value is Dictionary and result[key] is Dictionary:
            for sub_key in default_value.keys():
                if not (result[key] as Dictionary).has(sub_key):
                    (result[key] as Dictionary)[sub_key] = default_value[sub_key]
    result.erase("schema_version")
    return result
