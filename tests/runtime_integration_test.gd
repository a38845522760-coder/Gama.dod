extends SceneTree

func _initialize() -> void:
    call_deferred("_run_integration")

func _run_integration() -> void:
    var failures: Array[String] = []
    var arena_resource := load("res://scenes/world/core_test_arena.tscn")
    if not (arena_resource is PackedScene):
        push_error("Runtime integration: arena scene failed to load")
        quit(1)
        return

    var arena := (arena_resource as PackedScene).instantiate()
    root.add_child(arena)
    await process_frame
    await physics_frame

    for node_path in [
        "Player",
        "DynamicPhysicsCrate",
        "RollingPhysicsCanister",
        "MovingPhysicsPlatform",
        "SurfacePanel_Concrete",
        "SurfacePanel_PaintedSteel",
        "SurfacePanel_Rubber",
        "SurfacePanel_Grate",
        "ServiceBayMachineBase",
        "AnimatedValveWheel_0",
        "AnimatedPressureGauge_0",
        "CoreHUD",
        "TouchHUD",
        "PauseMenu",
        "TrainingTarget_0",
        "HazardZone",
        "SupplyStation",
    ]:
        if arena.get_node_or_null(node_path) == null:
            failures.append("Expected runtime node is missing: %s" % node_path)

    var player := arena.get_node_or_null("Player") as CharacterBody3D
    var spawn_manager := arena.get_node_or_null("SpawnManager")
    if spawn_manager == null or not spawn_manager.has_method("_is_spawn_transform_clear"):
        failures.append("Collision-aware spawn validation is missing")
    else:
        var secondary_spawn: Transform3D = spawn_manager.call("get_next_spawn_transform", "")
        if not bool(spawn_manager.call("_is_spawn_transform_clear", secondary_spawn)):
            failures.append("Spawn manager returned a transform blocked by the player-sized capsule query")
    if player != null:
        var viewmodel := player.get_node_or_null("CameraPivot/Camera3D/EquipmentViewmodel")
        if viewmodel == null:
            failures.append("Runtime player viewmodel is missing")
        elif viewmodel.find_child("Muzzle", true, false) == null or viewmodel.find_child("RightIndex", true, false) == null or viewmodel.find_child("LeftThumb", true, false) == null:
            failures.append("Rifle viewmodel must have a muzzle and both hands")
        if not player.has_method("get_movement_snapshot"):
            failures.append("Runtime movement telemetry is missing")
        if not player.has_method("_refresh_surface_profile") or not player.has_method("_update_sprint_stamina") or not player.has_method("_blend_surface_response"):
            failures.append("Surface response or sprint endurance subsystem is missing")
        var surface_probe_nodes := player.find_children("SurfaceProbe_*", "RayCast3D", true, false)
        if surface_probe_nodes.size() != 5:
            failures.append("Player must have five-footprint surface probes (center, left, right, front, rear)")
        var movement_snapshot: Dictionary = player.call("get_movement_snapshot")
        for snapshot_key in ["stamina", "stamina_max", "surface_speed_multiplier", "surface_traction_multiplier"]:
            if not movement_snapshot.has(snapshot_key):
                failures.append("Movement snapshot is missing telemetry: %s" % snapshot_key)
        var capsule := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if capsule == null or not (capsule.shape is CapsuleShape3D):
            failures.append("Runtime player capsule is invalid")


    # ---- weapon: firing consumes ammo, damages a target, leaves a persistent hole ----------
    var weapon := player.get_node_or_null("WeaponController") if player != null else null
    var target := arena.get_node_or_null("TrainingTarget_0")
    if weapon == null:
        failures.append("Player has no WeaponController")
    else:
        var start_ammo: int = int(weapon.call("get_magazine"))
        weapon.call("_try_fire")
        if int(weapon.call("get_magazine")) != start_ammo - 1:
            failures.append("Firing must consume exactly one round")
        var effects = weapon.call("get_effects")
        effects.call("spawn_hole", Vector3(0.0, 1.0, -23.6), Vector3(0.0, 0.0, 1.0), arena.get_node_or_null("NorthWall"))
        if int(effects.call("get_hole_count")) < 1:
            failures.append("Bullet holes must persist after being spawned")
        weapon.call("refill")
        if int(weapon.call("get_magazine")) != int(weapon.call("get_magazine_size")):
            failures.append("Refill must restore a full magazine")
    if target == null or not target.has_method("receive_hit"):
        failures.append("Training target must expose receive_hit")
    else:
        var result: Dictionary = target.call("receive_hit", {"damage": 500.0, "position": target.global_position + Vector3(0, 1.0, 0), "normal": Vector3.BACK})
        if not bool(result.get("killed", false)):
            failures.append("Lethal hit must destroy a training target")

    # ---- crouch toggle and slide ---------------------------------------------------------
    if player != null:
        player.call("request_crouch_tap")
        if not bool(player.get("_crouch_toggled")):
            failures.append("Tapping crouch while standing must toggle crouch on")
        player.call("request_crouch_tap")
        if bool(player.get("_crouch_toggled")) or not bool(player.get("_prone_toggled")):
            failures.append("Tapping crouch a second time must lie the player down")
        player.call("request_crouch_tap")
        if bool(player.get("_crouch_toggled")) or bool(player.get("_prone_toggled")):
            failures.append("Tapping crouch a third time must stand up")

    # Verify standing clearance with an overhead beam, then verify the same
    # query allows standing again after the obstruction is removed.
    if player != null:
        var player_capsule_node := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
        var player_capsule := player_capsule_node.shape as CapsuleShape3D if player_capsule_node != null else null
        if player_capsule != null:
            player.set_physics_process(false)
            var saved_height := player_capsule.height
            var saved_position := player_capsule_node.position
            player_capsule.height = 1.28
            player_capsule_node.position.y = 0.64
            player.set("_current_capsule_height", 1.28)

            var test_ceiling := StaticBody3D.new()
            test_ceiling.name = "TemporaryHeadroomTestBeam"
            test_ceiling.collision_layer = 1
            test_ceiling.collision_mask = 1
            var ceiling_shape_node := CollisionShape3D.new()
            var ceiling_shape := BoxShape3D.new()
            ceiling_shape.size = Vector3(2.0, 0.10, 2.0)
            ceiling_shape_node.shape = ceiling_shape
            test_ceiling.add_child(ceiling_shape_node)
            arena.add_child(test_ceiling)
            test_ceiling.global_position = player.global_position + Vector3(0.0, 1.57, 0.0)
            await physics_frame
            if bool(player.call("_has_standing_clearance")):
                failures.append("Standing clearance must reject a low overhead beam")
            test_ceiling.queue_free()
            await physics_frame
            if not bool(player.call("_has_standing_clearance")):
                failures.append("Standing clearance must allow standing after the beam is removed")
            player_capsule.height = saved_height
            player_capsule_node.position = saved_position
            player.set("_current_capsule_height", saved_height)
            player.set_physics_process(true)

    # Multiple player instances must never share a mutable crouch collision resource.
    var player_scene := load("res://scenes/player/player.tscn") as PackedScene
    if player_scene != null:
        var second_player := player_scene.instantiate() as CharacterBody3D
        second_player.position = Vector3(100.0, 0.0, 0.0)
        root.add_child(second_player)
        await process_frame
        var first_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D if player != null else null
        var second_shape := second_player.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if first_shape == null or second_shape == null or first_shape.shape == null or second_shape.shape == null:
            failures.append("Player capsule resources must exist for both instances")
        elif first_shape.shape.get_instance_id() == second_shape.shape.get_instance_id():
            failures.append("Player instances must own independent capsule shape resources")
        second_player.queue_free()
        await process_frame

    for panel_name in ["SurfacePanel_Concrete", "SurfacePanel_PaintedSteel", "SurfacePanel_Rubber", "SurfacePanel_Grate"]:
        var panel := arena.get_node_or_null(panel_name) as StaticBody3D
        if panel == null or not panel.has_meta("surface_type") or not panel.has_meta("traction_multiplier"):
            failures.append("Surface response panel is missing profile metadata: %s" % panel_name)

    var canister := arena.get_node_or_null("RollingPhysicsCanister") as RigidBody3D
    if canister == null or not canister.is_in_group("pushable"):
        failures.append("Rolling canister must be a pushable rigid body")

    var crate := arena.get_node_or_null("DynamicPhysicsCrate") as RigidBody3D
    if crate == null or not crate.is_in_group("pushable"):
        failures.append("Dynamic crate must be a pushable rigid body")

    if failures.is_empty():
        print("IRON_YARD_RUNTIME_INTEGRATION: PASS")
        arena.queue_free()
        await process_frame
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        arena.queue_free()
        await process_frame
        quit(1)
