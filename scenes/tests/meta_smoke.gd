extends Node
## Headless smoke for the meta screens:
##   godot --headless --path . res://scenes/tests/meta_smoke.tscn
## Instantiates the menu, run and result scenes with real fixture runs in
## every phase, presses the real buttons (emits `pressed` on them, exactly what
## a tap does) and asserts the resulting GameSession.run. Prints
## "META_SMOKE n checks, m failed", writes evidence/meta_smoke.json and quits
## with exit code 0/1. The player's real save is backed up and restored.

const MENU := "res://scenes/menu/main_menu.tscn"
const RUN := "res://scenes/flow/run_screen.tscn"
const RESULT := "res://scenes/flow/result_screen.tscn"

var checks := 0
var failures: PackedStringArray = []
var log_lines: PackedStringArray = []
var _saved: Dictionary = {}
var _case: String = ""


var _onboarding_was: bool = false
var _settings_bytes: PackedByteArray = PackedByteArray()


func _ready() -> void:
	_backup_save()
	if FileAccess.file_exists(SettingsService.PATH):
		_settings_bytes = FileAccess.get_file_as_bytes(SettingsService.PATH)
	_onboarding_was = SettingsService.onboarding_done
	SettingsService.onboarding_done = true  # the first-run prompt has its own case
	var t0: int = Time.get_ticks_msec()
	await _menu_cases()
	await _reward_cases()
	await _route_cases()
	await _node_cases()
	await _header_cases()
	await _result_cases()
	await _pause_cases()
	await _resume_cases()
	await _howto_cases()
	await _keyboard_cases()
	await _round5_cases()
	_restore_save()
	SettingsService.onboarding_done = _onboarding_was
	if not _settings_bytes.is_empty():
		var sf := FileAccess.open(SettingsService.PATH, FileAccess.WRITE)
		sf.store_buffer(_settings_bytes)
		sf.close()
	var ms: int = Time.get_ticks_msec() - t0
	for f in failures:
		print("FAIL ", f)
	print("META_SMOKE %d checks, %d failed" % [checks, failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence"))
	var out := FileAccess.open("res://evidence/meta_smoke.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({
		"engine_version": Engine.get_version_info()["string"],
		"timestamp": Time.get_datetime_string_from_system(true),
		"checks": checks, "failed": failures.size(), "failures": failures, "steps": log_lines,
		"duration_ms": ms, "status": "PASS" if failures.is_empty() else "FAIL",
	}, "  ", true))
	out.close()
	get_tree().quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- helpers

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [_case, msg])


func step(msg: String) -> void:
	log_lines.append("%s: %s" % [_case, msg])


## Instantiates a scene in its own SubViewport (desktop or phone size).
func mount(path: String, run: Dictionary, size: Vector2i = Vector2i(1920, 1080)) -> Control:
	GameSession.run = run.duplicate(true)
	var sv := SubViewport.new()
	sv.size = size
	add_child(sv)
	var s: Control = (load(path) as PackedScene).instantiate()
	s.set("auto_navigate", false)
	sv.add_child(s)
	await _frames(2)
	return s


func unmount(s: Control) -> void:
	var sv: Node = s.get_parent()
	sv.queue_free()
	await _frames(1)


func btn(root: Node, node_name: String) -> Button:
	return root.find_child(node_name, true, false) as Button


## A real tap: emits `pressed` on the visible, enabled button.
func press(root: Node, node_name: String) -> bool:
	var b := btn(root, node_name)
	ok(b != null, "button %s exists" % node_name)
	if b == null:
		return false
	ok(not b.disabled and b.is_visible_in_tree(), "button %s enabled and visible" % node_name)
	ok(b.custom_minimum_size.y >= UiKit.MIN_HIT or b.size.y >= UiKit.MIN_HIT, "button %s is >= 48 px tall" % node_name)
	step("press " + node_name)
	b.pressed.emit()
	await _frames(1)
	return true


## Tap on a CardView / ChoiceTile (both emit `pressed` from _gui_input).
func tap(root: Node, node_name: String) -> void:
	var n: Node = root.find_child(node_name, true, false)
	ok(n != null and n.has_signal("pressed"), "tappable %s exists" % node_name)
	if n:
		step("tap " + node_name)
		n.emit_signal("pressed")
		await _frames(1)


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


# ------------------------------------------------------------------- menu

