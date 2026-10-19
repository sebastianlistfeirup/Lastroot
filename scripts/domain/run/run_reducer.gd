class_name RunReducer
extends RefCounted
## Whole run (bible p.6, p.11-15): deck, route, economy, reward transactions,
## champion path, relics, mutations and the six battles. Same contract as the
## BattleReducer: apply(run, cmd) -> {ok, run, events, error}; a rejected
## command returns the original run untouched.
##
## Fixed reward flow after a won normal battle k (bible p.15):
##   R05 heal -> +20 Resin -> card choice -> k=1/3 mutation | k=2/4 champion
##   then relic -> route branch (one of two nodes) -> node -> battle k+1.
## Every slot has a stable id and status offered/claimed/skipped; offers are
## generated once and stored before they are shown, so reload never rerolls.

const SCHEMA_VERSION := 1
const NODE_TYPES: PackedStringArray = ["camp", "card", "encounter", "removal"]
const FACTIONS: PackedStringArray = ["BARK", "SPORE"]


# ------------------------------------------------------------------ new run

static func new_run(seed_value: int, faction: String) -> Dictionary:
	var rules: Dictionary = Catalog.rules()
	var champion: String = Catalog.champion_for(faction)
	var run := {
		"schema_version": SCHEMA_VERSION,
		"content_version": Catalog.data()["content_version"],
		"run_id": "LR-%08X" % (seed_value & 0xFFFFFFFF),
		"seed": seed_value & 0xFFFFFFFF,
		"main_faction": faction, "champion_id": champion,
		"deck": [], "next_instance_id": 1, "next_unit_id": 1,
		"champion_path": "", "champion_rank": 0,
		"relics": [], "mutations": [],
		"resin": int(rules["resin_start"]), "heart": int(rules["heart_start"]), "heart_max": int(rules["heart_start"]),
		"battle_index": 0, "phase": "battle", "battle": {},
		"route": [], "reward": {}, "node": {}, "reward_claims": {},
		"rng": {
			"shuffle": RngStream.create(seed_value, "shuffle"),
			"route": RngStream.create(seed_value, "route"),
			"reward": RngStream.create(seed_value, "reward"),
		},
		"stats": {"turns": 0, "cards_played": 0, "heart_lost": 0, "battles_won": 0},
		"result": "", "history": [],
	}
	_add_card(run, champion)
	var counts: Dictionary = Catalog.data()["start_deck"]["normal_counts"]
	var ids: Array = counts.keys()
	ids.sort()
	for cid: String in ids:
		for i in int(counts[cid]):
			_add_card(run, cid)
	# Route: five branch points, each two different node types.
	for k in range(1, 6):
		var types: Array = RngStream.pick_distinct(run["rng"]["route"], Array(NODE_TYPES), 2)
		run["route"].append({"id": "N%d" % k, "after_battle": k, "status": "locked",
			"options": [{"id": "N%dA" % k, "type": types[0]}, {"id": "N%dB" % k, "type": types[1]}], "chosen": ""})
	_start_battle(run, 0, [])
	return run


static func _add_card(run: Dictionary, def_id: String) -> int:
	var iid: int = int(run["next_instance_id"])
	run["next_instance_id"] = iid + 1
	(run["deck"] as Array).append({"instance_id": iid, "def_id": def_id, "upgrade_id": ""})
	return iid


static func _start_battle(run: Dictionary, index: int, ev: Array) -> void:
	run["battle_index"] = index
	run["phase"] = "battle"
	run["reward"] = {}
	run["node"] = {}
	var b: Dictionary = BattleFactory.create(run, index)
	run["battle"] = b["state"]
	run["heart_at_battle_start"] = run["heart"]
	ev.append({"kind": "battle_started", "battle_index": index})
	ev.append_array(b["events"])


# ------------------------------------------------------------------ queries

static func normal_card_count(run: Dictionary) -> int:
	var n := 0
	for inst: Dictionary in run["deck"]:
		if Catalog.card(inst["def_id"])["kind"] != "champion":
			n += 1
	return n


static func instance(run: Dictionary, iid: int) -> Dictionary:
	for inst: Dictionary in run["deck"]:
		if int(inst["instance_id"]) == iid:
			return inst
	return {}


static func current_slot(run: Dictionary) -> Dictionary:
	for slot: Dictionary in run.get("reward", {}).get("slots", []):
		if slot["status"] == "offered":
			return slot
	return {}


static func current_route(run: Dictionary) -> Dictionary:
	for r: Dictionary in run["route"]:
		if r["status"] == "open":
			return r
	return {}


# ---------------------------------------------------------------- commands

