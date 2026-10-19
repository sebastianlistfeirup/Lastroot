extends Node
## Scene tests with real nodes and real input paths (bible p.28, LR-07/08/09):
## godot --headless --path . res://scenes/tests/scene_smoke.tscn
## Writes evidence/scene_smoke.json; exit code 1 on failure.

var checks := 0
var failures: PackedStringArray = []
var results: Array = []


func ok(cond: bool, msg: String) -> void:
	checks += 1
	results.append({"name": msg, "ok": cond})
	if not cond:
		failures.append(msg)
		print("FAIL ", msg)


func _ready() -> void:
	await _run()
	print("SMOKE %d checks, %d failed" % [checks, failures.size()])
	var f := FileAccess.open("res://evidence/scene_smoke.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine_version": Engine.get_version_info()["string"],
		"timestamp": Time.get_datetime_string_from_system(true), "checks": checks,
		"failures": failures, "results": results, "status": "PASS" if failures.is_empty() else "FAIL"}, "  ", true))
	f.close()
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open_battle(faction: String, seed_value: int) -> BattleScreen:
	GameSession.run = RunReducer.new_run(seed_value, faction)
	GameSession.presentation_pending = false
	var scr: BattleScreen = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(scr)
	await _frames(3)
	return scr


func _settle(scr: BattleScreen) -> void:
	for i in 600:
		if not scr.presenter.playing:
			break
		scr.presenter.skip()
		await get_tree().process_frame
	await _frames(2)


