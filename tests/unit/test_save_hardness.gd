extends TestCase
## LR-29: save hardness. Legacy migration (real v1 fixtures), corrupt bytes,
## truncation, interrupted writes, wrong checksum, invalid IDs, missing keys,
## wrong types, future versions — through the real SaveService file code in an
## isolated folder — plus the double-reward guard across save/reload.

const LEGACY := "res://fixtures/legacy/"
const LEGACY_FILES: PackedStringArray = ["v1_battle.json", "v1_reward.json", "v1_route.json", "v1_node.json"]
const TEST_DIR := "user://test_save_hardness"
const SaveServiceScript := preload("res://scripts/autoload/save_service.gd")


func _svc() -> Node:
	var s: Node = SaveServiceScript.new()
	s.use_dir(TEST_DIR)
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + "/" + f)
	return s


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Re-signs an edited run so only the content check can refuse it.
func _signed(run: Dictionary, ver: int = SaveCodec.SCHEMA_VERSION) -> String:
	var env := SaveCodec.make_envelope(run)
	env["schema_version"] = ver
	return JSON.stringify(env)


func _route_run(seed_value: int) -> Dictionary:
	var run: Dictionary = AutoPlayer.play_battle(RunReducer.new_run(seed_value, "BARK"))
	while run["phase"] == "reward":
		run = RunReducer.apply(run, AutoPlayer.choose_run(run))["run"]
	return run


# ------------------------------------------------------------ legacy / migration

func test_legacy_v1_fixtures_migrate_and_play_to_the_end() -> void:
	for fname in LEGACY_FILES:
		var text := FileAccess.get_file_as_string(LEGACY + fname)
		var raw: Dictionary = JsonUtil.parse(text)
		eq(int(raw["schema_version"]), 1, "%s is a schema-1 file" % fname)
		check(not (raw["payload"]["run"] as Dictionary).has("mode"), "%s really lacks v2 fields" % fname)
		var d := SaveCodec.decode(text)
		check(d["ok"], "%s decodes (%s %s)" % [fname, d.get("code", ""), d.get("problems", [])])
		if not d["ok"]:
			continue
		eq(d["migrated_from"], 1, "%s migrated from 1" % fname)
		var run: Dictionary = d["run"]
		for k in ["mode", "history", "claimed_choices", "heart_at_battle_start"]:
			check(run.has(k), "%s migrated run has %s" % [fname, k])
		eq(run["phase"], str(raw["payload"]["run"]["phase"]), "%s phase kept" % fname)
		eq(JsonUtil.canonical(run["deck"]), JsonUtil.canonical(raw["payload"]["run"]["deck"]), "%s deck kept" % fname)
		eq(int(run["resin"]), int(raw["payload"]["run"]["resin"]), "%s resin kept" % fname)
		# Re-encoded as current schema and decodes without migration.
		var d2 := SaveCodec.decode(SaveCodec.encode(run, d["presentation"]))
		check(d2["ok"] and d2["migrated_from"] == 0, "%s re-saves as schema %d" % [fname, SaveCodec.SCHEMA_VERSION])
		# The migrated run is fully playable by the current reducers.
		var res := AutoPlayer.play_run(run)
		var end: Dictionary = res["run"]
		check(end["phase"] in ["won", "lost"], "%s plays to the end (phase %s)" % [fname, end["phase"]])
		check(SaveCodec.validate_run(end).is_empty(), "%s end state valid" % fname)


func test_legacy_reward_fixture_keeps_offer_and_grants_once() -> void:
	var d := SaveCodec.decode(FileAccess.get_file_as_string(LEGACY + "v1_reward.json"))
	var run: Dictionary = d["run"]
	var slot := RunReducer.current_slot(run)
	eq(slot["offer"], ["B06", "B02", "B04"], "stored v1 offer survives migration (no reroll)")
	var resin: int = run["resin"]
	var r := RunReducer.apply(run, {"type": "claim", "slot": slot["id"], "choice": "B02"})
	check(r["ok"], "claim on migrated run")
	eq(int(r["run"]["resin"]), resin, "no Resin re-granted")
	check(not RunReducer.apply(r["run"], {"type": "claim", "slot": slot["id"], "choice": "B02"})["ok"], "second claim refused")
	eq((r["run"]["claimed_choices"] as Dictionary).get(slot["id"], {}).get("choice", ""), "B02", "choice recorded after migration")


