extends Node

## Application/session metadata. Match-specific rules live in MatchController.

signal session_started(mode_id: String)
signal session_ended(mode_id: String)
signal active_screen_changed(screen_id: String)

var active_screen_id: String = "boot"
var active_mode_id: String = ""
var session_active: bool = false
## Chosen in the mode-select screen and read by the map when it loads.
var pending_mode: String = "ffa"
var pending_difficulty: int = 1

func set_active_screen(screen_id: String) -> void:
    var clean_id := screen_id.strip_edges()
    if clean_id.is_empty() or clean_id == active_screen_id:
        return
    active_screen_id = clean_id
    active_screen_changed.emit(active_screen_id)

func begin_session(mode_id: String) -> bool:
    var clean_mode_id := mode_id.strip_edges()
    if clean_mode_id.is_empty() or session_active:
        return false
    active_mode_id = clean_mode_id
    session_active = true
    session_started.emit(active_mode_id)
    return true

func end_session() -> void:
    if not session_active:
        return
    var ended_mode_id := active_mode_id
    session_active = false
    active_mode_id = ""
    session_ended.emit(ended_mode_id)