static func apply(run: Dictionary, cmd: Dictionary) -> Dictionary:
	var r: Dictionary = run.duplicate(true)
	var ev: Array = []
	var err: String = _dispatch(r, cmd, ev)
	if err != "":
		return {"ok": false, "run": run, "events": [], "error": err}
	return {"ok": true, "run": r, "events": ev, "error": ""}


static func _dispatch(r: Dictionary, cmd: Dictionary, ev: Array) -> String:
	match str(cmd.get("type", "")):
		"battle":
			return _battle(r, cmd.get("cmd", {}), ev)
		"claim":
			return _claim(r, str(cmd.get("slot", "")), cmd.get("choice", ""), ev)
		"skip":
			return _skip(r, str(cmd.get("slot", "")), ev)
		"choose_node":
			return _choose_node(r, str(cmd.get("node", "")), ev)
		"camp_upgrade":
			return _camp_upgrade(r, int(cmd.get("card", -1)), str(cmd.get("upgrade", "")), ev)
		"remove_card":
			return _remove_card(r, int(cmd.get("card", -1)), ev)
		"encounter":
			return _encounter(r, str(cmd.get("choice", "")), ev)
		"leave_node":
			return _leave_node(r, ev)
	return "Unknown command."


static func _battle(r: Dictionary, bcmd: Dictionary, ev: Array) -> String:
	if r["phase"] != "battle" or r["battle"].is_empty():
		return "There is no battle in progress."
	var res: Dictionary = BattleReducer.apply(r["battle"], bcmd)
	if not res["ok"]:
		return res["error"]
	var b: Dictionary = res["state"]
	r["battle"] = b
	ev.append_array(res["events"])
	var lost: int = int(r["heart"]) - int(b["heart"])
	if lost > 0:
		r["stats"]["heart_lost"] = int(r["stats"]["heart_lost"]) + lost
	r["heart"] = b["heart"]
	if str(bcmd.get("type", "")) == "play_card":
		r["stats"]["cards_played"] = int(r["stats"]["cards_played"]) + 1
	if b["terminal_result"] != "":
		_finish_battle(r, ev)
	return ""


static func _finish_battle(r: Dictionary, ev: Array) -> void:
	var b: Dictionary = r["battle"]
	r["next_unit_id"] = b["next_unit_id"]
	r["rng"]["shuffle"] = b["rng"]
	r["heart"] = b["heart"]
	r["stats"]["turns"] = int(r["stats"]["turns"]) + int(b["turn"])
	r["last_battle"] = {"index": b["battle_index"], "result": b["terminal_result"], "turns": b["turn"], "heart": b["heart"]}
	if not r.has("history"):
		r["history"] = []
	(r["history"] as Array).append({"index": b["battle_index"], "battle_def_id": b["battle_def_id"],
		"result": b["terminal_result"], "turns": b["turn"], "heart_start": r.get("heart_at_battle_start", b["heart"]),
		"heart_end": b["heart"], "deployed": (b["zones"]["deployed"] as Array).size()})
	r["battle"] = {}
	if b["terminal_result"] == "lost":
		r["phase"] = "lost"
		r["result"] = "lost"
		ev.append({"kind": "run_lost", "battle_index": b["battle_index"]})
		return
	r["stats"]["battles_won"] = int(r["stats"]["battles_won"]) + 1
	if b["is_boss"]:
		r["phase"] = "won"
		r["result"] = "won"
		ev.append({"kind": "run_won"})
		return
	_enter_rewards(r, int(b["battle_index"]) + 1, ev)


