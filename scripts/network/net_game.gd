extends Node

## LAN multiplayer for every game mode (host-authoritative, up to 3 guests).
## Connect over a phone hotspot or any shared Wi-Fi: the host makes a room, guests find it
## automatically (UDP broadcast) or type the host's IP address.
##  - The host runs the real match (bots, waves, score).
##  - Guests see the bots as puppets; their shots are reported to the host.
##  - Players appear to each other as jointed soldiers (NetAvatar) and can hurt each other
##    where the mode makes them enemies (free-for-all).

signal rooms_changed
signal lobby_changed
signal status_changed(text: String)
signal left

const GAME_PORT: int = 24560
const DISCOVERY_PORT: int = 24561
const MAX_GUESTS: int = 3
const MAGIC: String = "IRONYARD1"
const STATE_INTERVAL: float = 0.0667
const BOT_INTERVAL: float = 0.1
const ROOM_TIMEOUT: float = 4.5
const MAP_SCENE: String = "res://scenes/world/iron_yard_map.tscn"
const ZOMBIE_MAP_SCENE: String = "res://scenes/world/zombie_map.tscn"

var role: String = "offline"
var local_name: String = "Player"
var players: Dictionary = {}
var rooms: Dictionary = {}
var status_text: String = ""
var match_running: bool = false

var _peer: ENetMultiplayerPeer
var _udp_send: PacketPeerUDP
var _udp_listen: PacketPeerUDP
var _announce_left: float = 0.0
var _state_left: float = 0.0
var _bot_left: float = 0.0
var _avatars: Dictionary = {}
var _guest_states: Dictionary = {}
var _puppets: Dictionary = {}
var _puppet_seen: Dictionary = {}
var _bot_counter: int = 0
var _local_player: Node3D
var _spawn_manager: Node
var _mode_id: String = "ffa"
var _net_root: Node3D
var _header_layer: CanvasLayer
var _header_label: Label
var _last_header: String = ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var saved_name: String = str(SaveManager.get_progress("mp_name", ""))
    if saved_name.is_empty():
        saved_name = "Player%d" % (randi() % 900 + 100)
    local_name = saved_name

func set_local_name(new_name: String) -> void:
    var clean: String = new_name.strip_edges().substr(0, 14)
    if clean.is_empty():
        return
    local_name = clean
    SaveManager.set_progress("mp_name", clean)

func is_host() -> bool:
    return role == "host" and match_running

func is_guest() -> bool:
    return role == "guest" and match_running

func local_addresses() -> PackedStringArray:
    var out := PackedStringArray()
    for address in IP.get_local_addresses():
        var text: String = str(address)
        if _is_lan_ipv4(text):
            out.append(text)
    return out

func _is_lan_ipv4(text: String) -> bool:
    var parts: PackedStringArray = text.split(".")
    if parts.size() != 4:
        return false
    if text.begins_with("127.") or text.begins_with("169.254.") or text.begins_with("0."):
        return false
    return true

# ---------------------------------------------------------------- lobby

func host_room() -> bool:
    leave(false)
    var peer := ENetMultiplayerPeer.new()
    var error: int = peer.create_server(GAME_PORT, MAX_GUESTS)
    if error != OK:
        _set_status(Loc.t("mp_host_failed"))
        return false
    _peer = peer
    multiplayer.multiplayer_peer = _peer
    _connect_signals()
    role = "host"
    players = {1: local_name}
    _udp_send = PacketPeerUDP.new()
    _udp_send.set_broadcast_enabled(true)
    _announce_left = 0.0
    _set_status(Loc.t("mp_waiting_guests"))
    lobby_changed.emit()
    return true

func join_room(address: String) -> bool:
    var clean: String = address.strip_edges()
    if clean.is_empty():
        return false
    leave(false)
    var peer := ENetMultiplayerPeer.new()
    var error: int = peer.create_client(clean, GAME_PORT)
    if error != OK:
        _set_status(Loc.t("mp_join_failed"))
        return false
    _peer = peer
    multiplayer.multiplayer_peer = _peer
    _connect_signals()
    role = "guest"
    players = {}
    _set_status(Loc.t("mp_connecting"))
    lobby_changed.emit()
    return true

