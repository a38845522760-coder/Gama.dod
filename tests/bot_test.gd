extends SceneTree

## Checks the Phase 3 content: weapon table, bevel meshes, every enemy profile, the AI loop
## and the kill pipeline. Run: godot --headless --path . --script res://tests/bot_test.gd

var _failures: Array[String] = []
var _killed_count: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # ---- weapons ----------------------------------------------------------------------
    for weapon_id in WeaponDefinitions.ORDER:
        var def: Dictionary = WeaponDefinitions.get_definition(weapon_id)
        for key in ["damage", "rounds_per_minute", "magazine_size", "reserve_ammo", "reload_time", "range", "pellets", "style"]:
            if not def.has(key):
                _failures.append("Weapon %s is missing %s" % [weapon_id, key])
        var model: Node3D = WeaponModels.build(weapon_id)
        if WeaponModels.get_muzzle(model) == null:
            _failures.append("Weapon model %s has no muzzle" % weapon_id)
        model.free()

    # ---- bevel mesh -----------------------------------------------------------------------
    var mesh: ArrayMesh = BevelMesh.box(Vector3(2.0, 1.0, 3.0), 0.05)
    if mesh.get_surface_count() != 1:
        _failures.append("BevelMesh must have one surface")
    else:
        var arrays: Array = mesh.surface_get_arrays(0)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        if vertices.size() != 132:
            _failures.append("BevelMesh expected 132 vertices, got %d" % vertices.size())

    # ---- bots ------------------------------------------------------------------------------
    var floor_body := StaticBody3D.new()
    var floor_shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(80.0, 1.0, 80.0)
    floor_shape.shape = box
    floor_body.add_child(floor_shape)
    floor_body.position = Vector3(0.0, -0.5, 0.0)
    root.add_child(floor_body)

    var bots: Array[Bot] = []
    var index: int = 0
    for profile_id in BotDefinitions.PROFILES.keys():
        var bot := Bot.new()
        bot.profile_id = str(profile_id)
        bot.team = "team_%d" % index
        bot.display_name = "T%d" % index
        bot.always_hunt = true
        root.add_child(bot)
        bot.global_position = Vector3(float(index % 5) * 6.0 - 12.0, 0.2, float(index / 5) * 6.0 - 3.0)
        bot.died.connect(func(_b: Bot, _k: Node, _h: bool) -> void: _killed_count += 1)
        bots.append(bot)
        index += 1
    for frame in range(90):
        await process_frame
    for bot in bots:
        if not bot.is_alive():
            _failures.append("Bot %s died on its own" % bot.profile_id)
        if bot.global_position.y < -5.0:
            _failures.append("Bot %s fell through the floor" % bot.profile_id)
    var first: Bot = bots[0]
    var result: Dictionary = first.receive_hit({"damage": 99999.0, "position": first.global_position + Vector3(0, 1.0, 0), "normal": Vector3.UP, "source": bots[1]})
    if not bool(result.get("killed", false)) or first.is_alive():
        _failures.append("A lethal hit must kill a bot")
    if _killed_count != 1:
        _failures.append("Exactly one died signal expected, got %d" % _killed_count)
    var friendly := CombatUtil.is_hostile(bots[2], bots[2])
    if friendly:
        _failures.append("A fighter must not be hostile to itself")

    if _failures.is_empty():
        print("IRON_YARD_BOT_TEST: PASS")
        quit(0)
    else:
        for failure in _failures:
            push_error(failure)
        print("IRON_YARD_BOT_TEST: FAIL (%d)" % _failures.size())
        quit(1)
