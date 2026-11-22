extends Node
class_name ModeManager

## Runs one match on the Iron Yard map. Four modes share this class:
##   ffa     - free-for-all deathmatch: everybody is everybody's enemy, first to the kill limit wins
##   tdm     - team deathmatch: Alpha (you + allies) vs Bravo
##   zombie  - endless zombie waves with allies, runners, spitters, brutes and bosses
##   assault - endless waves of armed soldiers (grunts, rushers, marksmen, heavies, officers)
## It spawns and respawns the bots, keeps score, drives the HUD banners and ends the match.

signal match_over(summary: Dictionary)

const MODES: Dictionary = {
    "ffa": {"kind": "deathmatch", "kill_limit": 20, "time": 360.0, "bots": 7},
    "tdm": {"kind": "deathmatch", "kill_limit": 30, "time": 420.0, "bots": 9},
    "zombie": {"kind": "waves", "enemy_team": "zombie"},
    "assault": {"kind": "waves", "enemy_team": "enemy"},
}
const ALPHA_COLOR: Color = Color("#3d8bff")
const BRAVO_COLOR: Color = Color("#ff4d3d")
const ALLY_COLOR: Color = Color("#41d9ee")
const MAX_ALIVE_ENEMIES: int = 14
const PLAYER_LIVES: int = 3

var mode_id: String = "ffa"
var difficulty: int = 1
var fx: BulletEffects
var hud: ModeHUD

var _map: Node3D
var _player: CharacterBody3D
var _spawn_manager: SpawnManager
var _rng := RandomNumberGenerator.new()
var _bots: Array[Bot] = []
var _scores: Dictionary = {}
var _player_name: String = "You"
var _time_left: float = 0.0
var _finished: bool = false
var _header_timer: float = 0.0
var _player_kills: int = 0
var _player_deaths: int = 0
var _last_player_attacker: Node = null
var _used_names: Array[String] = []

# waves
var _wave: int = 0
var _wave_pending: Array = []
var _wave_active: bool = false
var _intermission: float = 3.0
var _spawn_timer: float = 0.0
var _lives: int = PLAYER_LIVES
var _ally_check: float = 4.0
var _wave_kills: int = 0
var _gadgets: GadgetController

func setup(map: Node3D, player: CharacterBody3D, spawn_manager: SpawnManager, selected_mode: String, selected_difficulty: int) -> void:
    _map = map
    _player = player
    _spawn_manager = spawn_manager
    mode_id = selected_mode if MODES.has(selected_mode) else "ffa"
    difficulty = clampi(selected_difficulty, 0, 2)
    _rng.randomize()
    _player_name = "تو" if Loc.language == "fa" else "You"
    add_to_group("mode_manager")
    fx = BulletEffects.new()
    fx.name = "BotEffects"
    add_child(fx)
    hud = ModeHUD.new()
    hud.name = "ModeHUD"
    hud.manager = self
    add_child(hud)

    _player.add_to_group("combatants")
    _player.set_meta("team", _player_team())
    _player.set_meta("display_name", _player_name)
    var health := _player.get_node_or_null("HealthComponent") as HealthComponent
    if health != null:
        health.max_health = 100.0 + 25.0 * float(SaveManager.get_upgrade_level("health"))
        health.max_armor = 100.0
        health.reset()
        health.damaged.connect(_on_player_damaged)
    _apply_start_armor()
    _player.connect("died", Callable(self, "_on_player_died"))
    _player.connect("respawned", Callable(self, "_apply_start_armor"))
    EventBus.combatant_killed.connect(_on_combatant_killed)
    BotNav.bake(_map, self)

    var config: Dictionary = MODES[mode_id]
    _player.global_transform = get_player_spawn_transform()
    if str(config["kind"]) == "deathmatch":
        _time_left = float(config["time"])
        _setup_deathmatch(config)
    else:
        _setup_waves()
    SaveManager.set_progress("last_mode", mode_id)
    hud.banner(_mode_title(), 3.0)
    _update_header()

func _exit_tree() -> void:
    if EventBus.combatant_killed.is_connected(_on_combatant_killed):
        EventBus.combatant_killed.disconnect(_on_combatant_killed)
    BotNav.reset()

func _player_team() -> String:
    match mode_id:
        "tdm":
            return "alpha"
        "zombie", "assault":
            return "player"
        _:
            return "ffa_player"

