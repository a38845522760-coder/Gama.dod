extends Node

## Downloadable content (autoload "ContentManager").
##
## Maps, weapons and characters ship as separate .pck packs hosted on a GitHub release.
## The APK stays small; the player downloads only what they want, and a pack is mounted
## (cheap, nothing is loaded into RAM) at startup. Only the scenes the match actually
## instantiates take memory. Packs must be data-only (scenes, meshes, textures, resources) -
## no scripts - so they can never break the base game.
##
## Flow: refresh_manifest() -> get_packs() -> install_pack(id) -> pack_installed(id)
##       -> load_pack_scene(id) / get_pack_meta(id).
## Offline: ready-made packs (<id>_v<version>.pck) copied to the phone can be installed with
##       scan_phone_folder() + import_from_file(path).

signal manifest_loaded(pack_count: int)
signal manifest_failed(reason: String)
signal pack_progress(pack_id: String, received: int, total: int)
signal pack_installed(pack_id: String)
signal pack_removed(pack_id: String)
signal pack_failed(pack_id: String, reason: String)

## The release that holds manifest.json and the .pck files. Can be overridden without a
## rebuild by writing a different URL into user://content/base_url.txt.
const CONFIG := preload("res://scripts/content/content_config.gd")
const OVERRIDE_URL_PATH: String = "user://content/base_url.txt"
const MANIFEST_CACHE_PATH: String = "user://content/manifest_cache.json"
const STATE_PATH: String = "user://content/installed.json"
const PACK_DIR: String = "user://content/packs"
const TMP_DIR: String = "user://content/tmp"
## Folders scanned for ready-made .pck files to import (phone storage, then a desktop test folder).
const IMPORT_DIRS: Array[String] = [
    "/storage/emulated/0/Download/IronYard",
    "/storage/emulated/0/IronYard",
    "/sdcard/Download/IronYard",
    "user://import",
]

var manifest_online: bool = false
var restart_required: bool = false

var _packs: Array = []
var _extras: Array = []
var _installed: Dictionary = {}
var _mounted: Dictionary = {}
var _downloads: Dictionary = {}
var _manifest_request: HTTPRequest = null
var _manifest_error: String = ""
var _last_emitted: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    DirAccess.make_dir_recursive_absolute(PACK_DIR)
    DirAccess.make_dir_recursive_absolute(TMP_DIR)
    _load_state()
    _load_manifest_cache()
    _mount_all_installed()
    _rebuild_extras()
    set_process(false)

# ---- public queries ---------------------------------------------------------------------

func get_base_url() -> String:
    var override_text := FileUtil.read_text(OVERRIDE_URL_PATH).strip_edges()
    if override_text.begins_with("http"):
        return override_text
    return str(CONFIG.BASE_URL)

func get_packs() -> Array:
    ## Online manifest entries plus installed packs the manifest does not list (imported ones).
    var merged: Array = []
    var known: Dictionary = {}
    var extra_types: Dictionary = {}
    for extra in _extras:
        extra_types[str((extra as Dictionary).get("id", ""))] = extra
    for pack in _packs:
        var entry: Dictionary = (pack as Dictionary).duplicate()
        var pack_key := str(entry.get("id", ""))
        known[pack_key] = true
        if str(entry.get("type", "other")) == "other" and extra_types.has(pack_key):
            var meta_entry: Dictionary = extra_types[pack_key]
            entry["type"] = meta_entry.get("type", "other")
            entry["modes"] = meta_entry.get("modes", [])
            entry["battle"] = meta_entry.get("battle", false)
            entry["name"] = meta_entry.get("name", entry.get("name", {}))
            entry["max_players"] = meta_entry.get("max_players", 1)
        merged.append(entry)
    for pack in _extras:
        if not known.has(str((pack as Dictionary).get("id", ""))) and _installed.has(str(pack["id"])):
            merged.append(pack)
    return merged

func get_packs_of_type(pack_type: String) -> Array:
    return ContentCatalog.filter_by_type(get_packs(), pack_type)

