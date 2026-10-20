class_name SaveCodec
extends RefCounted
## SaveEnvelope (bible p.20): game_id, build_id, schema_version, checksum,
## timestamp, run (with battle and pending reward inside) and the
## presentation checkpoint. Pure: no file access (SaveService does I/O).
##
## Envelope schema history (LR-29, fixtures/legacy/README.md):
##   1  first build (29da5a2). The run lacks `mode`, `history`,
##      `claimed_choices` and `heart_at_battle_start` (added later; the
##      reducer tolerated their absence, the UI/playtest log did not show them).
##   2  same envelope; the run always carries `mode`, `history` and
##      `heart_at_battle_start` (`claimed_choices` appears with the first claim).
## decode() verifies the checksum over the payload *as stored*, then migrates
## step by step to SCHEMA_VERSION and validates every stable ID and type
## against the catalog before the run is handed to the reducer.

const GAME_ID := "LASTROOT"
const SCHEMA_VERSION := 2
const MIN_SCHEMA_VERSION := 1
const BUILD_ID := "lastroot-0.1.0"
const PHASES: PackedStringArray = ["battle", "reward", "route", "node", "won", "lost"]
const SLOT_STATUS: PackedStringArray = ["offered", "claimed", "skipped"]
const ROUTE_STATUS: PackedStringArray = ["locked", "open", "chosen"]
const NODE_TYPES: PackedStringArray = ["camp", "card", "encounter", "removal"]


static func make_envelope(run: Dictionary, presentation: Dictionary = {}) -> Dictionary:
	var payload := {"run": run, "presentation_checkpoint": presentation}
	return {
		"game_id": GAME_ID, "build_id": BUILD_ID, "schema_version": SCHEMA_VERSION,
		"content_version": run.get("content_version", ""),
		"timestamp": Time.get_datetime_string_from_system(true),
		"checksum": JsonUtil.canonical(payload).sha256_text(),
		"payload": payload,
	}


static func encode(run: Dictionary, presentation: Dictionary = {}) -> String:
	return JSON.stringify(make_envelope(run, presentation), "", true)


## {ok, error, code, run, presentation, migrated_from, problems}.
## code: ok | not_lastroot | future_version | corrupt | invalid | unreadable.
## Never repairs silently: a migration is a documented, versioned step; any
## unknown ID or wrong type is refused (problems lists why).
static func decode(text: String) -> Dictionary:
	var env: Variant = JsonUtil.parse(text)
	if typeof(env) != TYPE_DICTIONARY:
		return _fail("unreadable", "The save file cannot be read.")
	var e: Dictionary = env
	if e.get("game_id", "") != GAME_ID:
		return _fail("not_lastroot", "This is not a LASTROOT save.")
	var raw_ver: Variant = e.get("schema_version", -1)
	if typeof(raw_ver) != TYPE_INT:
		return _fail("corrupt", "The save is damaged.")
	var ver: int = raw_ver
	if ver > SCHEMA_VERSION:
		return _fail("future_version", "This save comes from a newer version of the game (schema %d)." % ver)
	if ver < MIN_SCHEMA_VERSION or typeof(e.get("payload")) != TYPE_DICTIONARY:
		return _fail("corrupt", "The save is damaged.")
	var payload: Dictionary = e["payload"]
	if JsonUtil.canonical(payload).sha256_text() != str(e.get("checksum", "")):
		return _fail("corrupt", "The save is damaged (checksum mismatch).")
	var run_v: Variant = payload.get("run")
	if typeof(run_v) != TYPE_DICTIONARY or not (run_v as Dictionary).has("deck"):
		return _fail("corrupt", "The save has no run.")
	var run: Dictionary = (run_v as Dictionary).duplicate(true)
	var from_ver: int = ver
	while ver < SCHEMA_VERSION:
		match ver:
			1:
				migrate_1_to_2(run)
		ver += 1
	var problems: PackedStringArray = validate_run(run)
	if not problems.is_empty():
		var f := _fail("invalid", "The save contains unknown or invalid data.")
		f["problems"] = problems
		return f
	var pres: Variant = payload.get("presentation_checkpoint", {})
	if typeof(pres) != TYPE_DICTIONARY:
		pres = {}
	return {"ok": true, "error": "", "code": "ok", "run": run, "presentation": pres,
		"envelope": e, "migrated_from": from_ver if from_ver != SCHEMA_VERSION else 0}