func _apply_start_armor() -> void:
    var health := _player.get_node_or_null("HealthComponent") as HealthComponent
    var armor_level: int = SaveManager.get_upgrade_level("armor")
    if health != null and armor_level > 0:
        health.add_armor(25.0 * float(armor_level))

func _mode_title() -> String:
    return Loc.t("mode_" + mode_id)

# ---------------------------------------------------------------- spawning

func get_player_spawn_transform() -> Transform3D:
    if mode_id == "tdm":
        return _pick_spawn("alpha")
    if mode_id == "zombie":
        # Maps may define a safe "survivor" start area; otherwise any point is used.
        return _pick_spawn("survivor")
    return _pick_spawn("")

func _pick_spawn(team_key: String) -> Transform3D:
    var points: Array[Node3D] = _spawn_manager.get_spawn_points(team_key)
    if points.is_empty():
        points = _spawn_manager.get_spawn_points("")
    if points.is_empty():
        return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.1, 12.0))
    var living: Array[Node3D] = []
    for node in get_tree().get_nodes_in_group("combatants"):
        if node is Node3D and CombatUtil.is_alive(node):
            living.append(node as Node3D)
    var best: Node3D = null
    var best_clearance: float = -1.0
    var order: Array[Node3D] = []
    order.assign(points)
    order.shuffle()
    for point in order:
        var clearance: float = 9999.0
        for other in living:
            clearance = minf(clearance, point.global_position.distance_to(other.global_position))
        if clearance >= 22.0:
            best = point
            break
        if clearance > best_clearance:
            best_clearance = clearance
            best = point
    var result: Transform3D = best.global_transform
    result.origin += Vector3(_rng.randf_range(-1.2, 1.2), 0.05, _rng.randf_range(-1.2, 1.2))
    return result

func _unique_name() -> String:
    for attempt in range(20):
        var candidate: String = BotDefinitions.random_name(_rng)
        if not _used_names.has(candidate):
            _used_names.append(candidate)
            return candidate
    return BotDefinitions.random_name(_rng)

func _spawn_bot(spec: Dictionary, at: Transform3D) -> Bot:
    var bot := Bot.new()
    bot.profile_id = str(spec["profile"])
    bot.team = str(spec["team"])
    bot.display_name = str(spec["name"])
    bot.difficulty = difficulty
    bot.fx = fx
    bot.mode_ref = self
    bot.always_hunt = bool(spec.get("hunt", false))
    bot.show_marker = bool(spec.get("marker", false))
    bot.use_team_look = bool(spec.get("team_look", false))
    bot.team_color = spec.get("color", Color(0, 0, 0, 0))
    bot.health_scale = float(spec.get("health_scale", 1.0))
    bot.weapon_override = str(spec.get("weapon", ""))
    bot.set_meta("spec", spec)
    add_child(bot)
    bot.global_transform = at
    bot.died.connect(_on_bot_died)
    _bots.append(bot)
    return bot

func _alive_bots() -> Array[Bot]:
    var result: Array[Bot] = []
    for bot in _bots:
        if is_instance_valid(bot) and bot.is_alive():
            result.append(bot)
    return result

func _count_alive_team(team_name: String) -> int:
    var count: int = 0
    for bot in _alive_bots():
        if bot.team == team_name:
            count += 1
    return count

# ---------------------------------------------------------------- deathmatch modes

func _setup_deathmatch(config: Dictionary) -> void:
    var bot_total: int = int(config["bots"])
    if mode_id == "ffa":
        _scores[_player_name] = 0
        var weapons: Array[String] = ["rifle", "smg", "shotgun", "revolver", "rifle", "lmg", "pistol"]
        for index in range(bot_total):
            var bot_name: String = _unique_name()
            _scores[bot_name] = 0
            var spec: Dictionary = {"profile": "ffa_fighter", "team": "ffa_%d" % index, "name": bot_name,
                "weapon": weapons[index % weapons.size()]}
            _spawn_bot(spec, _pick_spawn(""))
    else:
        _scores["alpha"] = 0
        _scores["bravo"] = 0
        var types: Array[String] = ["grunt", "rusher", "officer", "grunt", "marksman", "heavy", "grunt", "rusher", "officer", "grunt"]
        # Alpha = the player + (bots / 2) allies, Bravo = the rest, so the teams are even.
        var alpha_bots: int = bot_total / 2
        var bravo_bots: int = bot_total - alpha_bots
        for index in range(alpha_bots):
            var spec_a: Dictionary = {"profile": types[index % types.size()], "team": "alpha", "name": _unique_name(),
                "marker": true, "team_look": true, "color": ALPHA_COLOR}
            _spawn_bot(spec_a, _pick_spawn("alpha"))
        for index in range(bravo_bots):
            var spec_b: Dictionary = {"profile": types[(index + 3) % types.size()], "team": "bravo", "name": _unique_name(),
                "team_look": true, "color": BRAVO_COLOR}
            _spawn_bot(spec_b, _pick_spawn("bravo"))

