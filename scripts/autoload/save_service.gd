extends Node
## File side of saving (bible p.20, LR-10): atomic write (tmp -> rename),
## previous good save kept as backup, corrupt/future saves never overwritten
## or deleted, JSON export/import.

signal saved

const DIR := "user://saves"
const MAIN := "user://saves/run.json"
const BACKUP := "user://saves/run.backup.json"
const TMP := "user://saves/run.tmp"
const EXPORT_DIR := "user://exports"

var last_error: String = ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func has_save() -> bool:
	return FileAccess.file_exists(MAIN) or FileAccess.file_exists(BACKUP)


## Writes the authoritative state. The previous main file becomes the backup
## only if it is itself valid, so a damaged file never replaces a good backup.
func save_run(run: Dictionary, presentation: Dictionary = {}) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var text: String = SaveCodec.encode(run, presentation)
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		last_error = "Cannot write save (%s)." % error_string(FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(MAIN):
		var cur: Dictionary = SaveCodec.decode(FileAccess.get_file_as_string(MAIN))
		if cur["ok"]:
			DirAccess.copy_absolute(MAIN, BACKUP)
	var err: int = DirAccess.rename_absolute(TMP, MAIN)
	if err != OK:
		last_error = "Cannot finish save (%s)." % error_string(err)
		return false
	saved.emit()
	return true


## {ok, code, error, run, presentation, source}. source = main | backup.
func load_run() -> Dictionary:
	var main: Dictionary = _read(MAIN)
	main["source"] = "main"
	if main["ok"]:
		return main
	if main["code"] == "future_version":
		return main  # never fall back silently past a newer save
	var bak: Dictionary = _read(BACKUP)
	if bak["ok"]:
		main["backup_available"] = true
	return main


func load_backup() -> Dictionary:
	var bak: Dictionary = _read(BACKUP)
	bak["source"] = "backup"
	return bak


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": "missing", "error": "No save.", "run": {}, "presentation": {}}
	return SaveCodec.decode(FileAccess.get_file_as_string(path))


func delete_run() -> void:
	for p in [MAIN, BACKUP, TMP]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func export_json(run: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	var path := "%s/lastroot_%s.json" % [EXPORT_DIR, run.get("run_id", "run")]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(SaveCodec.encode(run))
	f.close()
	return ProjectSettings.globalize_path(path)


func import_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": "missing", "error": "File not found.", "run": {}}
	return SaveCodec.decode(FileAccess.get_file_as_string(path))
