extends Node
## Screenshot capture for the meta screens:
##   xvfb-run -a godot --path . --rendering-method gl_compatibility res://scenes/tests/meta_capture.tscn
## Each case renders in its own SubViewport at 1920x1080 and 430x932 (the
## logical portrait viewport of a 390x844 phone) and is saved to
## evidence/meta_screens/<case>_<size>.png. Optional: -- --only=<substring>.
## The player's real save is backed up first and restored at the end.

const OUT := "res://evidence/meta_screens/"
const SIZES := {"desktop": Vector2i(1920, 1080), "phone": Vector2i(430, 932)}

var _saved: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_backup_save()
	PlaytestLog.path = "user://capture_playtest_log.json"  # keep the real log clean
	PlaytestLog.clear()
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var cases: Array = _cases()
	var n := 0
	for c: Dictionary in cases:
		if only != "" and not str(c["id"]).contains(only):
			continue
		for size_name: String in SIZES.keys():
			if c.has("sizes") and not (c["sizes"] as Array).has(size_name):
				continue
			await _capture(c, size_name, SIZES[size_name])
			n += 1
	_restore_save()
	print("META_CAPTURE %d screenshots -> %s" % [n, ProjectSettings.globalize_path(OUT)])
	get_tree().quit(0)


func _cases() -> Array:
	return [
		{"id": "menu_title", "scene": "menu", "run": MetaFixtures.route(1), "save": true},
		{"id": "menu_faction", "scene": "menu", "run": {}, "view": "faction"},
		{"id": "menu_first_run", "scene": "menu", "run": {}, "view": "first_run"},
		{"id": "menu_settings", "scene": "menu", "run": {}, "open": "settings"},
		{"id": "menu_settings_playtest", "scene": "menu", "run": {}, "open": "settings_playtest"},
		{"id": "menu_credits", "scene": "menu", "run": {}, "open": "credits"},
		{"id": "reward_card", "scene": "run", "run": MetaFixtures.reward_slot("card"), "select": "first_offer"},
		{"id": "reward_mutation", "scene": "run", "run": MetaFixtures.reward_slot("mutation")},
		{"id": "reward_champion", "scene": "run", "run": MetaFixtures.reward_slot("champion"), "select": "first_offer"},
		{"id": "reward_champion_rank2", "scene": "run", "run": MetaFixtures.reward_slot("champion2")},
		{"id": "reward_relic", "scene": "run", "run": MetaFixtures.reward_slot("relic", "SPORE")},
		{"id": "route_b1", "scene": "run", "run": MetaFixtures.route(1)},
		{"id": "route_b4", "scene": "run", "run": MetaFixtures.route(4), "select": "first_option"},
		{"id": "node_camp", "scene": "run", "run": MetaFixtures.node("camp", 1), "select": "first_upgradable"},
		{"id": "node_removal", "scene": "run", "run": MetaFixtures.node("removal", 1), "select": "first_normal"},
		{"id": "node_encounter", "scene": "run", "run": MetaFixtures.node("encounter", 1)},
		{"id": "node_card", "scene": "run", "run": MetaFixtures.node("card", 1)},
		{"id": "run_deck", "scene": "run", "run": MetaFixtures.route(4), "open": "deck"},
		{"id": "run_detail", "scene": "run", "run": MetaFixtures.route(4), "open": "relic_detail"},
		{"id": "run_pause", "scene": "run", "run": MetaFixtures.route(1), "open": "pause"},
		{"id": "result_won", "scene": "result", "run": MetaFixtures.won()},
		{"id": "result_lost", "scene": "result", "run": MetaFixtures.lost()},
		{"id": "result_demo", "scene": "result", "run": MetaFixtures.demo_done()},
		{"id": "menu_demo", "scene": "menu", "run": {}, "demo": true},
		{"id": "da_route", "scene": "run", "run": MetaFixtures.route(4), "lang": "da"},
		{"id": "da_camp", "scene": "run", "run": MetaFixtures.node("camp", 1), "select": "first_upgradable", "lang": "da"},
		{"id": "da_faction", "scene": "menu", "run": {}, "view": "faction", "lang": "da"},
		{"id": "route_boss", "scene": "run", "run": MetaFixtures.route(5)},
		{"id": "howto_floors", "scene": "menu", "run": {}, "open": "howto:0"},
		{"id": "howto_sap", "scene": "menu", "run": {}, "open": "howto:1"},
		{"id": "howto_target", "scene": "menu", "run": {}, "open": "howto:2"},
		{"id": "howto_forecast", "scene": "menu", "run": {}, "open": "howto:3"},
		{"id": "howto_climb", "scene": "menu", "run": {}, "open": "howto:4"},
		{"id": "howto_status", "scene": "menu", "run": {}, "open": "howto:5"},
		{"id": "howto_boss", "scene": "menu", "run": {}, "open": "howto:6"},
		{"id": "da_howto_status", "scene": "menu", "run": {}, "open": "howto:5", "lang": "da"},
		{"id": "run_pause_abandon", "scene": "run", "run": MetaFixtures.route(1), "open": "abandon"},
		{"id": "battle_mid", "scene": "battle", "run": DebugFixtures.make("midbattle", "SPORE", 3)},
		{"id": "battle_pause", "scene": "battle", "run": DebugFixtures.make("midbattle", "BARK", 1), "open": "battle_pause"},
		{"id": "pbattle_b1_hint", "scene": "battle", "run": DebugFixtures.make("battle1", "BARK", 1), "sizes": ["phone"]},
		{"id": "pbattle_b1_ghosts", "scene": "battle", "run": DebugFixtures.make("battle1", "BARK", 1), "open": "battle_card", "sizes": ["phone"]},
		{"id": "pbattle_mid", "scene": "battle", "run": DebugFixtures.make("midbattle", "SPORE", 3), "sizes": ["phone"]},
		{"id": "pbattle_mid_ghosts", "scene": "battle", "run": DebugFixtures.make("midbattle", "SPORE", 3), "open": "battle_card", "sizes": ["phone"]},
		{"id": "pbattle_mid_sheet", "scene": "battle", "run": DebugFixtures.make("midbattle", "SPORE", 3), "open": "battle_sheet", "sizes": ["phone"]},
		{"id": "pbattle_mid_badge", "scene": "battle", "run": DebugFixtures.make("midbattle", "SPORE", 3), "open": "battle_badge", "sizes": ["phone"]},
		{"id": "pbattle_boss", "scene": "battle", "run": DebugFixtures.make("boss", "BARK", 2), "sizes": ["phone"]},
		{"id": "pbattle_mid_da130", "scene": "battle", "run": DebugFixtures.make("midbattle", "SPORE", 3), "lang": "da", "scale": 1.3, "sizes": ["phone"]},
		{"id": "text130_reward_relic", "scene": "run", "run": MetaFixtures.reward_slot("relic"), "scale": 1.3},
	]


