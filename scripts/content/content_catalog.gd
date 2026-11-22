extends RefCounted
class_name ContentCatalog

## Pure logic for the downloadable-content manifest (no network, no autoloads), so it can be
## unit-tested headless. ContentManager does the I/O; this class only parses and decides.
##
## manifest.json layout (schema 1):
## {
##   "schema": 1,
##   "packs": [
##     {"id": "demo_arena", "type": "map", "version": 1, "file": "demo_arena.pck",
##      "size": 123456, "sha256": "<hex>",
##      "name": {"fa": "...", "en": "..."},
##      "modes": ["battle", "duel"], "max_players": 8}
##   ]
## }

const SCHEMA: int = 1
const TYPES: Array[String] = ["map", "weapon", "character", "other"]
## Game modes a map can be offered for. Old manifests with "battle": true still work.
const MODES: Array[String] = ["battle", "duel", "training"]
const BIG_DOWNLOAD_BYTES: int = 100 * 1024 * 1024

static func parse_manifest(text: String) -> Dictionary:
    ## Returns {"ok": bool, "packs": Array[Dictionary], "error": String}.
    var result := {"ok": false, "packs": [], "error": ""}
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Dictionary):
        result["error"] = "manifest is not a JSON object"
        return result
    var root: Dictionary = parsed
    if int(root.get("schema", 0)) != SCHEMA:
        result["error"] = "unsupported manifest schema"
        return result
    if not (root.get("packs") is Array):
        result["error"] = "manifest has no packs array"
        return result
    var seen: Dictionary = {}
    var packs: Array = []
    for entry in (root["packs"] as Array):
        if not (entry is Dictionary):
            continue
        var clean := sanitize_pack(entry)
        if clean.is_empty() or seen.has(clean["id"]):
            continue
        seen[clean["id"]] = true
        packs.append(clean)
    result["ok"] = true
    result["packs"] = packs
    return result

static func sanitize_pack(entry: Dictionary) -> Dictionary:
    var id := str(entry.get("id", "")).strip_edges()
    var file := str(entry.get("file", "")).strip_edges()
    if not is_safe_name(id) or not is_safe_file(file):
        return {}
    var pack_type := str(entry.get("type", "other"))
    if not TYPES.has(pack_type):
        pack_type = "other"
    var name_table: Dictionary = {}
    if entry.get("name") is Dictionary:
        name_table = (entry["name"] as Dictionary).duplicate()
    var modes: Array = []
    if entry.get("modes") is Array:
        for mode in (entry["modes"] as Array):
            var mode_id := str(mode)
            if MODES.has(mode_id) and not modes.has(mode_id):
                modes.append(mode_id)
    if bool(entry.get("battle", false)) and not modes.has("battle"):
        modes.append("battle")
    return {
        "id": id,
        "type": pack_type,
        "version": maxi(1, int(entry.get("version", 1))),
        "file": file,
        "size": maxi(0, int(entry.get("size", 0))),
        "sha256": str(entry.get("sha256", "")).strip_edges().to_lower(),
        "name": name_table,
        "modes": modes,
        "battle": modes.has("battle"),
        "max_players": maxi(1, int(entry.get("max_players", 1))),
    }

static func is_safe_name(value: String) -> bool:
    ## Pack ids become folder/file names, so only plain identifiers are allowed.
    if value.is_empty() or value.length() > 64:
        return false
    for index in range(value.length()):
        var code := value.unicode_at(index)
        var ok := (code >= 48 and code <= 57) or (code >= 97 and code <= 122) or code == 95 or code == 45
        if not ok:
            return false
    return true

static func is_safe_file(value: String) -> bool:
    if value.is_empty() or value.length() > 96 or not (value.ends_with(".pck") or value.ends_with(".zip")):
        return false
    if value.contains("/") or value.contains("\\") or value.contains(".."):
        return false
    return true

static func build_url(base_url: String, file: String) -> String:
    var base := base_url.strip_edges()
    if not base.ends_with("/"):
        base += "/"
    return base + file

static func localized_name(pack: Dictionary, language: String) -> String:
    var table: Dictionary = pack.get("name", {})
    if table.has(language):
        return str(table[language])
    if table.has("en"):
        return str(table["en"])
    return str(pack.get("id", "?"))

static func format_size(bytes: int) -> String:
    if bytes >= 1024 * 1024 * 1024:
        return "%.2f GB" % (float(bytes) / 1073741824.0)
    if bytes >= 1024 * 1024:
        return "%.1f MB" % (float(bytes) / 1048576.0)
    return "%d KB" % maxi(1, int(ceil(float(bytes) / 1024.0)))