func start_search() -> void:
    stop_search()
    _udp_listen = PacketPeerUDP.new()
    _udp_listen.set_broadcast_enabled(true)
    var error: int = _udp_listen.bind(DISCOVERY_PORT, "*")
    if error != OK:
        _udp_listen = null

func stop_search() -> void:
    if _udp_listen != null:
        _udp_listen.close()
        _udp_listen = null

func leave(announce: bool = true) -> void:
    stop_search()
    if _peer != null:
        _peer.close()
        _peer = null
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    if _udp_send != null:
        _udp_send.close()
        _udp_send = null
    var was_online: bool = role != "offline"
    role = "offline"
    players = {}
    rooms = {}
    match_running = false
    AppState.multiplayer_active = false
    _clear_match_nodes()
    if was_online:
        _set_status("")
        lobby_changed.emit()
        if announce:
            left.emit()

func start_match() -> void:
    if role != "host" or match_running:
        return
    _begin_match.rpc(AppState.pending_mode, AppState.pending_difficulty, AppState.pending_allies, AppState.pending_enemies)

func _connect_signals() -> void:
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

func _on_peer_connected(_id: int) -> void:
    pass

func _on_peer_disconnected(id: int) -> void:
    if role != "host":
        return
    players.erase(id)
    _guest_states.erase(id)
    if _avatars.has(id):
        var avatar: Variant = _avatars[id]
        if is_instance_valid(avatar):
            (avatar as Node).queue_free()
        _avatars.erase(id)
    _sync_players.rpc(players)
    lobby_changed.emit()

func _on_connected_to_server() -> void:
    _set_status(Loc.t("mp_connected"))
    _register_name.rpc_id(1, local_name)

func _on_connection_failed() -> void:
    leave(false)
    _set_status(Loc.t("mp_join_failed"))

func _on_server_disconnected() -> void:
    var was_in_match: bool = match_running
    leave(false)
    _set_status(Loc.t("mp_host_left"))
    if was_in_match:
        get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _set_status(text: String) -> void:
    status_text = text
    status_changed.emit(text)

@rpc("any_peer", "reliable")
func _register_name(player_name: String) -> void:
    if role != "host":
        return
    var id: int = multiplayer.get_remote_sender_id()
    if match_running:
        return
    players[id] = player_name.strip_edges().substr(0, 14)
    _sync_players.rpc(players)
    lobby_changed.emit()

@rpc("authority", "reliable")
func _sync_players(table: Dictionary) -> void:
    players = table
    lobby_changed.emit()

@rpc("authority", "call_local", "reliable")
func _begin_match(mode: String, difficulty: int, allies: int, enemies: int) -> void:
    AppState.pending_mode = mode
    AppState.pending_difficulty = difficulty
    AppState.pending_allies = allies
    AppState.pending_enemies = enemies
    AppState.multiplayer_active = true
    match_running = true
    stop_search()
    _bot_counter = 0
    get_tree().paused = false
    get_tree().change_scene_to_file(ZOMBIE_MAP_SCENE if mode == "zombie" else MAP_SCENE)

# ---------------------------------------------------------------- match attach

func team_for_peer(id: int) -> String:
    match _mode_id:
        "tdm":
            return "alpha"
        "zombie", "assault":
            return "player"
        _:
            return "ffa_h%d" % id

func _prepare(map: Node3D, player: Node3D, mode: String) -> void:
    _clear_match_nodes()
    _local_player = player
    _mode_id = mode
    _net_root = Node3D.new()
    _net_root.name = "NetRoot"
    map.add_child(_net_root)
    _state_left = 0.0
    _bot_left = 0.0

