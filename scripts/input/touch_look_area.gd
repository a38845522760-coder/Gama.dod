extends Control
class_name TouchLookArea

signal look_delta(delta: Vector2)
var _touch_index: int = -1

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _touch_index == -1:
            _touch_index = touch.index
        elif not touch.pressed and touch.index == _touch_index:
            _touch_index = -1
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _touch_index:
            look_delta.emit(drag.relative)

func release_all() -> void:
    _touch_index = -1

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED:
        release_all()
