class_name AutoPlayer
extends RefCounted
## Greedy bot that plays through the real reducer, judging each legal action
## by the real Forecast. A regression and balance tool (bible p.22: "En bot er
## regressionstest, ikke bevis for sjov"), never used by the game itself.


## Every legal single command in the current player phase.
static func legal_commands(s: Dictionary) -> Array:
	var out: Array = []
	if s["phase"] != "player":
		return out
	for iid: int in s["zones"]["hand"]:
		var def: Dictionary = BattleReducer.card_def(s, iid)
		if BattleReducer.play_cost(s, iid) > int(s["energy"]):
			continue
		if Catalog.is_creature(def):
			for f in 3:
				var base := {"type": "play_card", "card": iid, "floor": f, "position": 0}
				if def.get("on_play", {}).get("op", "") == "heal_other_ally" and not BattleReducer.all_allies(s).is_empty():
					base["target"] = _most_hurt_ally(s)
				out.append(base)
				var back := base.duplicate()
				back["position"] = BattleReducer.floor_list(s, f, "ally").size()
				if back["position"] != 0:
					out.append(back)
		else:
			var legal: Dictionary = BattleReducer.spell_targets(s, def)
			for uid: int in legal["units"]:
				out.append({"type": "play_card", "card": iid, "target": uid})
			for f: int in legal["floors"]:
				out.append({"type": "play_card", "card": iid, "floor": f})
				if def["spell"]["target"] == "all_enemies":
					break
	if BattleReducer.move_cost(s) <= int(s["energy"]):
		for uid: int in BattleReducer.all_allies(s):
			var u: Dictionary = BattleReducer.unit(s, uid)
			if u["moved_this_turn"]:
				continue
			for df in [-1, 1]:
				var f: int = int(u["floor"]) + df
				if f >= 0 and f < 3:
					out.append({"type": "move", "unit": uid, "floor": f, "position": 0})
	return out


static func _most_hurt_ally(s: Dictionary) -> int:
	var best := -1
	var worst := 1 << 30
	for uid: int in BattleReducer.all_allies(s):
		var u: Dictionary = BattleReducer.unit(s, uid)
		var missing: int = int(u["hp"]) - int(u["max_hp"])
		if missing < worst:
			worst = missing
			best = uid
	return best


static func score(s: Dictionary) -> float:
	if s["terminal_result"] == "lost":
		return -100000.0
	var v: float = float(s["heart"]) * 30.0
	if s["terminal_result"] == "won":
		v += 50000.0
	for uid: int in BattleReducer.all_enemies(s):
		var u: Dictionary = BattleReducer.unit(s, uid)
		v -= float(u["hp"]) + float(u["armor"]) * 0.7 + 4.0
		v -= float(u["floor"]) * 6.0 * float(u["attack"])
		v += float(u["poison"]) * 1.5
	for uid: int in BattleReducer.all_allies(s):
		var u: Dictionary = BattleReducer.unit(s, uid)
		v += float(u["hp"]) * 0.6 + float(u["armor"]) * 0.4 + float(u["attack"]) * 1.5
	return v


## Best next command, or end_turn when nothing improves the forecast.
static func choose(s: Dictionary) -> Dictionary:
	var best_cmd := {"type": "end_turn"}
	var best: float = score(Forecast.end_turn(s)["state"]) + float(s["energy"]) * -0.5
	for cmd: Dictionary in legal_commands(s):
		var f: Dictionary = Forecast.after_command(s, cmd)
		if not f["ok"]:
			continue
		var v: float = score(f["state"])
		if v > best + 0.01:
			best = v
			best_cmd = cmd
	return best_cmd


## Run-level decision for reward/route/node screens.
static func choose_run(run: Dictionary) -> Dictionary:
	match str(run["phase"]):
		"battle":
			return {"type": "battle", "cmd": choose(run["battle"])}
		"reward":
			var slot: Dictionary = RunReducer.current_slot(run)
			var offer: Array = slot["offer"]
			var pick: String = offer[0]
			if slot["type"] == "card":
				for c: String in offer:
					if _card_value(c) > _card_value(pick):
						pick = c
			return {"type": "claim", "slot": slot["id"], "choice": pick}
		"route":
			var route: Dictionary = RunReducer.current_route(run)
			var opts: Array = route["options"]
			var pref := ["camp", "card", "encounter", "removal"]
			var pick: Dictionary = opts[0]
			for o: Dictionary in opts:
				if pref.find(o["type"]) < pref.find(pick["type"]):
					pick = o
			return {"type": "choose_node", "node": pick["id"]}
		"node":
			var node: Dictionary = run["node"]
			match str(node["type"]):
				"camp":
					for inst: Dictionary in run["deck"]:
						var ups: Array = CardStats.legal_upgrades(Catalog.card(inst["def_id"]), inst["upgrade_id"])
						if not ups.is_empty() and int(ups[0]["price"]) <= int(run["resin"]):
							return {"type": "camp_upgrade", "card": inst["instance_id"], "upgrade": ups[0]["id"]}
				"card":
					var slot: Dictionary = node["slots"][0]
					if slot["status"] == "offered":
						return {"type": "claim", "slot": slot["id"], "choice": slot["offer"][0]}
				"encounter":
					return {"type": "encounter", "choice": "heal" if int(run["heart"]) < int(run["heart_max"]) - 8 else "resin"}
			return {"type": "leave_node"}
	return {}


static func _card_value(def_id: String) -> float:
	var d: Dictionary = Catalog.card(def_id)
	if Catalog.is_creature(d):
		return float(d["attack"]) * 1.4 + float(d["max_hp"]) * 0.35 - float(d["cost"]) * 2.0
	return 4.0 - float(d["cost"])


## Plays a whole run; returns {run, steps}. max_steps guards against loops.
static func play_run(run: Dictionary, max_steps: int = 4000) -> Dictionary:
	var steps := 0
	while steps < max_steps and run["phase"] in ["battle", "reward", "route", "node"]:
		var cmd: Dictionary = choose_run(run)
		var r: Dictionary = RunReducer.apply(run, cmd)
		if not r["ok"]:
			push_error("AutoPlayer: rejected %s: %s" % [cmd, r["error"]])
			break
		run = r["run"]
		steps += 1
	return {"run": run, "steps": steps}


## Plays only the current battle to its end.
static func play_battle(run: Dictionary, max_steps: int = 600) -> Dictionary:
	var steps := 0
	while steps < max_steps and run["phase"] == "battle":
		var r: Dictionary = RunReducer.apply(run, {"type": "battle", "cmd": choose(run["battle"])})
		if not r["ok"]:
			push_error("AutoPlayer: " + str(r["error"]))
			break
		run = r["run"]
		steps += 1
	return run