func _capture(c: Dictionary, size_name: String, sz: Vector2i) -> void:
	GameSession.run = (c["run"] as Dictionary).duplicate(true)
	Loc.set_language(str(c.get("lang", "en")))
	UiKit.font_scale = float(c.get("scale", 1.0))
	if c.get("save", false):
		SaveService.save_run(GameSession.run)
	elif str(c["scene"]) == "menu":
		SaveService.delete_run()
	var sv := SubViewport.new()
	sv.size = sz
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	add_child(sv)
	var path: String = {"menu": "res://scenes/menu/main_menu.tscn", "run": "res://scenes/flow/run_screen.tscn",
		"result": "res://scenes/flow/result_screen.tscn", "battle": "res://scenes/battle/battle.tscn"}[c["scene"]]
	MainMenu.force_demo_tag = bool(c.get("demo", false))
	if c.has("view"):
		MainMenu.start_view = str(c["view"])
	var screen: Node = (load(path) as PackedScene).instantiate()
	screen.set("auto_navigate", false)
	sv.add_child(screen)
	await _frames(3 if c["scene"] != "battle" else 30)
	_apply_select(screen, str(c.get("select", "")))
	_apply_open(screen, str(c.get("open", "")))
	await _frames(6)
	var img: Image = sv.get_texture().get_image()
	img.save_png(OUT + "%s_%s.png" % [c["id"], size_name])
	sv.queue_free()
	Loc.set_language("en")
	UiKit.font_scale = 1.0
	await _frames(1)


