extends Node
## QA recording entry (LR-34 evidence/video). Same start as boot.gd -- a
## DebugFixtures state driven by the real AutoDriver through GameSession --
## plus a logger that writes what the run actually did next to the movie:
## per end turn the forecast shown before it (Forecast.end_turn on the live
## battle state) and whether the real resolution events matched it.
## Run under Movie Maker, e.g.
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1280x720 \
##     --write-movie /tmp/clip.avi --fixed-fps 30 res://scenes/tests/record_clip.tscn -- \
##     --setup=battle1 --faction=SPORE --seed=3 --autoplay=1 --max_seconds=28 --log=evidence/video/x.json
## Extra args: --max_seconds=N (movie time cap), --battle_seconds=N (quit N s
## after a battle screen starts, for reward->battle clips), --delay=S (seconds
## between bot actions; AutoDriver default 0.9), --log=path.
## Demo/save checks (LR-34): --new_run=BARK|SPORE starts through
## GameSession.new_run (the player's path, so a "demo" export gets a demo run)
## instead of a fixture; --continue=1 loads the saved run like the Continue
## button; --end_hold=S keeps going when the run ends: the bot stops, the
## battle playback finishes, the end banner's button is pressed, the result
## screen stays S seconds; --shot_on_end=path then saves a screenshot of it. The
## log records the save file (path, mode, phase) before and after.


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	var logger := ClipLogger.new()
	logger.args = args
	logger.log_path = str(args.get("log", ""))
	logger.max_seconds = float(args.get("max_seconds", "30"))
	logger.battle_seconds = float(args.get("battle_seconds", "-1"))
	logger.shot_path = str(args.get("shot_on_end", ""))
	logger.end_hold = float(args.get("end_hold", "-1"))
	logger.save_before = ClipLogger.save_info()
	get_tree().root.call_deferred("add_child", logger)
	if args.has("continue"):
		logger.continue_result = GameSession.continue_run()
		logger.continue_result.erase("run")
	elif args.has("new_run"):
		GameSession.new_run(str(args["new_run"]), int(args.get("seed", "1")))
	else:
		GameSession.run = DebugFixtures.make(str(args.get("setup", "battle1")), str(args.get("faction", "BARK")), int(args.get("seed", "1")))
		GameSession.presentation_pending = false
	var ad := AutoDriver.new()
	ad.battles = maxi(1, int(args.get("autoplay", "1")))
	ad.delay = float(args.get("delay", str(ad.delay)))
	logger.driver = ad
	get_tree().root.call_deferred("add_child", ad)
	AppFlow.call_deferred("goto_phase")


