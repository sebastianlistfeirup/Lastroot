extends TestCase
## LR-15/16/17 domain: reward order, transactions, route, nodes, full runs.


func _bot_until(run: Dictionary, phase: String, max_steps: int = 3000) -> Dictionary:
	var steps := 0
	while run["phase"] != phase and run["phase"] in ["battle", "reward", "route", "node"] and steps < max_steps:
		run = RunReducer.apply(run, AutoPlayer.choose_run(run))["run"]
		steps += 1
	return run


func test_reward_order_after_battle_two() -> void:
	var run := RunReducer.new_run(11, "BARK")
	run = AutoPlayer.play_battle(run)
	run = _bot_until(run, "battle")
	run = AutoPlayer.play_battle(run)
	if run["phase"] != "reward":
		check(false, "bot should win battle 2 (seed 11), phase %s" % run["phase"])
		return
	var types: Array = []
	for slot: Dictionary in run["reward"]["slots"]:
		types.append(slot["type"])
	eq(types, ["resin", "card", "champion", "relic"], "fixed order after battle 2")


func test_reward_offers_survive_reload() -> void:
	var run := AutoPlayer.play_battle(RunReducer.new_run(12, "SPORE"))
	var dec: Dictionary = SaveCodec.decode(SaveCodec.encode(run))
	check(dec["ok"], "decodes")
	eq(JsonUtil.canonical(dec["run"]["reward"]), JsonUtil.canonical(run["reward"]), "same offers after reload")


func test_mutation_after_battle_one_and_m04_once() -> void:
	var run := AutoPlayer.play_battle(RunReducer.new_run(13, "BARK"))
	var card: Dictionary = RunReducer.current_slot(run)
	run = RunReducer.apply(run, {"type": "skip", "slot": card["id"]})["run"]
	var mut: Dictionary = RunReducer.current_slot(run)
	eq(mut["type"], "mutation", "mutation choice after battle 1")
	check(not RunReducer.apply(run, {"type": "skip", "slot": mut["id"]})["ok"], "mutation cannot be skipped")
	var hm: int = run["heart_max"]
	var r := RunReducer.apply(run, {"type": "claim", "slot": mut["id"], "choice": "M04"})
	eq(r["run"]["heart_max"], hm + 15, "M04 +15 max")
	check(not RunReducer.apply(r["run"], {"type": "claim", "slot": mut["id"], "choice": "M04"})["ok"], "M04 settles once")
	eq(r["run"]["phase"], "route", "route after battle-1 rewards")


func test_champion_path_locks() -> void:
	var run := RunReducer.new_run(14, "BARK")
	run["reward"] = {"battle_number": 2, "slots": [{"id": "B2.champion", "type": "champion", "status": "offered", "offer": ["BULWARK", "WRATH"], "skippable": false}]}
	run["phase"] = "reward"
	run = RunReducer.apply(run, {"type": "claim", "slot": "B2.champion", "choice": "WRATH"})["run"]
	eq([run["champion_path"], run["champion_rank"]], ["WRATH", 1], "rank 1")
	run["reward"] = {"battle_number": 4, "slots": [{"id": "B4.champion", "type": "champion", "status": "offered", "offer": ["BULWARK", "WRATH"], "skippable": false}]}
	run["phase"] = "reward"
	check(not RunReducer.apply(run, {"type": "claim", "slot": "B4.champion", "choice": "BULWARK"})["ok"], "other path refused")
	run = RunReducer.apply(run, {"type": "claim", "slot": "B4.champion", "choice": "WRATH"})["run"]
	eq(run["champion_rank"], 2, "rank 2")
	var st := CardStats.unit_stats(Catalog.card("B01"), "", "WRATH", 2)
	eq([st["attack"], st["max_hp"]], [10, 24], "Wrath 2: 4+6 / 20+4")


func _at_node(type: String, seed_value: int = 15) -> Dictionary:
	var run := RunReducer.new_run(seed_value, "BARK")
	run["battle"] = {}
	run["phase"] = "node"
	run["node"] = {"id": "N1A", "type": type, "status": "open", "slots": []}
	return run


func test_camp_upgrade_rules() -> void:
	var run := _at_node("camp")
	var twig := RunReducer._add_card(run, "B12")
	check(not RunReducer.apply(run, {"type": "camp_upgrade", "card": twig, "upgrade": ""})["ok"], "B12 not upgradable")
	var champ: int = run["deck"][0]["instance_id"]
	check(not RunReducer.apply(run, {"type": "camp_upgrade", "card": champ, "upgrade": "attack_2"})["ok"], "champion not via camp")
	var sprout: int = run["deck"][1]["instance_id"]
	var r := RunReducer.apply(run, {"type": "camp_upgrade", "card": sprout, "upgrade": "attack_2"})
	check(r["ok"], "upgrade ok: " + str(r["error"]))
	eq(r["run"]["resin"], 5, "30 - 25")
	eq(RunReducer.instance(r["run"], sprout)["upgrade_id"], "attack_2", "stored on the instance")
	var other: int = run["deck"][2]["instance_id"]
	eq(RunReducer.instance(r["run"], other)["upgrade_id"], "", "other copy unchanged")
	eq(r["run"]["phase"], "battle", "next battle started")


