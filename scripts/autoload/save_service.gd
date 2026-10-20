extends Node
## File side of saving (bible p.20, LR-10, LR-29): atomic write (tmp -> rename),
## previous good save kept as backup, corrupt/future saves never deleted: a
## file that cannot be decoded is copied to a quarantine name before anything
## overwrites it. An interrupted write is recovered on load (a complete,
## valid tmp file is the newest authoritative state; a partial one is ignored).
## JSON export/import go through the same decoder (checksum, migration, IDs).
## Demo runs (export feature "demo" or run.mode == "demo", LR-34) live in their
## own slot (run.demo.json / run.demo.backup.json / run.demo.tmp) so a demo can
## never overwrite a full run; each slot refuses a run of the other mode
## (code "wrong_slot").

signal saved

const DIR := "user://saves"
const MAIN := "user://saves/run.json"
const BACKUP := "user://saves/run.backup.json"
const TMP := "user://saves/run.tmp"
const DEMO_MAIN := "user://saves/run.demo.json"
const EXPORT_DIR := "user://exports"
const QUARANTINE_KEEP := 3

var last_error: String = ""
## Paths are variables so tests can run an isolated instance in another folder.
var dir: String = DIR
var main_path: String = MAIN
var backup_path: String = BACKUP
var tmp_path: String = TMP
## Which slot load_run / has_save / delete_run use: the build's own mode.
var demo_build: bool = OS.has_feature("demo")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir)


## Points this instance at another folder (tests only).
func use_dir(d: String) -> void:
	dir = d
	main_path = d + "/run.json"
	backup_path = d + "/run.backup.json"
	tmp_path = d + "/run.tmp"
	DirAccess.make_dir_recursive_absolute(dir)


## {main, backup, tmp} of the full or the demo slot.
func slot_paths(demo: bool) -> Dictionary:
	if not demo:
		return {"main": main_path, "backup": backup_path, "tmp": tmp_path}
	return {"main": dir + "/run.demo.json", "backup": dir + "/run.demo.backup.json", "tmp": dir + "/run.demo.tmp"}


static func is_demo_run(run: Dictionary) -> bool:
	return str(run.get("mode", "full")) == "demo"


func _slot() -> Dictionary:
	return slot_paths(demo_build)


func has_save() -> bool:
	var sl: Dictionary = _slot()
	return FileAccess.file_exists(sl["main"]) or FileAccess.file_exists(sl["backup"]) or _decodes_in(sl["tmp"], demo_build)


## Writes the authoritative state into the slot of the run's mode. The
## previous main file becomes the backup only if it is itself valid (and of
## the slot's mode), so a damaged file never replaces a good backup; a main
## file that does not decode (damaged, newer version) is quarantined first so
## it is never lost.
func save_run(run: Dictionary, presentation: Dictionary = {}) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var demo: bool = is_demo_run(run)
	var sl: Dictionary = slot_paths(demo)
	var text: String = SaveCodec.encode(run, presentation)
	var f := FileAccess.open(sl["tmp"], FileAccess.WRITE)
	if f == null:
		last_error = "Cannot write save (%s)." % error_string(FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.close()
	_rotate(sl, demo)
	var err: int = DirAccess.rename_absolute(sl["tmp"], sl["main"])
	if err != OK:
		last_error = "Cannot finish save (%s)." % error_string(err)
		return false
	saved.emit()
	return true


## {ok, code, error, run, presentation, source}. source = main | backup.
func load_run() -> Dictionary:
	var sl: Dictionary = _slot()
	var recovered: bool = _recover_tmp(sl, demo_build)
	var main: Dictionary = _read_slot(sl["main"], demo_build)
	main["source"] = "main"
	main["recovered_from_tmp"] = recovered
	if main["ok"]:
		return main
	if main["code"] == "future_version":
		return main  # never fall back silently past a newer save
	var bak: Dictionary = _read_slot(sl["backup"], demo_build)
	if bak["ok"]:
		main["backup_available"] = true
	return main


func load_backup() -> Dictionary:
	var bak: Dictionary = _read_slot(_slot()["backup"], demo_build)
	bak["source"] = "backup"
	return bak


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": "missing", "error": "No save.", "run": {}, "presentation": {}}
	return SaveCodec.decode(FileAccess.get_file_as_string(path))


## Decodes a file of a slot; a run of the other mode is refused.
func _read_slot(path: String, demo: bool) -> Dictionary:
	var d: Dictionary = _read(path)
	if d["ok"] and is_demo_run(d["run"]) != demo:
		return {"ok": false, "code": "wrong_slot", "run": {}, "presentation": {},
			"error": "This save belongs to the demo." if is_demo_run(d["run"]) else "This save belongs to the full game."}
	return d


func _decodes_in(path: String, demo: bool) -> bool:
	return FileAccess.file_exists(path) and _read_slot(path, demo)["ok"]


## Current main -> backup if it is good; otherwise (damaged, newer version or
## a run of the other mode) it is quarantined, never lost.
func _rotate(sl: Dictionary, demo: bool) -> void:
	if not FileAccess.file_exists(sl["main"]):
		return
	var cur: Dictionary = _read_slot(sl["main"], demo)
	if cur["ok"]:
		DirAccess.copy_absolute(sl["main"], sl["backup"])
	else:
		_quarantine(sl["main"], str(cur["code"]))


## A write that was cut off between "tmp complete" and "rename" leaves a valid
## tmp file next to the previous main file: it is the newer state, so it is
## promoted exactly like save_run would have done. A partial tmp is left alone
## (the next save overwrites it).
func _recover_tmp(sl: Dictionary, demo: bool) -> bool:
	if not _decodes_in(sl["tmp"], demo):
		return false
	_rotate(sl, demo)
	return DirAccess.rename_absolute(sl["tmp"], sl["main"]) == OK


## Copies an undecodable save to run.q.<code>.<time>.<n>.json (keeps the newest few).
func _quarantine(path: String, code: String) -> void:
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var target := "%s/run.q.%s.%s.%06d.json" % [dir, code, stamp, Time.get_ticks_usec() % 1000000]
	DirAccess.copy_absolute(path, target)
	var kept: Array = Array(quarantined_files())
	kept.sort()
	while kept.size() > QUARANTINE_KEEP:
		DirAccess.remove_absolute(str(kept.pop_front()))


func quarantined_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for fname in DirAccess.get_files_at(dir):
		if fname.begins_with("run.q.") and fname.ends_with(".json"):
			out.append(dir + "/" + fname)
	return out


func delete_run() -> void:
	var sl: Dictionary = _slot()
	for p: String in [sl["main"], sl["backup"], sl["tmp"]]:
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


## Import goes through the same decoder and the build's slot rule.
func import_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": "missing", "error": "File not found.", "run": {}}
	return _read_slot(path, demo_build)
