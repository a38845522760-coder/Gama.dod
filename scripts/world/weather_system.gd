extends Node
class_name WeatherSystem

## Dynamic weather and time of day: clear, overcast, fog, rain (with thunder), dusk and night.
## Presets blend smoothly; street lamps switch on as the light drops. Rain is a pooled
## CPU particle volume that follows the player and scales with the quality preset.

signal weather_changed(weather_id: String)

const ORDER: Array[String] = ["clear", "overcast", "fog", "rain", "dusk", "night"]
const PRESETS: Dictionary = {
    "clear": {"sun_energy": 1.25, "sun_pitch": -52.0, "ambient": 0.95, "fog_density": 0.0007, "rain": 0.0, "lamps": 0.0,
        "sun_color": Color("#fff1d6"), "sky_top": Color("#3f7fc4"), "sky_horizon": Color("#bcd6e8"), "ground": Color("#6b6a62"), "fog_color": Color("#b9cde0")},
    "overcast": {"sun_energy": 0.55, "sun_pitch": -45.0, "ambient": 1.0, "fog_density": 0.0030, "rain": 0.0, "lamps": 0.0,
        "sun_color": Color("#e4e8ee"), "sky_top": Color("#74808c"), "sky_horizon": Color("#a9b2ba"), "ground": Color("#58595a"), "fog_color": Color("#9aa3ab")},
    "fog": {"sun_energy": 0.35, "sun_pitch": -40.0, "ambient": 1.05, "fog_density": 0.0210, "rain": 0.0, "lamps": 0.25,
        "sun_color": Color("#dfe6ea"), "sky_top": Color("#8c969e"), "sky_horizon": Color("#b8c0c6"), "ground": Color("#6b7075"), "fog_color": Color("#aab3ba")},
    "rain": {"sun_energy": 0.3, "sun_pitch": -40.0, "ambient": 0.8, "fog_density": 0.0065, "rain": 1.0, "lamps": 0.35,
        "sun_color": Color("#b7c4d4"), "sky_top": Color("#3c4652"), "sky_horizon": Color("#6c7782"), "ground": Color("#3a3f44"), "fog_color": Color("#69747f")},
    "dusk": {"sun_energy": 0.7, "sun_pitch": -8.0, "ambient": 0.6, "fog_density": 0.0020, "rain": 0.0, "lamps": 0.8,
        "sun_color": Color("#ff9a52"), "sky_top": Color("#35507d"), "sky_horizon": Color("#f0955a"), "ground": Color("#3b2f2c"), "fog_color": Color("#c98a62")},
    "night": {"sun_energy": 0.12, "sun_pitch": -30.0, "ambient": 0.32, "fog_density": 0.0030, "rain": 0.0, "lamps": 1.0,
        "sun_color": Color("#8fa8ff"), "sky_top": Color("#05080f"), "sky_horizon": Color("#141c2e"), "ground": Color("#07090d"), "fog_color": Color("#0e1422")},
}
const NUMERIC_KEYS: Array[String] = ["sun_energy", "sun_pitch", "ambient", "fog_density", "rain", "lamps"]
const COLOR_KEYS: Array[String] = ["sun_color", "sky_top", "sky_horizon", "ground", "fog_color"]

@export var auto_cycle: bool = false
@export_range(30.0, 300.0, 5.0) var cycle_seconds: float = 100.0

var current_id: String = "clear"
var _current: Dictionary = {}
var _target: Dictionary = {}
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _player: Node3D
var _lamp_lights: Array[OmniLight3D] = []
var _rain: CPUParticles3D
var _rain_player: AudioStreamPlayer
var _thunder_player: AudioStreamPlayer
var _cycle_left: float = 0.0
var _thunder_left: float = 12.0
var _flash: float = 0.0
var _rain_base_amount: int = 600

func setup(world_environment: WorldEnvironment, sun: DirectionalLight3D, player: Node3D, lamp_lights: Array[OmniLight3D]) -> void:
    _environment = world_environment.environment
    _sun = sun
    _player = player
    _lamp_lights = lamp_lights
    if _environment != null and _environment.sky != null:
        _sky_material = _environment.sky.sky_material as ProceduralSkyMaterial
    var density: float = float(SettingsManager.get_quality_profile().get("effects_density", 0.5))
    _rain_base_amount = int(300.0 + 900.0 * density)
    _build_rain()
    _current = _copy_preset("clear")
    _target = _copy_preset("clear")
    _apply()
    _cycle_left = cycle_seconds

func get_current_id() -> String:
    return current_id

func set_weather(weather_id: String, instant: bool = false) -> bool:
    if not PRESETS.has(weather_id):
        return false
    current_id = weather_id
    _target = _copy_preset(weather_id)
    if instant:
        _current = _copy_preset(weather_id)
        _apply()
    var rain_amount: float = float(_target["rain"])
    if _rain != null:
        _rain.amount = maxi(1, int(float(_rain_base_amount) * maxf(rain_amount, 0.1)))
    weather_changed.emit(weather_id)
    return true

func cycle_next() -> void:
    var index := ORDER.find(current_id)
    set_weather(ORDER[(index + 1) % ORDER.size()])