## v1 -> v2: adds the run fields later builds write. Reconstructs what the
## save itself still knows (offer/pick of the visible reward and node slots);
## earlier battles' history rows did not exist in v1 and stay absent.
static func migrate_1_to_2(run: Dictionary) -> void:
	if not run.has("mode"):
		run["mode"] = "full"
	if not run.has("history"):
		run["history"] = []
	if not run.has("heart_at_battle_start"):
		run["heart_at_battle_start"] = run.get("heart", 0)
	if not run.has("claimed_choices"):
		var cc: Dictionary = {}
		var slots: Array = []
		if typeof(run.get("reward")) == TYPE_DICTIONARY:
			slots.append_array((run["reward"] as Dictionary).get("slots", []))
		if typeof(run.get("node")) == TYPE_DICTIONARY:
			slots.append_array((run["node"] as Dictionary).get("slots", []))
		for s: Variant in slots:
			if typeof(s) != TYPE_DICTIONARY:
				continue
			var slot: Dictionary = s
			if slot.has("offer") and str(slot.get("status", "")) != "offered":
				cc[str(slot.get("id", ""))] = {"type": slot.get("type", ""),
					"offer": (slot["offer"] as Array).duplicate() if typeof(slot["offer"]) == TYPE_ARRAY else [],
					"choice": str(slot.get("choice", ""))}
		run["claimed_choices"] = cc


# -------------------------------------------------------------- validation

## Structural + content check of a (migrated) run. Empty = safe to hand to the
## reducers. Checks every stable ID against the catalog and every field the
## reducers index directly, so a hand-edited or imported JSON with a valid
## checksum but unknown cards/units/relics is refused instead of crashing.
static func validate_run(run: Dictionary) -> PackedStringArray:
	var p: PackedStringArray = []
	var types := {
		"run_id": TYPE_STRING, "main_faction": TYPE_STRING, "champion_id": TYPE_STRING,
		"champion_path": TYPE_STRING, "phase": TYPE_STRING, "result": TYPE_STRING, "mode": TYPE_STRING,
		"deck": TYPE_ARRAY, "relics": TYPE_ARRAY, "mutations": TYPE_ARRAY, "route": TYPE_ARRAY,
		"history": TYPE_ARRAY, "battle": TYPE_DICTIONARY, "reward": TYPE_DICTIONARY,
		"node": TYPE_DICTIONARY, "reward_claims": TYPE_DICTIONARY, "rng": TYPE_DICTIONARY,
		"stats": TYPE_DICTIONARY,
		"seed": TYPE_INT, "next_instance_id": TYPE_INT, "next_unit_id": TYPE_INT,
		"champion_rank": TYPE_INT, "resin": TYPE_INT, "heart": TYPE_INT, "heart_max": TYPE_INT,
		"battle_index": TYPE_INT, "heart_at_battle_start": TYPE_INT,
	}
	for k: String in types:
		if not run.has(k):
			p.append("missing key %s" % k)
		elif typeof(run[k]) != types[k]:
			p.append("%s has wrong type" % k)
	if run.has("claimed_choices") and typeof(run["claimed_choices"]) != TYPE_DICTIONARY:
		p.append("claimed_choices has wrong type")  # created lazily by the first claim
	if not p.is_empty():
		return p
	if not (Catalog.FACTIONS as PackedStringArray).has(run["main_faction"]):
		p.append("unknown faction %s" % run["main_faction"])
	elif run["champion_id"] != Catalog.champion_for(run["main_faction"]):
		p.append("champion %s does not match faction" % run["champion_id"])
	if run["champion_path"] != "" and Catalog.champion_path(run["champion_id"], run["champion_path"]).is_empty():
		p.append("unknown champion path %s" % run["champion_path"])
	if not PHASES.has(run["phase"]):
		p.append("unknown phase %s" % run["phase"])
	if run["champion_rank"] < 0 or run["champion_rank"] > 2:
		p.append("champion rank out of range")
	if run["resin"] < 0 or run["heart_max"] <= 0 or run["heart"] < 0 or run["heart"] > run["heart_max"]:
		p.append("resin/heart out of range")
	var n_battles: int = (Catalog.data()["normal_battles"] as Array).size() + 1
	if run["battle_index"] < 0 or run["battle_index"] >= n_battles:
		p.append("battle index out of range")
	for k: String in ["shuffle", "route", "reward"]:
		if not _is_rng(run["rng"].get(k)):
			p.append("rng stream %s invalid" % k)
	for k: String in ["turns", "cards_played", "heart_lost", "battles_won"]:
		if typeof(run["stats"].get(k)) != TYPE_INT:
			p.append("stats.%s invalid" % k)
	var seen := {}
	for d: Variant in run["deck"]:
		if typeof(d) != TYPE_DICTIONARY or typeof(d.get("instance_id")) != TYPE_INT \
				or typeof(d.get("def_id")) != TYPE_STRING or typeof(d.get("upgrade_id")) != TYPE_STRING:
			p.append("deck entry malformed")
			continue
		var iid: int = d["instance_id"]
		if seen.has(iid) or iid <= 0 or iid >= run["next_instance_id"]:
			p.append("deck instance id %d invalid" % iid)
		seen[iid] = true
		p.append_array(_check_card(d["def_id"], d["upgrade_id"]))
	if seen.is_empty():
		p.append("deck is empty")
	_check_ids(p, run["relics"], "relic", true)
	_check_ids(p, run["mutations"], "mutation", true)
	for r: Variant in run["route"]:
		if typeof(r) != TYPE_DICTIONARY or typeof(r.get("id")) != TYPE_STRING \
				or not ROUTE_STATUS.has(str(r.get("status", ""))) or typeof(r.get("options")) != TYPE_ARRAY \
				or typeof(r.get("after_battle")) != TYPE_INT:
			p.append("route entry malformed")
			continue
		for o: Variant in r["options"]:
			if typeof(o) != TYPE_DICTIONARY or typeof(o.get("id")) != TYPE_STRING or not NODE_TYPES.has(str(o.get("type", ""))):
				p.append("route option malformed in %s" % r["id"])
	match run["phase"]:
		"battle":
			if run["battle"].is_empty():
				p.append("battle phase without battle")
			else:
				p.append_array(_validate_battle(run["battle"]))
		"reward":
			if typeof(run["reward"].get("slots")) != TYPE_ARRAY or typeof(run["reward"].get("battle_number")) != TYPE_INT:
				p.append("reward phase without slots")
			else:
				p.append_array(_validate_slots(run["reward"]["slots"], run))
		"node":
			var nd: Dictionary = run["node"]
			if not NODE_TYPES.has(str(nd.get("type", ""))) or typeof(nd.get("id")) != TYPE_STRING \
					or not (["open", "used"] as Array).has(nd.get("status", "")) or typeof(nd.get("slots", [])) != TYPE_ARRAY:
				p.append("node malformed")
			else:
				p.append_array(_validate_slots(nd.get("slots", []), run))
	return p