static func pack_status(pack: Dictionary, installed: Dictionary) -> String:
    ## "missing" | "installed" | "update"
    var id := str(pack.get("id", ""))
    if not installed.has(id):
        return "missing"
    var record: Dictionary = installed[id]
    if int(record.get("version", 0)) < int(pack.get("version", 1)):
        return "update"
    return "installed"

static func filter_by_type(packs: Array, pack_type: String) -> Array:
    var out: Array = []
    for pack in packs:
        if str((pack as Dictionary).get("type", "other")) == pack_type:
            out.append(pack)
    return out

static func has_mode(pack: Dictionary, mode: String) -> bool:
    return (pack.get("modes", []) as Array).has(mode)

static func filter_maps_for_mode(packs: Array, mode: String) -> Array:
    ## Maps that are offered for a game mode ("battle", "duel", ...).
    var out: Array = []
    for pack in packs:
        var info: Dictionary = pack
        if str(info.get("type", "")) == "map" and has_mode(info, mode):
            out.append(info)
    return out

static func parse_pack_file_name(file_name: String) -> Dictionary:
    ## "demo_arena_v2.pck" -> {"id": "demo_arena", "version": 2}; {} when the name does not follow
    ## the <id>_v<version>.pck convention used by tools/build_packs.py.
    var regex := RegEx.new()
    regex.compile("^([a-z0-9_-]{1,64})_v([0-9]{1,6})\\.(pck|zip)$")
    var found := regex.search(file_name)
    if found == null or not is_safe_name(found.get_string(1)):
        return {}
    return {"id": found.get_string(1), "version": maxi(1, int(found.get_string(2))), "ext": found.get_string(3)}

static func display_name_for_path(path: String) -> String:
    ## File name for a picked file. On Android the picker returns a content:// URI whose last part
    ## looks like "primary%3ADownload%2Fgorg_v1.pck"; decode it and keep only the file name.
    var decoded := path.uri_decode()
    var file_name := decoded.get_file()
    if file_name.contains(":"):
        file_name = file_name.get_slice(":", file_name.get_slice_count(":") - 1)
    return file_name.strip_edges()

static func infer_type_from_id(id: String) -> String:
    ## Used when a release has no manifest.json: guess the tab from the pack name.
    if id.begins_with("map") or id.contains("arena") or id.contains("_map"):
        return "map"
    if id.begins_with("weapon") or id.begins_with("gun") or id.contains("rifle") or id.contains("pistol"):
        return "weapon"
    if id.begins_with("char") or id.contains("skin"):
        return "character"
    return "other"

static func packs_from_release_assets(text: String) -> Dictionary:
    ## Fallback when manifest.json is missing: GitHub's release API lists every uploaded asset.
    ## Returns {"ok": bool, "packs": Array, "error": String}. Only <id>_v<n>.pck / .zip are used.
    var result := {"ok": false, "packs": [], "error": ""}
    if text.strip_edges().is_empty():
        result["error"] = "empty release answer"
        return result
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Dictionary) or not ((parsed as Dictionary).get("assets") is Array):
        result["error"] = "release has no assets"
        return result
    var packs: Array = []
    var seen: Dictionary = {}
    for asset in ((parsed as Dictionary)["assets"] as Array):
        if not (asset is Dictionary):
            continue
        var file_name := str((asset as Dictionary).get("name", ""))
        var named := parse_pack_file_name(file_name)
        if named.is_empty():
            continue
        var digest := str((asset as Dictionary).get("digest", ""))
        var entry := sanitize_pack({
            "id": named["id"], "type": infer_type_from_id(str(named["id"])), "version": named["version"],
            "file": file_name, "size": int((asset as Dictionary).get("size", 0)),
            "sha256": digest.trim_prefix("sha256:") if digest.begins_with("sha256:") else "",
        })
        if entry.is_empty():
            continue
        var existing: Dictionary = seen.get(entry["id"], {})
        if existing.is_empty() or int(entry["version"]) > int(existing["version"]):
            seen[entry["id"]] = entry
    for key in seen:
        packs.append(seen[key])
    result["ok"] = true
    result["packs"] = packs
    return result

static func pack_from_meta(meta: Dictionary, file_name: String, size: int) -> Dictionary:
    ## Builds a catalog entry for a pack that is installed but not in the online manifest
    ## (for example one imported from the phone). The data comes from the pack's own pack_meta.txt.
    var raw := {
        "id": meta.get("id", ""), "type": meta.get("type", "other"), "version": meta.get("version", 1),
        "file": file_name, "size": size, "name": meta.get("name", {}),
        "modes": meta.get("modes", []), "battle": meta.get("battle", false),
        "max_players": meta.get("max_players", 1),
    }
    return sanitize_pack(raw)