func _menu_cases() -> void:
	_case = "menu_no_save"
	SaveService.delete_run()
	var m: Control = await mount(MENU, {})
	ok(btn(m, "ContinueButton") == null, "no Continue without a save")
	ok(btn(m, "NewRunButton") != null, "New Run present")
	ok((btn(m, "QuitButton") != null) == MainMenu.show_quit(), "Quit only on desktop")
	await press(m, "SettingsButton")
	ok((m.find_child("SettingsPanel", true, false) as Control).visible, "settings overlay opens")
	(m.find_child("SettingsPanel", true, false) as SettingsPanel).close()
	await press(m, "CreditsButton")
	var lic: Label = m.find_child("LicenseText", true, false) as Label
	ok(lic != null and lic.text.contains("MIT") or (lic != null and lic.text.length() > 200), "credits show Godot's license text")
	(m.find_child("CreditsPanel", true, false) as CreditsPanel).close()
	await press(m, "NewRunButton")
	ok((m as MainMenu).view == "faction", "New Run opens champion select")
	ok(m.find_child("ChampionCard", true, false) is CardView, "champion shown as CardView")
	await press(m, "BackButton")
	ok((m as MainMenu).view == "title", "Back returns to the title")
	await press(m, "NewRunButton")
	await press(m, "Choose_SPORE")
	ok(GameSession.run.get("main_faction", "") == "SPORE", "new run with the Spore faction")
	ok(GameSession.phase() == "battle" and (m as MainMenu).pending_scene == "battle", "new run goes to battle")
	await unmount(m)

	_case = "menu_continue"
	var fixture: Dictionary = MetaFixtures.route(1)
	SaveService.save_run(fixture)
	m = await mount(MENU, {})
	ok(btn(m, "ContinueButton") != null, "Continue shown with a save")
	GameSession.run = {}
	await press(m, "ContinueButton")
	ok(GameSession.phase() == "route" and (m as MainMenu).pending_scene == "run", "Continue loads the run into the route screen")
	# New Run over an unfinished run asks first.
	await press(m, "NewRunButton")
	var dlg: MessageDialog = m.find_child("MessageDialog", true, false) as MessageDialog
	ok(dlg.visible, "confirm dialog before replacing a run")
	ok((m as MainMenu).view == "title", "still on title until confirmed")
	var confirm: Button = dlg.footer.get_child(1) as Button
	confirm.pressed.emit()
	await _frames(1)
	ok((m as MainMenu).view == "faction", "confirmed -> champion select")
	await unmount(m)

	_case = "menu_corrupt"
	SaveService.save_run(fixture)
	SaveService.save_run(fixture)  # second write makes the first one the backup
	var bad := FileAccess.open(SaveService.MAIN, FileAccess.WRITE)
	bad.store_string("{ this is not json")
	bad.close()
	m = await mount(MENU, {})
	GameSession.run = {}
	await press(m, "ContinueButton")
	dlg = m.find_child("MessageDialog", true, false) as MessageDialog
	ok(dlg.visible and dlg.title_text == Loc.t("Damaged save"), "damaged save explained")
	ok(FileAccess.file_exists(SaveService.MAIN), "damaged file is kept")
	var load_b: Button = dlg.footer.get_child(dlg.footer.get_child_count() - 1) as Button
	ok(load_b.text == Loc.t("Load backup"), "backup offered")
	load_b.pressed.emit()
	await _frames(1)
	ok(GameSession.phase() == "route", "backup loaded")
	await unmount(m)

	_case = "menu_future"
	var env: Dictionary = SaveCodec.make_envelope(fixture, {})
	env["schema_version"] = 999
	var fut_text: String = JSON.stringify(env)
	var ff := FileAccess.open(SaveService.MAIN, FileAccess.WRITE)
	ff.store_string(fut_text)
	ff.close()
	m = await mount(MENU, {})
	GameSession.run = {}
	await press(m, "ContinueButton")
	dlg = m.find_child("MessageDialog", true, false) as MessageDialog
	ok(dlg.visible and dlg.title_text == Loc.t("Newer save"), "future version explained")
	ok(GameSession.run.is_empty(), "nothing loaded from a newer save")
	ok(FileAccess.get_file_as_string(SaveService.MAIN) == fut_text, "newer save never touched")
	await unmount(m)
	SaveService.delete_run()


# ---------------------------------------------------------------- rewards

