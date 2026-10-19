class_name BattleFactory
extends RefCounted
## Builds a BattleState from the run (bible p.6, p.20). Battle status and HP
## reset to upgraded battle-start values; the run deck is only read.


## Waves as [{turn, enemies: [def_id...]}] in catalog order.
static func waves_for(battle_index: int) -> Array:
	var out: Array = []
	if battle_index >= 5:
		var b: Dictionary = Catalog.boss()
		var t := 1
		for w: Array in b["waves"]:
			out.append({"turn": t, "enemies": w.duplicate()})
			t += 1
		out.append({"turn": int(b["arrival_turn"]), "enemies": [b["id"]]})
		return out
	for w: Dictionary in Catalog.normal_battle(battle_index)["waves"]:
		var ids: Array = []
		for g: Dictionary in w["groups"]:
			for i in int(g["count"]):
				ids.append(g["enemy_id"])
		out.append({"turn": int(w["turn"]), "enemies": ids})
	return out


## Returns {state, events}. The run is not modified; RunReducer copies the
## battle's next_unit_id, rng and heart back when the battle ends.
static func create(run: Dictionary, battle_index: int) -> Dictionary:
	var deck: Dictionary = {}
	var champion_iid := -1
	var normals: Array = []
	for inst: Dictionary in run["deck"]:
		deck[str(inst["instance_id"])] = {"def_id": inst["def_id"], "upgrade_id": inst.get("upgrade_id", "")}
		if Catalog.card(inst["def_id"]).get("kind", "") == "champion":
			champion_iid = int(inst["instance_id"])
		else:
			normals.append(int(inst["instance_id"]))
	normals.sort()
	var is_boss: bool = battle_index >= 5
	var s := {
		"battle_id": "%s-B%d" % [run["run_id"], battle_index + 1],
		"battle_index": battle_index,
		"battle_def_id": Catalog.boss()["id"] if is_boss else Catalog.normal_battle(battle_index)["id"],
		"is_boss": is_boss,
		"turn": 0, "phase": "player", "energy": 0, "wave_index": 0, "waves": waves_for(battle_index),
		"zones": {"draw": normals, "hand": [], "discard": [], "deployed": [], "consumed": []},
		"champion_iid": champion_iid, "deck": deck,
		"units": {}, "floors": [{"allies": [], "enemies": []}, {"allies": [], "enemies": []}, {"allies": [], "enemies": []}],
		"flags": {"r02": false, "r03": false, "r08": false},
		"event_sequence": 0, "resolution_id": 0, "current_resolution": 0,
		"terminal_result": "", "boss_escaped": false, "boss_unit_id": -1, "death_queue": [],
		"next_unit_id": int(run["next_unit_id"]),
		"rng": (run["rng"]["shuffle"] as Dictionary).duplicate(),
		"heart": int(run["heart"]), "heart_max": int(run["heart_max"]),
		"relics": (run["relics"] as Array).duplicate(), "mutations": (run["mutations"] as Array).duplicate(),
		"champion_id": run["champion_id"], "champion_path": run.get("champion_path", ""),
		"champion_rank": int(run.get("champion_rank", 0)),
	}
	RngStream.shuffle(s["rng"], s["zones"]["draw"])
	if champion_iid >= 0:
		s["zones"]["hand"].append(champion_iid)  # tur 1: champion separat
	var ev: Array = []
	BattleReducer.begin_turn(s, ev)
	return {"state": s, "events": ev}