static func _is_rng(v: Variant) -> bool:
	return typeof(v) == TYPE_DICTIONARY and typeof(v.get("seed")) == TYPE_INT and typeof(v.get("state")) == TYPE_INT


static func _check_card(def_id: String, upgrade_id: String) -> PackedStringArray:
	var def: Dictionary = Catalog.card(def_id)
	if def.is_empty():
		return ["unknown card %s" % def_id]
	if upgrade_id != "":
		for u: Dictionary in def.get("upgrades", []):
			if u["id"] == upgrade_id:
				return []
		return ["unknown upgrade %s on %s" % [upgrade_id, def_id]]
	return []


static func _check_ids(p: PackedStringArray, ids: Array, kind: String, unique: bool) -> void:
	var seen := {}
	for v: Variant in ids:
		if typeof(v) != TYPE_STRING:
			p.append("%s id has wrong type" % kind)
			continue
		var id: String = v
		var def: Dictionary = Catalog.relic(id) if kind == "relic" else Catalog.mutation(id)
		if def.is_empty():
			p.append("unknown %s %s" % [kind, id])
		if unique and seen.has(id):
			p.append("duplicate %s %s" % [kind, id])
		seen[id] = true


static func _validate_slots(slots: Array, run: Dictionary) -> PackedStringArray:
	var p: PackedStringArray = []
	for s: Variant in slots:
		if typeof(s) != TYPE_DICTIONARY or typeof(s.get("id")) != TYPE_STRING \
				or not SLOT_STATUS.has(str(s.get("status", ""))) or typeof(s.get("type")) != TYPE_STRING:
			p.append("reward slot malformed")
			continue
		var slot: Dictionary = s
		if not slot.has("offer"):
			continue  # resin / heart_heal summaries
		if typeof(slot["offer"]) != TYPE_ARRAY:
			p.append("slot %s offer malformed" % slot["id"])
			continue
		for o: Variant in slot["offer"]:
			if typeof(o) != TYPE_STRING:
				p.append("slot %s offer malformed" % slot["id"])
				continue
			var ok: bool
			match slot["type"]:
				"card":
					ok = not Catalog.card(o).is_empty()
				"relic":
					ok = not Catalog.relic(o).is_empty()
				"mutation":
					ok = not Catalog.mutation(o).is_empty()
				"champion":
					ok = not Catalog.champion_path(run["champion_id"], o).is_empty()
				_:
					ok = false
			if not ok:
				p.append("slot %s offers unknown %s" % [slot["id"], o])
	return p


