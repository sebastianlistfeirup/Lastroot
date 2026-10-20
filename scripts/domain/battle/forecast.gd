class_name Forecast
extends RefCounted
## The forecast is the real reducer on a full clone (bible p.17): same
## resolve_end_turn, same RNG and counters. The original state is never
## touched. Results are cached on canonical_state_hash + preview_command.

static var _cache: Dictionary = {}
const CACHE_MAX := 64


## Outcome of ending the turn from `state` as it is now.
static func end_turn(state: Dictionary) -> Dictionary:
	var key: String = JsonUtil.state_hash(state)
	if _cache.has(key):
		return (_cache[key] as Dictionary).duplicate(true)  # callers may not mutate the cache
	var clone: Dictionary = state.duplicate(true)
	var ev: Array = []
	if clone["phase"] == "player":
		BattleReducer.resolve_end_turn(clone, ev)
	var out := {"ok": true, "state": clone, "events": ev, "hash": JsonUtil.state_hash(clone),
		"summary": summarize(state, clone, ev), "error": ""}
	if _cache.size() >= CACHE_MAX:
		_cache.clear()
	_cache[key] = out
	return out


## Outcome of playing `cmd` and then ending the turn (target preview). Uses no
## Sap, flags or RNG of the original.
static func after_command(state: Dictionary, cmd: Dictionary) -> Dictionary:
	var r: Dictionary = BattleReducer.apply(state, cmd)
	if not r["ok"]:
		return {"ok": false, "error": r["error"], "summary": {}, "events": []}
	if r["state"]["phase"] != "player":
		return {"ok": true, "state": r["state"], "events": r["events"], "error": "",
			"summary": summarize(state, r["state"], r["events"])}
	var f: Dictionary = end_turn(r["state"])
	var all_ev: Array = (r["events"] as Array).duplicate()
	all_ev.append_array(f["events"])
	return {"ok": true, "state": f["state"], "events": all_ev, "error": "",
		"summary": summarize(state, f["state"], all_ev)}


static func clear_cache() -> void:
	_cache.clear()


## What the HUD shows: per unit before/after, deaths, enemy next floor,
## heart damage, boss risk and the terminal result.
static func summarize(before: Dictionary, after: Dictionary, events: Array) -> Dictionary:
	var units: Dictionary = {}
	for key: String in before["units"].keys():
		var b: Dictionary = before["units"][key]
		if not b["alive"]:
			continue
		var a: Dictionary = after["units"].get(key, b)
		units[key] = {
			"hp": [b["hp"], a["hp"]], "armor": [b["armor"], a["armor"]], "poison": [b["poison"], a["poison"]],
			"floor": [b["floor"], a["floor"]], "dies": not a["alive"] and not a.get("removed", false),
			"escapes": a.get("removed", false) and b["side"] == "enemy",
		}
	var heart_damage := 0
	var risky_boss := false
	for e: Dictionary in events:
		if e["kind"] == "heart_damaged":
			heart_damage += int(e["amount"])
		elif e["kind"] == "boss_escaped":
			risky_boss = true
	var boss_on_crown := false
	var bid: int = int(before.get("boss_unit_id", -1))
	if bid >= 0:
		var bu: Dictionary = before["units"][str(bid)]
		boss_on_crown = bu["alive"] and int(bu["floor"]) == 2
	return {"units": units, "heart_damage": heart_damage, "heart_after": after["heart"],
		"result": after["terminal_result"], "boss_escapes": risky_boss, "boss_on_crown": boss_on_crown}
