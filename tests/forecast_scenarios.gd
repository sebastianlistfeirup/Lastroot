class_name ForecastScenarios
extends RefCounted
## Generates fixed forecast scenarios (bible p.17 "Bevis"): real battle states
## reached by the bot from fixed seeds with varied relics, mutations, champion
## paths and all six battles. Each scenario stores the state right before
## END_TURN and the expected resolved hash + event hash.

const RELIC_SETS := [[], ["R03"], ["R01", "R07"], ["R02", "R08"], ["R04", "R06"], ["R05", "R03", "R08"]]
const MUT_SETS := [[], ["M02"], ["M01", "M03"], ["M04"], ["M02", "M03"], ["M01"]]
const PATHS := [["", 0], ["BULWARK", 1], ["WRATH", 2], ["VENOM", 1], ["LIFEWEAVER", 2]]


static func generate(count: int) -> Array:
	var out: Array = []
	var seed_value := 1
	while out.size() < count and seed_value < 2000:
		var faction: String = "BARK" if seed_value % 2 == 1 else "SPORE"
		var run: Dictionary = RunReducer.new_run(seed_value * 7919, faction)
		run["relics"] = RELIC_SETS[seed_value % RELIC_SETS.size()]
		run["mutations"] = MUT_SETS[(seed_value / 2) % MUT_SETS.size()]
		var p: Array = PATHS[seed_value % PATHS.size()]
		var path: String = p[0]
		if path != "" and Catalog.champion_path(run["champion_id"], path).is_empty():
			path = Catalog.champion_paths(run["champion_id"])[0]["id"]
		run["champion_path"] = path
		run["champion_rank"] = p[1] if path != "" else 0
		# Two extra cards per seed so every card type appears across the set.
		var normals: PackedStringArray = Catalog.normal_card_ids()
		for k in 2:
			RunReducer._add_card(run, normals[(seed_value * 3 + k * 11) % normals.size()])
		var battle_index: int = seed_value % 6
		var s: Dictionary = BattleFactory.create(run, battle_index)["state"]
		var turn_pick: int = 1 + (seed_value % 4)
		var taken := 0
		var steps := 0
		while s["terminal_result"] == "" and steps < 300 and taken < 2:
			var cmd: Dictionary = AutoPlayer.choose(s)
			if cmd["type"] == "end_turn" and (int(s["turn"]) == turn_pick or int(s["turn"]) == turn_pick + 3):
				out.append(_make(s, "S%03d" % (out.size() + 1), seed_value, battle_index))
				taken += 1
			var r: Dictionary = BattleReducer.apply(s, cmd)
			if not r["ok"]:
				break
			s = r["state"]
			steps += 1
		seed_value += 1
	return out.slice(0, count)


static func _make(s: Dictionary, id: String, seed_value: int, battle_index: int) -> Dictionary:
	var f: Dictionary = Forecast.end_turn(s)
	var tags := {}
	for e: Dictionary in f["events"]:
		match str(e["kind"]):
			"death": tags["death"] = true
			"thorns": tags["thorns"] = true
			"poison_tick": tags["poison"] = true
			"heart_damaged": tags["heart_damage"] = true
			"boss_anchored", "boss_escaped": tags["boss"] = true
			"heal": tags["heal"] = true
			"enemy_climbed": tags["climb"] = true
	if not (s["mutations"] as Array).is_empty():
		tags["mutation"] = true
	if not (s["relics"] as Array).is_empty():
		tags["relic"] = true
	if s["is_boss"]:
		tags["boss"] = true
	if BattleReducer.all_allies(s).is_empty():
		tags["empty_board"] = true
	for u: Dictionary in s["units"].values():
		if u["moved_this_turn"]:
			tags["moved"] = true
	if f["state"]["terminal_result"] != "":
		tags["terminal_" + str(f["state"]["terminal_result"])] = true
	return {"id": id, "seed": seed_value, "battle_index": battle_index, "turn": s["turn"],
		"tags": tags.keys(), "state": s, "expected_hash": f["hash"],
		"expected_events": JsonUtil.state_hash(f["events"]), "event_count": (f["events"] as Array).size()}
