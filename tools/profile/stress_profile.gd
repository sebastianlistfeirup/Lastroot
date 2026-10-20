extends Node
## LR-29 performance profile (needs a real renderer, not --headless):
##   XDG_DATA_HOME=/tmp/xdg_x xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
##     --rendering-method gl_compatibility --resolution 1920x1080 res://tools/profile/stress_profile.tscn
## 1. Load time of the main scenes (load + instantiate + first two drawn frames),
##    cold (first in the process) and warm (second time).
## 2. Frame time of the battle scene for DebugFixtures states midbattle and boss
##    plus "full_tree": the boss battle with every floor filled to capacity with
##    allies and five enemies per floor (test-only state, built with the
##    reducer's own new_unit; validated by SaveCodec.validate_run).
##    Each: 60 warm-up frames, then IDLE_FRAMES idle frames, then the replay of
##    one real End turn at 1x speed. V-sync off, no FPS cap.
## Writes evidence/perf/stress_profile.json. Software rendering (llvmpipe under
## Xvfb) is far slower than any GPU: these numbers are an upper bound for the
## CPU/driver cost, not a frame-rate claim for players.

const OUT := "res://evidence/perf/stress_profile.json"
const IDLE_FRAMES := 300
const SCENES := {
	"menu": "res://scenes/menu/main_menu.tscn",
	"battle": "res://scenes/battle/battle.tscn",
	"run": "res://scenes/flow/run_screen.tscn",
	"result": "res://scenes/flow/result_screen.tscn",
}

var report: Dictionary = {}


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _main() -> void:
	report["engine_version"] = Engine.get_version_info()["string"]
	report["timestamp"] = Time.get_datetime_string_from_system(true)
	report["renderer"] = {
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"window": [get_window().size.x, get_window().size.y],
		"logical": [get_window().content_scale_size.x, get_window().content_scale_size.y],
		"cpu": OS.get_processor_name(), "cpu_count": OS.get_processor_count(),
	}
	report["caveat"] = "Software rasterizer under Xvfb in a cloud container (no GPU). Frame times are dominated by CPU rasterization and are NOT representative of player hardware; use them to compare states and builds, not as an fps promise."
	report["load"] = await _load_times()
	var states := {}
	for fx: String in ["midbattle", "boss", "full_tree"]:
		states[fx] = await _battle_profile(fx)
	report["battle"] = states
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/perf"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ", true))
	f.close()
	for fx: String in states:
		var s: Dictionary = states[fx]
		print("STRESS %s units=%d idle p50=%.1f p95=%.1f p99=%.1f ms  replay p95=%.1f ms  draw_calls=%d" % [fx, s["units"],
			s["idle"]["p50_ms"], s["idle"]["p95_ms"], s["idle"]["p99_ms"], s["replay"]["p95_ms"], s["draw_calls"]])
	for k: String in report["load"]:
		print("LOAD %s cold=%d ms warm=%d ms" % [k, report["load"][k]["cold_ms"], report["load"][k]["warm_ms"]])
	get_tree().quit(0)


# ------------------------------------------------------------------ load

func _fixture_for(scene_id: String) -> Dictionary:
	match scene_id:
		"battle":
			return DebugFixtures.make("midbattle", "BARK", 2)
		"run":
			return DebugFixtures.make("reward", "BARK", 2)
		"result":
			return DebugFixtures.make("won", "BARK", 2)
	return {}


func _load_times() -> Dictionary:
	var out := {}
	var fixtures := {}
	for id: String in SCENES:
		fixtures[id] = _fixture_for(id)  # domain work is not part of scene load time
	for id: String in SCENES:
		var times: Array = []
		for rep in 2:
			GameSession.run = (fixtures[id] as Dictionary).duplicate(true)
			GameSession.presentation_pending = false
			var t0: int = Time.get_ticks_usec()
			var ps: PackedScene = ResourceLoader.load(SCENES[id], "", ResourceLoader.CACHE_MODE_REUSE if rep > 0 else ResourceLoader.CACHE_MODE_REPLACE)
			var t1: int = Time.get_ticks_usec()
			var n: Node = ps.instantiate()
			n.set("auto_navigate", false)
			add_child(n)
			var t2: int = Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var t3: int = Time.get_ticks_usec()
			times.append({"load_ms": (t1 - t0) / 1000.0, "instantiate_ready_ms": (t2 - t1) / 1000.0,
				"first_frames_ms": (t3 - t2) / 1000.0, "total_ms": (t3 - t0) / 1000.0})
			n.queue_free()
			await _frames(3)
		out[id] = {"cold_ms": int(times[0]["total_ms"]), "warm_ms": int(times[1]["total_ms"]), "cold": times[0], "warm": times[1]}
	return out


# ------------------------------------------------------------------ battle

