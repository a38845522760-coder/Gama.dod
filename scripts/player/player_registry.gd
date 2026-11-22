extends Node
class_name PlayerRegistry

## Scene-scoped registry of active player nodes, keyed by stable session IDs.

signal player_registered(player_id: String, player: Node)
signal player_unregistered(player_id: String)

var _players: Dictionary = {}

func register_player(player_id: String, player: Node) -> bool:
    var clean_id := player_id.strip_edges()
    if clean_id.is_empty() or player == null or not is_instance_valid(player):
        return false
    if _players.has(clean_id):
        return false
    _players[clean_id] = weakref(player)
    player.tree_exiting.connect(_on_player_exiting.bind(clean_id), CONNECT_ONE_SHOT)
    player_registered.emit(clean_id, player)
    return true

func unregister_player(player_id: String) -> void:
    if not _players.has(player_id):
        return
    _players.erase(player_id)
    player_unregistered.emit(player_id)

func get_player(player_id: String) -> Node:
    if not _players.has(player_id):
        return null
    var reference: WeakRef = _players[player_id]
    var player := reference.get_ref() as Node
    if player == null:
        _players.erase(player_id)
    return player

func get_player_ids() -> PackedStringArray:
    var ids := PackedStringArray()
    for player_id in _players.keys():
        if get_player(str(player_id)) != null:
            ids.append(str(player_id))
    ids.sort()
    return ids

func _on_player_exiting(player_id: String) -> void:
    unregister_player(player_id)