func _reward_cases() -> void:
	_case = "reward_card"
	var run: Dictionary = MetaFixtures.reward_slot("card")
	var s: Control = await mount(RUN, run)
	ok(s.find_child("SlotStrip", true, false) != null, "slot strip shown")
	ok(s.find_child("Slot_B1_resin", true, false) != null, "resin summary in strip")
	ok(btn(s, "ConfirmButton").disabled, "confirm disabled before a choice")
	var slot: Dictionary = RunReducer.current_slot(GameSession.run)
	var pick: String = slot["offer"][2]
	var n_before: int = (GameSession.run["deck"] as Array).size()
	await tap(s, "Offer_" + pick)
	await press(s, "ConfirmButton")
	ok((GameSession.run["deck"] as Array).size() == n_before + 1, "card added")
	ok(str(GameSession.run["deck"][-1]["def_id"]) == pick, "the tapped card was added")
	ok(RunReducer.current_slot(GameSession.run).get("type", "") == "mutation", "mutation slot next")
	ok(btn(s, "SkipButton") == null, "mutation has no Skip")
	var mslot: Dictionary = RunReducer.current_slot(GameSession.run)
	await tap(s, "Offer_" + str(mslot["offer"][1]))
	await press(s, "ConfirmButton")
	ok((GameSession.run["mutations"] as Array).has(mslot["offer"][1]), "mutation claimed")
	ok(GameSession.phase() == "route", "rewards done -> route")
	await unmount(s)

	_case = "reward_card_skip"
	s = await mount(RUN, MetaFixtures.reward_slot("card"))
	var sid: String = RunReducer.current_slot(GameSession.run)["id"]
	await press(s, "SkipButton")
	ok(str(GameSession.run["reward_claims"].get(sid, "")) == "skipped", "card slot skipped")
	await unmount(s)

	_case = "reward_champion"
	s = await mount(RUN, MetaFixtures.reward_slot("champion"))
	var cs: Dictionary = RunReducer.current_slot(GameSession.run)
	ok((cs["offer"] as Array).size() == 2, "two paths offered")
	ok(s.find_child("Offer_" + str(cs["offer"][0]), true, false).find_child("After", true, false) is CardView, "before/after CardViews")
	await tap(s, "Offer_" + str(cs["offer"][1]))
	await press(s, "ConfirmButton")
	ok(GameSession.run["champion_path"] == cs["offer"][1] and int(GameSession.run["champion_rank"]) == 1, "path chosen at rank 1")
	ok(RunReducer.current_slot(GameSession.run).get("type", "") == "relic", "relic next")
	var rs: Dictionary = RunReducer.current_slot(GameSession.run)
	await tap(s, "Offer_" + str(rs["offer"][0]))
	await press(s, "ConfirmButton")
	ok((GameSession.run["relics"] as Array).has(rs["offer"][0]), "relic claimed")
	ok(GameSession.phase() == "route", "route after relic")
	await unmount(s)

	_case = "reward_champion_rank2"
	s = await mount(RUN, MetaFixtures.reward_slot("champion2"))
	var c2: Dictionary = RunReducer.current_slot(GameSession.run)
	ok((c2["offer"] as Array).size() == 1, "only the locked path at rank 2")
	await press(s, "ConfirmButton")
	ok(int(GameSession.run["champion_rank"]) == 2, "rank 2 reached")
	await unmount(s)

	_case = "reward_relic_portrait"
	s = await mount(RUN, MetaFixtures.reward_slot("relic", "SPORE"), Vector2i(430, 932))
	var rl: Dictionary = RunReducer.current_slot(GameSession.run)
	await tap(s, "Offer_" + str(rl["offer"][2]))
	await press(s, "ConfirmButton")
	ok((GameSession.run["relics"] as Array).has(rl["offer"][2]), "relic claimed on portrait")
	await unmount(s)


# ------------------------------------------------------------------ route

func _route_cases() -> void:
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(430, 932)]:
		_case = "route_%dx%d" % [size.x, size.y]
		var s: Control = await mount(RUN, MetaFixtures.route(1), size)
		ok(s.find_child("RouteMap", true, false) is RouteMap, "route map shown")
		var route: Dictionary = RunReducer.current_route(GameSession.run)
		var opt: Dictionary = route["options"][1]
		ok(s.find_child("MapNode_B5", true, false) != null, "boss node on the map")
		var mapb: Button = btn(s, "MapNode_" + str(opt["id"]))
		ok(mapb != null and mapb.size.x >= 48.0, "map node is a 48+ px target")
		mapb.pressed.emit()
		await _frames(1)
		ok((s as RunScreen).sel_node == opt["id"], "tapping the map selects the option")
		await press(s, "Go_" + str(opt["id"]))
		ok(GameSession.phase() == "node" and GameSession.run["node"]["id"] == opt["id"], "choose_node entered the node")
		await unmount(s)


# ------------------------------------------------------------------ nodes

