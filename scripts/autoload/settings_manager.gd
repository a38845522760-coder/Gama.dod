extends Node

## Validated application settings. Rendering changes are applied by PerformanceManager,
## audio buses are applied here, and language changes are picked up by Loc.

signal settings_changed(settings: Dictionary)

const SETTINGS_PATH := "user://iron_yard_settings.cfg"
const SAVE_DEBOUNCE: float = 0.5
const LANGUAGES: Array[String] = ["fa", "en"]
const DEFAULT_SETTINGS: Dictionary = {
    "quality_preset": "medium",
    "dynamic_quality": false,
    "fov": 82.0,
    "master_volume": 1.0,
    "music_volume": 0.8,
    "sfx_volume": 1.0,
    "look_sensitivity": 1.0,
    "touch_look_sensitivity": 1.0,
    "invert_y": false,
    "touch_scale": 1.0,
    "touch_opacity": 0.85,
    "haptics": true,
    "show_debug": false,
    "language": "fa",
}
const QUALITY_PROFILES: Dictionary = {
    "low": {"render_scale": 0.85, "shadow_tier": 0, "effects_density": 0.25, "texture_tier": 0, "msaa": 0},
    "medium": {"render_scale": 1.0, "shadow_tier": 1, "effects_density": 0.50, "texture_tier": 1, "msaa": 1},
    "high": {"render_scale": 1.0, "shadow_tier": 2, "effects_density": 0.80, "texture_tier": 2, "msaa": 2},
    "ultra": {"render_scale": 1.0, "shadow_tier": 3, "effects_density": 1.0, "texture_tier": 3, "msaa": 2},
}
const BUS_NAMES: Array[String] = ["Music", "SFX"]

var _settings: Dictionary = {}
var _save_left: float = 0.0
var _save_pending: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _settings = DEFAULT_SETTINGS.duplicate(true)
    var error := load_settings()
    if error != OK:
        push_warning("Settings could not be loaded; defaults remain active. Error: %s" % error)
    _ensure_audio_buses()
    apply_audio()
    set_process(false)

func get_settings() -> Dictionary:
    return _settings.duplicate(true)

func get_setting(key: String, fallback: Variant = null) -> Variant:
    return _settings.get(key, fallback)

func get_quality_preset() -> String:
    var preset := str(_settings.get("quality_preset", "medium"))
    return preset if QUALITY_PROFILES.has(preset) else "medium"

func get_quality_profile() -> Dictionary:
    return QUALITY_PROFILES[get_quality_preset()].duplicate(true)

func set_quality_preset(preset: String) -> bool:
    if not QUALITY_PROFILES.has(preset):
        return false
    _settings["quality_preset"] = preset
    _changed()
    return true

func set_setting(key: String, value: Variant) -> bool:
    if not DEFAULT_SETTINGS.has(key) or key == "quality_preset":
        return false
    var clean: Variant = _sanitize(key, value)
    if clean == null:
        return false
    _settings[key] = clean
    _changed()
    return true

func reset_to_defaults() -> void:
    var language := str(_settings.get("language", "fa"))
    _settings = DEFAULT_SETTINGS.duplicate(true)
    _settings["language"] = language
    _changed()

func save_settings() -> Error:
    _save_pending = false
    set_process(false)
    var config := ConfigFile.new()
    for key in _settings.keys():
        config.set_value("settings", str(key), _settings[key])
    return config.save(SETTINGS_PATH)

func load_settings() -> Error:
    var config := ConfigFile.new()
    var error := config.load(SETTINGS_PATH)
    if error == ERR_FILE_NOT_FOUND:
        return OK
    if error != OK:
        return error
    for key in DEFAULT_SETTINGS.keys():
        if config.has_section_key("settings", str(key)):
            var clean: Variant = _sanitize(str(key), config.get_value("settings", str(key)))
            if clean != null:
                _settings[key] = clean
    return OK

func apply_audio() -> void:
    _set_bus_volume("Master", float(_settings.get("master_volume", 1.0)))
    _set_bus_volume("Music", float(_settings.get("music_volume", 0.8)))
    _set_bus_volume("SFX", float(_settings.get("sfx_volume", 1.0)))

func _sanitize(key: String, value: Variant) -> Variant:
    match key:
        "quality_preset":
            var preset := str(value)
            return preset if QUALITY_PROFILES.has(preset) else null
        "language":
            var language := str(value)
            return language if LANGUAGES.has(language) else null
        "master_volume", "music_volume", "sfx_volume":
            return clampf(float(value), 0.0, 1.0)
        "look_sensitivity", "touch_look_sensitivity":
            return clampf(float(value), 0.1, 3.0)
        "fov":
            return clampf(float(value), 60.0, 110.0)
        "touch_scale":
            return clampf(float(value), 0.7, 1.5)
        "touch_opacity":
            return clampf(float(value), 0.3, 1.0)
        "invert_y", "dynamic_quality", "haptics", "show_debug":
            return bool(value)
    return null

func _changed() -> void:
    apply_audio()
    _save_pending = true
    _save_left = SAVE_DEBOUNCE
    set_process(true)
    settings_changed.emit(get_settings())

func _process(delta: float) -> void:
    if not _save_pending:
        set_process(false)
        return
    _save_left -= delta
    if _save_left <= 0.0:
        save_settings()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        if _save_pending:
            save_settings()

func _ensure_audio_buses() -> void:
    for bus_name in BUS_NAMES:
        if AudioServer.get_bus_index(bus_name) == -1:
            AudioServer.add_bus()
            var index := AudioServer.get_bus_count() - 1
            AudioServer.set_bus_name(index, bus_name)
            AudioServer.set_bus_send(index, "Master")

func _set_bus_volume(bus_name: String, linear: float) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    if index == -1:
        return
    AudioServer.set_bus_mute(index, linear <= 0.001)
    AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))