func _queue_respawn(spec: Dictionary) -> void:
    var timer := get_tree().create_timer(3.0)
    timer.timeout.connect(func() -> void:
        if _finished or not is_instance_valid(self):
            return
        var key: String = "bravo" if str(spec["team"]) == "bravo" else ("alpha" if str(spec["team"]) == "alpha" else "")
        _spawn_bot(spec, _pick_spawn(key)))

# ---------------------------------------------------------------- wave modes

func _setup_waves() -> void:
    _intermission = 4.0
    _ensure_allies()
    _gadgets = GadgetController.new()
    _gadgets.name = "Gadgets"
    _player.add_child(_gadgets)
    _gadgets.setup(_player)

func _ensure_allies() -> void:
    var wanted: int = 2
    var have: int = _count_alive_team("player")
    var weapons: Array[String] = ["rifle", "smg", "shotgun", "lmg"]
    for index in range(wanted - have):
        var spec: Dictionary = {"profile": "grunt", "team": "player", "name": _unique_name(), "marker": true,
            "team_look": true, "color": ALLY_COLOR, "weapon": weapons[_rng.randi() % weapons.size()], "health_scale": 1.3}
        var at: Transform3D = _player.global_transform
        at.origin += Vector3(_rng.randf_range(-3.0, 3.0), 0.1, _rng.randf_range(-3.0, 3.0))
        _spawn_bot(spec, at)

func _enemy_team() -> String:
    return str((MODES[mode_id] as Dictionary)["enemy_team"])

func _wave_list(wave: int) -> Array:
    var list: Array = []
    if mode_id == "zombie":
        if wave % 5 == 0:
            # Every fifth wave is a swarm made only of very fast, fragile sprinters.
            for index in range(mini(12 + wave * 2, 44)):
                list.append({"profile": "sprinter", "health_scale": 1.0 + 0.03 * float(wave - 1)})
        else:
            var total: int = mini(6 + wave * 3, 40)
            for index in range(total):
                var table: Array = [["walker", 10.0]]
                if wave >= 4:
                    table.append(["spitter", 2.5])
                list.append({"profile": _weighted(table), "health_scale": 1.0 + 0.06 * float(wave - 1)})
        # Tanks: wave 3 brings one, wave 6 two, wave 9 three, and so on.
        if wave % 3 == 0:
            for index in range(wave / 3):
                list.append({"profile": "brute", "health_scale": 1.0 + 0.05 * float(wave / 3 - 1)})
        # The big flamethrower zombie arrives once every ten waves.
        if wave % 10 == 0:
            list.append({"profile": "pyro", "health_scale": 1.0 + 0.2 * float(wave / 10 - 1)})
    else:
        var total_a: int = mini(4 + wave * 2, 30)
        if wave % 5 == 0:
            list.append({"profile": "heavy", "health_scale": 2.6 + 0.3 * float(wave / 5 - 1), "boss": true})
            total_a = total_a / 2
        for index in range(total_a):
            var table_a: Array = [["grunt", 10.0]]
            if wave >= 2:
                table_a.append(["rusher", 5.0])
                table_a.append(["officer", 3.0])
            if wave >= 3:
                table_a.append(["marksman", 3.0])
            if wave >= 4:
                table_a.append(["heavy", 1.5 + float(wave) / 3.0])
            list.append({"profile": _weighted(table_a), "health_scale": 1.0 + 0.05 * float(wave - 1)})
    list.shuffle()
    return list

func _weighted(table: Array) -> String:
    var total: float = 0.0
    for row in table:
        total += float((row as Array)[1])
    var roll: float = _rng.randf() * total
    for row in table:
        roll -= float((row as Array)[1])
        if roll <= 0.0:
            return str((row as Array)[0])
    return str((table[0] as Array)[0])

