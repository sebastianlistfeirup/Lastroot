extends Node
## LR-29 repeated run/restart leak check through the real scenes and AppFlow:
##   XDG_DATA_HOME=/tmp/xdg_x godot --headless --path . res://tools/profile/leak_check.tscn [-- --runs=30]
## Each iteration starts a run via GameSession, opens the real battle scene
## (AppFlow.goto, the same change_scene path as the game), plays with the bot
## through GameSession.battle_cmd while the presenter replays (skipped each
## frame), goes through reward/route/node screens via GameSession.cmd, and
## either finishes the whole run (even iterations, result screen) or abandons
## it after the first reward screen (odd iterations, back to the menu).
## After every iteration, on the menu, it records Performance monitors.
## Pass: after WARMUP iterations nothing grows monotonically (see _verdict).
## Writes evidence/perf/leak_check.json; exit 0/1. Uses user:// saves, so run
## it with its own XDG_DATA_HOME.

const WARMUP := 5
const SETTLE_S := 3.0
const OUT := "res://evidence/perf/leak_check.json"

var runs: int = 30
var samples: Array = []
var is_driver: bool = false
var only: String = ""
var leave_mid_playback: bool = OS.get_cmdline_user_args().has("--leave-mid-playback")
var reset_log: bool = OS.get_cmdline_user_args().has("--reset-playtest-log")
var _t0: int = 0


func _ready() -> void:
	if not is_driver:
		# This scene is replaced by the first AppFlow.goto; the driver must
		# survive scene changes, so a second instance lives under the root.
		var d: Node = (get_script() as GDScript).new()
		d.set("is_driver", true)
		d.name = "LeakDriver"
		get_tree().root.add_child.call_deferred(d)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
		if a.begins_with("--runs="):
			runs = maxi(WARMUP + 6, int(a.get_slice("=", 1)))
	_main.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_scene(id: String) -> bool:
	var path: String = AppFlow.SCENES[id]
	for i in 600:
		var cs: Node = get_tree().current_scene
		if cs != null and cs.scene_file_path == path and cs.is_node_ready():
			return true
		await get_tree().process_frame
	return false


func _sample(i: int, kind: String, steps: int, ms: int) -> void:
	await _frames(8)  # let queue_free and deferred calls finish
	await get_tree().create_timer(SETTLE_S).timeout  # pending one-shot timers (popups, toasts) expire
	await _frames(4)
	# Bounded caches by design (Forecast keeps <= 64 resolved states, then
	# clears) would make static memory saw-tooth; empty it so the samples
	# compare like with like. Its size is recorded first.
	var forecast_cached: int = Forecast._cache.size()
	Forecast._cache.clear()
	await _frames(2)
	samples.append({
		"forecast_cache_entries": forecast_cached,
		"static_caches": {"proxy_mesh": ProxyMesh._cache.size(), "palette": VisualPalette._cache.size(),
			"proxy_unfog": ProxyBuilder._unfog_cache.size(), "card_portraits": CardPortraits._cache.size(),
			"visual_slots_built": VisualSlots._built.size()},
		"iteration": i, "kind": kind, "commands": steps, "ms": ms,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"memory_static": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	})
	var s: Dictionary = samples[-1]
	print("LEAK it=%d %s cmds=%d objs=%d nodes=%d orphans=%d res=%d mem=%.1fMB %d ms caches=%s" % [i, kind, steps,
		s["objects"], s["nodes"], s["orphan_nodes"], s["resources"], float(s["memory_static"]) / 1048576.0, ms, JSON.stringify(s["static_caches"])])


## Plays the current run through the real screens until `stop` says so.
## Returns the number of accepted commands.
func _drive(stop: Callable) -> int:
	var steps := 0
	var idle := 0
	for guard in 40000:
		if stop.call():
			break
		var phase: String = GameSession.phase()
		var want: String = GameSession.scene_for_phase()
		var cs: Node = get_tree().current_scene
		if cs == null or cs.scene_file_path != AppFlow.SCENES[want]:
			# The battle just ended: like a player, let the last replay finish
			# (Skip) before leaving, unless --leave-mid-playback is given.
			if cs is BattleScreen and (cs as BattleScreen).presenter.playing and not leave_mid_playback:
				(cs as BattleScreen).presenter.skip()
				await get_tree().process_frame
				continue
			idle += 1
			if idle > 30:  # screens navigate themselves; nudge if one did not
				idle = 0
				AppFlow.goto_phase()
			await get_tree().process_frame
			continue
		idle = 0
		if cs is BattleScreen:
			var b: BattleScreen = cs
			if b.presenter.playing:
				b.presenter.skip()
			elif not b.locked and phase == "battle":
				if GameSession.battle_cmd(AutoPlayer.choose(GameSession.battle()))["ok"]:
					steps += 1
		elif phase in ["reward", "route", "node"]:
			if GameSession.cmd(AutoPlayer.choose_run(GameSession.run))["ok"]:
				steps += 1
		await get_tree().process_frame
	return steps