func _node_cases() -> void:
	_case = "camp"
	var s: Control = await mount(RUN, MetaFixtures.node("camp"))
	var target: Dictionary = {}
	for inst: Dictionary in DeckViewer.sorted_deck(GameSession.run):
		if not CardStats.legal_upgrades(Catalog.card(inst["def_id"]), inst["upgrade_id"]).is_empty():
			target = inst
			break
	var champ_iid: int = int(DeckViewer.sorted_deck(GameSession.run)[0]["instance_id"])
	await tap(s, "Card_%d" % champ_iid)
	ok(btn(s, "Upgrade_attack_2") == null, "champion shows no upgrade buttons")
	await tap(s, "Card_%d" % int(target["instance_id"]))
	var ups: Array = CardStats.legal_upgrades(Catalog.card(target["def_id"]), "")
	var resin0: int = int(GameSession.run["resin"])
	await press(s, "Upgrade_" + str(ups[0]["id"]))
	var inst2: Dictionary = RunReducer.instance(GameSession.run, int(target["instance_id"]))
	ok(inst2.get("upgrade_id", "") == ups[0]["id"], "upgrade applied")
	ok(int(GameSession.run["resin"]) == resin0 - int(ups[0]["price"]), "price paid")
	ok(GameSession.phase() == "battle" and (s as RunScreen).pending_scene == "battle", "camp -> next battle")
	await unmount(s)

	_case = "camp_unaffordable"
	var poor: Dictionary = MetaFixtures.node("camp")
	poor["resin"] = 5
	s = await mount(RUN, poor)
	await tap(s, "Card_%d" % int(target["instance_id"]))
	var ub: Button = btn(s, "Upgrade_" + str(ups[0]["id"]))
	ok(ub != null and ub.disabled, "unaffordable upgrade disabled")
	await press(s, "LeaveButton")
	ok(GameSession.phase() == "battle" and int(GameSession.run["resin"]) == 5, "leave camp keeps Resin")
	await unmount(s)

	_case = "removal"
	s = await mount(RUN, MetaFixtures.node("removal"), Vector2i(430, 932))
	var normal: Dictionary = {}
	for inst: Dictionary in DeckViewer.sorted_deck(GameSession.run):
		if Catalog.card(inst["def_id"])["kind"] != "champion":
			normal = inst
			break
	var deck_n: int = (GameSession.run["deck"] as Array).size()
	await tap(s, "Card_%d" % int(normal["instance_id"]))
	await press(s, "RemoveButton")
	ok((GameSession.run["deck"] as Array).size() == deck_n - 1, "card removed")
	ok(RunReducer.instance(GameSession.run, int(normal["instance_id"])).is_empty(), "the tapped card is gone")
	await unmount(s)

	_case = "removal_minimum"
	var thin: Dictionary = MetaFixtures.node("removal")
	var keep: Array = []
	var normals := 0
	for inst: Dictionary in thin["deck"]:
		if Catalog.card(inst["def_id"])["kind"] == "champion" or normals < 7:
			keep.append(inst)
			if Catalog.card(inst["def_id"])["kind"] != "champion":
				normals += 1
	thin["deck"] = keep
	s = await mount(RUN, thin)
	await tap(s, "Card_%d" % int(keep[-1]["instance_id"]))
	ok(btn(s, "RemoveButton").disabled, "removal disabled at 7 normal cards")
	var rej: Dictionary = (s as RunScreen).send({"type": "remove_card", "card": int(keep[-1]["instance_id"])})
	ok(not rej["ok"], "reducer agrees")
	await _frames(1)
	ok((s as RunScreen).last_toast() != "", "rejection reason shown")
	await unmount(s)

	for choice: String in ["resin", "heal"]:
		_case = "encounter_" + choice
		var enc: Dictionary = MetaFixtures.node("encounter")
		enc["heart"] = 40
		s = await mount(RUN, enc)
		await press(s, "Encounter_" + choice)
		if choice == "resin":
			ok(int(GameSession.run["resin"]) == int(enc["resin"]) + 15, "+15 Resin")
		else:
			ok(int(GameSession.run["heart"]) == 48, "Heart healed 8")
		ok(GameSession.phase() == "battle", "encounter -> battle")
		await unmount(s)

	_case = "card_node"
	s = await mount(RUN, MetaFixtures.node("card"))
	var slot: Dictionary = GameSession.run["node"]["slots"][0]
	var dn: int = (GameSession.run["deck"] as Array).size()
	await tap(s, "Offer_" + str(slot["offer"][0]))
	await press(s, "ConfirmButton")
	ok((GameSession.run["deck"] as Array).size() == dn + 1 and GameSession.phase() == "battle", "card node claim -> battle")
	await unmount(s)

	_case = "card_node_skip"
	s = await mount(RUN, MetaFixtures.node("card"))
	await press(s, "SkipButton")
	ok(GameSession.phase() == "battle", "card node skip -> battle")
	await unmount(s)


func _header_cases() -> void:
	_case = "header"
	var run: Dictionary = MetaFixtures.route(4)
	var s: Control = await mount(RUN, run)
	var rid: String = run["relics"][0]
	await press(s, "Relic_" + rid)
	ok((s as RunScreen).detail_text() == Loc.field(Catalog.relic(rid), "text"), "tap relic shows its text")
	await press(s, "Relic_" + rid)
	ok((s as RunScreen).detail_text() == "", "second tap closes the detail")
	await press(s, "HeartChip")
	ok((s as RunScreen).detail_text().contains("%d" % int(run["heart"])), "heart detail has real numbers")
	await press(s, "DeckButton")
	var dv: DeckViewer = s.find_child("DeckViewer", true, false) as DeckViewer
	var cards := 0
	for n: Node in dv.find_children("Card_*", "", true, false):
		if n is CardView:
			cards += 1
	ok(dv.visible and cards == (run["deck"] as Array).size(), "deck viewer shows every card (%d)" % cards)
	dv.close()
	await unmount(s)


