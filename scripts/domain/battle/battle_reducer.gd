class_name BattleReducer
extends RefCounted
## The only authority over a battle (bible p.7, p.17).
## apply(state, command) -> {ok, state, events, error, resolved_hash}
## The input state is never mutated: the reducer works on a deep copy and
## returns the original untouched when a command is rejected, so a rejected
## command never spends Sap, flags or RNG. Forecast runs the very same
## resolve_end_turn() on a clone.
##
## State is plain Dictionaries/Arrays/ints/Strings (serializable, cloneable).
## Floors: 0 Roots, 1 Trunk, 2 Crown. In every floor list index 0 is the front.

const FLOORS := 3
const SIDE_LIST := {"ally": "allies", "enemy": "enemies"}


# ---------------------------------------------------------------- public API

static func apply(state: Dictionary, cmd: Dictionary) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	var ev: Array = []
	var err: String = ""
	var resolved_hash: String = ""
	match str(cmd.get("type", "")):
		"play_card":
			err = _play_card(s, cmd, ev)
		"move":
			err = _move(s, cmd, ev)
		"end_turn":
			if s["phase"] != "player":
				err = "The battle is not waiting for you."
			else:
				resolve_end_turn(s, ev)
				resolved_hash = JsonUtil.state_hash(s)
				if s["terminal_result"] == "":
					begin_turn(s, ev)
		_:
			err = "Unknown command."
	if err != "":
		return {"ok": false, "state": state, "events": [], "error": err, "resolved_hash": ""}
	return {"ok": true, "state": s, "events": ev, "error": "", "resolved_hash": resolved_hash}


## Reason a command would be rejected, or "" when it is legal. Never mutates.
static func validate(state: Dictionary, cmd: Dictionary) -> String:
	return str(apply(state, cmd)["error"])


# ------------------------------------------------------------------ helpers

static func unit(s: Dictionary, uid: int) -> Dictionary:
	return s["units"].get(str(uid), {})


static func floor_list(s: Dictionary, f: int, side: String) -> Array:
	return s["floors"][f][SIDE_LIST[side]]


static func has_mutation(s: Dictionary, mid: String) -> bool:
	return (s["mutations"] as Array).has(mid)


static func has_relic(s: Dictionary, rid: String) -> bool:
	return (s["relics"] as Array).has(rid)


static func capacity(s: Dictionary, f: int) -> int:
	var cap: int = int(Catalog.rules()["floor_capacity"][f])
	if f == 0 and has_mutation(s, "M01"):
		cap += 1
	return cap


static func used_space(s: Dictionary, f: int) -> int:
	var total := 0
	for uid: int in floor_list(s, f, "ally"):
		total += int(unit(s, uid)["space"])
	return total


static func attack_value(s: Dictionary, u: Dictionary) -> int:
	var a: int = int(u["attack"])
	if u["side"] == "ally" and int(u["floor"]) == 1 and has_mutation(s, "M02"):
		a += 1  # derived from position, never stored (bible p.12)
	return a


static func living_units_on(s: Dictionary, f: int) -> Array:
	var ids: Array = []
	for uid: int in floor_list(s, f, "ally"):
		ids.append(uid)
	for uid: int in floor_list(s, f, "enemy"):
		ids.append(uid)
	ids.sort()
	return ids


static func all_enemies(s: Dictionary) -> Array:
	var out: Array = []
	for f in FLOORS:
		out.append_array(floor_list(s, f, "enemy"))
	return out


static func all_allies(s: Dictionary) -> Array:
	var out: Array = []
	for f in FLOORS:
		out.append_array(floor_list(s, f, "ally"))
	return out


static func card_def(s: Dictionary, iid: int) -> Dictionary:
	var inst: Dictionary = s["deck"].get(str(iid), {})
	return Catalog.card(str(inst.get("def_id", "")))


static func card_upgrade(s: Dictionary, iid: int) -> String:
	return str(s["deck"].get(str(iid), {}).get("upgrade_id", ""))


## Sap a card would cost right now (including R02 for the first spell).
static func play_cost(s: Dictionary, iid: int) -> int:
	var def: Dictionary = card_def(s, iid)
	var c: int = CardStats.cost(def, card_upgrade(s, iid))
	if def.get("kind", "") == "spell" and has_relic(s, "R02") and not s["flags"]["r02"]:
		c = maxi(0, c - 1)
	return c