func test_legacy_route_fixture_rebuilds_claimed_choices() -> void:
	var d := SaveCodec.decode(FileAccess.get_file_as_string(LEGACY + "v1_route.json"))
	var cc: Dictionary = d["run"]["claimed_choices"]
	eq(str(cc.get("B1.card", {}).get("choice", "")), "B06", "card pick rebuilt from slot")
	check(cc.has("B1.mutation"), "mutation pick rebuilt")


func test_legacy_tampered_payload_rejected_before_migration() -> void:
	var text := FileAccess.get_file_as_string(LEGACY + "v1_route.json")
	var env: Dictionary = JsonUtil.parse(text)
	env["payload"]["run"]["resin"] = 999
	eq(SaveCodec.decode(JSON.stringify(env))["code"], "corrupt", "v1 checksum still enforced")


func test_legacy_file_as_main_becomes_backup_after_save() -> void:
	var s := _svc()
	_write(s.main_path, FileAccess.get_file_as_string(LEGACY + "v1_node.json"))
	var res: Dictionary = s.load_run()
	check(res["ok"], "legacy main loads through SaveService")
	check(s.save_run(res["run"]), "re-save")
	var main_env: Dictionary = JsonUtil.parse(FileAccess.get_file_as_string(s.main_path))
	eq(int(main_env["schema_version"]), SaveCodec.SCHEMA_VERSION, "main now current schema")
	var bak: Dictionary = s.load_backup()
	check(bak["ok"] and bak["migrated_from"] == 1, "v1 file kept as valid backup")
	s.free()


# ------------------------------------------------------------ damaged files

func test_corrupt_bytes_fall_back_to_backup_and_keep_file() -> void:
	var s := _svc()
	var a := RunReducer.new_run(301, "BARK")
	var b: Dictionary = RunReducer.apply(a, {"type": "battle", "cmd": AutoPlayer.choose(a["battle"])})["run"]
	s.save_run(a)
	s.save_run(b)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(s.main_path)
	var rng := RngStream.create(7, "bytes")
	for i in 12:
		var pos: int = RngStream.next_int(rng, bytes.size())
		bytes[pos] = (bytes[pos] + 1 + RngStream.next_int(rng, 254)) % 256
	var fa := FileAccess.open(s.main_path, FileAccess.WRITE)
	fa.store_buffer(bytes)
	fa.close()
	var res: Dictionary = s.load_run()
	check(not res["ok"], "corrupt main refused")
	check(res.get("backup_available", false), "backup offered")
	var bak: Dictionary = s.load_backup()
	eq(JsonUtil.canonical(bak["run"]), JsonUtil.canonical(a), "backup is the previous good state")
	eq(FileAccess.get_file_as_bytes(s.main_path), bytes, "damaged file untouched by loading")
	s.save_run(bak["run"])  # player chose "Load backup" and continued
	var q: PackedStringArray = s.quarantined_files()
	eq(q.size(), 1, "damaged file quarantined before overwrite")
	if q.size() == 1:
		eq(FileAccess.get_file_as_bytes(q[0]), bytes, "quarantined bytes identical")
	check(s.load_run()["ok"], "fresh main valid again")
	s.free()


func test_truncated_main_falls_back_to_backup() -> void:
	var s := _svc()
	var a := RunReducer.new_run(302, "SPORE")
	s.save_run(a)
	s.save_run(a)
	var text := FileAccess.get_file_as_string(s.main_path)
	for cut in [0, 1, text.length() / 3, text.length() - 1]:
		_write(s.main_path, text.substr(0, cut))
		var res: Dictionary = s.load_run()
		check(not res["ok"] and res.get("backup_available", false), "truncated at %d -> backup" % cut)
	s.free()


func test_interrupted_write_complete_tmp_is_recovered() -> void:
	var s := _svc()
	var a := RunReducer.new_run(303, "BARK")
	var b: Dictionary = RunReducer.apply(a, {"type": "battle", "cmd": AutoPlayer.choose(a["battle"])})["run"]
	s.save_run(a)
	_write(s.tmp_path, SaveCodec.encode(b))  # crash after tmp was written, before rename
	check(s.has_save(), "has_save sees it")
	var res: Dictionary = s.load_run()
	check(res["ok"] and res["recovered_from_tmp"], "complete tmp promoted")
	eq(JsonUtil.canonical(res["run"]), JsonUtil.canonical(b), "newest state recovered (no lost action)")
	eq(JsonUtil.canonical(s.load_backup()["run"]), JsonUtil.canonical(a), "previous main became backup")
	check(not FileAccess.file_exists(s.tmp_path), "tmp consumed")
	s.free()


