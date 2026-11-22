extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures: Array[String] = []
    # Training targets are spawned only in practice mode; make the test's
    # requested map state explicit instead of depending on the app default.
    var previous_mode: String = AppState.pending_mode
    AppState.pending_mode = "practice"
    var packed := load("res://scenes/world/iron_yard_map.tscn")
    if not (packed is PackedScene):
        push_error("Iron Yard map scene failed to load")
        quit(1)
        return
    var map := (packed as PackedScene).instantiate()
    root.add_child(map)
    await process_frame
    await physics_frame
    await physics_frame

    for node_path in ["Player", "WorldEnvironment", "Sun", "WeatherSystem", "RegionManager", "SpawnManager", "SessionHelper", "CoreHUD", "TouchHUD", "PauseMenu", "Regions/Core"]:
        if map.get_node_or_null(node_path) == null:
            failures.append("Map node is missing: %s" % node_path)
    if map.find_child("TrainingTarget_0", true, false) == null:
        failures.append("Map node is missing: TrainingTarget_0")

    var stats: Dictionary = map.call("get_layout_stats")
    if int(stats.get("buildings", 0)) < 5:
        failures.append("Map needs at least 5 buildings (got %d)" % int(stats.get("buildings", 0)))
    if int(stats.get("containers", 0)) < 40:
        failures.append("Map needs at least 40 containers (got %d)" % int(stats.get("containers", 0)))
    if int(stats.get("trucks", 0)) < 3 or int(stats.get("cranes", 0)) < 2 or int(stats.get("trees", 0)) < 20:
        failures.append("Map is missing trucks, cranes or vegetation")

    var spawns := get_nodes_in_group("spawn_points")
    if spawns.size() < 16:
        failures.append("Expected at least 16 spawn points, got %d" % spawns.size())
    var alpha: int = 0
    var bravo: int = 0
    for spawn in spawns:
        if str(spawn.get("team_id")) == "alpha":
            alpha += 1
        elif str(spawn.get("team_id")) == "bravo":
            bravo += 1
    if alpha != bravo or alpha < 4:
        failures.append("Team spawns must be balanced (alpha %d / bravo %d)" % [alpha, bravo])

    var spawn_manager := map.get_node_or_null("SpawnManager")
    if spawn_manager != null:
        for team in ["alpha", "bravo", ""]:
            var spawn_transform: Transform3D = spawn_manager.call("get_next_spawn_transform", team)
            if not bool(spawn_manager.call("_is_spawn_transform_clear", spawn_transform)):
                failures.append("Spawn for team '%s' is blocked by geometry" % team)

    var weather := map.get_node_or_null("WeatherSystem")
    if weather != null:
        for weather_id in ["clear", "overcast", "fog", "rain", "dusk", "night"]:
            if not bool(weather.call("set_weather", weather_id, true)):
                failures.append("Weather preset failed: %s" % weather_id)
        if weather.call("set_weather", "tornado"):
            failures.append("Unknown weather ids must be rejected")
        weather.call("set_weather", "clear", true)

    var region_manager := map.get_node_or_null("RegionManager")
    if region_manager != null:
        region_manager.call("refresh")
        var total: int = int(region_manager.call("get_total_count"))
        if total < 8:
            failures.append("Expected at least 8 streaming regions, got %d" % total)
        var player := map.get_node_or_null("Player") as Node3D
        player.global_position = Vector3(-70.0, 1.0, 70.0)
        root.get_node("SettingsManager").call("set_quality_preset", "low")
        region_manager.call("refresh")
        if int(region_manager.call("get_visible_count")) >= total:
            failures.append("Low quality must hide far regions")
        root.get_node("SettingsManager").call("set_quality_preset", "ultra")
        region_manager.call("refresh")
        if int(region_manager.call("get_visible_count")) != total:
            failures.append("Ultra quality must show every region")
        root.get_node("SettingsManager").call("set_quality_preset", "medium")

    var player_node := map.get_node_or_null("Player")
    if player_node != null:
        player_node.call("toggle_camera_view")
        await process_frame
        if not bool(player_node.call("is_third_person")):
            failures.append("Camera button must switch to third person")
        player_node.call("toggle_camera_view")

    AppState.pending_mode = previous_mode
    if failures.is_empty():
        print("IRON_YARD_MAP_TEST: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("IRON_YARD_MAP_TEST: FAIL (%d)" % failures.size())
        quit(1)
