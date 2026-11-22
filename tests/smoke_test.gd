extends SceneTree

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var failures: Array[String] = []

    # ---- scenes ------------------------------------------------------------------
    for scene_path in [
        "res://scenes/boot/boot.tscn",
        "res://scenes/ui/main_menu.tscn",
        "res://scenes/player/player.tscn",
        "res://scenes/world/core_test_arena.tscn",
        "res://scenes/world/iron_yard_map.tscn",
    ]:
        if not (load(scene_path) is PackedScene):
            failures.append("Scene failed to load: %s" % scene_path)

    var player_resource := load("res://scenes/player/player.tscn")
    if player_resource is PackedScene:
        var player := (player_resource as PackedScene).instantiate()
        if not (player is CharacterBody3D):
            failures.append("Player root is not CharacterBody3D")
        for node_path in ["CollisionShape3D", "CameraPivot/Camera3D", "HealthComponent", "WeaponController", "CameraPivot/Camera3D/EquipmentViewmodel"]:
            if player.get_node_or_null(node_path) == null:
                failures.append("Player node is missing: %s" % node_path)
        for method_name in ["get_movement_snapshot", "request_crouch_tap", "is_crouch_active", "add_recoil", "respawn", "is_dead", "_try_start_slide"]:
            if not player.has_method(method_name):
                failures.append("Player method is missing: %s" % method_name)
        player.free()

    # ---- scripts -----------------------------------------------------------------
    for script_path in [
        "res://scripts/core/file_util.gd",
        "res://scripts/autoload/save_manager.gd",
        "res://scripts/autoload/settings_manager.gd",
        "res://scripts/autoload/localization.gd",
        "res://scripts/player/equipment_viewmodel.gd",
        "res://scripts/weapons/weapon_controller.gd",
        "res://scripts/weapons/weapon_definitions.gd",
        "res://scripts/weapons/weapon_audio.gd",
        "res://scripts/weapons/bullet_effects.gd",
        "res://scripts/world/training_target.gd",
        "res://scripts/world/hazard_zone.gd",
        "res://scripts/world/map_kit.gd",
        "res://scripts/world/industrial_map.gd",
        "res://scripts/world/weather_system.gd",
        "res://scripts/world/region_manager.gd",
        "res://scripts/world/supply_station.gd",
        "res://scripts/world/iron_yard_map.gd",
        "res://scripts/gameplay/session_helper.gd",
        "res://scripts/ui/core_hud.gd",
        "res://scripts/ui/crosshair.gd",
        "res://scripts/ui/pause_menu.gd",
        "res://scripts/ui/settings_screen.gd",
        "res://scripts/ui/main_menu.gd",
        "res://scripts/ui/ui_style.gd",
        "res://scripts/input/touch_button.gd",
        "res://scripts/input/touch_hud.gd",
        "res://scripts/input/virtual_joystick.gd",
        "res://scripts/world/rotating_valve_wheel.gd",
        "res://scripts/world/animated_pressure_gauge.gd",
        "res://scripts/world/rotating_industrial_fan.gd",
        "res://scripts/world/animated_warning_beacon.gd",
        "res://scripts/world/moving_test_platform.gd",
        "res://scripts/world/bevel_mesh.gd",
        "res://scripts/characters/soldier_model.gd",
        "res://scripts/weapons/weapon_models.gd",
        "res://scripts/enemies/bot.gd",
        "res://scripts/enemies/bot_definitions.gd",
        "res://scripts/enemies/bot_nav.gd",
        "res://scripts/enemies/combat_util.gd",
        "res://scripts/modes/mode_manager.gd",
        "res://scripts/ui/mode_hud.gd",
        "res://scripts/ui/mode_select_screen.gd",
        "res://scripts/ui/shop_screen.gd",
        "res://scripts/ui/arsenal_hud.gd",
        "res://scripts/ui/weapon_slot.gd",
        "res://scripts/ui/weapon_preview.gd",
        "res://scripts/shop/shop_catalog.gd",
        "res://scripts/gameplay/pickup.gd",
    ]:
        if load(script_path) == null:
            failures.append("Script failed to load/parse: %s" % script_path)

    for texture_path in [
        "res://assets/textures/concrete_albedo.png",
        "res://assets/textures/painted_steel_albedo.png",
        "res://assets/textures/rubber_albedo.png",
    ]:
        if not FileAccess.file_exists(texture_path):
            failures.append("Texture is missing: %s" % texture_path)

    # ---- input map -----------------------------------------------------------------
    for action_name in ["move_forward", "move_backward", "move_left", "move_right", "jump", "sprint", "crouch", "interact", "fire", "reload", "pause", "inspect_equipment", "toggle_camera", "cycle_weather", "zoom"]:
        if not InputMap.has_action(action_name):
            failures.append("Input action is missing: %s" % action_name)

    # ---- viewmodel API ---------------------------------------------------------------
    var viewmodel_script := load("res://scripts/player/equipment_viewmodel.gd")
    if viewmodel_script != null and viewmodel_script.can_instantiate():
        var viewmodel_instance: Object = viewmodel_script.new()
        for method_name in ["play_fire", "play_reload", "play_jump", "play_landing", "play_inspect", "update_motion", "get_muzzle_global_position"]:
            if not viewmodel_instance.has_method(method_name):
                failures.append("Viewmodel API is missing: %s" % method_name)
        viewmodel_instance.free()
    else:
        failures.append("Viewmodel script cannot be instantiated (parse error?)")

    # ---- health / armor ------------------------------------------------------------------
    var health := HealthComponent.new()
    health.current_health = 100.0
    health.add_armor(50.0)
    health.apply_damage(50.0)
    if absf(health.current_armor - 20.0) > 0.01 or absf(health.current_health - 80.0) > 0.01:
        failures.append("Armor must absorb 60%% of a hit (expected armor 20 / health 80, got %.1f / %.1f)" % [health.current_armor, health.current_health])
    health.free()

    # ---- weapon definitions ----------------------------------------------------------------
    var rifle := WeaponDefinitions.get_definition("rifle")
    for key in ["damage", "rounds_per_minute", "magazine_size", "reload_time", "range"]:
        if not rifle.has(key):
            failures.append("Rifle definition is missing: %s" % key)

    # ---- atomic file writing -----------------------------------------------------------------
    var test_path := "user://iy_smoke_test.json"
    var first_error := FileUtil.write_text_atomic(test_path, "{\"a\":1}")
    var second_error := FileUtil.write_text_atomic(test_path, "{\"a\":2}")
    if first_error != OK or second_error != OK or FileUtil.read_text(test_path).find("2") == -1:
        failures.append("Atomic file writing failed")
    FileUtil.remove_file(test_path)
    FileUtil.remove_file(test_path + ".bak")

    # ---- audio synthesis ---------------------------------------------------------------------
    var shot := WeaponAudio.get_stream("shot")
    if shot == null or shot.data.size() < 1000:
        failures.append("Procedural shot sound was not generated")

    if failures.is_empty():
        print("IRON_YARD_SMOKE_TEST: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("IRON_YARD_SMOKE_TEST: FAIL (%d)" % failures.size())
        quit(1)
