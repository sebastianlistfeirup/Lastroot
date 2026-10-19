extends TestCase
## Meta screens: settings persistence, localization completeness and the
## exact run commands the reward / route / node screens send.

const SCRATCH := "user://test_settings_roundtrip.cfg"


func test_settings_roundtrip() -> void:
	var a: Node = load("res://scripts/autoload/settings_service.gd").new()
	a.set("path", SCRATCH)
	a.set("language", "da")
	a.set("text_scale", 1.3)
	a.set("reduced_motion", true)
	a.set("anim_speed", 2.0)
	a.set("volumes", {"master": 0.5, "music": 0.25, "sfx": 0.75})
	check(a.call("save_settings"), "settings save")
	var b: Node = load("res://scripts/autoload/settings_service.gd").new()
	b.set("path", SCRATCH)
	check(b.call("load_settings"), "settings load")
	eq(b.get("language"), "da", "language survives")
	check(absf(float(b.get("text_scale")) - 1.3) < 0.001, "text scale survives")
	eq(b.get("reduced_motion"), true, "reduced motion survives")
	check(absf(float(b.get("anim_speed")) - 2.0) < 0.001, "animation speed survives")
	var v: Dictionary = b.get("volumes")
	check(absf(float(v["music"]) - 0.25) < 0.001 and absf(float(v["sfx"]) - 0.75) < 0.001, "volumes survive")
	# Garbage values are clamped, unknown languages fall back to English.
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "language", "xx")
	cfg.set_value("settings", "text_scale", 9.0)
	cfg.save(SCRATCH)
	var c: Node = load("res://scripts/autoload/settings_service.gd").new()
	c.set("path", SCRATCH)
	c.call("load_settings")
	eq(c.get("language"), "en", "unknown language -> en")
	check(float(c.get("text_scale")) <= 1.5, "text scale clamped")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	for n: Node in [a, b, c]:
		n.free()


## Every Loc.t("...") literal in the repo has a Danish translation with the
## same placeholders (GDScript twin of tools/loc_extract.py --check).
func test_localization_complete() -> void:
	var table: Dictionary = {}
	var f := FileAccess.open("res://localization/translations.csv", FileAccess.READ)
	check(f != null, "translations.csv exists")
	if f == null:
		return
	var header: PackedStringArray = f.get_csv_line()
	eq(Array(header), ["en", "da"], "csv columns")
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			table[row[0]] = row[1]
	var re := RegEx.new()
	re.compile("Loc\\.t\\(\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*\\)")
	var ph := RegEx.new()
	ph.compile("%[-+0-9.]*[dsfxX%]|\\{[a-z_]+\\}")
	var missing: PackedStringArray = []
	var files: PackedStringArray = []
	_collect("res://scripts", files)
	_collect("res://scenes", files)
	for path in files:
		var src: String = FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var key: String = m.get_string(1).replace("\\\"", "\"").replace("\\n", "\n")
			var da: String = str(table.get(key, ""))
			if da == "":
				missing.append("%s: %s" % [path.get_file(), key])
			elif _ph(ph, key) != _ph(ph, da):
				missing.append("placeholder mismatch: %s" % key)
	check(missing.is_empty(), "keys without Danish: %s" % ", ".join(missing.slice(0, 8)))
	check(table.size() > 150, "translation table is populated (%d rows)" % table.size())
	# Catalog names/texts without *_da must be in the table too.
	for p: Dictionary in Catalog.champion_paths("B01") + Catalog.champion_paths("S01"):
		if not p.has("text_da"):
			check(str(table.get(p["text"], "")) != "", "champion path text translated: %s" % p["text"])


static func _ph(re: RegEx, s: String) -> Array:
	var out: Array = []
	for m in re.search_all(s):
		out.append(m.get_string())
	out.sort()
	return out


func _collect(dir: String, out: PackedStringArray) -> void:
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir + "/" + file)


func _apply(run: Dictionary, cmd: Dictionary, what: String) -> Dictionary:
	var r: Dictionary = RunReducer.apply(run, cmd)
	check(r["ok"], "%s legal (%s)" % [what, r.get("error", "")])
	return r["run"] if r["ok"] else run


## The commands the reward screen sends, in order, on a bot-won battle 1.
func test_reward_screen_commands_after_bot_win() -> void:
	var run: Dictionary = AutoPlayer.play_battle(RunReducer.new_run(21, "BARK"))
	eq(run["phase"], "reward", "bot wins battle 1")
	if run["phase"] != "reward":
		return
	var card: Dictionary = RunReducer.current_slot(run)
	eq(card["type"], "card", "card choice is current")
	# Screen: tap offer[1] then "Add to deck".
	var before: int = (run["deck"] as Array).size()
	run = _apply(run, {"type": "claim", "slot": card["id"], "choice": card["offer"][1]}, "claim card")
	eq((run["deck"] as Array).size(), before + 1, "card added")
	var mut: Dictionary = RunReducer.current_slot(run)
	eq(mut["type"], "mutation", "mutation next")
	check(not RunReducer.apply(run, {"type": "skip", "slot": mut["id"]})["ok"], "mutation has no Skip button for a reason")
	run = _apply(run, {"type": "claim", "slot": mut["id"], "choice": mut["offer"][0]}, "claim mutation")
	eq(run["phase"], "route", "route after rewards")
	# Route: "Travel to" on either option is legal; a stale node id is not.
	var route: Dictionary = RunReducer.current_route(run)
	for opt: Dictionary in route["options"]:
		check(RunReducer.apply(run, {"type": "choose_node", "node": opt["id"]})["ok"], "choose %s legal" % opt["type"])
	check(not RunReducer.apply(run, {"type": "choose_node", "node": "N5A"})["ok"], "future node rejected")