func test_interrupted_write_partial_tmp_is_ignored() -> void:
	var s := _svc()
	var a := RunReducer.new_run(304, "BARK")
	s.save_run(a)
	var full := SaveCodec.encode(RunReducer.apply(a, {"type": "battle", "cmd": AutoPlayer.choose(a["battle"])})["run"])
	_write(s.tmp_path, full.substr(0, full.length() / 2))  # crash during the tmp write
	var res: Dictionary = s.load_run()
	check(res["ok"] and not res["recovered_from_tmp"], "partial tmp ignored")
	eq(JsonUtil.canonical(res["run"]), JsonUtil.canonical(a), "last complete save loads")
	check(s.save_run(res["run"]), "next save succeeds over the stale tmp")
	check(not FileAccess.file_exists(s.tmp_path), "stale tmp replaced")
	s.free()


func test_only_partial_tmp_and_no_main() -> void:
	var s := _svc()
	_write(s.tmp_path, "{\"game_id\":\"LASTROOT\",\"sch")
	check(not s.has_save(), "a partial tmp alone is not a save")
	eq(s.load_run()["code"], "missing", "reported as missing, no crash")
	s.free()


func test_wrong_checksum_rejected() -> void:
	var env := SaveCodec.make_envelope(RunReducer.new_run(305, "BARK"))
	env["checksum"] = "0".repeat(64)
	eq(SaveCodec.decode(JSON.stringify(env))["code"], "corrupt", "zeroed checksum")
	env.erase("checksum")
	eq(SaveCodec.decode(JSON.stringify(env))["code"], "corrupt", "missing checksum")
	env = SaveCodec.make_envelope(RunReducer.new_run(305, "BARK"))
	env["schema_version"] = "2"
	eq(SaveCodec.decode(JSON.stringify(env))["code"], "corrupt", "string schema_version")


func test_future_version_kept_and_quarantined_on_new_run() -> void:
	var s := _svc()
	var env := SaveCodec.make_envelope(RunReducer.new_run(306, "BARK"))
	env["schema_version"] = SaveCodec.SCHEMA_VERSION + 1
	var fut := JSON.stringify(env)
	_write(s.main_path, fut)
	s.save_run(RunReducer.new_run(306, "BARK"))  # pretend a valid backup existed earlier
	_write(s.main_path, fut)
	var res: Dictionary = s.load_run()
	eq(res["code"], "future_version", "future refused")
	check(not res.get("backup_available", false), "no silent fallback past a newer save")
	eq(FileAccess.get_file_as_string(s.main_path), fut, "file untouched")
	s.save_run(RunReducer.new_run(307, "SPORE"))  # player starts a new run anyway
	var kept := false
	for q in s.quarantined_files():
		kept = kept or FileAccess.get_file_as_string(q) == fut
	check(kept, "newer save preserved in quarantine, never deleted")
	s.free()


func test_quarantine_is_bounded() -> void:
	var s := _svc()
	for i in 6:
		_write(s.main_path, "junk %d" % i)
		s.save_run(RunReducer.new_run(310 + i, "BARK"))
	check(s.quarantined_files().size() <= SaveServiceScript.QUARANTINE_KEEP, "at most %d quarantined files" % SaveServiceScript.QUARANTINE_KEEP)
	s.free()


# ------------------------------------------------------------ content validation