func attach_host(map: Node3D, player: Node3D, _manager: Node, mode: String) -> void:
    _prepare(map, player, mode)
    for id in players.keys():
        if int(id) != 1:
            _ensure_avatar(int(id))

func attach_guest(map: Node3D, player: Node3D, spawn_manager: Node, mode: String) -> void:
    _prepare(map, player, mode)
    _spawn_manager = spawn_manager
    var my_id: int = multiplayer.get_unique_id()
    player.set_meta("team", team_for_peer(my_id))
    player.set_meta("display_name", local_name)
    player.add_to_group("combatants")
    if player.has_signal("died") and not player.is_connected("died", _on_guest_died):
        player.connect("died", _on_guest_died)
    _header_layer = CanvasLayer.new()
    _header_layer.layer = 9
    _header_label = Label.new()
    _header_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _header_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _header_label.position.y = 8.0
    _header_label.add_theme_font_size_override("font_size", 26)
    _header_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
    _header_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    _header_label.add_theme_constant_override("outline_size", 6)
    _header_label.text = _last_header
    _header_layer.add_child(_header_label)
    map.add_child(_header_layer)
    for id in players.keys():
        if int(id) != my_id:
            _ensure_avatar(int(id))

func _clear_match_nodes() -> void:
    _avatars.clear()
    _puppets.clear()
    _puppet_seen.clear()
    _guest_states.clear()
    _local_player = null
    _spawn_manager = null
    if _net_root != null and is_instance_valid(_net_root):
        _net_root.queue_free()
    _net_root = null
    if _header_layer != null and is_instance_valid(_header_layer):
        _header_layer.queue_free()
    _header_layer = null
    _header_label = null

func _ensure_avatar(id: int) -> Variant:
    if _avatars.has(id) and is_instance_valid(_avatars[id]):
        return _avatars[id]
    if _net_root == null or not is_instance_valid(_net_root):
        return null
    var avatar := NetAvatar.new()
    avatar.name = "Avatar_%d" % id
    _net_root.add_child(avatar)
    avatar.setup(id, str(players.get(id, "Player")), team_for_peer(id))
    _avatars[id] = avatar
    return avatar

func _on_guest_died() -> void:
    await get_tree().create_timer(4.0).timeout
    if _local_player == null or not is_instance_valid(_local_player) or not is_guest():
        return
    if _spawn_manager != null and _local_player.has_method("respawn"):
        _local_player.call("respawn", _spawn_manager.call("get_next_spawn_transform", ""))

# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
    _poll_discovery()
    if role == "host" and not match_running and _udp_send != null:
        _announce_left -= delta
        if _announce_left <= 0.0:
            _announce_left = 1.0
            _announce_room()
    if not match_running or _local_player == null or not is_instance_valid(_local_player):
        return
    _state_left -= delta
    if _state_left <= 0.0:
        _state_left = STATE_INTERVAL
        _send_player_state()
    if role == "host":
        _bot_left -= delta
        if _bot_left <= 0.0:
            _bot_left = BOT_INTERVAL
            _send_bots()
    else:
        _prune_puppets()

func _announce_room() -> void:
    var text: String = "%s|%s|%s|%d" % [MAGIC, local_name, AppState.pending_mode, players.size()]
    var bytes: PackedByteArray = text.to_utf8_buffer()
    var targets: Array[String] = ["255.255.255.255"]
    for address in local_addresses():
        var parts: PackedStringArray = address.split(".")
        targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
    for target in targets:
        _udp_send.set_dest_address(target, DISCOVERY_PORT)
        _udp_send.put_packet(bytes)

