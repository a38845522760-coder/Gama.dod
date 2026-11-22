extends Control

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
@onready var _status_label: Label = %StatusLabel
var _leaving: bool = false

func _ready() -> void:
    _status_label.text = Loc.t("tagline")
    AppState.set_active_screen("boot")
    await get_tree().create_timer(1.1).timeout
    _go()

func _go() -> void:
    if _leaving:
        return
    _leaving = true
    get_tree().change_scene_to_file(MENU_SCENE)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch or (event is InputEventKey and event.pressed):
        _go()