static func move_cost(s: Dictionary) -> int:
	if has_relic(s, "R08") and not s["flags"]["r08"]:
		return 0
	return 1


static func waves_remaining(s: Dictionary) -> int:
	return (s["waves"] as Array).size() - int(s["wave_index"])


static func _ev(s: Dictionary, ev: Array, kind: String, data: Dictionary = {}) -> void:
	s["event_sequence"] = int(s["event_sequence"]) + 1
	var e := {
		"seq": s["event_sequence"], "kind": kind, "turn": s["turn"],
		"resolution_id": s["current_resolution"],
		"stage": "resolution" if int(s["current_resolution"]) > 0 else "action",
	}
	e.merge(data)
	ev.append(e)


static func _snap(u: Dictionary) -> Dictionary:
	return {"hp": u["hp"], "armor": u["armor"], "poison": u["poison"], "growth": u["growth"]}


# ------------------------------------------------------------- unit creation

static func new_unit(s: Dictionary, side: String, def_id: String, card_iid: int, f: int, stats: Dictionary) -> int:
	var uid: int = int(s["next_unit_id"])
	s["next_unit_id"] = uid + 1
	var u := {
		"unit_id": uid, "side": side, "def_id": def_id, "card_iid": card_iid, "floor": f,
		"hp": stats["max_hp"], "max_hp": stats["max_hp"], "attack": stats["attack"],
		"armor": stats.get("armor", 0), "poison": 0, "thorns": stats.get("thorns", 0),
		"growth": stats.get("growth", 0), "on_hit_poison": stats.get("on_hit_poison", 0),
		"bonus_vs_poisoned": stats.get("bonus_vs_poisoned", 0), "space": stats.get("space", 0),
		"moved_this_turn": false, "spawned_resolution": int(s["current_resolution"]),
		"is_champion": stats.get("is_champion", false), "is_boss": stats.get("is_boss", false),
		"alive": true, "removed": false,
	}
	s["units"][str(uid)] = u
	return uid


static func spawn_enemy(s: Dictionary, ev: Array, def_id: String) -> int:
	var d: Dictionary = Catalog.enemy(def_id)
	var is_boss: bool = d.get("id", "") == Catalog.boss()["id"]
	# Difficulty scales max HP with round-half-up integer math (D32).
	var max_hp: int = (int(d["max_hp"]) * int(s.get("enemy_hp_pct", 100)) + 50) / 100
	var uid: int = new_unit(s, "enemy", def_id, -1, 0, {
		"attack": int(d["attack"]), "max_hp": max_hp, "armor": int(d["start_armor"]),
		"is_boss": is_boss,
	})
	floor_list(s, 0, "enemy").append(uid)
	if is_boss:
		s["boss_unit_id"] = uid
	_ev(s, ev, "enemy_spawned", {"target_id": uid, "def_id": def_id, "floor": 0,
		"position": floor_list(s, 0, "enemy").size() - 1, "after": _snap(unit(s, uid))})
	return uid


# ------------------------------------------------------------ damage & death

## Normal damage: Armor absorbs first (bible p.8).
static func damage(s: Dictionary, ev: Array, target: int, amount: int, source: int, kind: String = "damage") -> void:
	var t: Dictionary = unit(s, target)
	if t.is_empty() or not t["alive"] or amount <= 0:
		return
	var before := _snap(t)
	var absorbed: int = mini(int(t["armor"]), amount)
	t["armor"] = int(t["armor"]) - absorbed
	t["hp"] = int(t["hp"]) - (amount - absorbed)
	_ev(s, ev, kind, {"actor_id": source, "target_id": target, "amount": amount, "absorbed": absorbed,
		"before": before, "after": _snap(t)})
	if int(t["hp"]) <= 0:
		_kill(s, target)


## Removes the unit from target lists at once and queues its death (FIFO).
static func _kill(s: Dictionary, uid: int) -> void:
	var u: Dictionary = unit(s, uid)
	if not u["alive"]:
		return
	u["alive"] = false
	floor_list(s, int(u["floor"]), u["side"]).erase(uid)
	(s["death_queue"] as Array).append(uid)


