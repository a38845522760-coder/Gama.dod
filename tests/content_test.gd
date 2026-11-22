extends SceneTree

## Headless test for the downloadable-content logic (ContentCatalog) and the scripts around it.
## Run: godot --headless --path . --script res://tests/content_test.gd

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures: Array[String] = []

    for script_path in [
        "res://scripts/content/content_catalog.gd",
        "res://scripts/content/content_manager.gd",
        "res://scripts/ui/content_screen.gd",
        "res://scripts/world/pack_map.gd",
    ]:
        if load(script_path) == null:
            failures.append("Script failed to load/parse: %s" % script_path)
    if not (load("res://scenes/world/pack_map.tscn") is PackedScene):
        failures.append("pack_map.tscn failed to load")

    var good := JSON.stringify({"schema": 1, "packs": [
        {"id": "demo_arena", "type": "map", "version": 2, "file": "demo_arena_v2.pck", "size": 2048,
         "sha256": "ABCDEF", "name": {"fa": "الف", "en": "A"}, "modes": ["battle", "duel", "bogus", "duel"], "max_players": 6},
        {"id": "ak_47", "type": "weapon", "version": 1, "file": "ak_47_v1.pck", "size": 10},
        {"id": "../evil", "type": "map", "version": 1, "file": "x.pck"},
        {"id": "bad_file", "type": "map", "version": 1, "file": "../x.pck"},
        {"id": "no_ext", "type": "map", "version": 1, "file": "x.txt"},
        {"id": "demo_arena", "type": "map", "version": 9, "file": "dup.pck"},
        {"id": "weird_type", "type": "spaceship", "version": 1, "file": "w.pck"},
    ]})
    var parsed := ContentCatalog.parse_manifest(good)
    if not bool(parsed["ok"]):
        failures.append("Valid manifest was rejected: %s" % parsed["error"])
    else:
        var packs: Array = parsed["packs"]
        if packs.size() != 3:
            failures.append("Expected 3 safe packs (demo_arena, ak_47, weird_type), got %d" % packs.size())
        var first: Dictionary = packs[0]
        if str(first["sha256"]) != "abcdef" or int(first["max_players"]) != 6 or not bool(first["battle"]):
            failures.append("Pack fields were not normalized")
        if (first["modes"] as Array).size() != 2 or not ContentCatalog.has_mode(first, "duel"):
            failures.append("modes must keep only known, unique modes")
        if ContentCatalog.filter_maps_for_mode(packs, "duel").size() != 1:
            failures.append("filter_maps_for_mode(duel) failed")
        if ContentCatalog.filter_maps_for_mode(packs, "training").size() != 0:
            failures.append("filter_maps_for_mode(training) must be empty")
        if str((packs[2] as Dictionary)["type"]) != "other":
            failures.append("Unknown pack type must become 'other'")
        if ContentCatalog.filter_by_type(packs, "weapon").size() != 1:
            failures.append("filter_by_type failed")

    if bool(ContentCatalog.parse_manifest("not json")["ok"]):
        failures.append("Garbage manifest was accepted")
    if bool(ContentCatalog.parse_manifest("{\"schema\": 99, \"packs\": []}")["ok"]):
        failures.append("Wrong schema was accepted")

    if ContentCatalog.build_url("https://x.y/r", "a.pck") != "https://x.y/r/a.pck":
        failures.append("build_url must add a slash")
    if ContentCatalog.build_url("https://x.y/r/", "a.pck") != "https://x.y/r/a.pck":
        failures.append("build_url must not double the slash")
    if ContentCatalog.format_size(5 * 1048576) != "5.0 MB":
        failures.append("format_size MB wrong")
    if ContentCatalog.localized_name({"id": "q", "name": {"en": "Q"}}, "fa") != "Q":
        failures.append("localized_name must fall back to English")
    var pack := {"id": "demo_arena", "version": 2}
    if ContentCatalog.pack_status(pack, {}) != "missing":
        failures.append("pack_status missing")
    if ContentCatalog.pack_status(pack, {"demo_arena": {"version": 1}}) != "update":
        failures.append("pack_status update")
    if ContentCatalog.pack_status(pack, {"demo_arena": {"version": 2}}) != "installed":
        failures.append("pack_status installed")

    var old_style := ContentCatalog.sanitize_pack({"id": "old_map", "type": "map", "file": "o.pck", "battle": true})
    if not ContentCatalog.has_mode(old_style, "battle"):
        failures.append("Old 'battle: true' manifests must map to the battle mode")

    var named := ContentCatalog.parse_pack_file_name("gorg_v3.pck")
    if named.is_empty() or str(named["id"]) != "gorg" or int(named["version"]) != 3:
        failures.append("parse_pack_file_name failed for gorg_v3.pck")
    for bad_name in ["gorg.pck", "Gorg_v1.pck", "gorg_v1.rar", "../gorg_v1.pck", "gorg_vx.pck"]:
        if not ContentCatalog.parse_pack_file_name(bad_name).is_empty():
            failures.append("parse_pack_file_name accepted %s" % bad_name)

    var zipped := ContentCatalog.parse_pack_file_name("ak_47_v2.zip")
    if zipped.is_empty() or str(zipped["id"]) != "ak_47" or str(zipped["ext"]) != "zip":
        failures.append("parse_pack_file_name must accept .zip packs")
    if ContentCatalog.display_name_for_path("content://x/document/primary%3ADownload%2FIronYard%2Fgorg_v1.pck") != "gorg_v1.pck":
        failures.append("display_name_for_path failed for a content URI")
    var listing := ContentCatalog.packs_from_release_assets(JSON.stringify({"assets": [
        {"name": "manifest.json", "size": 5}, {"name": "ak_47_v1.pck", "size": 10}, {"name": "map_city_v2.zip", "size": 20}]}))
    if not bool(listing["ok"]) or (listing["packs"] as Array).size() != 2:
        failures.append("packs_from_release_assets must list only .pck/.zip assets")

    var from_meta := ContentCatalog.pack_from_meta(
        {"id": "gorg", "type": "map", "version": 1, "modes": ["duel"], "name": {"en": "Wolf"}}, "gorg_v1.pck", 4096)
    if from_meta.is_empty() or not ContentCatalog.has_mode(from_meta, "duel") or int(from_meta["size"]) != 4096:
        failures.append("pack_from_meta failed")

    for key in ["content_mode_duel", "content_mode_battle", "content_import", "content_import_btn", "content", "content_download", "content_delete", "content_play", "content_empty", "content_other", "content_choose_file"]:
        if not (load("res://scripts/autoload/localization.gd") as GDScript).get_script_constant_map()["STRINGS"].has(key):
            failures.append("Missing localization key: %s" % key)

    if failures.is_empty():
        print("IRON_YARD_CONTENT_TEST: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("IRON_YARD_CONTENT_TEST: FAIL (%d)" % failures.size())
        quit(1)