func test_invalid_ids_with_valid_checksum_rejected() -> void:
	var base: Dictionary = RunReducer.new_run(320, "BARK")
	var reward: Dictionary = AutoPlayer.play_battle(RunReducer.new_run(321, "SPORE"))
	var cases := {
		"card": func(r: Dictionary) -> void: r["deck"][3]["def_id"] = "B99",
		"upgrade": func(r: Dictionary) -> void: r["deck"][3]["upgrade_id"] = "attack_99",
		"relic": func(r: Dictionary) -> void: r["relics"] = ["R99"],
		"dup_relic": func(r: Dictionary) -> void: r["relics"] = ["R01", "R01"],
		"mutation": func(r: Dictionary) -> void: r["mutations"] = ["M77"],
		"faction": func(r: Dictionary) -> void: r["main_faction"] = "ROT",
		"champion": func(r: Dictionary) -> void: r["champion_id"] = "S01",
		"path": func(r: Dictionary) -> void: r["champion_path"] = "NOPE",
		"phase": func(r: Dictionary) -> void: r["phase"] = "shop",
		"route_type": func(r: Dictionary) -> void: r["route"][0]["options"][0]["type"] = "shop",
		"unit": func(r: Dictionary) -> void: (r["battle"]["units"].values()[0] as Dictionary)["def_id"] = "E99",
		"battle_card": func(r: Dictionary) -> void: (r["battle"]["deck"].values()[0] as Dictionary)["def_id"] = "X1",
		"hand_iid": func(r: Dictionary) -> void: (r["battle"]["zones"]["hand"] as Array).append(9999),
		"floor_uid": func(r: Dictionary) -> void: (r["battle"]["floors"][1]["enemies"] as Array).append(777),
		"wave_enemy": func(r: Dictionary) -> void: r["battle"]["waves"][0]["enemies"] = ["E42"],
		"heart": func(r: Dictionary) -> void: r["heart"] = int(r["heart_max"]) + 1,
		"battle_index": func(r: Dictionary) -> void: r["battle_index"] = 9,
		"dup_iid": func(r: Dictionary) -> void: r["deck"][2]["instance_id"] = r["deck"][1]["instance_id"],
	}
	for name: String in cases:
		var r: Dictionary = base.duplicate(true)
		(cases[name] as Callable).call(r)
		var d := SaveCodec.decode(_signed(r))
		check(not d["ok"] and d["code"] == "invalid", "%s refused (got %s)" % [name, d["code"]])
		check(not (d.get("problems", []) as PackedStringArray).is_empty(), "%s explained" % name)
	var r2: Dictionary = reward.duplicate(true)
	r2["reward"]["slots"][-1]["offer"] = ["X01", "X02"]
	eq(SaveCodec.decode(_signed(r2))["code"], "invalid", "unknown reward offer refused")


func test_import_json_with_invalid_ids_rejected() -> void:
	var s := _svc()
	var r := RunReducer.new_run(322, "SPORE")
	r["deck"][0]["def_id"] = "S99"
	var path: String = TEST_DIR + "/import.json"
	_write(path, _signed(r))
	var d: Dictionary = s.import_json(path)
	eq(d["code"], "invalid", "import refuses unknown card")
	eq(s.import_json(TEST_DIR + "/nope.json")["code"], "missing", "missing import file")
	s.free()


func test_missing_keys_rejected_without_crash() -> void:
	var base := RunReducer.new_run(323, "BARK")
	for k: String in base.keys():
		var r: Dictionary = base.duplicate(true)
		r.erase(k)
		var d := SaveCodec.decode(_signed(r))
		if k in ["schema_version", "content_version"]:
			continue  # informational, not read by the reducers
		check(not d["ok"], "missing %s refused" % k)
	var b: Dictionary = base.duplicate(true)
	for k: String in (base["battle"] as Dictionary).keys():
		var r: Dictionary = base.duplicate(true)
		(r["battle"] as Dictionary).erase(k)
		SaveCodec.decode(_signed(r))  # must not crash; most keys are checked
	for k: String in ["units", "deck", "zones", "floors", "rng", "turn", "heart"]:
		var r: Dictionary = b.duplicate(true)
		(r["battle"] as Dictionary).erase(k)
		check(not SaveCodec.decode(_signed(r))["ok"], "missing battle.%s refused" % k)