## Commit victory -> R05 -> +20 Resin -> offers (generated and stored now).
static func _enter_rewards(r: Dictionary, k: int, ev: Array) -> void:
	var rules: Dictionary = Catalog.rules()
	var slots: Array = []
	var rng: Dictionary = r["rng"]["reward"]
	if (r["relics"] as Array).has("R05"):
		var before: int = int(r["heart"])
		r["heart"] = mini(int(r["heart_max"]), before + 4)
		slots.append({"id": "B%d.R05" % k, "type": "heart_heal", "status": "claimed", "amount": int(r["heart"]) - before})
		ev.append({"kind": "heart_healed", "reason": "R05", "before": before, "after": r["heart"]})
	r["resin"] = int(r["resin"]) + int(rules["normal_win_resin"])
	slots.append({"id": "B%d.resin" % k, "type": "resin", "status": "claimed", "amount": int(rules["normal_win_resin"])})
	ev.append({"kind": "resin_gained", "amount": rules["normal_win_resin"], "after": r["resin"]})
	slots.append({"id": "B%d.card" % k, "type": "card", "status": "offered", "offer": _card_offer(rng)})
	if (rules["mutation_choice_after_battles"] as Array).has(k):
		var unowned: Array = []
		for m: Dictionary in Catalog.data()["mutations"]:
			if not (r["mutations"] as Array).has(m["id"]):
				unowned.append(m["id"])
		slots.append({"id": "B%d.mutation" % k, "type": "mutation", "status": "offered", "offer": unowned, "skippable": false})
	if (rules["champion_choice_after_battles"] as Array).has(k):
		var paths: Array = []
		if r["champion_path"] == "":
			for p: Dictionary in Catalog.champion_paths(r["champion_id"]):
				paths.append(p["id"])
		else:
			paths = [r["champion_path"]]
		slots.append({"id": "B%d.champion" % k, "type": "champion", "status": "offered", "offer": paths, "skippable": false})
	if (rules["relic_choice_after_battles"] as Array).has(k):
		var pool: Array = []
		for rel: Dictionary in Catalog.data()["relics"]:
			if not (r["relics"] as Array).has(rel["id"]):
				pool.append(rel["id"])
		slots.append({"id": "B%d.relic" % k, "type": "relic", "status": "offered",
			"offer": RngStream.pick_distinct(rng, pool, 3), "skippable": false})
	r["reward"] = {"battle_number": k, "slots": slots}
	r["phase"] = "reward"
	for slot: Dictionary in slots:
		r["reward_claims"][slot["id"]] = slot["status"]
	ev.append({"kind": "rewards_offered", "battle_number": k})


static func _card_offer(rng: Dictionary) -> Array:
	return RngStream.pick_distinct(rng, Array(Catalog.normal_card_ids()), 3)


static func _find_slot(r: Dictionary, slot_id: String) -> Dictionary:
	for slot: Dictionary in r.get("reward", {}).get("slots", []):
		if slot["id"] == slot_id:
			return slot
	var node: Dictionary = r.get("node", {})
	for slot: Dictionary in node.get("slots", []):
		if slot["id"] == slot_id:
			return slot
	return {}


static func _claim(r: Dictionary, slot_id: String, choice: Variant, ev: Array) -> String:
	var slot: Dictionary = _find_slot(r, slot_id)
	if slot.is_empty():
		return "That reward is not available."
	if slot["status"] != "offered":
		return "That reward has already been %s." % slot["status"]
	if r["phase"] == "reward" and current_slot(r).get("id", "") != slot_id:
		return "Finish the earlier reward first."
	var c: String = str(choice)
	if not (slot["offer"] as Array).has(c):
		return "Choose one of the offered options."
	match slot["type"]:
		"card":
			var iid: int = _add_card(r, c)
			ev.append({"kind": "card_added", "card": iid, "def_id": c})
		"mutation":
			(r["mutations"] as Array).append(c)
			if c == "M04":
				r["heart_max"] = int(r["heart_max"]) + 15
				r["heart"] = int(r["heart"]) + 15
			ev.append({"kind": "mutation_gained", "id": c})
		"champion":
			if r["champion_path"] != "" and r["champion_path"] != c:
				return "The champion's path is locked."
			r["champion_path"] = c
			r["champion_rank"] = mini(2, int(r["champion_rank"]) + 1)
			ev.append({"kind": "champion_upgraded", "path": c, "rank": r["champion_rank"]})
		"relic":
			if (r["relics"] as Array).has(c):
				return "You already own that relic."
			(r["relics"] as Array).append(c)
			ev.append({"kind": "relic_gained", "id": c})
	slot["status"] = "claimed"
	slot["choice"] = c
	r["reward_claims"][slot_id] = "claimed"
	_advance(r, ev)
	return ""


static func _skip(r: Dictionary, slot_id: String, ev: Array) -> String:
	var slot: Dictionary = _find_slot(r, slot_id)
	if slot.is_empty():
		return "That reward is not available."
	if slot["status"] != "offered":
		return "That reward has already been %s." % slot["status"]
	if not slot.get("skippable", true):
		return "This choice cannot be skipped."
	slot["status"] = "skipped"
	r["reward_claims"][slot_id] = "skipped"
	ev.append({"kind": "reward_skipped", "slot": slot_id})
	_advance(r, ev)
	return ""


## Moves the run forward once the current screen's slots are settled.
static func _advance(r: Dictionary, ev: Array) -> void:
	if r["phase"] == "reward":
		if not current_slot(r).is_empty():
			return
		var k: int = int(r["reward"]["battle_number"])
		for route: Dictionary in r["route"]:
			if int(route["after_battle"]) == k:
				route["status"] = "open"
		r["phase"] = "route"
		ev.append({"kind": "route_opened", "after_battle": k})
	elif r["phase"] == "node":
		var node: Dictionary = r["node"]
		if node["type"] == "card":
			for slot: Dictionary in node["slots"]:
				if slot["status"] == "offered":
					return
			_leave_node(r, ev)