# ----------------------------------------------------------------- result

func _result_cases() -> void:
	for kind: String in ["won", "lost"]:
		_case = "result_" + kind
		var run: Dictionary = MetaFixtures.won() if kind == "won" else MetaFixtures.lost()
		ok(run.get("phase", "") == kind, "fixture is a real %s run" % kind)
		var s: Control = await mount(RESULT, run)
		var head: Label = s.find_child("Headline", true, false) as Label
		ok(head != null and head.text == (Loc.t("The tree stands") if kind == "won" else Loc.t("The Heart has fallen")), "headline")
		var turns: Label = s.find_child("Stat_Turns_played", true, false) as Label
		ok(turns != null and turns.text == str(int(run["stats"]["turns"])), "turns from run stats")
		var cp: Label = s.find_child("Stat_Cards_played", true, false) as Label
		ok(cp != null and cp.text == str(int(run["stats"]["cards_played"])), "cards played from run stats")
		await press(s, "NewRunButton" if kind == "won" else "MainMenuButton")
		ok((s as ResultScreen).pending_scene == "menu", "goes to menu")
		ok(MainMenu.start_view == ("faction" if kind == "won" else "title"), "New run opens champion select")
		ok(GameSession.phase() == kind, "result buttons start no run")
		MainMenu.start_view = "title"
		await unmount(s)


func _pause_cases() -> void:
	_case = "pause"
	var holder := Control.new()
	add_child(holder)
	var p: PauseMenu = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	holder.add_child(p)
	await _frames(1)
	ok(btn(p, "PauseCornerButton").visible, "visible pause button")
	await press(p, "PauseCornerButton")
	ok(p.is_open, "opens from the button")
	await press(p, "PauseSettingsButton")
	ok((p.find_child("SettingsPanel", true, false) as Control).visible, "settings from pause")
	(p.find_child("SettingsPanel", true, false) as SettingsPanel).close()
	await press(p, "ResumeButton")
	ok(not p.is_open, "Resume closes")
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	p._unhandled_input(ev)
	ok(p.is_open, "Esc opens")
	ok(btn(p, "SaveQuitButton") != null and btn(p, "SaveQuitButton").pressed.get_connections().size() > 0, "Save & quit wired (not pressed: it leaves the scene)")
	p.close()
	holder.queue_free()
	await _frames(1)


# ------------------------------------------------- LR-21 leave and resume

func _pause_of(screen: Node) -> PauseMenu:
	var p: PauseMenu = screen.find_child("PauseMenu", true, false) as PauseMenu
	if p:
		p.auto_navigate = false
	return p