func test_wrong_types_rejected_without_crash() -> void:
	var base := RunReducer.new_run(324, "SPORE")
	var wrong: Array = ["x", 3, [], {}, null, 1.5, true]
	var accepted := 0
	for k: String in base.keys():
		if k in ["schema_version", "content_version"]:
			continue
		for w: Variant in wrong:
			if typeof(w) == typeof(base[k]):
				continue
			var r: Dictionary = base.duplicate(true)
			r[k] = w
			if SaveCodec.decode(_signed(r))["ok"]:
				accepted += 1
				failures.append("%s: %s=%s accepted" % [current, k, var_to_str(w)])
	eq(accepted, 0, "no wrong-typed field accepted")
	# Nested: a few representative deep fields.
	var nested := [
		func(r: Dictionary) -> void: r["deck"][0] = "B01",
		func(r: Dictionary) -> void: r["deck"][0]["instance_id"] = "1",
		func(r: Dictionary) -> void: r["rng"]["shuffle"] = 5,
		func(r: Dictionary) -> void: r["battle"]["zones"]["hand"] = "1,2,3",
		func(r: Dictionary) -> void: (r["battle"]["units"].values()[0] as Dictionary)["hp"] = "5",
		func(r: Dictionary) -> void: r["battle"]["floors"] = {},
		func(r: Dictionary) -> void: r["stats"]["turns"] = "0",
	]
	for i in nested.size():
		var r: Dictionary = base.duplicate(true)
		(nested[i] as Callable).call(r)
		check(not SaveCodec.decode(_signed(r))["ok"], "nested wrong type %d refused" % i)


func test_every_reducer_state_passes_validation() -> void:
	# No false positives: every state the real reducers produce through whole
	# runs (all six battles incl. boss, rewards, every node type) is accepted.
	var bad := 0
	var states := 0
	for seed_value in [401, 402, 403, 404]:
		for faction in ["BARK", "SPORE"]:
			var run := RunReducer.new_run(seed_value, faction)
			var steps := 0
			while steps < 4000 and run["phase"] in ["battle", "reward", "route", "node"]:
				if steps % 7 == 0 or run["phase"] != "battle":
					states += 1
					var p := SaveCodec.validate_run(run)
					if not p.is_empty():
						bad += 1
						if bad < 4:
							failures.append("%s: seed %d %s phase %s: %s" % [current, seed_value, faction, run["phase"], p])
				var r := RunReducer.apply(run, AutoPlayer.choose_run(run))
				if not r["ok"]:
					break
				run = r["run"]
				steps += 1
			check(SaveCodec.validate_run(run).is_empty(), "final state valid %d %s" % [seed_value, faction])
	eq(bad, 0, "all %d sampled states valid" % states)


# ------------------------------------------------------------ double rewards

## Save during reward, reload, claim, reload, claim again: granted once.
func test_double_reward_guard_across_reloads() -> void:
	var s := _svc()
	var run: Dictionary = AutoPlayer.play_battle(RunReducer.new_run(330, "BARK"))
	eq(run["phase"], "reward", "battle won")
	s.save_run(run, {"pending": true})
	var resin_after_win: int = run["resin"]
	var deck_n: int = (run["deck"] as Array).size()
	# reload during reward: no +20 again, offer identical
	var l1: Dictionary = s.load_run()
	eq(int(l1["run"]["resin"]), resin_after_win, "reload does not re-grant win Resin")
	var slot := RunReducer.current_slot(l1["run"])
	eq(slot["offer"], RunReducer.current_slot(run)["offer"], "offer not rerolled")
	var c := RunReducer.apply(l1["run"], {"type": "claim", "slot": slot["id"], "choice": slot["offer"][0]})
	check(c["ok"], "first claim")
	s.save_run(c["run"])
	var l2: Dictionary = s.load_run()
	var again := RunReducer.apply(l2["run"], {"type": "claim", "slot": slot["id"], "choice": slot["offer"][1]})
	check(not again["ok"], "claim after reload refused")
	eq((l2["run"]["deck"] as Array).size(), deck_n + 1, "exactly one card added")
	eq(int(l2["run"]["resin"]), resin_after_win, "Resin unchanged by claim/reload")
	# finish rewards -> route; choose a node; reload; choose again refused
	var r: Dictionary = l2["run"]
	while r["phase"] == "reward":
		r = RunReducer.apply(r, AutoPlayer.choose_run(r))["run"]
		s.save_run(r)
		r = s.load_run()["run"]
	eq(r["phase"], "route", "route reached through reloads")
	var route := RunReducer.current_route(r)
	var n := RunReducer.apply(r, {"type": "choose_node", "node": route["options"][0]["id"]})
	s.save_run(n["run"])
	var l3: Dictionary = s.load_run()
	check(not RunReducer.apply(l3["run"], {"type": "choose_node", "node": route["options"][1]["id"]})["ok"], "second route choice refused after reload")
	s.free()