## Safe drain point: death events in FIFO order, each handled exactly once.
static func drain_deaths(s: Dictionary, ev: Array) -> void:
	var q: Array = s["death_queue"]
	while not q.is_empty():
		var uid: int = q.pop_front()
		var u: Dictionary = unit(s, uid)
		_ev(s, ev, "death", {"target_id": uid, "def_id": u["def_id"], "side": u["side"], "floor": u["floor"]})
		if u["side"] == "ally":
			var od: Dictionary = Catalog.card(u["def_id"]).get("on_death", {})
			if od.get("op", "") == "poison_enemy_floor":
				_ev(s, ev, "on_death_effect", {"actor_id": uid, "def_id": u["def_id"], "floor": u["floor"]})
				apply_poison(s, ev, floor_list(s, int(u["floor"]), "enemy").duplicate(), int(od["amount"]), true, uid)


## Poison stacks. Player-caused applications trigger R03 once per turn: +1 on
## the first target, which is the lowest unit_id for areas (bible p.12, T07).
static func apply_poison(s: Dictionary, ev: Array, targets: Array, amount: int, player_caused: bool, source: int) -> void:
	var living: Array = []
	for uid: int in targets:
		if unit(s, uid).get("alive", false):
			living.append(uid)
	if living.is_empty() or amount <= 0:
		return
	var bonus_target := -1
	if player_caused and has_relic(s, "R03") and not s["flags"]["r03"]:
		s["flags"]["r03"] = true
		bonus_target = living.min()
	for uid: int in living:
		var u: Dictionary = unit(s, uid)
		var amt: int = amount + (1 if uid == bonus_target else 0)
		var before := _snap(u)
		u["poison"] = int(u["poison"]) + amt
		_ev(s, ev, "poison_applied", {"actor_id": source, "target_id": uid, "amount": amt,
			"relic": "R03" if uid == bonus_target else "", "before": before, "after": _snap(u)})


static func heal(s: Dictionary, ev: Array, uid: int, amount: int, source: int, reason: String) -> void:
	var u: Dictionary = unit(s, uid)
	if u.is_empty() or not u["alive"] or amount <= 0:
		return
	var before := _snap(u)
	var new_hp: int = mini(int(u["max_hp"]), int(u["hp"]) + amount)
	if new_hp == int(u["hp"]):
		return
	u["hp"] = new_hp
	_ev(s, ev, "heal", {"actor_id": source, "target_id": uid, "amount": amount, "reason": reason,
		"before": before, "after": _snap(u)})


static func add_armor(s: Dictionary, ev: Array, uid: int, amount: int, source: int, reason: String) -> void:
	var u: Dictionary = unit(s, uid)
	if u.is_empty() or not u["alive"] or amount <= 0:
		return
	var before := _snap(u)
	u["armor"] = int(u["armor"]) + amount
	_ev(s, ev, "armor_gained", {"actor_id": source, "target_id": uid, "amount": amount, "reason": reason,
		"before": before, "after": _snap(u)})


# ------------------------------------------------------------------- attack

## Direct attack transaction (bible p.8): front target, damage + bonuses,
## on-hit Poison if the target survives, snapshot Thorns back, drain deaths.
static func attack(s: Dictionary, ev: Array, attacker: int) -> void:
	var a: Dictionary = unit(s, attacker)
	if a.is_empty() or not a["alive"]:
		return
	var other: String = "enemy" if a["side"] == "ally" else "ally"
	var targets: Array = floor_list(s, int(a["floor"]), other)
	if targets.is_empty():
		return
	var target: int = targets[0]
	var t: Dictionary = unit(s, target)
	var dmg: int = attack_value(s, a)
	if int(t["poison"]) > 0:
		dmg += int(a["bonus_vs_poisoned"])
	var thorns_snapshot: int = int(t["thorns"])
	_ev(s, ev, "attack", {"actor_id": attacker, "target_id": target, "floor": a["floor"], "amount": dmg})
	damage(s, ev, target, dmg, attacker)
	if t["alive"] and int(a["on_hit_poison"]) > 0:
		apply_poison(s, ev, [target], int(a["on_hit_poison"]), a["side"] == "ally", attacker)
	if thorns_snapshot > 0 and a["alive"]:
		damage(s, ev, attacker, thorns_snapshot, target, "thorns")
	drain_deaths(s, ev)