func _apply_select(screen: Node, sel: String) -> void:
	if not (screen is RunScreen):
		return
	var rs: RunScreen = screen
	var run: Dictionary = GameSession.run
	match sel:
		"first_offer":
			rs.select_offer(str(RunReducer.current_slot(run)["offer"][0]))
		"first_option":
			rs.sel_node = str(RunReducer.current_route(run)["options"][0]["id"])
			rs.render()
		"first_upgradable":
			for inst: Dictionary in DeckViewer.sorted_deck(run):
				if not CardStats.legal_upgrades(Catalog.card(inst["def_id"]), inst["upgrade_id"]).is_empty():
					rs.select_instance(int(inst["instance_id"]))
					return
		"first_normal":
			for inst: Dictionary in DeckViewer.sorted_deck(run):
				if Catalog.card(inst["def_id"])["kind"] != "champion":
					rs.select_instance(int(inst["instance_id"]))
					return


func _apply_open(screen: Node, what: String) -> void:
	if what.begins_with("howto:"):
		var h: HowToPlayPanel = screen.find_child("HowToPlayPanel", true, false) as HowToPlayPanel
		h.page = int(what.substr(6))
		h.open()
		return
	match what:
		"settings_playtest":
			PlaytestLog.record_run(MetaFixtures.won())
			PlaytestLog.record_run(MetaFixtures.lost())
			var sp: SettingsPanel = screen.find_child("SettingsPanel", true, false) as SettingsPanel
			sp.open()
			sp.last_export = PlaytestLog.export_file()
			sp.rebuild()
			(sp.find_child("ClearPlaytestButton", true, false) as Control).grab_focus.call_deferred()
		"abandon":
			(screen.find_child("MenuButton", true, false) as Button).pressed.emit()
			(screen.find_child("PauseMenu", true, false) as PauseMenu).ask_abandon()
		"battle_pause":
			screen.call("_open_menu")
		"battle_card":
			var b: Dictionary = GameSession.battle()
			for iid: int in b["zones"]["hand"]:
				if Catalog.is_creature(BattleReducer.card_def(b, iid)) and BattleReducer.play_cost(b, iid) <= int(b["energy"]):
					screen.call("_on_card_pressed", iid)
					return
		"battle_sheet":
			if screen.has_method("set_sheet_open"):
				screen.call("set_sheet_open", true)
		"battle_badge":
			var b: Dictionary = GameSession.battle()
			for key: String in b["units"].keys():
				if b["units"][key]["side"] == "enemy" and b["units"][key]["alive"]:
					screen.call("_on_badge_pressed", int(key))
					return
		"settings":
			(screen.find_child("SettingsPanel", true, false) as SettingsPanel).open()
		"credits":
			(screen.find_child("CreditsPanel", true, false) as CreditsPanel).open()
		"deck":
			(screen.find_child("DeckButton", true, false) as Button).pressed.emit()
		"pause":
			(screen.find_child("MenuButton", true, false) as Button).pressed.emit()
		"relic_detail":
			for n: Node in screen.find_child("HeaderRow", true, false).get_children():
				if n.name.begins_with("Relic_"):
					(n as Button).pressed.emit()
					return


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _backup_save() -> void:
	for p: String in [SaveService.MAIN, SaveService.BACKUP]:
		if FileAccess.file_exists(p):
			_saved[p] = FileAccess.get_file_as_bytes(p)


func _restore_save() -> void:
	SaveService.delete_run()
	for p: String in _saved.keys():
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_buffer(_saved[p])
		f.close()