## Quit from the run screen via header Menu -> pause, "restart", Continue.
func _resume_cases() -> void:
	var fixtures := {"reward_card": MetaFixtures.reward_slot("card"), "reward_champion": MetaFixtures.reward_slot("champion"),
		"route": MetaFixtures.route(1), "camp": MetaFixtures.node("camp"), "card_node": MetaFixtures.node("card")}
	for id: String in fixtures.keys():
		_case = "resume_" + id
		var run: Dictionary = fixtures[id]
		SaveService.save_run(run)
		var s: Control = await mount(RUN, run)
		await press(s, "MenuButton")
		var p: PauseMenu = _pause_of(s)
		ok(p != null and p.is_open, "header Menu opens the pause menu")
		await press(p, "SaveQuitButton")
		ok(p.pending_scene == "menu", "Save & quit goes to the menu")
		await unmount(s)
		GameSession.run = {}  # as after a restart
		var m: Control = await mount(MENU, {})
		var sum: Label = m.find_child("ContinueSummary", true, false) as Label
		var champ: String = Loc.field(Catalog.card(run["champion_id"]), "name")
		ok(sum != null and sum.text.contains(champ), "summary names the champion")
		ok(sum != null and sum.text.contains("%d of 6" % (int(run["battle_index"]) + 2)), "summary shows battle k/6")
		ok(sum != null and sum.text.contains("%d/%d" % [int(run["heart"]), int(run["heart_max"])]), "summary shows the Heart")
		await press(m, "ContinueButton")
		ok((m as MainMenu).pending_scene == "run", "Continue returns to the run screen")
		ok(JsonUtil.canonical(GameSession.run) == JsonUtil.canonical(run), "the whole run is identical after reload")
		var before_slot: Dictionary = RunReducer.current_slot(run) if run["phase"] == "reward" else {}
		if not before_slot.is_empty():
			var after_slot: Dictionary = RunReducer.current_slot(GameSession.run)
			ok(after_slot["id"] == before_slot["id"] and after_slot["offer"] == before_slot["offer"], "same offered slot and offer (no reroll)")
		await unmount(m)
		s = await mount(RUN, GameSession.run)
		if not before_slot.is_empty():
			for o: String in before_slot["offer"]:
				ok(s.find_child("Offer_" + o, true, false) != null, "offer %s shown again" % o)
		elif run["phase"] == "route":
			for opt: Dictionary in RunReducer.current_route(run)["options"]:
				ok(btn(s, "Go_" + str(opt["id"])) != null, "same route option %s" % opt["id"])
		elif run["node"]["type"] == "card":
			for o: String in run["node"]["slots"][0]["offer"]:
				ok(s.find_child("Offer_" + o, true, false) != null, "card node offer %s shown again" % o)
		else:
			ok(int(GameSession.run["resin"]) == int(run["resin"]) and GameSession.run["node"]["id"] == run["node"]["id"], "same node, no Resin change")
		await unmount(s)

	_case = "resume_midbattle"
	var mid: Dictionary = DebugFixtures.make("midbattle", "SPORE", 3)
	SaveService.save_run(mid)
	GameSession.run = {}
	var res: Dictionary = GameSession.continue_run()
	ok(res["ok"] and GameSession.phase() == "battle", "mid-battle save continues into battle")
	ok(JsonUtil.canonical(GameSession.run["battle"]) == JsonUtil.canonical(mid["battle"]), "battle state identical (hand, waves, RNG)")

	_case = "result_record_kept"
	var won: Dictionary = MetaFixtures.won()
	SaveService.save_run(won)
	var r: Control = await mount(RESULT, won)
	await press(r, "NewRunButton")
	ok(SaveService.load_run()["run"].get("phase", "") == "won", "won record kept after New run")
	await unmount(r)
	var m2: Control = await mount(MENU, {})
	ok((m2 as MainMenu).view == "faction", "result New run opens champion select")
	ok(SaveService.load_run()["run"].get("phase", "") == "won", "record kept while choosing")
	await press(m2, "BackButton")
	var sum2: Label = m2.find_child("ContinueSummary", true, false) as Label
	ok(sum2 != null and sum2.text.contains(Loc.t("Run won")), "Continue summary shows the finished run")
	await press(m2, "NewRunButton")
	ok(not (m2.find_child("MessageDialog", true, false) as MessageDialog).visible, "no confirm needed over a finished run")
	await press(m2, "Choose_BARK")
	ok(SaveService.load_run()["run"].get("phase", "") == "battle" and SaveService.load_run()["run"]["run_id"] != won["run_id"], "record replaced only when the new run starts")
	await unmount(m2)

	_case = "abandon"
	var rr: Dictionary = MetaFixtures.route(1)
	SaveService.save_run(rr)
	var s2: Control = await mount(RUN, rr)
	await press(s2, "MenuButton")
	var p2: PauseMenu = _pause_of(s2)
	await press(p2, "AbandonButton")
	ok(p2.confirming_abandon and btn(p2, "ResumeButton") == null, "in-page confirmation replaces the menu")
	await press(p2, "KeepPlayingButton")
	ok(not p2.confirming_abandon and GameSession.has_run(), "Keep playing cancels")
	await press(p2, "AbandonButton")
	await press(p2, "ConfirmAbandonButton")
	ok(not GameSession.has_run() and not SaveService.has_save(), "run and save removed")
	ok(p2.pending_scene == "menu", "abandon goes to the menu")
	await unmount(s2)


func _howto_cases() -> void:
	_case = "howto_menu"
	var m: Control = await mount(MENU, {})
	await press(m, "HowToButton")
	var h: HowToPlayPanel = m.find_child("HowToPlayPanel", true, false) as HowToPlayPanel
	ok(h.visible and h.page == 0, "How to play opens on page 1")
	ok(btn(h, "PrevPage").disabled, "no Back on the first page")
	var n: int = h.page_count()
	ok(n >= 7, "seven pages")
	var titles: Array = []
	for i in n:
		var t: Label = h.find_child("PageTitle", true, false) as Label
		titles.append(t.text if t else "")
		ok(h.find_child("Art", true, false) is HowToArt, "page %d illustrated" % (i + 1))
		await press(h, "NextPage")
	ok(not h.visible, "Done on the last page closes")
	ok(titles.has(Loc.field(Catalog.boss(), "name")), "boss page present")
	var status_text: String = ""
	h.page = 5
	h.open()
	status_text = (h.find_child("PageText", true, false) as Label).text
	for g: String in ["armor", "poison", "thorns", "growth"]:
		ok(status_text.contains(UiKit.status_glyph(g)), "status page uses the battle glyph %s" % g)
	h.close()
	await unmount(m)

	_case = "howto_pause"
	var s: Control = await mount(RUN, MetaFixtures.route(1))
	await press(s, "MenuButton")
	var p: PauseMenu = _pause_of(s)
	await press(p, "PauseHowToButton")
	ok((p.find_child("HowToPlayPanel", true, false) as Control).visible, "How to play from the pause menu")
	await unmount(s)


# ------------------------------------------------- LR-28 keyboard / pad

