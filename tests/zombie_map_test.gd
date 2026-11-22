extends SceneTree

## Headless check of the zombie map, Tesla gun, wave rules and time-based health.
## Run: godot --headless --path . --script res://tests/zombie_map_test.gd

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures: Array[String] = []
    AppState.pending_mode = "zombie"
    var packed := load("res://scenes/world/zombie_map.tscn")
    if not (packed is PackedScene):
        push_error("Zombie map scene failed to load")
        quit(1)
        return
    var map := (packed as PackedScene).instantiate()
    root.add_child(map)
    await process_frame
    await physics_frame
    await physics_frame

    for node_path in ["Player", "WorldEnvironment", "Moon", "RegionManager", "SpawnManager", "SessionHelper", "ModeManager", "Regions/Core"]:
        if map.get_node_or_null(node_path) == null:
            failures.append("Map node is missing: %s" % node_path)
    if get_nodes_in_group("spawn_points").size() < 24:
        failures.append("Expected at least 24 spawn points")
    var horde: int = 0
    var survivor: int = 0
    for spawn in get_nodes_in_group("spawn_points"):
        if str(spawn.get("team_id")) == "horde":
            horde += 1
        elif str(spawn.get("team_id")) == "survivor":
            survivor += 1
    if horde < 12 or survivor < 4:
        failures.append("Need horde and survivor spawn groups (got %d / %d)" % [horde, survivor])
    var tesla_shops: int = 0
    for node in map.find_children("WeaponShop_*", "", true, false):
        if (node.get("stock") as Array).has("tesla"):
            tesla_shops += 1
    if tesla_shops != 1:
        failures.append("Exactly one shop should sell the Tesla gun (got %d)" % tesla_shops)

    # Tesla gun numbers from the design.
    var tesla: Dictionary = WeaponDefinitions.get_definition("tesla")
    if int(tesla["magazine_size"]) != 5 or int(tesla["reserve_ammo"]) != 30:
        failures.append("Tesla gun must have a 5-round magazine and 30 reserve")
    if int(tesla["chain_targets_min"]) != 3 or int(tesla["chain_targets_max"]) != 5:
        failures.append("Tesla gun must chain 3-5 targets")

    # Wave rules.
    var manager: ModeManager = map.get_node("ModeManager")
    for wave in range(1, 31):
        var list: Array = manager._wave_list(wave)
        var counts: Dictionary = {}
        for entry in list:
            var id: String = str((entry as Dictionary)["profile"])
            counts[id] = int(counts.get(id, 0)) + 1
        if int(counts.get("brute", 0)) != (wave / 3 if wave % 3 == 0 else 0):
            failures.append("Wave %d: wrong brute count %d" % [wave, int(counts.get("brute", 0))])
        if int(counts.get("pyro", 0)) != (1 if wave % 10 == 0 else 0):
            failures.append("Wave %d: wrong pyro count" % wave)
        if wave % 5 == 0:
            for id in counts.keys():
                if id != "sprinter" and id != "brute" and id != "pyro":
                    failures.append("Wave %d should only hold sprinters (plus tanks/pyro)" % wave)
        elif int(counts.get("sprinter", 0)) > 0:
            failures.append("Wave %d should not hold sprinters" % wave)

    # Time-based health: regenerates fully ~6 s after 3 s without damage.
    var health := HealthComponent.new()
    health.regen_enabled = true
    root.add_child(health)
    health.apply_damage(70.0)
    for step in range(60):
        health._process(0.05)
    if health.current_health > 31.0:
        failures.append("Health must not regenerate during the first 3 seconds")
    for step in range(130):
        health._process(0.05)
    if health.current_health < health.max_health - 0.5:
        failures.append("Health should be full after ~6 s of regeneration")

    # Gadgets start full.
    var gadgets: GadgetController = manager.get_gadgets()
    if gadgets == null or gadgets.grenades != 4 or gadgets.traps != 4:
        failures.append("Gadgets should start with 4 grenades and 4 traps")

    if failures.is_empty():
        print("[IronYard] zombie map test passed")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