# ---------------------------------------------------------------- resolution

## END_TURN steps 4-8 (bible p.7). Shared by the real battle and Forecast.
static func resolve_end_turn(s: Dictionary, ev: Array) -> void:
	s["phase"] = "resolving"
	s["resolution_id"] = int(s["resolution_id"]) + 1
	s["current_resolution"] = s["resolution_id"]
	_ev(s, ev, "resolution_begin", {})
	for f in FLOORS:
		_ev(s, ev, "floor_begin", {"floor": f})
		# Poison phase: only Poison present at the snapshot ticks.
		var snapshot: Array = []
		for uid: int in living_units_on(s, f):
			var u: Dictionary = unit(s, uid)
			if int(u["poison"]) > 0:
				snapshot.append([uid, int(u["poison"])])
		for pair: Array in snapshot:
			var u: Dictionary = unit(s, pair[0])
			if not u["alive"] or int(u["floor"]) != f:
				continue
			var before := _snap(u)
			u["hp"] = int(u["hp"]) - int(pair[1])
			u["poison"] = maxi(0, int(u["poison"]) - 1)
			_ev(s, ev, "poison_tick", {"target_id": pair[0], "amount": pair[1], "floor": f,
				"before": before, "after": _snap(u)})
			if int(u["hp"]) <= 0:
				_kill(s, pair[0])
			drain_deaths(s, ev)
		# Allies front-to-back, then living enemies front-to-back.
		for side in ["ally", "enemy"]:
			for uid: int in floor_list(s, f, side).duplicate():
				var u: Dictionary = unit(s, uid)
				if u["alive"] and int(u["floor"]) == f and int(u["spawned_resolution"]) != int(s["resolution_id"]):
					attack(s, ev, uid)
		# Growth heals living units at the end of the floor.
		for uid: int in living_units_on(s, f):
			var u: Dictionary = unit(s, uid)
			if int(u["growth"]) > 0:
				heal(s, ev, uid, int(u["growth"]), uid, "growth")
		_ev(s, ev, "floor_end", {"floor": f})
	_climb(s, ev)
	_check_terminal(s, ev)
	if s["terminal_result"] == "":
		var kept: Array = []
		var discarded: Array = []
		for iid: int in s["zones"]["hand"]:
			if iid == int(s["champion_iid"]):
				kept.append(iid)  # D02: unplayed champion stays in hand
			else:
				discarded.append(iid)
		s["zones"]["hand"] = kept
		(s["zones"]["discard"] as Array).append_array(discarded)
		if not discarded.is_empty():
			_ev(s, ev, "hand_discarded", {"cards": discarded})
	_ev(s, ev, "resolution_end", {"heart": s["heart"], "result": s["terminal_result"]})
	s["current_resolution"] = 0


## Step 7-8: every surviving normal enemy climbs one floor simultaneously from
## a pre-move list; climbers queue behind enemies already standing there. The
## boss stays while a living ally shares its floor (bible p.14).
static func _climb(s: Dictionary, ev: Array) -> void:
	var pre: Array = []
	for f in FLOORS:
		pre.append(floor_list(s, f, "enemy").duplicate())
	var new_lists: Array = [[], [], []]
	var movers: Array = [[], [], []]
	for f in FLOORS:
		for uid: int in pre[f]:
			var u: Dictionary = unit(s, uid)
			if u["is_boss"] and not floor_list(s, f, "ally").is_empty():
				new_lists[f].append(uid)
				_ev(s, ev, "boss_anchored", {"actor_id": uid, "floor": f})
			else:
				movers[f].append(uid)
	for f in FLOORS:
		for uid: int in movers[f]:
			var u: Dictionary = unit(s, uid)
			if f == FLOORS - 1:
				if u["is_boss"]:
					s["boss_escaped"] = true
					u["alive"] = false
					u["removed"] = true
					_ev(s, ev, "boss_escaped", {"actor_id": uid, "from_floor": f})
				else:
					var dmg: int = maxi(1, int(u["attack"]))
					var before: int = int(s["heart"])
					s["heart"] = maxi(0, before - dmg)
					u["alive"] = false
					u["removed"] = true
					_ev(s, ev, "heart_damaged", {"actor_id": uid, "amount": dmg, "before": before, "after": s["heart"]})
			else:
				u["floor"] = f + 1
				new_lists[f + 1].append(uid)
				_ev(s, ev, "enemy_climbed", {"actor_id": uid, "from_floor": f, "to_floor": f + 1,
					"position": new_lists[f + 1].size() - 1})
	for f in FLOORS:
		s["floors"][f]["enemies"] = new_lists[f]