func _save_files() -> void:
	SaveService.delete_run()
	var run := RunReducer.new_run(5150, "BARK")
	ok(SaveService.save_run(run), "save writes")
	run["resin"] = 77
	ok(SaveService.save_run(run), "second save writes (first becomes backup)")
	var f := FileAccess.open(SaveService.MAIN, FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	var res: Dictionary = SaveService.load_run()
	ok(not res["ok"] and res.get("backup_available", false), "corrupt save offers the backup")
	var bak: Dictionary = SaveService.load_backup()
	ok(bak["ok"] and int(bak["run"]["resin"]) == 30, "backup holds the previous good save")
	var env := SaveCodec.make_envelope(run)
	env["schema_version"] = 42
	f = FileAccess.open(SaveService.MAIN, FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f.close()
	res = SaveService.load_run()
	ok(res["code"] == "future_version", "future version refused")
	ok(FileAccess.file_exists(SaveService.MAIN), "future-version file is not deleted")
	var exported: String = SaveService.export_json(run)
	ok(exported != "" and SaveService.import_json(exported)["ok"], "JSON export/import")
	SaveService.delete_run()
	# presentation checkpoint: final state saved before playback; load shows it.
	GameSession.run = RunReducer.new_run(5151, "SPORE")
	GameSession.battle_cmd({"type": "end_turn"})
	var mid: Dictionary = SaveService.load_run()
	ok(mid["ok"] and mid["presentation"].get("pending", false), "saved with presentation_pending during playback")
	ok(int(mid["run"]["battle"]["turn"]) == 2, "saved state is already the final result")
	GameSession.continue_run()
	ok(not GameSession.presentation_pending and int(GameSession.battle()["turn"]) == 2, "load shows the finished result, nothing re-settled")


func _flow() -> void:
	# menu -> battle -> result -> menu, each scene instanced from AppFlow's table.
	var ok_all := true
	GameSession.run = RunReducer.new_run(31, "BARK")
	for sid in ["menu", "battle", "result", "menu"]:
		if sid == "result":
			GameSession.run = AutoPlayer.play_run(RunReducer.new_run(31, "BARK"))["run"]
		var ps: PackedScene = load(AppFlow.SCENES[sid])
		var n: Node = ps.instantiate() if ps != null else null
		if n == null:
			ok_all = false
			continue
		add_child(n)
		await _frames(4)
		ok_all = ok_all and is_instance_valid(n)
		n.queue_free()
		await _frames(2)
	ok(ok_all, "menu_to_battle_to_result_to_menu")


func _run() -> void:
	await _save_files()
	await _flow()
	# --- layout and first action through the real buttons
	var scr: BattleScreen = await _open_battle("BARK", 4242)
	var b: Dictionary = GameSession.battle()
	ok(scr.stage.floor_views.size() == 3, "three floor views")
	ok(scr.views.size() == BattleReducer.all_enemies(b).size(), "one view per living unit at start")
	var champ: int = b["champion_iid"]
	scr._on_card_pressed(champ)
	ok(scr.mode == "card" and scr.ghost_nodes.size() > 0, "champion shows insert slots")
	var slot: Button = null
	for g in scr.ghost_nodes:
		if g is Button and not (g as Button).disabled:
			slot = g
			break
	ok(slot != null, "an enabled slot exists")
	slot.pressed.emit()
	ok(not scr.pending.is_empty(), "slot sets a pending command")
	ok(scr.forecast_box.get_child_count() > 0, "preview forecast rendered")
	var energy_before: int = GameSession.battle()["energy"]
	scr.btn_confirm.pressed.emit()
	await _settle(scr)
	ok(BattleReducer.all_allies(GameSession.battle()).size() == 1, "champion on the board")
	ok(int(GameSession.battle()["energy"]) == energy_before, "champion cost 0")
	var n_allies: int = BattleReducer.all_allies(GameSession.battle()).size()
	scr.btn_confirm.pressed.emit()
	await _settle(scr)
	ok(BattleReducer.all_allies(GameSession.battle()).size() == n_allies, "second confirm does nothing (one tap, one action)")
	ok(scr.views.size() == BattleReducer.all_allies(GameSession.battle()).size() + BattleReducer.all_enemies(GameSession.battle()).size(), "views match units")
	# --- invalid target shows a reason and spends nothing
	var hash_before := JsonUtil.state_hash(GameSession.battle())
	scr.pending = {"type": "play_card", "card": -99, "floor": 0}
	scr._preview()
	ok(scr.reason_label.text != "", "invalid command shows a reason")
	ok(JsonUtil.state_hash(GameSession.battle()) == hash_before, "invalid command changes nothing")
	# --- end turn locks input during playback
	scr.btn_end.pressed.emit()
	await get_tree().process_frame
	ok(scr.locked, "input locked while resolving")
	var h_locked := JsonUtil.state_hash(GameSession.battle())
	var hand: Array = GameSession.battle()["zones"]["hand"]
	if not hand.is_empty():
		scr._on_card_pressed(hand[0])
	scr.btn_end.pressed.emit()
	ok(JsonUtil.state_hash(GameSession.battle()) == h_locked, "no command accepted while locked")
	await _settle(scr)
	ok(not scr.locked, "unlocked after playback")
	ok(int(GameSession.battle()["turn"]) == 2, "turn 2 after one end turn")
	ok(not GameSession.presentation_pending, "presentation checkpoint cleared")
	# --- views snap to authoritative anchors after playback
	var bad := 0
	for uid: int in scr.views.keys():
		if not (GameSession.battle()["units"][str(uid)]["alive"]):
			bad += 1
	ok(bad == 0, "no view for a dead unit")
	# --- resize does not touch the battle
	var h2 := JsonUtil.state_hash(GameSession.battle())
	get_window().size = Vector2i(390, 844)
	await _frames(3)
	scr._relayout()
	ok(JsonUtil.state_hash(GameSession.battle()) == h2, "resize keeps BattleState")
	get_window().size = Vector2i(1600, 900)
	await _frames(2)
	scr.queue_free()
	await _frames(2)
	# --- complete battle 1 with both champions via the screen's command path
	for faction in ["BARK", "SPORE"]:
		var s2: BattleScreen = await _open_battle(faction, 777)
		var steps := 0
		while GameSession.phase() == "battle" and steps < 300:
			var cmd: Dictionary = AutoPlayer.choose(GameSession.battle())
			GameSession.battle_cmd(cmd)
			await _settle(s2)
			steps += 1
		ok(GameSession.phase() == "reward", "%s wins battle 1 through the scene (phase %s)" % [faction, GameSession.phase()])
		ok(s2.end_banner != null and s2.end_banner.visible, "%s end banner shown" % faction)
		s2.queue_free()
		await _frames(2)
	# --- skip and full-speed playback end in the same view state
	var s3: BattleScreen = await _open_battle("SPORE", 99)
	GameSession.battle_cmd(AutoPlayer.choose(GameSession.battle()))
	await _settle(s3)
	var base_run: Dictionary = GameSession.run.duplicate(true)
	GameSession.battle_cmd({"type": "end_turn"})
	await _settle(s3)
	var pos_skip := _positions(s3)
	GameSession.run = base_run
	s3._full_sync()
	s3.presenter.speed = 2.0
	GameSession.battle_cmd({"type": "end_turn"})
	for i in 900:
		if not s3.presenter.playing:
			break
		await get_tree().process_frame
	await _frames(30)
	ok(_positions(s3) == pos_skip, "2x playback and skip end in identical view state")
	s3.queue_free()


func _positions(s: BattleScreen) -> Dictionary:
	var out := {}
	for uid: int in s.views.keys():
		var p: Vector3 = (s.views[uid] as Node3D).position
		out[uid] = Vector3(snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01))
	return out
