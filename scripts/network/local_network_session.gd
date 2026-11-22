extends Node
class_name LocalNetworkSession

## ENet transport adapter for a future host-authoritative LAN match.
## This is transport/session plumbing only; gameplay replication and discovery are separate work.

signal state_changed(state_id: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connection_failed
signal server_disconnected

const DEFAULT_PORT: int = 24560
const MAX_REMOTE_PEERS: int = 3
var _peer: ENetMultiplayerPeer
var state_id: String = "offline"

func host(port: int = DEFAULT_PORT, max_remote_peers: int = MAX_REMOTE_PEERS) -> Error:
    close_session()
    var candidate := ENetMultiplayerPeer.new()
    var error := candidate.create_server(port, clampi(max_remote_peers, 1, 3))
    if error != OK:
        return error
    _peer = candidate
    multiplayer.multiplayer_peer = _peer
    _connect_peer_signals()
    _set_state("hosting")
    return OK

func join(address: String, port: int = DEFAULT_PORT) -> Error:
    var clean_address := address.strip_edges()
    if clean_address.is_empty():
        return ERR_INVALID_PARAMETER
    close_session()
    var candidate := ENetMultiplayerPeer.new()
    var error := candidate.create_client(clean_address, port)
    if error != OK:
        return error
    _peer = candidate
    multiplayer.multiplayer_peer = _peer
    _connect_peer_signals()
    _set_state("connecting")
    return OK

func close_session() -> void:
    if _peer != null:
        _peer.close()
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    _peer = null
    _set_state("offline")

func get_remote_peer_ids() -> PackedInt32Array:
    return multiplayer.get_peers()

func is_host() -> bool:
    return _peer != null and state_id == "hosting" and multiplayer.is_server()

func _connect_peer_signals() -> void:
    if not multiplayer.peer_connected.is_connected(_on_peer_connected):
        multiplayer.peer_connected.connect(_on_peer_connected)
    if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
        multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
        multiplayer.connected_to_server.connect(_on_connected_to_server)
    if not multiplayer.connection_failed.is_connected(_on_connection_failed):
        multiplayer.connection_failed.connect(_on_connection_failed)
    if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
        multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(peer_id: int) -> void:
    peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
    peer_left.emit(peer_id)

func _on_connected_to_server() -> void:
    _set_state("connected")

func _on_connection_failed() -> void:
    _set_state("offline")
    connection_failed.emit()

func _on_server_disconnected() -> void:
    _set_state("offline")
    server_disconnected.emit()

func _set_state(value: String) -> void:
    if state_id == value:
        return
    state_id = value
    state_changed.emit(state_id)