static func _choose_node(r: Dictionary, node_id: String, ev: Array) -> String:
	if r["phase"] != "route":
		return "There is no path to choose now."
	var route: Dictionary = current_route(r)
	var chosen: Dictionary = {}
	for opt: Dictionary in route.get("options", []):
		if opt["id"] == node_id:
			chosen = opt
	if chosen.is_empty():
		return "Choose one of the two paths."
	route["status"] = "chosen"
	route["chosen"] = node_id
	r["reward_claims"][node_id] = "claimed"
	var node := {"id": node_id, "type": chosen["type"], "status": "open", "slots": []}
	if chosen["type"] == "card":
		node["slots"] = [{"id": node_id + ".card", "type": "card", "status": "offered", "offer": _card_offer(r["rng"]["reward"])}]
	r["node"] = node
	r["phase"] = "node"
	ev.append({"kind": "node_entered", "node": node_id, "type": chosen["type"]})
	return ""


static func _require_node(r: Dictionary, type: String) -> String:
	if r["phase"] != "node" or r["node"].get("type", "") != type:
		return "You are not at a %s." % type
	if r["node"]["status"] != "open":
		return "This place has already been used."
	return ""


## Camp: pay 25 or 35 Resin for one legal upgrade, or leave.
static func _camp_upgrade(r: Dictionary, iid: int, upgrade_id: String, ev: Array) -> String:
	var e: String = _require_node(r, "camp")
	if e != "":
		return e
	var inst: Dictionary = instance(r, iid)
	if inst.is_empty():
		return "Choose a card from your deck."
	var def: Dictionary = Catalog.card(inst["def_id"])
	var legal: Array = CardStats.legal_upgrades(def, inst["upgrade_id"])
	var up: Dictionary = {}
	for u: Dictionary in legal:
		if u["id"] == upgrade_id:
			up = u
	if up.is_empty():
		return "That card cannot get this upgrade." if legal.is_empty() == false else "That card cannot be upgraded."
	if int(r["resin"]) < int(up["price"]):
		return "Not enough Resin (needs %d)." % up["price"]
	r["resin"] = int(r["resin"]) - int(up["price"])
	inst["upgrade_id"] = upgrade_id
	r["node"]["status"] = "used"
	ev.append({"kind": "card_upgraded", "card": iid, "upgrade": upgrade_id, "price": up["price"]})
	return _leave_node(r, ev)


## Removal: 15 Resin, one normal card; at least seven normal cards remain.
static func _remove_card(r: Dictionary, iid: int, ev: Array) -> String:
	var e: String = _require_node(r, "removal")
	if e != "":
		return e
	var inst: Dictionary = instance(r, iid)
	if inst.is_empty():
		return "Choose a card from your deck."
	if Catalog.card(inst["def_id"])["kind"] == "champion":
		return "The champion cannot be removed."
	var rules: Dictionary = Catalog.rules()
	if normal_card_count(r) - 1 < int(rules["min_normal_cards"]):
		return "Your deck must keep at least %d normal cards." % rules["min_normal_cards"]
	if int(r["resin"]) < int(rules["remove_cost"]):
		return "Not enough Resin (needs %d)." % rules["remove_cost"]
	r["resin"] = int(r["resin"]) - int(rules["remove_cost"])
	(r["deck"] as Array).erase(inst)
	r["node"]["status"] = "used"
	ev.append({"kind": "card_removed", "card": iid, "def_id": inst["def_id"]})
	return _leave_node(r, ev)


## Encounter: 15 Resin or heal the Heart 8.
static func _encounter(r: Dictionary, choice: String, ev: Array) -> String:
	var e: String = _require_node(r, "encounter")
	if e != "":
		return e
	match choice:
		"resin":
			r["resin"] = int(r["resin"]) + 15
			ev.append({"kind": "resin_gained", "amount": 15, "after": r["resin"]})
		"heal":
			var before: int = int(r["heart"])
			r["heart"] = mini(int(r["heart_max"]), before + 8)
			ev.append({"kind": "heart_healed", "reason": "encounter", "before": before, "after": r["heart"]})
		_:
			return "Choose Resin or healing."
	r["node"]["status"] = "used"
	return _leave_node(r, ev)


static func _leave_node(r: Dictionary, ev: Array) -> String:
	if r["phase"] != "node":
		return "You are not at a node."
	var node: Dictionary = r["node"]
	for slot: Dictionary in node.get("slots", []):
		if slot["status"] == "offered":
			slot["status"] = "skipped"
			r["reward_claims"][slot["id"]] = "skipped"
	ev.append({"kind": "node_left", "node": node["id"]})
	_start_battle(r, int(r["battle_index"]) + 1, ev)
	return ""