func get_pack_info(pack_id: String) -> Dictionary:
    for pack in get_packs():
        if str((pack as Dictionary).get("id", "")) == pack_id:
            return pack
    return {}

func get_status(pack_id: String) -> String:
    ## "missing" | "installed" | "update" | "downloading" | "verifying"
    if _downloads.has(pack_id):
        return str((_downloads[pack_id] as Dictionary).get("phase", "downloading"))
    var info := get_pack_info(pack_id)
    if info.is_empty():
        return "installed" if _installed.has(pack_id) else "missing"
    return ContentCatalog.pack_status(info, _installed)

func is_installed(pack_id: String) -> bool:
    return _installed.has(pack_id) and _mounted.get(pack_id, false)

func get_installed_ids() -> Array:
    return _installed.keys()

func get_installed_maps_for_mode(mode: String) -> Array:
    ## Installed maps offered for a mode: "battle", "duel", ...
    var out: Array = []
    for pack in ContentCatalog.filter_maps_for_mode(get_packs(), mode):
        if is_installed(str((pack as Dictionary)["id"])):
            out.append(pack)
    return out

func get_installed_battle_maps() -> Array:
    return get_installed_maps_for_mode("battle")

func get_total_installed_bytes() -> int:
    var total: int = 0
    for id in _installed:
        total += int((_installed[id] as Dictionary).get("size", 0))
    return total

func get_progress(pack_id: String) -> Vector2i:
    ## (received, total) bytes for an active download, else (0, 0).
    if not _downloads.has(pack_id):
        return Vector2i.ZERO
    var download: Dictionary = _downloads[pack_id]
    return Vector2i(int(download.get("received", 0)), int(download.get("total", 0)))

func get_pack_meta(pack_id: String) -> Dictionary:
    ## Reads res://content/<id>/pack_meta.txt (JSON text) from a mounted pack.
    if not is_installed(pack_id):
        return {}
    var path := "res://content/%s/pack_meta.txt" % pack_id
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func load_pack_scene(pack_id: String) -> PackedScene:
    var meta := get_pack_meta(pack_id)
    var entry := str(meta.get("entry_scene", ""))
    if entry.is_empty() or not entry.begins_with("res://content/%s/" % pack_id):
        return null
    var resource: Resource = load(entry)
    return resource as PackedScene

# ---- manifest ----------------------------------------------------------------------------

func refresh_manifest() -> void:
    if _manifest_request != null:
        return
    var request := HTTPRequest.new()
    request.timeout = 20.0
    add_child(request)
    _manifest_request = request
    request.request_completed.connect(_on_manifest_completed.bind(request))
    var error := request.request(ContentCatalog.build_url(get_base_url(), "manifest.json"))
    if error != OK:
        _manifest_request = null
        request.queue_free()
        manifest_online = false
        manifest_failed.emit("request error %d" % error)

func _on_manifest_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
    _manifest_request = null
    request.queue_free()
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        _manifest_error = "network %d / http %d" % [result, response_code]
        _try_release_listing()
        return
    var text := body.get_string_from_utf8()
    var parsed := ContentCatalog.parse_manifest(text)
    if not bool(parsed["ok"]):
        _manifest_error = str(parsed["error"])
        _try_release_listing()
        return
    if (parsed["packs"] as Array).is_empty():
        _manifest_error = "manifest.json is empty"
        _try_release_listing()
        return
    _packs = parsed["packs"]
    manifest_online = true
    FileUtil.write_text_atomic(MANIFEST_CACHE_PATH, text, false)
    manifest_loaded.emit(_packs.size())