## Defeat is settled before victory (bible p.7, p.14).
static func _check_terminal(s: Dictionary, ev: Array) -> void:
	if s["terminal_result"] != "":
		return
	if int(s["heart"]) <= 0 or s.get("boss_escaped", false):
		s["terminal_result"] = "lost"
		s["phase"] = "lost"
		_ev(s, ev, "battle_lost", {"heart": s["heart"], "boss_escaped": s.get("boss_escaped", false)})
	elif waves_remaining(s) <= 0 and all_enemies(s).is_empty():
		s["terminal_result"] = "won"
		s["phase"] = "won"
		_ev(s, ev, "battle_won", {"heart": s["heart"]})


# ---------------------------------------------------------------- turn start

## BEGIN_TURN + DRAW_AND_WAVE (bible p.7 steps 1-2).
static func begin_turn(s: Dictionary, ev: Array) -> void:
	s["turn"] = int(s["turn"]) + 1
	s["phase"] = "player"
	s["flags"] = {"r02": false, "r03": false, "r08": false}
	for uid: int in all_allies(s):
		unit(s, uid)["moved_this_turn"] = false
	var energy: int = int(Catalog.rules()["base_energy"])
	if int(s["turn"]) == 1 and has_relic(s, "R04"):
		energy += 1
	s["energy"] = energy
	_ev(s, ev, "turn_begin", {"energy": energy})
	var boss_id: int = int(s.get("boss_unit_id", -1))
	if boss_id >= 0 and unit(s, boss_id)["alive"] and int(s["turn"]) >= int(Catalog.boss()["escalate_from_turn"]):
		var b: Dictionary = unit(s, boss_id)
		b["attack"] = int(b["attack"]) + int(Catalog.boss()["attack_per_escalation"])
		_ev(s, ev, "boss_escalated", {"actor_id": boss_id, "attack": b["attack"]})
	# Turn-start healing in stable unit-id order.
	var allies: Array = all_allies(s)
	allies.sort()
	if has_mutation(s, "M03"):
		for uid: int in allies:
			if int(unit(s, uid)["floor"]) == 2:
				heal(s, ev, uid, 2, -1, "M03")
	if s["champion_path"] == "LIFEWEAVER" and int(s["champion_rank"]) > 0:
		var champ: Dictionary = _champion_unit(s)
		if not champ.is_empty() and champ["alive"]:
			for uid: int in allies:
				if int(unit(s, uid)["floor"]) == int(champ["floor"]):
					heal(s, ev, uid, int(s["champion_rank"]), int(champ["unit_id"]), "LIFEWEAVER")
	var n: int = int(Catalog.rules()["draw_per_turn"])
	if int(s["turn"]) == 1 and has_relic(s, "R06"):
		n += 1
	draw_cards(s, ev, n)
	for i in range(int(s["wave_index"]), (s["waves"] as Array).size()):
		var w: Dictionary = s["waves"][i]
		if int(w["turn"]) != int(s["turn"]):
			break
		_ev(s, ev, "wave_arrived", {"wave": i + 1, "of": (s["waves"] as Array).size()})
		for eid: String in w["enemies"]:
			spawn_enemy(s, ev, eid)
		s["wave_index"] = i + 1


static func _champion_unit(s: Dictionary) -> Dictionary:
	for uid: int in all_allies(s):
		var u: Dictionary = unit(s, uid)
		if u["is_champion"]:
			return u
	return {}


