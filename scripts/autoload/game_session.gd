extends Node
## Owns the active run (bible p.27). UI and 3D never change state: they send
## commands here, GameSession runs the pure reducer, saves the authoritative
## result atomically, then tells listeners. Presentation replays the returned
## events afterwards; it can never alter the outcome.

signal run_changed(events: Array)
signal command_rejected(reason: String)
signal run_started

var run: Dictionary = {}
## True while the presenter replays the last resolution (saved with the run so
## a reload shows the final state instead of re-settling anything).
var presentation_pending: bool = false
var last_events: Array = []


func has_run() -> bool:
	return not run.is_empty()


func phase() -> String:
	return str(run.get("phase", ""))


func battle() -> Dictionary:
	return run.get("battle", {})


func new_run(faction: String, seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF
	run = RunReducer.new_run(seed_value, faction)
	presentation_pending = false
	last_events = []
	SaveService.save_run(run, _presentation())
	run_started.emit()
	run_changed.emit([])


## Loads the saved run. Returns SaveService's result; on success the run is active.
func continue_run(use_backup: bool = false) -> Dictionary:
	var res: Dictionary = SaveService.load_backup() if use_backup else SaveService.load_run()
	if res["ok"]:
		run = res["run"]
		presentation_pending = false  # load shows the finished result directly
		last_events = []
		if use_backup:
			SaveService.save_run(run, _presentation())
		run_started.emit()
		run_changed.emit([])
	return res


func abandon_run() -> void:
	run = {}
	SaveService.delete_run()


## Applies a run command. Returns the reducer result.
func cmd(command: Dictionary) -> Dictionary:
	if run.is_empty():
		return {"ok": false, "error": "No run."}
	var res: Dictionary = RunReducer.apply(run, command)
	if not res["ok"]:
		command_rejected.emit(res["error"])
		return res
	run = res["run"]
	last_events = res["events"]
	presentation_pending = _has_resolution(last_events)
	SaveService.save_run(run, _presentation())
	run_changed.emit(last_events)
	return res


func battle_cmd(command: Dictionary) -> Dictionary:
	return cmd({"type": "battle", "cmd": command})


## Called by the presenter when the visual replay finished (or was skipped).
func presentation_done() -> void:
	if presentation_pending:
		presentation_pending = false
		SaveService.save_run(run, _presentation())


func _presentation() -> Dictionary:
	return {"pending": presentation_pending, "resolution_id": int(battle().get("resolution_id", 0))}


func _has_resolution(events: Array) -> bool:
	for e: Dictionary in events:
		if e.get("kind", "") == "resolution_end":
			return true
	return false


## Scene id that matches the run phase (AppFlow uses it).
func scene_for_phase() -> String:
	match phase():
		"battle":
			return "battle"
		"reward", "route", "node":
			return "run"
		"won", "lost":
			return "result"
	return "menu"
