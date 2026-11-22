extends AnimatableBody3D
class_name MovingTestPlatform

@export var travel_axis: Vector3 = Vector3.UP
@export_range(0.1, 2.5, 0.05) var amplitude: float = 0.75
@export_range(1.0, 12.0, 0.1) var period_seconds: float = 4.8

var _start_position: Vector3
var _phase: float = 0.0

func _ready() -> void:
    sync_to_physics = true
    _start_position = position

func _physics_process(delta: float) -> void:
    _phase = fposmod(_phase + delta / maxf(period_seconds, 0.1) * TAU, TAU)
    var normalized_axis := travel_axis.normalized()
    position = _start_position + normalized_axis * sin(_phase) * amplitude