## Draws normal cards; an empty draw pile reshuffles the discard pile with the
## battle's saved shuffle stream. Deployed and consumed cards never return.
static func draw_cards(s: Dictionary, ev: Array, n: int) -> void:
	var z: Dictionary = s["zones"]
	for i in n:
		if (z["draw"] as Array).is_empty():
			if (z["discard"] as Array).is_empty():
				return
			z["draw"] = z["discard"]
			z["discard"] = []
			RngStream.shuffle(s["rng"], z["draw"])
			_ev(s, ev, "deck_shuffled", {"count": (z["draw"] as Array).size()})
		var iid: int = (z["draw"] as Array).pop_front()
		(z["hand"] as Array).append(iid)
		_ev(s, ev, "card_drawn", {"card": iid})


# ------------------------------------------------------------ player actions

static func _play_card(s: Dictionary, cmd: Dictionary, ev: Array) -> String:
	if s["phase"] != "player":
		return "The battle is not waiting for you."
	var iid: int = int(cmd.get("card", -1))
	if not (s["zones"]["hand"] as Array).has(iid):
		return "That card is not in your hand."
	var def: Dictionary = card_def(s, iid)
	var upg: String = card_upgrade(s, iid)
	var cost: int = play_cost(s, iid)
	if cost > int(s["energy"]):
		return "Not enough Sap (needs %d)." % cost
	if Catalog.is_creature(def):
		return _play_creature(s, cmd, ev, iid, def, upg, cost)
	return _play_spell(s, cmd, ev, iid, def, upg, cost)


static func _play_creature(s: Dictionary, cmd: Dictionary, ev: Array, iid: int, def: Dictionary, upg: String, cost: int) -> String:
	var f: int = int(cmd.get("floor", -1))
	if f < 0 or f >= FLOORS:
		return "Choose a floor."
	var stats: Dictionary = CardStats.unit_stats(def, upg, str(s["champion_path"]), int(s["champion_rank"]))
	var space: int = int(stats["space"])
	if used_space(s, f) + space > capacity(s, f):
		return "No space on the %s (%d/%d, needs %d)." % [Catalog.floor_name(f), used_space(s, f), capacity(s, f), space]
	var allies: Array = floor_list(s, f, "ally")
	var pos: int = clampi(int(cmd.get("position", allies.size())), 0, allies.size())
	var heal_target: int = -1
	var on_play: Dictionary = def.get("on_play", {})
	if on_play.get("op", "") == "heal_other_ally":
		var others: Array = all_allies(s)
		if not others.is_empty():
			heal_target = int(cmd.get("target", -1))
			if not others.has(heal_target):
				return "Choose another ally to heal."
	# Commit.
	s["energy"] = int(s["energy"]) - cost
	(s["zones"]["hand"] as Array).erase(iid)
	(s["zones"]["deployed"] as Array).append(iid)
	_ev(s, ev, "card_played", {"card": iid, "def_id": def["id"], "cost": cost})
	stats["is_champion"] = def["kind"] == "champion"
	var uid: int = new_unit(s, "ally", def["id"], iid, f, stats)
	allies.insert(pos, uid)
	_ev(s, ev, "unit_inserted", {"target_id": uid, "def_id": def["id"], "card": iid, "floor": f,
		"position": pos, "after": _snap(unit(s, uid))})
	if has_relic(s, "R01") and def["faction"] == "BARK":
		add_armor(s, ev, uid, 3, -1, "R01")
	if has_relic(s, "R07") and def["kind"] == "unit":
		var u: Dictionary = unit(s, uid)
		u["max_hp"] = int(u["max_hp"]) + 3
		u["hp"] = int(u["hp"]) + 3
		_ev(s, ev, "max_hp_gained", {"target_id": uid, "amount": 3, "reason": "R07", "after": _snap(u)})
	match on_play.get("op", ""):
		"heal_other_ally":
			if heal_target >= 0:
				heal(s, ev, heal_target, int(on_play["amount"]), uid, def["id"])
		"growth_floor_others":
			for other: int in floor_list(s, f, "ally"):
				if other != uid:
					var o: Dictionary = unit(s, other)
					var before := _snap(o)
					o["growth"] = int(o["growth"]) + int(on_play["amount"])
					_ev(s, ev, "growth_gained", {"actor_id": uid, "target_id": other, "amount": on_play["amount"],
						"before": before, "after": _snap(o)})
	drain_deaths(s, ev)
	_check_terminal(s, ev)
	return ""


