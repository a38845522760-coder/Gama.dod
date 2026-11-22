extends Node
class_name RegionManager

## Regional visibility management. The map is cut into a grid of regions; regions that are
## far from the player are hidden (no draw calls, no shadow rendering) and shown again when
## the player comes back. The radius follows the quality preset, so weak phones draw less.
## "Core" (ground, perimeter wall, landmarks) is never hidden.

signal visible_regions_changed(visible_count: int, total: int)

const RADIUS_BY_PRESET: Dictionary = {"low": 62.0, "medium": 84.0, "high": 110.0, "ultra": 170.0}
const REGION_HALF_DIAGONAL: float = 30.0

## Maps with larger regions raise this to the region's half diagonal.
var region_half_diagonal: float = REGION_HALF_DIAGONAL
var _regions: Array[Node3D] = []
var _player: Node3D
var _timer: float = 0.0
var _visible_count: int = 0

func setup(regions: Array[Node3D], player: Node3D) -> void:
    _regions = regions
    _player = player
    SettingsManager.settings_changed.connect(func(_settings: Dictionary) -> void: refresh())
    refresh()

func get_visible_count() -> int:
    return _visible_count

func get_total_count() -> int:
    return _regions.size()

func get_radius() -> float:
    return float(RADIUS_BY_PRESET.get(SettingsManager.get_quality_preset(), 84.0))

func refresh() -> void:
    if not is_instance_valid(_player):
        return
    var radius := get_radius() + region_half_diagonal
    var player_flat := Vector2(_player.global_position.x, _player.global_position.z)
    var count: int = 0
    for region in _regions:
        var center3: Vector3 = region.get_meta("center", region.global_position)
        var center := Vector2(center3.x, center3.z)
        var should_show: bool = center.distance_to(player_flat) <= radius
        if region.visible != should_show:
            region.visible = should_show
        if should_show:
            count += 1
    if count != _visible_count:
        _visible_count = count
        visible_regions_changed.emit(_visible_count, _regions.size())

func _process(delta: float) -> void:
    _timer -= delta
    if _timer <= 0.0:
        _timer = 0.4
        refresh()
