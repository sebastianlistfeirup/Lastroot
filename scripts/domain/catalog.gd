class_name Catalog
extends RefCounted
## Immutable content definitions (CardDef, EnemyDef, relics, mutations, battles).
## Loaded once from data/definitions/catalog.json and validated; the domain
## never writes to these dictionaries (bible p.9: "CardDef er uforanderlig").

const PATH := "res://data/definitions/catalog.json"
const KINDS: PackedStringArray = ["unit", "champion", "spell"]
const FACTIONS: PackedStringArray = ["BARK", "SPORE"]
const SPELL_OPS := {
	"damage": ["enemy", "enemy_floor"],
	"armor": ["ally"],
	"lift": ["ally"],
	"heal": ["ally_floor"],
	"remove_draw": ["ally_normal"],
	"poison": ["enemy", "enemy_floor", "all_enemies"],
	"heal_growth": ["ally"],
	"strip_damage": ["enemy"],
	"bloom": ["enemy_poisoned"],
}
const ON_PLAY_OPS: PackedStringArray = ["heal_other_ally", "growth_floor_others"]
const ON_DEATH_OPS: PackedStringArray = ["poison_enemy_floor"]
const UPGRADE_STATS: PackedStringArray = ["attack", "max_hp", "damage", "armor", "heal", "poison", "cost"]

static var _data: Dictionary = {}
static var _cards: Dictionary = {}
static var _enemies: Dictionary = {}
static var _relics: Dictionary = {}
static var _mutations: Dictionary = {}
static var last_errors: PackedStringArray = []


static func data() -> Dictionary:
	if _data.is_empty():
		load_from(PATH)
	return _data


static func load_from(path: String) -> bool:
	var d: Variant = JsonUtil.load_file(path)
	if typeof(d) != TYPE_DICTIONARY:
		last_errors = ["catalog: cannot read %s" % path]
		push_error(last_errors[0])
		return false
	return install(d)


## Validate and install a catalog dictionary. Returns false (and keeps the
## previous catalog) when validation fails; reasons are in last_errors.
static func install(d: Dictionary) -> bool:
	var errs: PackedStringArray = validate(d)
	last_errors = errs
	if not errs.is_empty():
		for e in errs:
			push_error("catalog: " + e)
		return false
	_data = d
	_cards = _index(d["cards"])
	_enemies = _index(d["enemies"])
	_enemies[d["boss"]["id"]] = d["boss"]
	_relics = _index(d["relics"])
	_mutations = _index(d["mutations"])
	return true


static func _index(arr: Array) -> Dictionary:
	var out: Dictionary = {}
	for x: Dictionary in arr:
		out[x["id"]] = x
	return out


static func validate(d: Dictionary) -> PackedStringArray:
	var errs: PackedStringArray = []
	for key in ["cards", "enemies", "boss", "normal_battles", "relics", "mutations", "rules", "start_deck", "champion_paths"]:
		if not d.has(key):
			errs.append("missing section '%s'" % key)
	if not errs.is_empty():
		return errs
	var seen: Dictionary = {}
	var champions := 0
	var normals := 0
	for c: Dictionary in d["cards"]:
		var cid: String = str(c.get("id", ""))
		if cid == "":
			errs.append("card without id")
			continue
		if seen.has(cid):
			errs.append("duplicate card id %s" % cid)
		seen[cid] = true
		var kind: String = str(c.get("kind", ""))
		if not KINDS.has(kind):
			errs.append("%s: unknown kind '%s'" % [cid, kind])
			continue
		if not FACTIONS.has(str(c.get("faction", ""))):
			errs.append("%s: unknown faction '%s'" % [cid, c.get("faction", "")])
		if kind == "champion":
			champions += 1
		else:
			normals += 1
		if int(c.get("cost", -1)) < 0:
			errs.append("%s: negative or missing cost" % cid)
		if kind == "spell":
			var sp: Dictionary = c.get("spell", {})
			var op: String = str(sp.get("op", ""))
			if not SPELL_OPS.has(op):
				errs.append("%s: unknown effect '%s'" % [cid, op])
			elif not (SPELL_OPS[op] as Array).has(str(sp.get("target", ""))):
				errs.append("%s: effect '%s' cannot target '%s'" % [cid, op, sp.get("target", "")])
		else:
			if int(c.get("max_hp", 0)) <= 0:
				errs.append("%s: creature needs max_hp > 0" % cid)
			if int(c.get("space", 0)) <= 0:
				errs.append("%s: creature needs space > 0" % cid)
			if c.has("on_play") and not ON_PLAY_OPS.has(str(c["on_play"].get("op", ""))):
				errs.append("%s: unknown effect '%s'" % [cid, c["on_play"].get("op", "")])
			if c.has("on_death") and not ON_DEATH_OPS.has(str(c["on_death"].get("op", ""))):
				errs.append("%s: unknown effect '%s'" % [cid, c["on_death"].get("op", "")])
		for u: Dictionary in c.get("upgrades", []):
			if not UPGRADE_STATS.has(str(u.get("stat", ""))):
				errs.append("%s: unknown upgrade stat '%s'" % [cid, u.get("stat", "")])
	if seen.size() != 24:
		errs.append("expected 24 card types, found %d" % seen.size())
	if champions != 2 or normals != 22:
		errs.append("expected 22 normal + 2 champions, found %d + %d" % [normals, champions])
	var eseen: Dictionary = {}
	for e: Dictionary in d["enemies"]:
		if eseen.has(e["id"]):
			errs.append("duplicate enemy id %s" % e["id"])
		eseen[e["id"]] = true
	for b: Dictionary in d["normal_battles"]:
		for w: Dictionary in b["waves"]:
			for g: Dictionary in w["groups"]:
				if not eseen.has(g["enemy_id"]):
					errs.append("%s: unknown enemy %s" % [b["id"], g["enemy_id"]])
	for w: Array in d["boss"]["waves"]:
		for eid: String in w:
			if not eseen.has(eid):
				errs.append("boss wave: unknown enemy %s" % eid)
	for cid: String in d["start_deck"]["normal_counts"].keys():
		if not seen.has(cid):
			errs.append("start deck: unknown card %s" % cid)
	return errs


static func card(def_id: String) -> Dictionary:
	data()
	return _cards.get(def_id, {})


static func enemy(def_id: String) -> Dictionary:
	data()
	return _enemies.get(def_id, {})


static func relic(rid: String) -> Dictionary:
	data()
	return _relics.get(rid, {})


static func mutation(mid: String) -> Dictionary:
	data()
	return _mutations.get(mid, {})


static func rules() -> Dictionary:
	return data()["rules"]


static func cards() -> Array:
	return data()["cards"]


static func normal_card_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Dictionary in cards():
		if c["kind"] != "champion":
			out.append(c["id"])
	return out


static func champion_for(faction: String) -> String:
	for c: Dictionary in cards():
		if c["kind"] == "champion" and c["faction"] == faction:
			return c["id"]
	return ""


static func champion_paths(champion_id: String) -> Array:
	return data()["champion_paths"].get(champion_id, [])


static func champion_path(champion_id: String, path_id: String) -> Dictionary:
	for p: Dictionary in champion_paths(champion_id):
		if p["id"] == path_id:
			return p
	return {}


static func normal_battle(index: int) -> Dictionary:
	return data()["normal_battles"][index]


static func boss() -> Dictionary:
	return data()["boss"]


static func floor_name(f: int) -> String:
	return ["Roots", "Trunk", "Crown"][clampi(f, 0, 2)]


static func is_creature(def: Dictionary) -> bool:
	return def.get("kind", "") in ["unit", "champion"]