## Targets a spell may legally choose, as unit ids or floor indices.
static func spell_targets(s: Dictionary, def: Dictionary) -> Dictionary:
	var sp: Dictionary = def.get("spell", {})
	var units: Array = []
	var floors: Array = []
	match str(sp.get("target", "")):
		"enemy":
			units = all_enemies(s)
		"enemy_poisoned":
			for uid: int in all_enemies(s):
				if int(unit(s, uid)["poison"]) > 0:
					units.append(uid)
		"ally":
			units = all_allies(s)
			if sp.get("op", "") == "lift":
				var ok: Array = []
				for uid: int in units:
					var u: Dictionary = unit(s, uid)
					var f: int = int(u["floor"])
					if f < FLOORS - 1 and used_space(s, f + 1) + int(u["space"]) <= capacity(s, f + 1):
						ok.append(uid)
				units = ok
		"ally_normal":
			for uid: int in all_allies(s):
				if not unit(s, uid)["is_champion"]:
					units.append(uid)
		"enemy_floor":
			for f in FLOORS:
				if not floor_list(s, f, "enemy").is_empty():
					floors.append(f)
		"ally_floor":
			for f in FLOORS:
				if not floor_list(s, f, "ally").is_empty():
					floors.append(f)
		"all_enemies":
			if not all_enemies(s).is_empty():
				floors = [0, 1, 2]
	return {"units": units, "floors": floors}


static func _play_spell(s: Dictionary, cmd: Dictionary, ev: Array, iid: int, def: Dictionary, upg: String, cost: int) -> String:
	var sp: Dictionary = def["spell"]
	var op: String = sp["op"]
	var tgt_type: String = sp["target"]
	var legal: Dictionary = spell_targets(s, def)
	var target: int = int(cmd.get("target", -1))
	var f: int = int(cmd.get("floor", -1))
	match tgt_type:
		"enemy", "enemy_poisoned", "ally", "ally_normal":
			if not (legal["units"] as Array).has(target):
				return _target_reason(s, tgt_type, op)
		"enemy_floor", "ally_floor":
			if not (legal["floors"] as Array).has(f):
				return "Choose a floor with %s." % ("an enemy" if tgt_type == "enemy_floor" else "an ally")
		"all_enemies":
			if (legal["floors"] as Array).is_empty():
				return "There are no enemies to affect."
	# Commit.
	s["energy"] = int(s["energy"]) - cost
	if has_relic(s, "R02") and not s["flags"]["r02"]:
		s["flags"]["r02"] = true
	(s["zones"]["hand"] as Array).erase(iid)
	if def.get("consume", false):
		(s["zones"]["consumed"] as Array).append(iid)
	else:
		(s["zones"]["discard"] as Array).append(iid)
	_ev(s, ev, "card_played", {"card": iid, "def_id": def["id"], "cost": cost, "target_id": target, "floor": f})
	var amt := func(k: String) -> int: return CardStats.spell_amount(def, upg, k)
	match op:
		"damage":
			var ids: Array = [target] if tgt_type == "enemy" else floor_list(s, f, "enemy").duplicate()
			for uid: int in ids:
				damage(s, ev, uid, amt.call("damage"), -1)
		"armor":
			add_armor(s, ev, target, amt.call("armor"), -1, def["id"])
		"lift":
			var u: Dictionary = unit(s, target)
			var from_f: int = int(u["floor"])
			floor_list(s, from_f, "ally").erase(target)
			floor_list(s, from_f + 1, "ally").append(target)
			u["floor"] = from_f + 1
			_ev(s, ev, "unit_lifted", {"target_id": target, "from_floor": from_f, "to_floor": from_f + 1,
				"position": floor_list(s, from_f + 1, "ally").size() - 1})
		"heal":
			for uid: int in floor_list(s, f, "ally").duplicate():
				heal(s, ev, uid, amt.call("heal"), -1, def["id"])
		"remove_draw":
			var u: Dictionary = unit(s, target)
			u["alive"] = false
			u["removed"] = true
			floor_list(s, int(u["floor"]), "ally").erase(target)
			_ev(s, ev, "unit_removed", {"target_id": target, "def_id": u["def_id"], "floor": u["floor"]})
			draw_cards(s, ev, amt.call("draw"))
		"poison":
			var ids: Array
			if tgt_type == "enemy":
				ids = [target]
			elif tgt_type == "enemy_floor":
				ids = floor_list(s, f, "enemy").duplicate()
			else:
				ids = all_enemies(s)
			apply_poison(s, ev, ids, amt.call("poison"), true, -1)
		"heal_growth":
			heal(s, ev, target, amt.call("heal"), -1, def["id"])
			var u: Dictionary = unit(s, target)
			var before := _snap(u)
			u["growth"] = int(u["growth"]) + amt.call("growth")
			_ev(s, ev, "growth_gained", {"actor_id": -1, "target_id": target, "amount": amt.call("growth"),
				"before": before, "after": _snap(u)})
		"strip_damage":
			var u: Dictionary = unit(s, target)
			var before := _snap(u)
			var stripped: int = mini(int(u["armor"]), int(sp["strip"]))
			u["armor"] = int(u["armor"]) - stripped
			_ev(s, ev, "armor_stripped", {"actor_id": -1, "target_id": target, "amount": stripped,
				"before": before, "after": _snap(u)})
			damage(s, ev, target, amt.call("damage"), -1)
		"bloom":
			var u: Dictionary = unit(s, target)
			var before := _snap(u)
			var cur: int = int(u["poison"])
			u["poison"] = maxi(cur, mini(int(sp["cap"]), 2 * cur))
			_ev(s, ev, "poison_bloomed", {"actor_id": -1, "target_id": target, "before": before, "after": _snap(u)})
	drain_deaths(s, ev)
	_check_terminal(s, ev)
	return ""