## Sends a ui_* action (press + release, as a key or pad button would) into
## the screen's own viewport, like a real keyboard or controller.
func key(screen: Node, action: String) -> void:
	var vp: Viewport = screen.get_viewport()
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		vp.push_input(ev)
		await _frames(1)
	step("key " + action)
	await _frames(1)


func focus_name(screen: Node) -> String:
	var f: Control = screen.get_viewport().gui_get_focus_owner()
	return str(f.name) if f else ""


func _keyboard_cases() -> void:
	_case = "pad_events"
	var accept_pad := false
	for e: InputEvent in InputMap.action_get_events("ui_accept"):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			accept_pad = true
	ok(accept_pad, "pad A is mapped to ui_accept")
	var cancel_pad := false
	for e: InputEvent in InputMap.action_get_events("ui_cancel"):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_B:
			cancel_pad = true
	ok(cancel_pad, "pad B is mapped to ui_cancel")

	_case = "keyboard_menu"
	SaveService.delete_run()
	var m: Control = await mount(MENU, {})
	await _frames(2)
	ok(focus_name(m) == "NewRunButton", "initial focus on New Run (got %s)" % focus_name(m))
	await key(m, "ui_down")
	ok(focus_name(m) == "HowToButton", "ui_down moves to the next menu button (got %s)" % focus_name(m))
	await key(m, "ui_accept")
	var h: HowToPlayPanel = m.find_child("HowToPlayPanel", true, false) as HowToPlayPanel
	ok(h.visible and focus_name(m) == "NextPage", "How to play opens with focus on Next")
	await key(m, "ui_right")
	ok(h.page == 1, "ui_right flips the page")
	await key(m, "ui_cancel")
	ok(not h.visible, "ui_cancel closes How to play")
	await _frames(1)
	(m.find_child("NewRunButton", true, false) as Control).grab_focus()
	await key(m, "ui_accept")
	ok((m as MainMenu).view == "faction", "ui_accept on New Run opens champion select")
	await _frames(2)
	ok(focus_name(m) == "Choose_BARK", "champion select focuses the first champion (got %s)" % focus_name(m))
	await key(m, "ui_cancel")
	ok((m as MainMenu).view == "title", "ui_cancel goes back to the title")
	(m.find_child("NewRunButton", true, false) as Control).grab_focus()
	await key(m, "ui_accept")
	await _frames(2)
	await key(m, "ui_right")
	var chosen: String = focus_name(m)
	ok(chosen == "Choose_SPORE", "ui_right moves to the other champion (got %s)" % chosen)
	await key(m, "ui_accept")
	ok(GameSession.phase() == "battle" and GameSession.run.get("main_faction", "") == chosen.trim_prefix("Choose_"), "ui_accept starts the run with the focused champion")
	await unmount(m)

	_case = "keyboard_reward"
	var s: Control = await mount(RUN, MetaFixtures.reward_slot("card"))
	await _frames(2)
	var slot: Dictionary = RunReducer.current_slot(GameSession.run)
	ok(focus_name(s) == "Offer_" + str(slot["offer"][0]), "initial focus on the first offer (got %s)" % focus_name(s))
	await key(s, "ui_right")
	var picked: String = focus_name(s).trim_prefix("Offer_")
	ok(picked == str(slot["offer"][1]), "ui_right moves to the next card (got %s)" % picked)
	await key(s, "ui_accept")
	await _frames(2)
	ok((s as RunScreen).sel_offer == picked, "ui_accept selects the focused card")
	ok(focus_name(s) == "ConfirmButton", "focus jumps to the enabled confirm button (got %s)" % focus_name(s))
	var deck_n: int = (GameSession.run["deck"] as Array).size()
	await key(s, "ui_accept")
	await _frames(2)
	ok((GameSession.run["deck"] as Array).size() == deck_n + 1 and str(GameSession.run["deck"][-1]["def_id"]) == picked, "ui_accept claims the card")
	ok(RunReducer.current_slot(GameSession.run).get("type", "") == "mutation", "next slot shown")
	ok(focus_name(s).begins_with("Offer_"), "focus lands on the new offers (got %s)" % focus_name(s))
	await key(s, "ui_cancel")
	var p: PauseMenu = _pause_of(s)
	ok(p.is_open, "ui_cancel opens the pause menu on the run screen")
	await _frames(2)
	ok(focus_name(s) == "ResumeButton", "pause focuses Resume (got %s)" % focus_name(s))
	await key(s, "ui_cancel")
	ok(not p.is_open, "ui_cancel closes the pause menu")
	await unmount(s)

	_case = "keyboard_route"
	s = await mount(RUN, MetaFixtures.route(1))
	await _frames(2)
	ok(focus_name(s).begins_with("Go_"), "route focuses a Travel button (got %s)" % focus_name(s))
	var go: String = focus_name(s).trim_prefix("Go_")
	await key(s, "ui_accept")
	ok(GameSession.phase() == "node" and GameSession.run["node"]["id"] == go, "ui_accept travels to the focused node")
	await unmount(s)

	_case = "keyboard_overlays"
	s = await mount(RUN, MetaFixtures.route(4))
	await press(s, "DeckButton")
	var dv: DeckViewer = s.find_child("DeckViewer", true, false) as DeckViewer
	await _frames(2)
	ok(dv.visible and dv.close_button.has_focus(), "deck viewer focuses Close")
	await key(s, "ui_cancel")
	ok(not dv.visible, "ui_cancel closes the deck viewer")
	await unmount(s)
	var r: Control = await mount(RESULT, MetaFixtures.won())
	await _frames(2)
	ok(focus_name(r) == "NewRunButton", "result focuses New run (got %s)" % focus_name(r))
	await key(r, "ui_right")
	ok(focus_name(r) == "MainMenuButton", "ui_right reaches Main menu")
	await key(r, "ui_accept")
	ok((r as ResultScreen).pending_scene == "menu", "ui_accept on Main menu")
	await unmount(r)
	var m2: Control = await mount(MENU, {})
	(m2.find_child("SettingsButton", true, false) as Control).grab_focus()
	await key(m2, "ui_accept")
	var sp: SettingsPanel = m2.find_child("SettingsPanel", true, false) as SettingsPanel
	ok(sp.visible, "settings opens from the keyboard")
	await key(m2, "ui_cancel")
	ok(not sp.visible, "ui_cancel closes settings")
	await unmount(m2)



