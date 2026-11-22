extends RefCounted
class_name FileUtil

## Crash-safe file helpers. Data is written to a temporary file first and only then
## swapped in, so an app kill in the middle of a save can never leave a half-written file.

static func write_text_atomic(path: String, text: String, keep_backup: bool = true) -> Error:
    var tmp_path := path + ".tmp"
    var file := FileAccess.open(tmp_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(text)
    file.flush()
    var write_error: Error = file.get_error()
    file.close()
    if write_error != OK:
        return write_error
    var dir := DirAccess.open(path.get_base_dir())
    if dir == null:
        return DirAccess.get_open_error()
    if keep_backup and FileAccess.file_exists(path):
        dir.copy(path, path + ".bak")
    var rename_error: Error = dir.rename(tmp_path, path)
    if rename_error != OK:
        # Some platforms refuse to overwrite an existing destination.
        if FileAccess.file_exists(path):
            dir.remove(path)
        rename_error = dir.rename(tmp_path, path)
    return rename_error

static func read_text(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    var text := file.get_as_text()
    file.close()
    return text

static func remove_file(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)

static func rename_file(from_path: String, to_path: String) -> void:
    if FileAccess.file_exists(from_path):
        DirAccess.rename_absolute(from_path, to_path)