## --only=<scene>: bisecting aid. Opens just that screen each iteration
## (menu | battle | battle_play | run | result) and samples on the menu.
func _diagnose(i: int) -> void:
	match only:
		"battle", "battle_play":
			GameSession.new_run("BARK", 7000 + i)
			AppFlow.goto("battle")
			await _wait_scene("battle")
			if only == "battle_play":
				await _drive(func() -> bool: return GameSession.phase() != "battle")
				var bs: BattleScreen = get_tree().current_scene as BattleScreen
				while bs != null and bs.presenter.playing and not leave_mid_playback:
					bs.presenter.skip()
					await get_tree().process_frame
		"run":
			GameSession.run = AutoPlayer.play_battle(RunReducer.new_run(7000 + i, "BARK"))
			AppFlow.goto("run")
			await _wait_scene("run")
		"result":
			GameSession.run = AutoPlayer.play_run(RunReducer.new_run(7000 + i, "BARK"))["run"]
			AppFlow.goto("result")
			await _wait_scene("result")
	await _frames(10)
	GameSession.abandon_run()
	AppFlow.goto("menu")
	await _wait_scene("menu")
	await _sample(i, "only_" + only, 0, 0)


func _at_reward_screen() -> bool:
	return GameSession.phase() == "reward" and get_tree().current_scene is RunScreen


func _main() -> void:
	_t0 = Time.get_ticks_msec()
	AppFlow.goto("menu")
	await _wait_scene("menu")
	await _sample(0, "menu_baseline", 0, 0)
	for i in range(1, runs + 1):
		var t: int = Time.get_ticks_msec()
		if only != "":
			await _diagnose(i)
			continue
		var full: bool = i % 2 == 0
		GameSession.new_run("BARK" if i % 4 < 2 else "SPORE", 7000 + i)
		AppFlow.goto_phase()
		await _wait_scene("battle")
		var steps: int
		if full:
			steps = await _drive(func() -> bool: return GameSession.phase() in ["won", "lost"])
			AppFlow.goto_phase()
			await _wait_scene("result")
			await _frames(4)
		else:
			steps = await _drive(_at_reward_screen)
			await _frames(4)
			GameSession.abandon_run()
		AppFlow.goto("menu")
		await _wait_scene("menu")
		await _sample(i, "full_run_%s" % str(GameSession.run.get("result", "")) if full else "abandon_after_reward",
			steps, Time.get_ticks_msec() - t)
		if full:
			GameSession.abandon_run()
		if reset_log:
			PlaytestLog.clear()  # isolates growth of the (by design ever-growing) playtest log
	var verdict: Dictionary = _verdict()
	print("LEAK_CHECK %s %s" % [verdict["status"], JSON.stringify(verdict["growth"])])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/perf"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"engine_version": Engine.get_version_info()["string"],
		"timestamp": Time.get_datetime_string_from_system(true),
		"command": "godot --headless --path . res://tools/profile/leak_check.tscn -- --runs=%d" % runs,
		"runs": runs, "warmup": WARMUP, "duration_ms": Time.get_ticks_msec() - _t0,
		"note": "Headless (dummy renderer, dummy audio). Samples taken on the main menu after each run. "
			+ "Even iterations play the whole run through battle/reward/route/node/result scenes; odd ones abandon after the first reward screen. "
			+ "Like a player, the driver lets the last replay finish (Skip) before leaving a battle; --leave-mid-playback leaves during the replay instead. "
			+ "Forecast's bounded state cache (<= 64 entries) is emptied before each sample; the entry count is recorded.",
		"mode": "leave_mid_playback" if leave_mid_playback else ("only_" + only if only != "" else "realistic"),
		"known_finding": "Leaving the battle scene while the presenter replays (e.g. Save & quit during an animation) leaks 2 objects per exit (--only=battle_play --leave-mid-playback: +2 objects per iteration, nodes and resources flat). Not fixed: suspected suspended replay coroutines in BattlePresenter/BattleScreen; a child-Timer variant of BattlePresenter._wait did not change it.",
		"criterion": verdict["criterion"], "growth": verdict["growth"], "status": verdict["status"],
		"samples": samples,
	}, "  ", true))
	f.close()
	get_tree().quit(0 if verdict["status"] == "PASS" else 1)


## After warm-up, compares the first and last third of the remaining samples
## (same mix of full/abandoned runs) and counts strictly increasing steps.
func _verdict() -> Dictionary:
	var post: Array = samples.slice(WARMUP + 1)
	var third: int = maxi(2, post.size() / 3)
	var early: Array = post.slice(0, third)
	var late: Array = post.slice(post.size() - third)
	var growth := {}
	var fail := false
	var limits := {"objects": 0.02, "nodes": 0.02, "resources": 0.03, "memory_static": 0.05}
	for k: String in ["objects", "nodes", "orphan_nodes", "resources", "memory_static"]:
		var a: float = _mean(early, k)
		var b: float = _mean(late, k)
		var ups := 0
		for j in range(1, post.size()):
			if int(post[j][k]) > int(post[j - 1][k]):
				ups += 1
		var rel: float = (b - a) / maxf(a, 1.0)
		var bad: bool
		if k == "orphan_nodes":
			bad = b - a > 2.0
		else:
			bad = rel > float(limits[k])
		# strictly monotonic growth across all post-warm-up iterations = leak
		bad = bad or (ups == post.size() - 1 and rel > 0.005)
		fail = fail or bad
		growth[k] = {"early_mean": a, "late_mean": b, "relative": snappedf(rel, 0.0001), "increasing_steps": ups,
			"of_steps": post.size() - 1, "ok": not bad}
	return {"status": "FAIL" if fail else "PASS", "growth": growth,
		"criterion": "After %d warm-up runs: late-third mean vs early-third mean grows <= 2%% (objects, nodes), <= 3%% (resources), <= 5%% (static memory), orphan nodes <= +2; and no metric rises in every single step." % WARMUP}


func _mean(arr: Array, k: String) -> float:
	var s := 0.0
	for x: Dictionary in arr:
		s += float(x[k])
	return s / maxf(1.0, float(arr.size()))
