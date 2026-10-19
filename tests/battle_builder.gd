class_name BattleBuilder
extends RefCounted
## Test fixtures: a real battle from a real run, then cleared so a test can
## place exactly the units it needs. Everything goes through the same reducer.


static func run(seed_value: int = 1234, faction: String = "BARK") -> Dictionary:
	return RunReducer.new_run(seed_value, faction)


## Empty battle in the player phase of turn 1 with no waves left.
static func empty(seed_value: int = 1234, faction: String = "BARK") -> Dictionary:
	var s: Dictionary = BattleFactory.create(run(seed_value, faction), 0)["state"]
	for f in 3:
		s["floors"][f] = {"allies": [], "enemies": []}
	s["units"] = {}
	s["waves"] = []
	s["wave_index"] = 0
	return s


static func ally(s: Dictionary, f: int, stats: Dictionary, def_id: String = "B02") -> int:
	var st := {"attack": 1, "max_hp": 10, "armor": 0, "space": 1}
	st.merge(stats, true)
	var uid: int = BattleReducer.new_unit(s, "ally", def_id, -1, f, st)
	if stats.has("hp"):
		BattleReducer.unit(s, uid)["hp"] = stats["hp"]
	BattleReducer.floor_list(s, f, "ally").append(uid)
	return uid


static func enemy(s: Dictionary, f: int, stats: Dictionary, def_id: String = "E01") -> int:
	var st := {"attack": 1, "max_hp": 10, "armor": 0}
	st.merge(stats, true)
	var uid: int = BattleReducer.new_unit(s, "enemy", def_id, -1, f, st)
	var u: Dictionary = BattleReducer.unit(s, uid)
	for k in ["hp", "poison", "thorns"]:
		if stats.has(k):
			u[k] = stats[k]
	if stats.get("is_boss", false):
		s["boss_unit_id"] = uid
	BattleReducer.floor_list(s, f, "enemy").append(uid)
	return uid


## Puts a card of def_id into hand as a new deck instance and returns its iid.
static func give_card(s: Dictionary, def_id: String, upgrade_id: String = "") -> int:
	var iid: int = 900 + (s["deck"] as Dictionary).size()
	s["deck"][str(iid)] = {"def_id": def_id, "upgrade_id": upgrade_id}
	(s["zones"]["hand"] as Array).append(iid)
	return iid


static func kinds(events: Array, kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in events:
		if e["kind"] == kind:
			out.append(e)
	return out


static func resolve(s: Dictionary) -> Array:
	var ev: Array = []
	BattleReducer.resolve_end_turn(s, ev)
	return ev
