extends SceneTree
## Forecast latency over the stored scenarios (bible p.22: target < 50 ms).
## godot --headless --path . --script res://tools/balance/profile_forecast.gd
## Writes evidence/perf/forecast_latency.json. Measured on this machine only.


func _init() -> void:
	var d: Dictionary = JsonUtil.load_file("res://fixtures/forecast/scenarios.json")
	var end_turn: Array = []
	var preview: Array = []
	for sc: Dictionary in d["scenarios"]:
		var s: Dictionary = sc["state"]
		Forecast.clear_cache()
		var t0 := Time.get_ticks_usec()
		Forecast.end_turn(s)
		end_turn.append((Time.get_ticks_usec() - t0) / 1000.0)
		var cmds: Array = AutoPlayer.legal_commands(s)
		if not cmds.is_empty():
			Forecast.clear_cache()
			t0 = Time.get_ticks_usec()
			Forecast.after_command(s, cmds[0])
			preview.append((Time.get_ticks_usec() - t0) / 1000.0)
	var rep := {"engine_version": Engine.get_version_info()["string"], "machine": "cloud container, 4 cores, no GPU",
		"target_ms": 50, "end_turn": _stats(end_turn), "preview_after_command": _stats(preview)}
	rep["status"] = "PASS" if rep["end_turn"]["p95"] < 50.0 and rep["preview_after_command"]["p95"] < 50.0 else "FAIL"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/perf"))
	var f := FileAccess.open("res://evidence/perf/forecast_latency.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rep, "  ", true))
	f.close()
	print(JSON.stringify(rep))
	quit()


func _stats(a: Array) -> Dictionary:
	a.sort()
	if a.is_empty():
		return {}
	return {"n": a.size(), "p50": a[a.size() / 2], "p95": a[int(a.size() * 0.95)], "max": a[-1]}