func _start_wave() -> void:
    _wave += 1
    _wave_kills = 0
    _wave_pending = _wave_list(_wave)
    _wave_active = true
    _spawn_timer = 0.5
    var banner_text: String = "%s %d" % [Loc.t("wave"), _wave]
    if mode_id == "zombie":
        if _wave % 10 == 0:
            banner_text += "  —  " + Loc.t("pyro_wave")
        elif _wave % 5 == 0:
            banner_text += "  —  " + Loc.t("sprint_wave")
    elif _wave % 5 == 0:
        banner_text += "  —  " + Loc.t("boss_wave")
    hud.banner(banner_text, 3.0)
    _ensure_allies()

func _spawn_next_enemy() -> void:
    var entry: Dictionary = _wave_pending.pop_back()
    var spec: Dictionary = {"profile": str(entry["profile"]), "team": _enemy_team(), "name": BotDefinitions.get_display_name(str(entry["profile"]), Loc.language),
        "hunt": mode_id == "zombie", "health_scale": float(entry.get("health_scale", 1.0))}
    if mode_id == "assault":
        spec["team_look"] = true
        spec["color"] = BRAVO_COLOR
    var horde_key: String = "horde" if mode_id == "zombie" else ""
    var at: Transform3D = _pick_spawn(horde_key)
    # Waves come from the far side of the map, never on top of the player.
    var best: Transform3D = at
    var best_distance: float = at.origin.distance_to(_player.global_position)
    for attempt in range(3):
        var candidate: Transform3D = _pick_spawn(horde_key)
        var distance: float = candidate.origin.distance_to(_player.global_position)
        if distance > best_distance:
            best = candidate
            best_distance = distance
    _spawn_bot(spec, best)

func _process_waves(delta: float) -> void:
    _ally_check -= delta
    if _ally_check <= 0.0:
        _ally_check = 20.0
        _ensure_allies()
    if not _wave_active:
        _intermission -= delta
        if _intermission <= 0.0:
            _start_wave()
        return
    _spawn_timer -= delta
    if not _wave_pending.is_empty() and _spawn_timer <= 0.0 and _count_alive_team(_enemy_team()) < MAX_ALIVE_ENEMIES:
        _spawn_next_enemy()
        _spawn_timer = 0.8
    if _wave_pending.is_empty() and _count_alive_team(_enemy_team()) == 0:
        _wave_active = false
        _intermission = 12.0
        var bonus: int = 30 + 12 * _wave
        SaveManager.add_credits(bonus)
        hud.banner("%s %d %s  +%d" % [Loc.t("wave"), _wave, Loc.t("cleared"), bonus], 3.5)
        hud.add_feed(Loc.t("shop_hint"), Color("#ffd166"))
        var weapon := _player.get_node_or_null("WeaponController")
        var full_resupply: bool = mode_id == "zombie" and _wave % 5 == 0
        if full_resupply and weapon != null and weapon.has_method("refill"):
            # After every fifth wave: all guns full, plus 4 grenades and 4 traps.
            weapon.call("refill")
            if _gadgets != null:
                _gadgets.refill()
            hud.add_feed(Loc.t("resupplied"), Color("#7fd6ff"))
        elif weapon != null and weapon.has_method("give_ammo_pack"):
            weapon.call("give_ammo_pack")
        var health := _player.get_node_or_null("HealthComponent") as HealthComponent
        if health != null:
            health.restore(30.0)

# ---------------------------------------------------------------- roam targets

func get_roam_point(bot: Bot) -> Vector3:
    var player_position: Vector3 = _player.global_position
    var kind: String = str((MODES[mode_id] as Dictionary)["kind"])
    if kind == "waves":
        if bot.team == "player":
            # Allies stay close to the player.
            return player_position + Vector3(_rng.randf_range(-9.0, 9.0), 0.0, _rng.randf_range(-9.0, 9.0))
        return player_position + Vector3(_rng.randf_range(-14.0, 14.0), 0.0, _rng.randf_range(-14.0, 14.0))
    if mode_id == "tdm":
        var enemy_team: String = "bravo" if bot.team == "alpha" else "alpha"
        var points: Array[Node3D] = _spawn_manager.get_spawn_points(enemy_team)
        if not points.is_empty() and _rng.randf() < 0.6:
            var pick: Node3D = points[_rng.randi() % points.size()]
            return pick.global_position + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0))
    # Free-for-all: wander toward other fighters, the player included.
    var living: Array[Node3D] = []
    for node in get_tree().get_nodes_in_group("combatants"):
        if node != bot and node is Node3D and CombatUtil.is_alive(node):
            living.append(node as Node3D)
    if not living.is_empty() and _rng.randf() < 0.7:
        var other: Node3D = living[_rng.randi() % living.size()]
        return other.global_position + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0))
    return Vector3(_rng.randf_range(-62.0, 62.0), 0.0, _rng.randf_range(-62.0, 62.0))