func _poll_discovery() -> void:
    if _udp_listen == null:
        return
    var changed: bool = false
    var now: float = Time.get_ticks_msec() / 1000.0
    while _udp_listen.get_available_packet_count() > 0:
        var bytes: PackedByteArray = _udp_listen.get_packet()
        var ip: String = _udp_listen.get_packet_ip()
        var parts: PackedStringArray = bytes.get_string_from_utf8().split("|")
        if parts.size() >= 4 and parts[0] == MAGIC:
            var fresh: Dictionary = {"name": parts[1], "mode": parts[2], "players": int(parts[3]), "seen": now}
            var previous: Variant = rooms.get(ip, null)
            if previous == null or str((previous as Dictionary)["name"]) != parts[1] or str((previous as Dictionary)["mode"]) != parts[2] or int((previous as Dictionary)["players"]) != int(parts[3]):
                changed = true
            rooms[ip] = fresh
    for ip in rooms.keys():
        if now - float((rooms[ip] as Dictionary)["seen"]) > ROOM_TIMEOUT:
            rooms.erase(ip)
            changed = true
    if changed:
        rooms_changed.emit()

func _send_player_state() -> void:
    if not _local_player.has_method("get_net_state"):
        return
    var state: Array = _local_player.call("get_net_state")
    if role == "guest":
        _guest_state.rpc_id(1, state)
        return
    # Host: broadcast the full roster (host + every guest) to all guests.
    var roster: Array = [[1, state]]
    for id in _guest_states.keys():
        roster.append([int(id), _guest_states[id]])
    if players.size() > 1:
        _roster.rpc(roster)

@rpc("any_peer", "unreliable_ordered")
func _guest_state(state: Array) -> void:
    if role != "host":
        return
    var id: int = multiplayer.get_remote_sender_id()
    _guest_states[id] = state
    var avatar: Variant = _ensure_avatar(id)
    if avatar != null:
        (avatar as NetAvatar).net_set_state(state)

@rpc("authority", "unreliable_ordered")
func _roster(roster: Array) -> void:
    if role != "guest" or _net_root == null:
        return
    var my_id: int = multiplayer.get_unique_id()
    for entry in roster:
        var id: int = int(entry[0])
        if id == my_id:
            continue
        var avatar: Variant = _ensure_avatar(id)
        if avatar != null:
            (avatar as NetAvatar).net_set_state(entry[1] as Array)

# ---------------------------------------------------------------- damage

func damage_player(target_peer: int, amount: float) -> void:
    if amount <= 0.0:
        return
    if target_peer == multiplayer.get_unique_id():
        _apply_local_damage(amount)
    elif role == "host":
        _take_damage.rpc_id(target_peer, amount)
    elif role == "guest":
        _relay_damage.rpc_id(1, target_peer, amount)

func _apply_local_damage(amount: float) -> void:
    if _local_player == null or not is_instance_valid(_local_player):
        return
    var health := _local_player.get_node_or_null("HealthComponent") as HealthComponent
    if health != null and health.is_alive():
        health.apply_damage(amount, null)

@rpc("any_peer", "reliable")
func _relay_damage(target_peer: int, amount: float) -> void:
    if role != "host" or not match_running:
        return
    damage_player(target_peer, clampf(amount, 0.0, 250.0))

@rpc("authority", "reliable")
func _take_damage(amount: float) -> void:
    _apply_local_damage(amount)

# ---------------------------------------------------------------- bots

func next_bot_id() -> int:
    _bot_counter += 1
    return _bot_counter

func _send_bots() -> void:
    var list: Array = []
    for node in get_tree().get_nodes_in_group("bots"):
        var bot := node as Bot
        if bot == null or not is_instance_valid(bot) or bot.net_puppet:
            continue
        if not bot.has_meta("net_id"):
            bot.set_meta("net_id", next_bot_id())
        list.append([int(bot.get_meta("net_id")), bot.profile_id, bot.team, bot.team_color.to_html(true), bot.use_team_look,
            bot.weapon_override, bot.health_scale, bot.global_position, bot.rotation.y, bot.is_alive(), bot.display_name, bot.show_marker])
    if players.size() > 1:
        _bot_snapshot.rpc(list)