static func _target_reason(s: Dictionary, tgt_type: String, op: String) -> String:
	match tgt_type:
		"enemy":
			return "Choose an enemy." if not all_enemies(s).is_empty() else "There are no enemies."
		"enemy_poisoned":
			return "Choose a poisoned enemy."
		"ally_normal":
			return "Choose one of your normal creatures (not the champion)."
		"ally":
			if op == "lift":
				return "Choose an ally below the Crown with space on the floor above."
			return "Choose an ally."
	return "Invalid target."


static func _move(s: Dictionary, cmd: Dictionary, ev: Array) -> String:
	if s["phase"] != "player":
		return "The battle is not waiting for you."
	var uid: int = int(cmd.get("unit", -1))
	var u: Dictionary = unit(s, uid)
	if u.is_empty() or not u["alive"] or u["side"] != "ally":
		return "Choose one of your creatures."
	if u["moved_this_turn"]:
		return "It has already moved this turn."
	var from_f: int = int(u["floor"])
	var to_f: int = int(cmd.get("floor", from_f))
	if to_f < 0 or to_f >= FLOORS or absi(to_f - from_f) > 1:
		return "Creatures move one floor at a time."
	var from_list: Array = floor_list(s, from_f, "ally")
	var from_pos: int = from_list.find(uid)
	if to_f == from_f:
		var p: int = clampi(int(cmd.get("position", from_pos)), 0, from_list.size() - 1)
		if p == from_pos:
			return "Choose a different position."
	elif used_space(s, to_f) + int(u["space"]) > capacity(s, to_f):
		return "No space on the %s (%d/%d, needs %d)." % [Catalog.floor_name(to_f), used_space(s, to_f), capacity(s, to_f), u["space"]]
	var cost: int = move_cost(s)
	if cost > int(s["energy"]):
		return "Not enough Sap (needs %d)." % cost
	# Commit as one transaction: space, Sap, position, moved_this_turn.
	s["energy"] = int(s["energy"]) - cost
	if cost == 0:
		s["flags"]["r08"] = true
	from_list.erase(uid)
	var to_list: Array = floor_list(s, to_f, "ally")
	var pos: int = clampi(int(cmd.get("position", to_list.size())), 0, to_list.size())
	to_list.insert(pos, uid)
	u["floor"] = to_f
	u["moved_this_turn"] = true
	_ev(s, ev, "unit_moved", {"target_id": uid, "from_floor": from_f, "to_floor": to_f,
		"from_position": from_pos, "position": pos, "cost": cost})
	return ""