func _full_tree() -> Dictionary:
	var run: Dictionary = DebugFixtures.make("boss", "BARK", 2)
	var b: Dictionary = run["battle"]
	var small: Array = []
	for c: Dictionary in Catalog.cards():
		if c["kind"] == "unit" and int(c["space"]) == 1:
			small.append(c["id"])
	var enemies: Array = []
	for e: Dictionary in Catalog.data()["enemies"]:
		enemies.append(e["id"])
	var iid := 1000
	for f in 3:
		var k := 0
		while BattleReducer.used_space(b, f) + 1 <= BattleReducer.capacity(b, f):
			var cid: String = small[k % small.size()]
			var def: Dictionary = Catalog.card(cid)
			b["deck"][str(iid)] = {"def_id": cid, "upgrade_id": ""}
			(b["zones"]["deployed"] as Array).append(iid)
			var uid: int = BattleReducer.new_unit(b, "ally", cid, iid, f, CardStats.unit_stats(def, "", "", 0))
			BattleReducer.floor_list(b, f, "ally").append(uid)
			iid += 1
			k += 1
		while BattleReducer.floor_list(b, f, "enemy").size() < 5:
			var eid: String = enemies[(f + BattleReducer.floor_list(b, f, "enemy").size()) % enemies.size()]
			var d: Dictionary = Catalog.enemy(eid)
			var uid2: int = BattleReducer.new_unit(b, "enemy", eid, -1, f, {"attack": int(d["attack"]), "max_hp": int(d["max_hp"]), "armor": int(d["start_armor"])})
			BattleReducer.floor_list(b, f, "enemy").append(uid2)
	run["next_instance_id"] = iid
	return run


func _stats(us: Array) -> Dictionary:
	var ms: Array = us.map(func(x: int) -> float: return x / 1000.0)
	ms.sort()
	if ms.is_empty():
		return {"frames": 0}
	var sum := 0.0
	for x: float in ms:
		sum += x
	var pick := func(q: float) -> float: return snappedf(float(ms[clampi(int(q * (ms.size() - 1)), 0, ms.size() - 1)]), 0.01)
	return {"frames": ms.size(), "mean_ms": snappedf(sum / ms.size(), 0.01), "p50_ms": pick.call(0.5),
		"p95_ms": pick.call(0.95), "p99_ms": pick.call(0.99), "max_ms": snappedf(float(ms[-1]), 0.01),
		"fps_mean": snappedf(1000.0 * ms.size() / maxf(sum, 0.001), 0.1)}


func _battle_profile(fx: String) -> Dictionary:
	var run: Dictionary = _full_tree() if fx == "full_tree" else DebugFixtures.make(fx, "BARK", 2)
	var problems: PackedStringArray = SaveCodec.validate_run(run)
	GameSession.run = run
	GameSession.presentation_pending = false
	var scr: BattleScreen = (load(SCENES["battle"]) as PackedScene).instantiate() as BattleScreen
	add_child(scr)
	await _frames(60)
	var idle: Array = []
	var proc: Array = []
	var last: int = Time.get_ticks_usec()
	for i in IDLE_FRAMES:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		idle.append(now - last)
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		last = now
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objs: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var vmem: int = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var units: int = BattleReducer.all_allies(GameSession.battle()).size() + BattleReducer.all_enemies(GameSession.battle()).size()
	# replay of one real End turn at 1x
	scr.presenter.speed = 1.0
	var t_cmd: int = Time.get_ticks_usec()
	GameSession.battle_cmd({"type": "end_turn"})
	var t_cmd_done: int = Time.get_ticks_usec()
	var replay: Array = []
	last = Time.get_ticks_usec()
	var guard := 0
	while (scr.presenter.playing or guard < 2) and guard < 6000:
		await RenderingServer.frame_post_draw
		var now2: int = Time.get_ticks_usec()
		replay.append(now2 - last)
		last = now2
		guard += 1
	var res := {"units": units, "valid_state": problems.is_empty(), "state_problems": problems,
		"idle": _stats(idle), "process_ms_mean": snappedf(_mean(proc), 0.01), "replay": _stats(replay),
		"replay_seconds": snappedf((Time.get_ticks_usec() - t_cmd_done) / 1e6, 0.01),
		"end_turn_command_ms": snappedf((t_cmd_done - t_cmd) / 1000.0, 0.01),
		"draw_calls": draw_calls, "primitives": prims, "objects_in_frame": objs,
		"video_mem_mb": snappedf(vmem / 1048576.0, 0.1), "nodes": nodes}
	scr.queue_free()
	await _frames(5)
	return res


func _mean(a: Array) -> float:
	var s := 0.0
	for x: float in a:
		s += x
	return s / maxf(1.0, float(a.size()))