# ------------------------------------------- onboarding, focus mode, battles

func _round5_cases() -> void:
	_case = "first_run_skip"
	SettingsService.onboarding_done = false
	SaveService.delete_run()
	var m: Control = await mount(MENU, {})
	await press(m, "NewRunButton")
	ok((m as MainMenu).view == "first_run" and m.find_child("FirstRunPrompt", true, false) != null, "first run offers the guide before champion select")
	await press(m, "SkipGuideButton")
	ok((m as MainMenu).view == "faction" and SettingsService.onboarding_done, "Skip goes to champion select and is remembered")
	await unmount(m)
	m = await mount(MENU, {})
	await press(m, "NewRunButton")
	ok((m as MainMenu).view == "faction", "asked only once")
	await unmount(m)

	_case = "first_run_show"
	SettingsService.onboarding_done = false
	m = await mount(MENU, {})
	await press(m, "NewRunButton")
	await press(m, "ShowGuideButton")
	var h: HowToPlayPanel = m.find_child("HowToPlayPanel", true, false) as HowToPlayPanel
	ok(h.visible and h.page == 0, "Show me opens How to play at page 1")
	ok(SettingsService.onboarding_done, "choice remembered")
	h.close()
	await _frames(1)
	ok((m as MainMenu).view == "faction", "closing the guide continues to champion select")
	await unmount(m)
	var cfg := ConfigFile.new()
	ok(cfg.load(SettingsService.path) == OK and bool(cfg.get_value("settings", "onboarding_done", false)), "flag persisted in settings.cfg")
	SettingsService.onboarding_done = true

	_case = "focus_ring_mode"
	SettingsService.set_keyboard_nav(false)
	ok(not UiKit.focus_visible and UiKit.focus_box().border_color.a == 0.0, "no ring for mouse/touch users")
	var kev := InputEventKey.new()
	kev.keycode = KEY_DOWN
	kev.pressed = true
	SettingsService._input(kev)
	ok(UiKit.focus_visible and UiKit.focus_box().border_color.a == 1.0, "first key shows the ring")
	var mev := InputEventMouseButton.new()
	mev.button_index = MOUSE_BUTTON_LEFT
	mev.pressed = true
	SettingsService._input(mev)
	ok(not UiKit.focus_visible, "mouse hides it again")
	var pev := InputEventJoypadButton.new()
	pev.button_index = JOY_BUTTON_A
	pev.pressed = true
	SettingsService._input(pev)
	ok(UiKit.focus_visible, "pad shows it")
	SettingsService.set_keyboard_nav(false)

	_case = "result_battles"
	for kind: String in ["won", "lost"]:
		var run: Dictionary = MetaFixtures.won() if kind == "won" else MetaFixtures.lost()
		var r: Control = await mount(RESULT, run)
		var lb: Dictionary = run["last_battle"]
		var row: Node = r.find_child("BattleRow_%d" % int(lb["index"]), true, false)
		ok(row != null, "%s: last battle row shown" % kind)
		var txt: String = ""
		if row:
			for l: Node in row.find_children("*", "Label", true, false):
				txt += (l as Label).text + " "
		ok(txt.contains(Loc.t("%d turns") % int(lb["turns"])) and txt.contains("%s %d" % [Loc.t("Heart"), int(lb["heart"])]), "%s: real turns and Heart (%s)" % [kind, txt.strip_edges()])
		await unmount(r)