# ---------------------------------------------------------------- events

func _on_player_damaged(_amount: float, source: Node) -> void:
    if source != null:
        _last_player_attacker = source

func _on_player_died() -> void:
    _player_deaths += 1
    var killer: Node = _last_player_attacker if (_last_player_attacker != null and is_instance_valid(_last_player_attacker)) else null
    EventBus.combatant_killed.emit(_player, killer, false)
    if str((MODES[mode_id] as Dictionary)["kind"]) == "waves":
        _lives -= 1
        if _lives <= 0:
            _finish(false)

func _on_bot_died(bot: Bot, killer: Node, headshot: bool) -> void:
    _bots.erase(bot)
    if killer != null and killer.is_in_group("player_controller"):
        _player_kills += 1
        _wave_kills += 1
    _maybe_drop(bot)
    if _finished:
        return
    var config: Dictionary = MODES[mode_id]
    if str(config["kind"]) == "deathmatch":
        _queue_respawn(bot.get_meta("spec") as Dictionary)

func _maybe_drop(bot: Bot) -> void:
    if mode_id == "zombie" and _gadgets != null:
        # Rare supply crate: ammo + grenades + traps. Big zombies drop it far more often.
        var supply_chance: float = 0.04
        var profile_id: String = str(bot.profile_id)
        if profile_id == "brute":
            supply_chance = 0.3
        elif profile_id == "pyro":
            supply_chance = 1.0
        if _rng.randf() < supply_chance:
            var crate := Pickup.new()
            crate.kind = "supply"
            add_child(crate)
            crate.global_position = bot.global_position + Vector3(0.0, 0.1, 0.0)
            return
    var chance: float = 0.22 if bot.is_zombie else 0.18
    if mode_id == "ffa" or mode_id == "tdm":
        chance = 0.0
    if _rng.randf() > chance:
        return
    var pickup := Pickup.new()
    var roll: float = _rng.randf()
    pickup.kind = "health" if roll < 0.45 else ("ammo" if roll < 0.8 else "armor")
    add_child(pickup)
    pickup.global_position = bot.global_position + Vector3(0.0, 0.1, 0.0)

func _display_name_of(node: Node) -> String:
    if node == null or not is_instance_valid(node):
        return "?"
    if node == _player:
        return _player_name
    return str(node.get_meta("display_name", node.name))

func _on_combatant_killed(victim: Node, killer: Node, headshot: bool) -> void:
    if _finished:
        return
    var killer_name: String = _display_name_of(killer) if killer != null else ""
    var victim_name: String = _display_name_of(victim)
    var feed_color: Color = Color("#ffd166") if (killer == _player) else (Color("#ff7a6b") if victim == _player else Color(0.85, 0.9, 0.95))
    if killer != null:
        hud.add_feed("%s  ▸  %s%s" % [killer_name, victim_name, "  ⌖" if headshot else ""], feed_color)
    else:
        hud.add_feed("%s  ✖" % victim_name, feed_color)
    var config: Dictionary = MODES[mode_id]
    if str(config["kind"]) != "deathmatch":
        return
    if killer == null or killer == victim or not CombatUtil.is_hostile(killer, victim):
        return
    var key: String = _display_name_of(killer) if mode_id == "ffa" else CombatUtil.team_of(killer)
    _scores[key] = int(_scores.get(key, 0)) + 1
    if int(_scores[key]) >= int(config["kill_limit"]):
        _finish(true, key)

# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
    if _finished:
        return
    var config: Dictionary = MODES[mode_id]
    if str(config["kind"]) == "deathmatch":
        _time_left -= delta
        if _time_left <= 0.0:
            _finish(true, "")
            return
    else:
        _process_waves(delta)
    _header_timer -= delta
    if _header_timer <= 0.0:
        _header_timer = 0.25
        _update_header()