func _copy_preset(weather_id: String) -> Dictionary:
    return (PRESETS[weather_id] as Dictionary).duplicate(true)

func _process(delta: float) -> void:
    if _environment == null:
        return
    var blend := 1.0 - exp(-delta * 0.8)
    for key in NUMERIC_KEYS:
        _current[key] = lerpf(float(_current[key]), float(_target[key]), blend)
    for key in COLOR_KEYS:
        _current[key] = (_current[key] as Color).lerp(_target[key] as Color, blend)
    _update_thunder(delta)
    _apply()
    if auto_cycle:
        _cycle_left -= delta
        if _cycle_left <= 0.0:
            _cycle_left = cycle_seconds
            cycle_next()
    if _rain != null and is_instance_valid(_player):
        _rain.global_position = _player.global_position + Vector3(0.0, 13.0, 0.0)

func _apply() -> void:
    if _environment == null:
        return
    _environment.ambient_light_energy = float(_current["ambient"]) + _flash * 1.6
    _environment.fog_density = float(_current["fog_density"])
    _environment.fog_light_color = _current["fog_color"]
    if _sky_material != null:
        _sky_material.sky_top_color = (_current["sky_top"] as Color).lerp(Color.WHITE, _flash * 0.5)
        _sky_material.sky_horizon_color = _current["sky_horizon"]
        _sky_material.ground_horizon_color = _current["sky_horizon"]
        _sky_material.ground_bottom_color = _current["ground"]
    if _sun != null:
        _sun.light_energy = float(_current["sun_energy"]) + _flash * 0.8
        _sun.light_color = _current["sun_color"]
        _sun.rotation_degrees.x = float(_current["sun_pitch"])
    var lamp_energy := float(_current["lamps"]) * 3.0
    for lamp in _lamp_lights:
        if is_instance_valid(lamp):
            lamp.light_energy = lamp_energy
            lamp.visible = lamp_energy > 0.05
    var rain_level := float(_current["rain"])
    if _rain != null:
        _rain.emitting = rain_level > 0.05
    if _rain_player != null:
        _rain_player.volume_db = linear_to_db(clampf(rain_level, 0.001, 1.0) * 0.4)
        if rain_level > 0.05 and not _rain_player.playing:
            _rain_player.play()
        elif rain_level <= 0.05 and _rain_player.playing:
            _rain_player.stop()

func _update_thunder(delta: float) -> void:
    _flash = maxf(0.0, _flash - delta * 3.5)
    if current_id != "rain":
        return
    _thunder_left -= delta
    if _thunder_left <= 0.0:
        _thunder_left = randf_range(9.0, 22.0)
        _flash = 1.0
        if _thunder_player != null:
            get_tree().create_timer(randf_range(0.6, 2.2)).timeout.connect(func() -> void:
                if is_instance_valid(_thunder_player):
                    _thunder_player.play())

func _build_rain() -> void:
    _rain = CPUParticles3D.new()
    _rain.name = "Rain"
    _rain.top_level = true
    _rain.amount = _rain_base_amount
    _rain.lifetime = 1.1
    _rain.emitting = false
    _rain.local_coords = false
    _rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    _rain.emission_box_extents = Vector3(18.0, 0.2, 18.0)
    _rain.direction = Vector3(0.12, -1.0, 0.0)
    _rain.spread = 2.0
    _rain.initial_velocity_min = 20.0
    _rain.initial_velocity_max = 24.0
    _rain.gravity = Vector3(0.0, -4.0, 0.0)
    var streak := BoxMesh.new()
    streak.size = Vector3(0.012, 0.55, 0.012)
    _rain.mesh = streak
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.75, 0.85, 1.0, 0.45)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _rain.material_override = material
    _rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_rain)

    _rain_player = AudioStreamPlayer.new()
    _rain_player.stream = _make_rain_loop()
    _rain_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
    _rain_player.volume_db = -40.0
    add_child(_rain_player)
    _thunder_player = AudioStreamPlayer.new()
    _thunder_player.stream = _make_thunder()
    _thunder_player.bus = _rain_player.bus
    _thunder_player.volume_db = -6.0
    add_child(_thunder_player)

func _make_rain_loop() -> AudioStreamWAV:
    var rate := 22050
    var count := rate * 2
    var data := PackedByteArray()
    data.resize(count * 2)
    var low: float = 0.0
    for i in range(count):
        var white := randf() * 2.0 - 1.0
        low = low * 0.55 + white * 0.45
        data.encode_s16(i * 2, int(clampf(low * 0.5, -1.0, 1.0) * 30000.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.stereo = false
    stream.data = data
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = count
    return stream

func _make_thunder() -> AudioStreamWAV:
    var rate := 22050
    var count := int(float(rate) * 2.6)
    var data := PackedByteArray()
    data.resize(count * 2)
    var low: float = 0.0
    for i in range(count):
        var t := float(i) / float(rate)
        low = low * 0.93 + (randf() * 2.0 - 1.0) * 0.07
        var envelope := exp(-t * 1.6) * (1.0 + 0.5 * sin(t * 9.0))
        data.encode_s16(i * 2, int(clampf(low * 9.0 * envelope, -1.0, 1.0) * 30000.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.stereo = false
    stream.data = data
    return stream
