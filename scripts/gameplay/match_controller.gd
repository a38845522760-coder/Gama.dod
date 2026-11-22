extends Node
class_name MatchController

## Mode-independent match lifecycle contract. Individual modes provide their own rule modules.

enum Phase { LOBBY, COUNTDOWN, ACTIVE, RESULTS }

signal phase_changed(phase: Phase)
signal match_started(mode_id: String)
signal match_finished(mode_id: String, results: Dictionary)

var phase: Phase = Phase.LOBBY
var mode_id: String = ""
var elapsed_seconds: float = 0.0
var duration_seconds: float = 0.0
var results: Dictionary = {}

func begin(mode: String, duration: float = 0.0) -> bool:
    var clean_mode := mode.strip_edges()
    if clean_mode.is_empty() or phase == Phase.ACTIVE:
        return false
    mode_id = clean_mode
    duration_seconds = maxf(0.0, duration)
    elapsed_seconds = 0.0
    results.clear()
    _set_phase(Phase.ACTIVE)
    match_started.emit(mode_id)
    return true

func finish(final_results: Dictionary = {}) -> bool:
    if phase != Phase.ACTIVE:
        return false
    results = final_results.duplicate(true)
    _set_phase(Phase.RESULTS)
    match_finished.emit(mode_id, results)
    return true

func reset() -> void:
    mode_id = ""
    elapsed_seconds = 0.0
    duration_seconds = 0.0
    results.clear()
    _set_phase(Phase.LOBBY)

func _process(delta: float) -> void:
    if phase != Phase.ACTIVE:
        return
    elapsed_seconds += delta
    if duration_seconds > 0.0 and elapsed_seconds >= duration_seconds:
        finish({"reason": "time_limit", "elapsed_seconds": elapsed_seconds})

func _set_phase(value: Phase) -> void:
    if phase == value:
        return
    phase = value
    phase_changed.emit(phase)
    EventBus.match_phase_changed.emit(Phase.keys()[phase].to_lower())