func _format_time(seconds: float) -> String:
    var total: int = maxi(0, int(ceil(seconds)))
    return "%d:%02d" % [total / 60, total % 60]

func _update_header() -> void:
    var config: Dictionary = MODES[mode_id]
    var text: String = ""
    match mode_id:
        "ffa":
            text = "%s  %d / %d      %s" % [Loc.t("kills"), int(_scores.get(_player_name, 0)), int(config["kill_limit"]), _format_time(_time_left)]
        "tdm":
            text = "%s %d   —   %d %s      %s" % [Loc.t("team_alpha"), int(_scores.get("alpha", 0)), int(_scores.get("bravo", 0)), Loc.t("team_bravo"), _format_time(_time_left)]
        _:
            var remaining: int = _wave_pending.size() + _count_alive_team(_enemy_team())
            if _wave_active:
                text = "%s %d      %s %d      ♥ %d" % [Loc.t("wave"), _wave, Loc.t("enemies"), remaining, maxi(_lives, 0)]
                text += _gadget_text()
            else:
                text = "%s %d      %s %d      ♥ %d" % [Loc.t("next_wave"), _wave + 1, Loc.t("in_seconds"), maxi(0, int(ceil(_intermission))), maxi(_lives, 0)]
                text += _gadget_text()
    hud.set_header(text)

func _gadget_text() -> String:
    if _gadgets == null:
        return ""
    return "      %s %d   %s %d" % [Loc.t("grenades"), _gadgets.grenades, Loc.t("traps"), _gadgets.traps]

func get_gadgets() -> GadgetController:
    return _gadgets

func get_mode_id() -> String:
    return mode_id

# ---------------------------------------------------------------- finishing

func _finish(played_to_end: bool, winner_key: String = "") -> void:
    if _finished:
        return
    _finished = true
    var config: Dictionary = MODES[mode_id]
    var title: String = ""
    var lines: Array[String] = []
    var bonus: int = 0
    var victory: bool = false
    if str(config["kind"]) == "deathmatch":
        if mode_id == "ffa":
            var ranking: Array = []
            for key in _scores.keys():
                ranking.append([str(key), int(_scores[key])])
            ranking.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
            var place: int = 1
            for index in range(ranking.size()):
                if str((ranking[index] as Array)[0]) == _player_name:
                    place = index + 1
            victory = place == 1
            title = Loc.t("victory") if victory else Loc.t("match_over")
            for index in range(mini(5, ranking.size())):
                var row: Array = ranking[index]
                lines.append("%d.  %s   —   %d" % [index + 1, str(row[0]), int(row[1])])
            lines.append("")
            lines.append("%s: %d     %s: %d" % [Loc.t("kills"), _player_kills, Loc.t("deaths"), _player_deaths])
            bonus = 220 if victory else maxi(40, 140 - place * 15)
        else:
            var alpha: int = int(_scores.get("alpha", 0))
            var bravo: int = int(_scores.get("bravo", 0))
            victory = alpha > bravo
            title = Loc.t("victory") if victory else (Loc.t("defeat") if bravo > alpha else Loc.t("draw"))
            lines.append("%s  %d   —   %d  %s" % [Loc.t("team_alpha"), alpha, bravo, Loc.t("team_bravo")])
            lines.append("")
            lines.append("%s: %d     %s: %d" % [Loc.t("kills"), _player_kills, Loc.t("deaths"), _player_deaths])
            bonus = 240 if victory else 70
    else:
        title = Loc.t("game_over")
        var reached: int = maxi(0, _wave - (0 if _wave_active else 0))
        lines.append("%s: %d" % [Loc.t("waves_reached"), reached])
        lines.append("%s: %d" % [Loc.t("kills"), _player_kills])
        bonus = 20 * reached
        var best_key: String = "best_wave_" + mode_id
        if reached > int(SaveManager.get_progress(best_key, 0)):
            SaveManager.set_progress(best_key, reached)
            lines.append(Loc.t("new_record"))
    if bonus > 0:
        SaveManager.add_credits(bonus)
        lines.append("")
        lines.append("%s +%d" % [Loc.t("credits"), bonus])
    SaveManager.set_progress("matches_played", int(SaveManager.get_progress("matches_played", 0)) + 1)
    SaveManager.flush()
    var summary: Dictionary = {"title": title, "lines": lines, "victory": victory, "bonus": bonus}
    match_over.emit(summary)
    hud.show_results(title, lines, victory)
