extends Node

## Applies conservative game-level quality switches and exposes frame-time diagnostics.
## Dynamic quality is opt-in and changes only rendering quality, never physics/gameplay.

const PRESET_ORDER: Array[String] = ["low", "medium", "high", "ultra"]
var _frame_samples: Array[float] = []
var _last_sample_second: int = -1
var _over_budget_seconds: float = 0.0
var _under_budget_seconds: float = 0.0
var _quality_cooldown: float = 0.0
var _dynamic_quality_enabled: bool = false
var _applied_preset: String = "medium"

func _ready() -> void:
    SettingsManager.settings_changed.connect(_on_settings_changed)
    _dynamic_quality_enabled = bool(SettingsManager.get_setting("dynamic_quality", false))
    apply_quality_preset(SettingsManager.get_quality_preset())
    set_process(true)

func apply_quality_preset(preset: String) -> bool:
    if not SettingsManager.QUALITY_PROFILES.has(preset):
        return false
    var profile: Dictionary = SettingsManager.QUALITY_PROFILES[preset]
    var target_viewport := get_viewport()
    if target_viewport != null:
        target_viewport.scaling_3d_scale = float(profile.get("render_scale", 1.0))
        target_viewport.msaa_3d = int(profile.get("msaa", 0)) as Viewport.MSAA
    var shadow_tier := int(profile.get("shadow_tier", 1))
    var lights := get_tree().root.find_children("*", "Light3D", true, false)
    for node in lights:
        var light := node as Light3D
        if light != null and not light.is_in_group("no_shadow"):
            light.shadow_enabled = shadow_tier > 0
            light.shadow_blur = 0.0 if shadow_tier <= 1 else (0.6 if shadow_tier == 2 else 1.4)
    var environments := get_tree().root.find_children("*", "WorldEnvironment", true, false)
    for node in environments:
        var world_environment := node as WorldEnvironment
        if world_environment != null and world_environment.environment != null:
            world_environment.environment.ssao_enabled = shadow_tier >= 2
            world_environment.environment.glow_enabled = shadow_tier >= 2
    _applied_preset = preset
    EventBus.quality_profile_changed.emit(preset)
    return true

func set_dynamic_quality_enabled(enabled: bool) -> void:
    _dynamic_quality_enabled = enabled
    _over_budget_seconds = 0.0
    _under_budget_seconds = 0.0

func get_performance_snapshot() -> Dictionary:
    var p95_seconds := _percentile_95()
    return {
        "fps": Engine.get_frames_per_second(),
        "frame_time_ms": get_process_delta_time() * 1000.0,
        "p95_frame_time_ms": p95_seconds * 1000.0,
        "sample_count": _frame_samples.size(),
        "memory_static_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0),
        "object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
        "quality_preset": _applied_preset,
    }

func _process(delta: float) -> void:
    _frame_samples.append(delta)
    if _frame_samples.size() > 180:
        _frame_samples.pop_front()
    _quality_cooldown = maxf(0.0, _quality_cooldown - delta)
    if not _dynamic_quality_enabled or _quality_cooldown > 0.0 or _frame_samples.size() < 90:
        return
    var p95 := _percentile_95()
    if p95 > 0.025:
        _over_budget_seconds += delta
        _under_budget_seconds = 0.0
    elif p95 < 0.017:
        _under_budget_seconds += delta
        _over_budget_seconds = 0.0
    else:
        _over_budget_seconds = 0.0
        _under_budget_seconds = 0.0
    if _over_budget_seconds >= 3.0:
        _step_quality(-1)
        _over_budget_seconds = 0.0
        _quality_cooldown = 8.0
    elif _under_budget_seconds >= 12.0:
        _step_quality(1)
        _under_budget_seconds = 0.0
        _quality_cooldown = 12.0

func _percentile_95() -> float:
    if _frame_samples.is_empty():
        return 0.0
    var sorted_samples := _frame_samples.duplicate()
    sorted_samples.sort()
    var index := clampi(int(ceil(float(sorted_samples.size() - 1) * 0.95)), 0, sorted_samples.size() - 1)
    return float(sorted_samples[index])

func _step_quality(direction: int) -> void:
    var index := PRESET_ORDER.find(_applied_preset)
    if index < 0:
        index = 1
    var next_index := clampi(index + direction, 0, PRESET_ORDER.size() - 1)
    if next_index != index:
        apply_quality_preset(PRESET_ORDER[next_index])

func _on_settings_changed(settings: Dictionary) -> void:
    _dynamic_quality_enabled = bool(settings.get("dynamic_quality", false))
    var requested := str(settings.get("quality_preset", "medium"))
    if requested != _applied_preset:
        apply_quality_preset(requested)
