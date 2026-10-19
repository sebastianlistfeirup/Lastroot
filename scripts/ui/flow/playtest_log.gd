class_name PlaytestLog
extends RefCounted
## Local playtest records (LR-27/LR-31). One record per finished run in
## user://playtest_log.json, written the first time the result screen shows
## that run, never twice for the same run_id. Optional after-run feedback is
## stored in the same record. Nothing leaves the device: testers send the
## exported file themselves (docs/PLAYTEST_GUIDE.md).

const DEFAULT_PATH := "user://playtest_log.json"
const EXPORT_DIR := "user://exports"
const FORMAT := 1
const MAX_TEXT := 500

## Tests point this at a scratch file.
static var path: String = DEFAULT_PATH


static func load_all() -> Array:
	if not FileAccess.file_exists(path):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) == TYPE_DICTIONARY and typeof((d as Dictionary).get("runs")) == TYPE_ARRAY:
		return (d as Dictionary)["runs"]
	return []


static func _save_all(runs: Array) -> bool:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"format": FORMAT, "game": SaveCodec.GAME_ID, "runs": runs}, "  ", true))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


static func has_run(run_id: String) -> bool:
	for r: Dictionary in load_all():
		if str(r.get("run_id", "")) == run_id:
			return true
	return false


## Builds the record from the finished run (real numbers only).
static func build_record(run: Dictionary) -> Dictionary:
	var deck: Array = []
	for inst: Dictionary in run.get("deck", []):
		deck.append({"def_id": inst.get("def_id", ""), "upgrade": inst.get("upgrade_id", "")})
	var stats: Dictionary = run.get("stats", {})
	return {
		"run_id": str(run.get("run_id", "")),
		"seed": int(run.get("seed", 0)),
		"champion": str(run.get("champion_id", "")),
		"faction": str(run.get("main_faction", "")),
		"champion_path": str(run.get("champion_path", "")),
		"champion_rank": int(run.get("champion_rank", 0)),
		"result": str(run.get("result", run.get("phase", ""))),
		"battles_won": int(stats.get("battles_won", 0)),
		"history": run.get("history", []),
		"turns": int(stats.get("turns", 0)),
		"cards_played": int(stats.get("cards_played", 0)),
		"heart_lost": int(stats.get("heart_lost", 0)),
		"heart_end": int(run.get("heart", 0)),
		"heart_max": int(run.get("heart_max", 0)),
		"relics": run.get("relics", []),
		"mutations": run.get("mutations", []),
		"deck": deck,
		"reward_claims": run.get("reward_claims", {}),
		"build": SaveCodec.BUILD_ID,
		"language": Loc.language,
		"logged_at": Time.get_datetime_string_from_system(true),
		"feedback": {},
	}


## Appends the run once. Returns true when a new record was written.
static func record_run(run: Dictionary) -> bool:
	var id: String = str(run.get("run_id", ""))
	if id == "" or not (str(run.get("phase", "")) in ["won", "lost"]):
		return false
	var runs: Array = load_all()
	for r: Dictionary in runs:
		if str(r.get("run_id", "")) == id:
			return false
	runs.append(build_record(run))
	return _save_all(runs)


## stars 1..5 (0 = not given), forecast "yes" | "partly" | "no" | "", text <= 500 chars.
static func set_feedback(run_id: String, stars: int, forecast: String, text: String) -> bool:
	var runs: Array = load_all()
	for r: Dictionary in runs:
		if str(r.get("run_id", "")) == run_id:
			r["feedback"] = {"stars": clampi(stars, 0, 5), "forecast_clear": forecast if forecast in ["yes", "partly", "no"] else "",
				"text": text.strip_edges().left(MAX_TEXT), "given_at": Time.get_datetime_string_from_system(true)}
			return _save_all(runs)
	return false


static func feedback_of(run_id: String) -> Dictionary:
	for r: Dictionary in load_all():
		if str(r.get("run_id", "")) == run_id:
			return r.get("feedback", {})
	return {}


## {runs, champions: {champion_id: {runs, won}}}
static func summary() -> Dictionary:
	var champs: Dictionary = {}
	var runs: Array = load_all()
	for r: Dictionary in runs:
		var c: String = str(r.get("champion", ""))
		if not champs.has(c):
			champs[c] = {"runs": 0, "won": 0}
		champs[c]["runs"] = int(champs[c]["runs"]) + 1
		if str(r.get("result", "")) == "won":
			champs[c]["won"] = int(champs[c]["won"]) + 1
	return {"runs": runs.size(), "champions": champs}


## Writes user://exports/lastroot_playtest_<date>.json; returns its absolute path ("" on failure).
static func export_file() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR))
	var stamp: String = Time.get_datetime_string_from_system(false).replace(":", "-").replace("T", "_")
	var p: String = "%s/lastroot_playtest_%s.json" % [EXPORT_DIR, stamp]
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify({"format": FORMAT, "game": SaveCodec.GAME_ID, "build": SaveCodec.BUILD_ID,
		"exported_at": Time.get_datetime_string_from_system(true), "runs": load_all()}, "  ", true))
	f.close()
	return ProjectSettings.globalize_path(p)


static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