static func _validate_battle(b: Dictionary) -> PackedStringArray:
	var p: PackedStringArray = []
	for k: String in ["units", "deck", "zones", "rng", "flags"]:
		if typeof(b.get(k)) != TYPE_DICTIONARY:
			p.append("battle.%s invalid" % k)
	for k: String in ["floors", "waves", "relics", "mutations"]:
		if typeof(b.get(k)) != TYPE_ARRAY:
			p.append("battle.%s invalid" % k)
	for k: String in ["turn", "energy", "heart", "heart_max", "next_unit_id", "wave_index", "resolution_id", "battle_index"]:
		if typeof(b.get(k)) != TYPE_INT:
			p.append("battle.%s invalid" % k)
	if typeof(b.get("phase")) != TYPE_STRING or typeof(b.get("terminal_result")) != TYPE_STRING:
		p.append("battle phase invalid")
	if not p.is_empty():
		return p
	if not _is_rng(b["rng"]):
		p.append("battle rng invalid")
	for key: Variant in b["deck"]:
		var d: Variant = b["deck"][key]
		if typeof(d) != TYPE_DICTIONARY or typeof(d.get("def_id")) != TYPE_STRING or typeof(d.get("upgrade_id")) != TYPE_STRING:
			p.append("battle deck entry malformed")
			continue
		p.append_array(_check_card(d["def_id"], d["upgrade_id"]))
	for zone: String in ["hand", "draw", "discard", "consumed", "deployed"]:
		var z: Variant = b["zones"].get(zone)
		if typeof(z) != TYPE_ARRAY:
			p.append("zone %s missing" % zone)
			continue
		for iid: Variant in z:
			if typeof(iid) != TYPE_INT or not b["deck"].has(str(iid)):
				p.append("zone %s holds unknown card %s" % [zone, str(iid)])
	for key: Variant in b["units"]:
		var u: Variant = b["units"][key]
		if typeof(u) != TYPE_DICTIONARY or typeof(u.get("def_id")) != TYPE_STRING or typeof(u.get("unit_id")) != TYPE_INT:
			p.append("unit %s malformed" % str(key))
			continue
		var side: String = str(u.get("side", ""))
		var def: Dictionary = Catalog.enemy(u["def_id"]) if side == "enemy" else Catalog.card(u["def_id"])
		if def.is_empty() or not (["ally", "enemy"] as Array).has(side):
			p.append("unknown unit %s (%s)" % [u["def_id"], side])
		for f: String in ["hp", "max_hp", "attack", "armor", "poison", "thorns", "growth", "floor"]:
			if typeof(u.get(f)) != TYPE_INT:
				p.append("unit %s.%s invalid" % [str(key), f])
	if (b["floors"] as Array).size() != 3:
		p.append("battle needs three floors")
	for fl: Variant in b["floors"]:
		if typeof(fl) != TYPE_DICTIONARY or typeof(fl.get("allies")) != TYPE_ARRAY or typeof(fl.get("enemies")) != TYPE_ARRAY:
			p.append("floor malformed")
			continue
		for uid: Variant in (fl["allies"] as Array) + (fl["enemies"] as Array):
			if typeof(uid) != TYPE_INT or not b["units"].has(str(uid)):
				p.append("floor references unknown unit %s" % str(uid))
	for w: Variant in b["waves"]:
		if typeof(w) != TYPE_DICTIONARY or typeof(w.get("enemies")) != TYPE_ARRAY:
			p.append("wave malformed")
			continue
		for eid: Variant in w["enemies"]:
			if typeof(eid) != TYPE_STRING or Catalog.enemy(eid).is_empty():
				p.append("wave has unknown enemy %s" % str(eid))
	_check_ids(p, b["relics"], "relic", true)
	_check_ids(p, b["mutations"], "mutation", true)
	return p


static func _fail(code: String, msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "code": code, "run": {}, "presentation": {}}