## Card choice Skip, then champion path / relic after battle 2.
func test_champion_and_relic_commands() -> void:
	var run: Dictionary = MetaFixtures.reward_after(2, 21, "BARK")
	eq(run["phase"], "reward", "reward after battle 2")
	if run["phase"] != "reward":
		return
	var card: Dictionary = RunReducer.current_slot(run)
	run = _apply(run, {"type": "skip", "slot": card["id"]}, "skip card")
	var champ: Dictionary = RunReducer.current_slot(run)
	eq(champ["type"], "champion", "champion slot")
	eq((champ["offer"] as Array).size(), 2, "both paths at first choice")
	var def: Dictionary = Catalog.card(run["champion_id"])
	var pid: String = champ["offer"][0]
	var after: Dictionary = CardStats.unit_stats(def, "", pid, 1)
	run = _apply(run, {"type": "claim", "slot": champ["id"], "choice": pid}, "claim path")
	eq(run["champion_path"], pid, "path stored")
	eq(CardStats.unit_stats(def, "", run["champion_path"], run["champion_rank"]), after, "after-preview equals the real stats")
	var relic: Dictionary = RunReducer.current_slot(run)
	eq(relic["type"], "relic", "relic slot")
	eq((relic["offer"] as Array).size(), 3, "three relics")
	run = _apply(run, {"type": "claim", "slot": relic["id"], "choice": relic["offer"][2]}, "claim relic")
	eq(run["phase"], "route", "route after relic")


## Every node screen's buttons send legal commands; disabled buttons match rejections.
func test_node_screen_commands() -> void:
	var rules: Dictionary = Catalog.rules()
	# Camp: first upgradable card, cheapest upgrade.
	var camp: Dictionary = MetaFixtures.node("camp")
	eq(camp["node"]["type"], "camp", "camp entered")
	var done := false
	for inst: Dictionary in camp["deck"]:
		var ups: Array = CardStats.legal_upgrades(Catalog.card(inst["def_id"]), inst["upgrade_id"])
		if ups.is_empty():
			check(not RunReducer.apply(camp, {"type": "camp_upgrade", "card": inst["instance_id"], "upgrade": "attack_2"})["ok"], "illegal upgrade rejected")
			continue
		if not done:
			var r: Dictionary = _apply(camp, {"type": "camp_upgrade", "card": inst["instance_id"], "upgrade": ups[0]["id"]}, "camp upgrade")
			eq(int(r["resin"]), int(camp["resin"]) - int(ups[0]["price"]), "price paid")
			eq(r["phase"], "battle", "camp leads to the next battle")
			done = true
	var poor: Dictionary = camp.duplicate(true)
	poor["resin"] = 10
	for inst: Dictionary in poor["deck"]:
		var ups2: Array = CardStats.legal_upgrades(Catalog.card(inst["def_id"]), inst["upgrade_id"])
		if not ups2.is_empty():
			check(not RunReducer.apply(poor, {"type": "camp_upgrade", "card": inst["instance_id"], "upgrade": ups2[0]["id"]})["ok"], "unaffordable upgrade rejected")
			break
	_apply(camp, {"type": "leave_node"}, "leave camp")
	# Removal: first normal card; the champion is rejected.
	var rem: Dictionary = MetaFixtures.node("removal")
	for inst: Dictionary in rem["deck"]:
		var is_champ: bool = Catalog.card(inst["def_id"])["kind"] == "champion"
		var res: Dictionary = RunReducer.apply(rem, {"type": "remove_card", "card": inst["instance_id"]})
		if is_champ:
			check(not res["ok"], "champion removal rejected")
		else:
			check(res["ok"], "remove normal card legal")
			eq(int(res["run"]["resin"]), int(rem["resin"]) - int(rules["remove_cost"]), "removal price")
			break
	# Encounter: both buttons.
	var enc: Dictionary = MetaFixtures.node("encounter")
	eq(int(_apply(enc, {"type": "encounter", "choice": "resin"}, "encounter resin")["resin"]), int(enc["resin"]) + 15, "+15 Resin")
	_apply(enc, {"type": "encounter", "choice": "heal"}, "encounter heal")
	# Card node: claim and skip.
	var cn: Dictionary = MetaFixtures.node("card")
	var slot: Dictionary = cn["node"]["slots"][0]
	eq(_apply(cn, {"type": "claim", "slot": slot["id"], "choice": slot["offer"][0]}, "card node claim")["phase"], "battle", "claim leaves the node")
	eq(_apply(cn, {"type": "skip", "slot": slot["id"]}, "card node skip")["phase"], "battle", "skip leaves the node")