func _try_release_listing() -> void:
    ## No usable manifest.json: ask GitHub which files the release holds and list those instead.
    var regex := RegEx.new()
    regex.compile("^https://github\\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/?")
    var found := regex.search(get_base_url())
    if found == null:
        manifest_online = false
        manifest_failed.emit(_manifest_error)
        return
    var api_url := "https://api.github.com/repos/%s/%s/releases/tags/%s" % [found.get_string(1), found.get_string(2), found.get_string(3)]
    var request := HTTPRequest.new()
    request.timeout = 20.0
    add_child(request)
    _manifest_request = request
    request.request_completed.connect(_on_release_listing_completed.bind(request))
    var error := request.request(api_url, PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: IronYard"]))
    if error != OK:
        _manifest_request = null
        request.queue_free()
        manifest_online = false
        manifest_failed.emit("%s; release listing error %d" % [_manifest_error, error])

func _on_release_listing_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
    _manifest_request = null
    request.queue_free()
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        manifest_online = false
        manifest_failed.emit("%s; release http %d (check that the release exists and the repo is public)" % [_manifest_error, response_code])
        return
    var parsed := ContentCatalog.packs_from_release_assets(body.get_string_from_utf8())
    if not bool(parsed["ok"]) or (parsed["packs"] as Array).is_empty():
        manifest_online = false
        manifest_failed.emit("%s; no .pck/.zip files in the release" % _manifest_error)
        return
    _packs = parsed["packs"]
    manifest_online = true
    manifest_loaded.emit(_packs.size())

func _load_manifest_cache() -> void:
    var text := FileUtil.read_text(MANIFEST_CACHE_PATH)
    if text.is_empty():
        return
    var parsed := ContentCatalog.parse_manifest(text)
    if bool(parsed["ok"]):
        _packs = parsed["packs"]

# ---- install / remove -------------------------------------------------------------------

func install_pack(pack_id: String) -> void:
    if _downloads.has(pack_id):
        return
    var info := get_pack_info(pack_id)
    if info.is_empty():
        pack_failed.emit(pack_id, "unknown pack")
        return
    var tmp_path := "%s/%s.part" % [TMP_DIR, pack_id]
    FileUtil.remove_file(tmp_path)
    var request := HTTPRequest.new()
    request.download_file = tmp_path
    request.accept_gzip = false
    request.use_threads = true
    request.download_chunk_size = 262144
    request.timeout = 0.0
    add_child(request)
    _downloads[pack_id] = {
        "request": request, "tmp": tmp_path, "info": info, "phase": "downloading",
        "received": 0, "total": int(info.get("size", 0)),
    }
    request.request_completed.connect(_on_download_completed.bind(pack_id))
    var error := request.request(ContentCatalog.build_url(get_base_url(), str(info["file"])))
    if error != OK:
        _fail(pack_id, "request error %d" % error)
        return
    set_process(true)

func cancel_install(pack_id: String) -> void:
    if _downloads.has(pack_id) and str((_downloads[pack_id] as Dictionary).get("phase", "")) == "downloading":
        _fail(pack_id, "cancelled")

# ---- import from phone storage -------------------------------------------------------------

func scan_phone_folder() -> Array:
    ## Ready-made packs found in IMPORT_DIRS: [{"path", "file", "id", "version", "size"}].
    var found: Array = []
    var seen: Dictionary = {}
    for folder in IMPORT_DIRS:
        var dir := DirAccess.open(folder)
        if dir == null:
            continue
        for file_name in dir.get_files():
            var parsed := ContentCatalog.parse_pack_file_name(file_name)
            if parsed.is_empty() or seen.has(file_name):
                continue
            seen[file_name] = true
            var path := "%s/%s" % [folder, file_name]
            found.append({"path": path, "file": file_name, "id": parsed["id"],
                "version": parsed["version"], "size": _file_length(path)})
    return found

func pick_file_to_import() -> bool:
    ## Opens the system file picker (Android: Storage Access Framework). Returns false when this
    ## device has no native picker, so the caller can show its own dialog.
    if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
        return false
    var filters := PackedStringArray()
    if not OS.has_feature("android"):
        filters = PackedStringArray(["*.pck, *.zip ; Iron Yard content"])
    DisplayServer.file_dialog_show("Iron Yard content", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters, _on_native_file_picked)
    return true

func _on_native_file_picked(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
    if status and not selected_paths.is_empty():
        import_from_file(selected_paths[0])

func import_from_file(path: String) -> void:
    ## Installs a .pck or .zip pack from any path or content:// URI. Copying and checking run in a
    ## thread; the pack id comes from the zip's own pack_meta (zip) or the file name (<id>_v<n>.pck).
    var key := ContentCatalog.display_name_for_path(path)
    if key.is_empty():
        key = "pack"
    if _downloads.has(key):
        return
    var tmp_path := "%s/import_%d.part" % [TMP_DIR, Time.get_ticks_msec()]
    var thread := Thread.new()
    _downloads[key] = {
        "request": null, "tmp": tmp_path, "phase": "verifying", "imported": true, "thread": thread,
        "received": 0, "total": 0,
        "info": {"id": key, "version": 1, "file": "", "sha256": "", "size": 0},
    }
    thread.start(_import_job.bind(key, path, tmp_path))

func _import_job(key: String, source_path: String, tmp_path: String) -> void:
    var source := FileAccess.open(source_path, FileAccess.READ)
    if source == null:
        _import_failed.call_deferred(key, "cannot open the file (%d)" % FileAccess.get_open_error())
        return
    var target := FileAccess.open(tmp_path, FileAccess.WRITE)
    if target == null:
        source.close()
        _import_failed.call_deferred(key, "cannot write temporary file")
        return
    while not source.eof_reached():
        var chunk := source.get_buffer(1048576)
        if chunk.is_empty():
            break
        target.store_buffer(chunk)
    source.close()
    target.close()
    if _file_length(tmp_path) <= 0:
        _import_failed.call_deferred(key, "the file is empty")
        return
    var kind := _sniff_kind(tmp_path)
    if kind.is_empty():
        _import_failed.call_deferred(key, "not a .pck or .zip pack")
        return
    var pack_id := ""
    var version := 1
    if kind == "zip":
        var zip_info := _inspect_zip(tmp_path)
        if zip_info.has("error"):
            _import_failed.call_deferred(key, str(zip_info["error"]))
            return
        pack_id = str(zip_info["id"])
        version = int(zip_info["version"])
    else:
        var named := ContentCatalog.parse_pack_file_name(key)
        if named.is_empty():
            _import_failed.call_deferred(key, "file name must look like id_v1.pck")
            return
        pack_id = str(named["id"])
        version = int(named["version"])
    _import_ready.call_deferred(key, pack_id, version, kind, FileAccess.get_sha256(tmp_path))

func _sniff_kind(path: String) -> String:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    var head := file.get_buffer(4)
    file.close()
    if head.size() >= 4 and head[0] == 0x50 and head[1] == 0x4B:
        return "zip"
    if head.size() >= 4 and head[0] == 0x47 and head[1] == 0x44 and head[2] == 0x50 and head[3] == 0x43:
        return "pck"
    return ""

func _inspect_zip(path: String) -> Dictionary:
    ## A pack zip must hold content/<id>/pack_meta.txt (and the pack's files next to it) and no code.
    var zip := ZIPReader.new()
    if zip.open(path) != OK:
        return {"error": "the zip file cannot be opened"}
    var regex := RegEx.new()
    regex.compile("^content/([a-z0-9_-]{1,64})/pack_meta\\.txt$")
    var pack_id := ""
    for entry in zip.get_files():
        var lower := str(entry).to_lower()
        for banned in [".gd", ".gdc", ".cs", ".dll", ".so", ".gdextension"]:
            if lower.ends_with(banned):
                zip.close()
                return {"error": "packs must not contain code (%s)" % entry}
        var found := regex.search(str(entry))
        if found != null and pack_id.is_empty():
            pack_id = found.get_string(1)
    if pack_id.is_empty():
        zip.close()
        return {"error": "zip must contain content/<id>/pack_meta.txt"}
    var meta_text := zip.read_file("content/%s/pack_meta.txt" % pack_id).get_string_from_utf8()
    zip.close()
    if meta_text.strip_edges().is_empty():
        return {"error": "pack_meta.txt is empty"}
    var meta: Variant = JSON.parse_string(meta_text)
    if not (meta is Dictionary) or str((meta as Dictionary).get("id", "")) != pack_id:
        return {"error": "pack_meta id must equal the folder name"}
    return {"id": pack_id, "version": maxi(1, int((meta as Dictionary).get("version", 1)))}

func _import_ready(key: String, pack_id: String, version: int, kind: String, digest: String) -> void:
    if not _downloads.has(key):
        return
    var download: Dictionary = _downloads[key]
    if download.has("thread"):
        (download["thread"] as Thread).wait_to_finish()
        download.erase("thread")
    if pack_id != key and _downloads.has(pack_id):
        _fail(key, "this pack is already being installed")
        return
    download["info"] = {"id": pack_id, "version": version, "file": "%s_v%d.%s" % [pack_id, version, kind], "sha256": "", "size": 0}
    _downloads.erase(key)
    _downloads[pack_id] = download
    _hash_done(pack_id, digest)

func _import_failed(key: String, reason: String) -> void:
    if _downloads.has(key) and (_downloads[key] as Dictionary).has("thread"):
        ((_downloads[key] as Dictionary)["thread"] as Thread).wait_to_finish()
        (_downloads[key] as Dictionary).erase("thread")
    _fail(key, reason)

func remove_pack(pack_id: String) -> void:
    if _downloads.has(pack_id) or not _installed.has(pack_id):
        return
    var record: Dictionary = _installed[pack_id]
    FileUtil.remove_file("%s/%s" % [PACK_DIR, str(record.get("file", ""))])
    _installed.erase(pack_id)
    _save_state()
    # A mounted pack cannot be unmounted at runtime; its files disappear after a restart.
    pack_removed.emit(pack_id)

func _process(_delta: float) -> void:
    if _downloads.is_empty():
        set_process(false)
        return
    for pack_id in _downloads.keys():
        var download: Dictionary = _downloads[pack_id]
        if str(download.get("phase", "")) != "downloading":
            continue
        var request: HTTPRequest = download.get("request")
        if request == null:
            continue
        var received: int = request.get_downloaded_bytes()
        var total: int = request.get_body_size()
        if total <= 0:
            total = int(download.get("total", 0))
        download["received"] = received
        download["total"] = total
        var key := Vector2i(received / 65536, total)
        if _last_emitted.get(pack_id, Vector2i(-1, -1)) != key:
            _last_emitted[pack_id] = key
            pack_progress.emit(pack_id, received, total)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, pack_id: String) -> void:
    if not _downloads.has(pack_id):
        return
    var download: Dictionary = _downloads[pack_id]
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        _fail(pack_id, "network %d / http %d" % [result, response_code])
        return
    var tmp_path := str(download["tmp"])
    var info: Dictionary = download["info"]
    var length := _file_length(tmp_path)
    var expected := int(info.get("size", 0))
    if length <= 0 or (expected > 0 and length != expected):
        _fail(pack_id, "size mismatch (%d / %d)" % [length, expected])
        return
    download["phase"] = "verifying"
    download["received"] = length
    download["total"] = length
    pack_progress.emit(pack_id, length, length)
    var thread := Thread.new()
    download["thread"] = thread
    thread.start(_hash_job.bind(pack_id, tmp_path))

func _hash_job(pack_id: String, path: String) -> void:
    var digest := FileAccess.get_sha256(path)
    _hash_done.call_deferred(pack_id, digest)

func _hash_done(pack_id: String, digest: String) -> void:
    if not _downloads.has(pack_id):
        return
    var download: Dictionary = _downloads[pack_id]
    if download.has("thread"):
        (download["thread"] as Thread).wait_to_finish()
        download.erase("thread")
    var info: Dictionary = download["info"]
    var expected_hash := str(info.get("sha256", ""))
    if not expected_hash.is_empty() and expected_hash != digest.to_lower():
        _fail(pack_id, "checksum mismatch")
        return
    var tmp_path := str(download["tmp"])
    var file_name := str(info["file"])
    var final_path := "%s/%s" % [PACK_DIR, file_name]
    FileUtil.remove_file(final_path)
    FileUtil.rename_file(tmp_path, final_path)
    if not FileAccess.file_exists(final_path):
        _fail(pack_id, "could not store the pack")
        return
    var previous: Dictionary = _installed.get(pack_id, {})
    var previous_file := str(previous.get("file", ""))
    if not previous_file.is_empty() and previous_file != file_name:
        FileUtil.remove_file("%s/%s" % [PACK_DIR, previous_file])
    _installed[pack_id] = {
        "version": int(info.get("version", 1)), "file": file_name,
        "sha256": digest.to_lower(), "size": _file_length(final_path),
    }
    _save_state()
    if _mounted.get(pack_id, false):
        # An older version of this pack is already mounted; the new files apply after a restart.
        restart_required = true
    elif not _mount(pack_id):
        _installed.erase(pack_id)
        _save_state()
        FileUtil.remove_file(final_path)
        _fail(pack_id, "pack could not be mounted")
        return
    if bool(download.get("imported", false)):
        var meta := get_pack_meta(pack_id)
        if str(meta.get("id", "")) != pack_id:
            _installed.erase(pack_id)
            _save_state()
            FileUtil.remove_file(final_path)
            _fail(pack_id, "pack_meta id does not match the file name")
            return
    _rebuild_extras()
    _finish_download(pack_id)
    pack_installed.emit(pack_id)

func _fail(pack_id: String, reason: String) -> void:
    if _downloads.has(pack_id):
        var download: Dictionary = _downloads[pack_id]
        var request: HTTPRequest = download.get("request")
        if request != null and is_instance_valid(request):
            request.cancel_request()
        FileUtil.remove_file(str(download.get("tmp", "")))
    _finish_download(pack_id)
    pack_failed.emit(pack_id, reason)

func _finish_download(pack_id: String) -> void:
    if _downloads.has(pack_id):
        var request: HTTPRequest = (_downloads[pack_id] as Dictionary).get("request")
        if request != null and is_instance_valid(request):
            request.queue_free()
        _downloads.erase(pack_id)
    _last_emitted.erase(pack_id)

# ---- mounting & state ---------------------------------------------------------------------

func _mount_all_installed() -> void:
    for pack_id in _installed.keys():
        if not _mount(str(pack_id)):
            _installed.erase(pack_id)
    _save_state()

func _mount(pack_id: String) -> bool:
    if _mounted.get(pack_id, false):
        return true
    var record: Dictionary = _installed.get(pack_id, {})
    var path := "%s/%s" % [PACK_DIR, str(record.get("file", ""))]
    if not FileAccess.file_exists(path):
        return false
    # replace_files = false: a pack can add content but never override base-game files.
    if not ProjectSettings.load_resource_pack(path, false):
        return false
    _mounted[pack_id] = true
    return true

func _rebuild_extras() -> void:
    ## Catalog entries for installed packs, built from each pack's own metadata, so imported packs
    ## show up (and everything installed stays visible when the manifest cannot be downloaded).
    _extras.clear()
    for pack_id in _installed.keys():
        var meta := get_pack_meta(str(pack_id))
        if meta.is_empty():
            continue
        meta["id"] = str(pack_id)
        var record: Dictionary = _installed[pack_id]
        var entry := ContentCatalog.pack_from_meta(meta, str(record.get("file", "")), int(record.get("size", 0)))
        if not entry.is_empty():
            _extras.append(entry)

func _load_state() -> void:
    var state_text := FileUtil.read_text(STATE_PATH)
    if state_text.strip_edges().is_empty():
        return
    var parsed: Variant = JSON.parse_string(state_text)
    if parsed is Dictionary and (parsed as Dictionary).get("installed") is Dictionary:
        for id in (parsed["installed"] as Dictionary):
            if ContentCatalog.is_safe_name(str(id)) and (parsed["installed"][id] is Dictionary):
                var record: Dictionary = parsed["installed"][id]
                if ContentCatalog.is_safe_file(str(record.get("file", ""))):
                    _installed[str(id)] = record

func _save_state() -> void:
    FileUtil.write_text_atomic(STATE_PATH, JSON.stringify({"schema": 1, "installed": _installed}))

func _file_length(path: String) -> int:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return 0
    var length := file.get_length()
    file.close()
    return int(length)