func test_camp_cost_upgrade_price_and_poor() -> void:
	var run := _at_node("camp")
	var lift := RunReducer._add_card(run, "B10")
	var r := RunReducer.apply(run, {"type": "camp_upgrade", "card": lift, "upgrade": "cost_-1"})
	check(not r["ok"], "35 Resin needed with 30")
	eq(run["resin"], 30, "nothing paid")
	run["resin"] = 40
	r = RunReducer.apply(run, {"type": "camp_upgrade", "card": lift, "upgrade": "cost_-1"})
	eq(r["run"]["resin"], 5, "35 paid")
	eq(CardStats.cost(Catalog.card("B10"), "cost_-1"), 0, "Branch Lift costs 0")


func test_removal_keeps_seven_normals() -> void:
	var run := _at_node("removal")
	run["resin"] = 999
	var normals: Array = []
	for inst: Dictionary in run["deck"]:
		if Catalog.card(inst["def_id"])["kind"] != "champion":
			normals.append(inst["instance_id"])
	for i in 4:
		run["node"] = {"id": "N1A", "type": "removal", "status": "open", "slots": []}
		run["phase"] = "node"
		var r := RunReducer.apply(run, {"type": "remove_card", "card": normals[i]})
		check(r["ok"], "removal %d ok" % i)
		run = r["run"]
	eq(RunReducer.normal_card_count(run), 7, "seven left")
	run["node"] = {"id": "N1A", "type": "removal", "status": "open", "slots": []}
	run["phase"] = "node"
	check(not RunReducer.apply(run, {"type": "remove_card", "card": normals[5]})["ok"], "eighth removal refused")


func test_encounter_choices() -> void:
	var run := _at_node("encounter")
	run["heart"] = 50
	eq(RunReducer.apply(run, {"type": "encounter", "choice": "heal"})["run"]["heart"], 58, "heal 8")
	eq(RunReducer.apply(run, {"type": "encounter", "choice": "resin"})["run"]["resin"], 45, "+15")


func test_route_has_five_branches_of_two_types() -> void:
	var run := RunReducer.new_run(16, "SPORE")
	eq((run["route"] as Array).size(), 5, "five branch points")
	for r: Dictionary in run["route"]:
		check(r["options"][0]["type"] != r["options"][1]["type"], "two different node types")


func test_full_runs_with_both_champions() -> void:
	var wins := {"BARK": 0, "SPORE": 0}
	for seed_value in [101, 202, 303]:
		for faction in ["BARK", "SPORE"]:
			var res := AutoPlayer.play_run(RunReducer.new_run(seed_value, faction))
			var run: Dictionary = res["run"]
			check(run["phase"] in ["won", "lost"], "%s %d ends (phase %s)" % [faction, seed_value, run["phase"]])
			if run["phase"] == "won":
				wins[faction] += 1
				eq(int(run["stats"]["battles_won"]), 6, "six battles won")
	check(wins["BARK"] > 0, "Barkwarden wins at least one bot run %s" % [wins])
	check(wins["SPORE"] > 0, "Spore Sage wins at least one bot run %s" % [wins])


func test_demo_mode_ends_after_two_battles() -> void:
	var res := AutoPlayer.play_run(RunReducer.new_run(101, "BARK", "demo"))
	var run: Dictionary = res["run"]
	eq(run["phase"], "won", "demo run finishes")
	eq(run["result"], "demo_complete", "marked as demo complete")
	eq(int(run["stats"]["battles_won"]), 2, "after two battles")
	eq(RunReducer.new_run(101, "BARK")["mode"], "full", "default is the full game")


func test_hard_difficulty_scales_enemy_hp_only() -> void:
	var std := RunReducer.new_run(21, "BARK")
	var hard := RunReducer.new_run(21, "BARK", "full", "hard")
	check(not std.has("difficulty"), "standard is not stored (baseline unchanged)")
	eq(hard.get("difficulty", ""), "hard", "hard is stored in the run")
	check(not (std["battle"] as Dictionary).has("enemy_hp_pct"), "standard battle has no scale key")
	eq(int(hard["battle"]["enemy_hp_pct"]), 130, "hard battle scale")
	var want := {5: 7, 9: 12, 7: 9, 12: 16, 16: 21, 60: 78}
	var defs: Array = (Catalog.data()["enemies"] as Array).duplicate()
	defs.append(Catalog.boss())
	for d: Dictionary in defs:
		var s: Dictionary = (hard["battle"] as Dictionary).duplicate(true)
		var uid := BattleReducer.spawn_enemy(s, [], str(d["id"]))
		var base: int = int(d["max_hp"])
		var got: int = int(BattleReducer.unit(s, uid)["max_hp"])
		eq(got, int(want.get(base, (base * 130 + 50) / 100)), "%s hard max_hp" % d["id"])
		eq(int(BattleReducer.unit(s, uid)["attack"]), int(d["attack"]), "%s attack unchanged" % d["id"])
		var s2: Dictionary = (std["battle"] as Dictionary).duplicate(true)
		eq(int(BattleReducer.unit(s2, BattleReducer.spawn_enemy(s2, [], str(d["id"])))["max_hp"]), base, "%s standard max_hp" % d["id"])
	var dec: Dictionary = SaveCodec.decode(SaveCodec.encode(hard))
	check(dec["ok"], "hard run decodes")
	eq(dec["run"].get("difficulty", ""), "hard", "difficulty survives reload")
	var next := AutoPlayer.play_battle(hard)
	next = _bot_until(next, "battle")
	if next["phase"] == "battle":
		eq(int(next["battle"].get("enemy_hp_pct", 100)), 130, "next battle keeps hard scale")