class ClipLogger:
	extends Node
	var args: Dictionary = {}
	var log_path: String = ""
	var max_seconds: float = 30.0
	var battle_seconds: float = -1.0
	var _t: float = 0.0
	var _battle_t: float = -1.0
	var _forecast: Dictionary = {}
	var _turns: Array = []
	var _phases: Array = []
	var _notes: Array = []
	var _written := false
	var shot_path: String = ""
	var save_before: Dictionary = {}
	var continue_result: Dictionary = {}
	var _end_t: float = -1.0
	var _shot_done := false
	var end_hold: float = -1.0
	var driver: Node = null
	var _result_t: float = -1.0

	static func save_info() -> Dictionary:
		var out := {"feature_demo": OS.has_feature("demo"), "save_file": ProjectSettings.globalize_path(SaveService.MAIN),
			"has_save": SaveService.has_save()}
		if SaveService.has_save():
			var r: Dictionary = SaveService.load_run()
			out["load_ok"] = r.get("ok", false)
			if r.get("ok", false):
				var run: Dictionary = r["run"]
				for k: String in ["run_id", "mode", "phase", "battle_index", "result", "faction"]:
					out[k] = run.get(k, null)
		return out

	func _ready() -> void:
		GameSession.run_changed.connect(_on_changed)
		_snapshot_forecast()
		_phase_mark()

	func _process(dt: float) -> void:
		_t += dt
		if GameSession.phase() == "battle" and get_tree().current_scene is BattleScreen:
			if _battle_t < 0.0:
				_battle_t = 0.0
			_battle_t += dt
		if GameSession.phase() in ["won", "lost"] and end_hold >= 0.0:
			if is_instance_valid(driver):
				driver.queue_free()  # AutoDriver would quit 3 s after the run ends
			var scr: Node = get_tree().current_scene
			if scr is BattleScreen:
				var b: BattleScreen = scr
				var banner: bool = b.end_banner != null and is_instance_valid(b.end_banner) and b.end_banner.is_visible_in_tree()
				_end_t = maxf(_end_t, 0.0) + dt if banner else 0.0
				if _end_t > 2.0:
					# Press the end banner's button, as a player would.
					for btn: Node in b.end_banner.find_children("*", "BaseButton", true, false):
						(btn as BaseButton).pressed.emit()
						break
					_end_t = -10.0
			elif scr != null:
				_result_t = maxf(_result_t, 0.0) + dt
				if _result_t >= end_hold:
					if shot_path != "" and not _shot_done:
						_shot_done = true
						var img: Image = get_viewport().get_texture().get_image()
						var sp: String = shot_path if shot_path.is_absolute_path() else ProjectSettings.globalize_path("res://" + shot_path)
						DirAccess.make_dir_recursive_absolute(sp.get_base_dir())
						img.save_png(sp)
						print("CLIP_SHOT ", sp)
					_notes.append({"t": snappedf(_t, 0.01), "end_screen": str(scr.name), "scene_file": scr.scene_file_path})
					_write()
					get_tree().quit()
					return
		if _t >= max_seconds or (battle_seconds > 0.0 and _battle_t >= battle_seconds):
			_write()
			get_tree().quit()

	func _exit_tree() -> void:
		_write()

	func _phase_mark() -> void:
		var p: String = GameSession.phase()
		if _phases.is_empty() or _phases[-1]["phase"] != p:
			_phases.append({"t": snappedf(_t, 0.01), "phase": p, "battle_index": int(GameSession.run.get("battle_index", -1)),
				"result": str(GameSession.run.get("result", ""))})

	func _snapshot_forecast() -> void:
		_forecast = {}
		if GameSession.phase() != "battle":
			return
		var b: Dictionary = GameSession.battle()
		if str(b.get("phase", "")) != "player":
			return
		var f: Dictionary = Forecast.end_turn(b)
		_forecast = {"turn": int(b["turn"]), "heart_before": int(b["heart"]), "summary": f["summary"],
			"events": JsonUtil.canonical(f["events"])}

	func _on_changed(events: Array) -> void:
		for e: Dictionary in events:
			if str(e.get("kind", "")) == "mutation_gained":
				_notes.append({"t": snappedf(_t, 0.01), "mutation_gained": str(e.get("id", "")),
					"mutations_now": GameSession.run.get("mutations", [])})
		var resolved := false
		for e: Dictionary in events:
			if str(e.get("kind", "")) == "resolution_end":
				resolved = true
		if resolved and not _forecast.is_empty():
			var real: Array = events.filter(func(e: Dictionary) -> bool: return str(e.get("stage", "")) == "resolution")
			var s: Dictionary = _forecast["summary"]
			var deaths := 0
			for k: String in (s["units"] as Dictionary).keys():
				if s["units"][k]["dies"]:
					deaths += 1
			var real_deaths := 0
			var real_heart := 0
			var climbs := 0
			for e: Dictionary in real:
				if str(e.get("kind", "")) in ["death"]:
					real_deaths += 1
				if str(e.get("kind", "")) == "enemy_climbed":
					climbs += 1
				if str(e.get("kind", "")) == "heart_damaged":
					real_heart += int(e.get("amount", 0))
			_turns.append({"t": snappedf(_t, 0.01), "turn": _forecast["turn"],
				"forecast_heart_damage": s["heart_damage"], "forecast_deaths": deaths, "forecast_result": s["result"],
				"real_heart_damage": real_heart, "real_deaths": real_deaths, "enemy_climbs": climbs, "real_resolution_events": real.size(),
				"events_match_forecast": JsonUtil.canonical(real) == _forecast["events"]})
		_snapshot_forecast()
		_phase_mark()

	func _write() -> void:
		if _written or log_path == "":
			return
		_written = true
		var abs_path: String = log_path if log_path.is_absolute_path() else ProjectSettings.globalize_path("res://" + log_path)
		DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
		var all_match := true
		for t: Dictionary in _turns:
			all_match = all_match and bool(t["events_match_forecast"])
		var out := {"args": args, "movie_seconds": snappedf(_t, 0.01), "engine": Engine.get_version_info()["string"],
			"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
			"end_turns": _turns, "all_end_turns_match_forecast": all_match, "phases": _phases, "notes": _notes,
			"final_phase": GameSession.phase(), "final_mutations": GameSession.run.get("mutations", []),
			"final_mode": GameSession.run.get("mode", null), "final_result": GameSession.run.get("result", null),
			"battles_won": (GameSession.run.get("stats", {}) as Dictionary).get("battles_won", null),
			"save_before": save_before, "save_after": save_info(), "continue_result": continue_result}
		var f := FileAccess.open(abs_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(out, "  "))
			f.close()
		print("CLIP_LOG ", abs_path, " end_turns=", _turns.size(), " all_match=", all_match)