@rpc("authority", "unreliable_ordered")
func _bot_snapshot(list: Array) -> void:
    if role != "guest" or _net_root == null or not is_instance_valid(_net_root):
        return
    var now: float = Time.get_ticks_msec() / 1000.0
    for entry in list:
        var id: int = int(entry[0])
        var stored: Variant = _puppets.get(id, null)
        if stored == null or not is_instance_valid(stored):
            if _puppet_seen.has(id) and not bool(entry[9]):
                continue
            stored = _create_puppet(id, entry)
            _puppets[id] = stored
        _puppet_seen[id] = now
        (stored as Bot).net_set_state(entry[7] as Vector3, float(entry[8]), bool(entry[9]))

func _create_puppet(id: int, entry: Array) -> Bot:
    var bot := Bot.new()
    bot.net_puppet = true
    bot.profile_id = str(entry[1])
    bot.team = str(entry[2])
    bot.team_color = Color(str(entry[3]))
    bot.use_team_look = bool(entry[4])
    bot.weapon_override = str(entry[5])
    bot.health_scale = float(entry[6])
    bot.display_name = str(entry[10])
    bot.show_marker = bool(entry[11])
    bot.difficulty = clampi(AppState.pending_difficulty, 0, 2)
    bot.set_meta("net_id", id)
    _net_root.add_child(bot)
    bot.global_position = entry[7] as Vector3
    return bot

func _prune_puppets() -> void:
    var now: float = Time.get_ticks_msec() / 1000.0
    for id in _puppet_seen.keys():
        if now - float(_puppet_seen[id]) > 1.5:
            var stored: Variant = _puppets.get(id, null)
            if stored != null and is_instance_valid(stored):
                (stored as Node).queue_free()
            _puppets.erase(id)
            _puppet_seen.erase(id)

func report_bot_hit(bot_id: int, info: Dictionary) -> void:
    if role != "guest" or bot_id < 0:
        return
    var payload: Dictionary = {
        "damage": float(info.get("damage", 0.0)),
        "position": info.get("position", Vector3.ZERO),
        "direction": info.get("direction", Vector3.ZERO),
        "weapon_id": str(info.get("weapon_id", "")),
        "headshot_multiplier": float(info.get("headshot_multiplier", 2.0)),
    }
    _hit_bot.rpc_id(1, bot_id, payload)

@rpc("any_peer", "reliable")
func _hit_bot(bot_id: int, payload: Dictionary) -> void:
    if role != "host" or not match_running:
        return
    var sender: int = multiplayer.get_remote_sender_id()
    var avatar: Variant = _avatars.get(sender, null)
    for node in get_tree().get_nodes_in_group("bots"):
        if int(node.get_meta("net_id", -1)) != bot_id:
            continue
        var direction: Vector3 = payload.get("direction", Vector3.ZERO) as Vector3
        var info: Dictionary = {
            "damage": clampf(float(payload.get("damage", 0.0)), 0.0, 400.0),
            "position": payload.get("position", Vector3.ZERO),
            "direction": direction,
            "normal": -direction,
            "weapon_id": str(payload.get("weapon_id", "")),
            "headshot_multiplier": clampf(float(payload.get("headshot_multiplier", 2.0)), 1.0, 5.0),
            "source": avatar if avatar != null and is_instance_valid(avatar) else null,
        }
        if node.has_method("receive_hit"):
            node.call("receive_hit", info)
        return

# ---------------------------------------------------------------- match text / end

func send_header(text: String) -> void:
    if role != "host" or not match_running or players.size() <= 1 or text == _last_header:
        return
    _last_header = text
    _header.rpc(text)

@rpc("authority", "reliable")
func _header(text: String) -> void:
    _last_header = text
    if _header_label != null and is_instance_valid(_header_label):
        _header_label.text = text

func send_match_over(text: String) -> void:
    if role != "host" or not match_running or players.size() <= 1:
        return
    _match_over.rpc(text)

@rpc("authority", "reliable")
func _match_over(text: String) -> void:
    if _header_label != null and is_instance_valid(_header_label):
        _header_label.text = text
    await get_tree().create_timer(6.0).timeout
    if role == "guest":
        leave(false)
        get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
