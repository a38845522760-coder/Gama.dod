extends Node

## Typed cross-system events only. Never store authoritative gameplay state here.

signal session_started(mode_id: String)
signal session_ended(mode_id: String, results: Dictionary)
signal player_health_changed(player_id: String, current: float, maximum: float)
signal player_armor_changed(player_id: String, current: float, maximum: float)
signal player_died(player_id: String)
signal player_respawned(player_id: String)
signal player_score_changed(player_id: String, score: int)
signal currency_changed(player_id: String, amount: int)
signal target_destroyed(points: int, headshot: bool)
signal peer_connection_changed(peer_id: int, connected: bool)
signal match_phase_changed(phase_id: String)
signal quality_profile_changed(profile_id: String)
signal diagnostic_warning(code: String, details: String)
signal combatant_killed(victim: Node, killer: Node, headshot: bool)
signal shop_requested
