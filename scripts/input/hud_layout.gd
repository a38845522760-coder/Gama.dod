extends RefCounted
class_name HudLayout

## Saved, user-editable placement and size of the touch controls.
## Positions are stored as fractions of the screen so the layout survives different phones.

const KEYS: Array[String] = ["joystick", "fire", "jump", "crouch", "reload", "use", "zoom", "camera", "pause", "grenade", "trap"]
const BASE_RADIUS: Dictionary = {
    "joystick": 80.0, "fire": 56.0, "jump": 40.0, "crouch": 34.0, "reload": 33.0, "use": 33.0,
    "zoom": 36.0, "camera": 26.0, "pause": 26.0, "grenade": 30.0, "trap": 30.0,
}
const SAVE_KEY: String = "hud_layout"

static func default_centers(viewport: Vector2, inset: Vector4, scale_factor: float) -> Dictionary:
    var out: Dictionary = {}
    var margin: float = 30.0 * scale_factor
    var joy_r: float = 80.0 * scale_factor
    out["joystick"] = Vector2(inset.x + margin + joy_r, viewport.y - inset.w - margin - joy_r)
    var fire_center := Vector2(viewport.x - inset.z - 130.0 * scale_factor, viewport.y - inset.w - 140.0 * scale_factor)
    out["fire"] = fire_center
    out["jump"] = fire_center + Vector2(-132.0, -50.0) * scale_factor
    out["crouch"] = fire_center + Vector2(-112.0, 66.0) * scale_factor
    out["reload"] = fire_center + Vector2(-22.0, -146.0) * scale_factor
    out["use"] = fire_center + Vector2(-124.0, -150.0) * scale_factor
    out["zoom"] = fire_center + Vector2(-244.0, 6.0) * scale_factor
    out["camera"] = Vector2(viewport.x - inset.z - 330.0 * scale_factor, inset.y + 52.0 * scale_factor)
    out["pause"] = Vector2(inset.x + 56.0 * scale_factor, inset.y + 52.0 * scale_factor)
    out["grenade"] = fire_center + Vector2(-236.0, -96.0) * scale_factor
    out["trap"] = fire_center + Vector2(-214.0, -186.0) * scale_factor
    return out

static func load_layout() -> Dictionary:
    var raw: Variant = SaveManager.get_progress(SAVE_KEY, {})
    if raw is Dictionary:
        return (raw as Dictionary).duplicate(true)
    return {}

static func save_layout(layout: Dictionary) -> void:
    SaveManager.set_progress(SAVE_KEY, layout)
    SaveManager.flush()

static func resolve_center(key: String, layout: Dictionary, defaults: Dictionary, viewport: Vector2) -> Vector2:
    if layout.has(key) and layout[key] is Dictionary:
        var entry: Dictionary = layout[key]
        if entry.has("x") and entry.has("y"):
            return Vector2(clampf(float(entry["x"]), 0.02, 0.98) * viewport.x, clampf(float(entry["y"]), 0.04, 0.96) * viewport.y)
    return defaults.get(key, viewport * 0.5)

static func resolve_scale(key: String, layout: Dictionary) -> float:
    if layout.has(key) and layout[key] is Dictionary:
        var entry: Dictionary = layout[key]
        if entry.has("s"):
            return clampf(float(entry["s"]), 0.5, 2.2)
    return 1.0

static func safe_inset(viewport_size: Vector2) -> Vector4:
    # Returns left, top, right, bottom insets in viewport units (notches / rounded corners).
    var screen_size := Vector2(DisplayServer.screen_get_size())
    var safe := DisplayServer.get_display_safe_area()
    if screen_size.x <= 0.0 or screen_size.y <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
        return Vector4.ZERO
    var ratio := Vector2(viewport_size.x / screen_size.x, viewport_size.y / screen_size.y)
    var left: float = float(safe.position.x) * ratio.x
    var top: float = float(safe.position.y) * ratio.y
    var right: float = (screen_size.x - float(safe.position.x + safe.size.x)) * ratio.x
    var bottom: float = (screen_size.y - float(safe.position.y + safe.size.y)) * ratio.y
    return Vector4(maxf(left, 0.0), maxf(top, 0.0), maxf(right, 0.0), maxf(bottom, 0.0))