func test_double_node_payout_guard_every_node_type() -> void:
	var s := _svc()
	var base := _route_run(331)
	for t in ["camp", "card", "encounter", "removal"]:
		var r: Dictionary = base.duplicate(true)
		# force the open branch to offer this node type (test-only edit of the stored route)
		var route := RunReducer.current_route(r)
		route["options"][0]["type"] = t
		r["resin"] = 100
		r = RunReducer.apply(r, {"type": "choose_node", "node": route["options"][0]["id"]})["run"]
		s.save_run(r)
		r = s.load_run()["run"]
		var cmd: Dictionary
		match t:
			"camp":
				var inst: Dictionary = r["deck"][1]
				var ups: Array = CardStats.legal_upgrades(Catalog.card(inst["def_id"]), "")
				cmd = {"type": "camp_upgrade", "card": inst["instance_id"], "upgrade": ups[0]["id"]} if not ups.is_empty() else {"type": "leave_node"}
			"card":
				var sl: Dictionary = r["node"]["slots"][0]
				cmd = {"type": "claim", "slot": sl["id"], "choice": sl["offer"][0]}
			"encounter":
				cmd = {"type": "encounter", "choice": "resin"}
			"removal":
				cmd = {"type": "remove_card", "card": r["deck"][1]["instance_id"]}
		var once := RunReducer.apply(r, cmd)
		check(once["ok"], "%s used once (%s)" % [t, once["error"]])
		s.save_run(once["run"])
		var back: Dictionary = s.load_run()["run"]
		eq(back["phase"], "battle", "%s -> next battle" % t)
		check(not RunReducer.apply(back, cmd)["ok"], "%s cannot pay out again after reload" % t)
		eq(int(back["resin"]), int(once["run"]["resin"]), "%s Resin stable" % t)
		eq((back["deck"] as Array).size(), (once["run"]["deck"] as Array).size(), "%s deck stable" % t)
	s.free()


# ------------------------------------------------------------ demo slot (LR-34)

func test_demo_run_cannot_overwrite_full_save() -> void:
	var s := _svc()
	s.demo_build = false
	var full := RunReducer.new_run(340, "BARK")
	s.save_run(full)
	s.save_run(full)
	var full_bytes := FileAccess.get_file_as_string(s.main_path)
	var demo := RunReducer.new_run(341, "SPORE", "demo")
	check(s.save_run(demo), "demo run saves")
	check(s.save_run(demo), "demo run saves twice")
	eq(FileAccess.get_file_as_string(s.main_path), full_bytes, "full slot untouched by the demo")
	check(FileAccess.file_exists(s.slot_paths(true)["main"]), "demo has its own file")
	var lf: Dictionary = s.load_run()
	check(lf["ok"] and lf["run"]["run_id"] == full["run_id"], "full build still loads the full run")
	# demo build sees only the demo slot
	s.demo_build = true
	var ld: Dictionary = s.load_run()
	check(ld["ok"] and ld["run"]["run_id"] == demo["run_id"], "demo build loads the demo run")
	s.delete_run()
	check(not s.has_save(), "demo abandon deletes the demo slot only")
	s.demo_build = false
	check(s.load_run()["ok"], "full run survives a demo abandon")
	s.free()


func test_wrong_mode_in_slot_refused_and_kept() -> void:
	var s := _svc()
	s.demo_build = false
	var demo_text := SaveCodec.encode(RunReducer.new_run(342, "BARK", "demo"))
	_write(s.main_path, demo_text)  # a demo save copied into the full slot
	var res: Dictionary = s.load_run()
	eq(res["code"], "wrong_slot", "full slot refuses a demo run")
	var path: String = TEST_DIR + "/demo_import.json"
	_write(path, demo_text)
	eq(s.import_json(path)["code"], "wrong_slot", "full build refuses to import a demo run")
	s.save_run(RunReducer.new_run(343, "BARK"))
	var kept := false
	for q in s.quarantined_files():
		kept = kept or FileAccess.get_file_as_string(q) == demo_text
	check(kept, "misplaced demo save quarantined, not lost")
	s.demo_build = true
	_write(s.slot_paths(true)["main"], SaveCodec.encode(RunReducer.new_run(344, "BARK")))
	eq(s.load_run()["code"], "wrong_slot", "demo slot refuses a full run")
	s.free()
