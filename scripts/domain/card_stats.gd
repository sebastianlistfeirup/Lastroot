class_name CardStats
extends RefCounted
## Effective numbers of a card instance (definition + its own upgrade +
## champion path). Used by the reducer, camp previews and card UI, so every
## screen shows the same numbers the battle will use.


static func upgrade_def(def: Dictionary, upgrade_id: String) -> Dictionary:
	if upgrade_id == "":
		return {}
	for u: Dictionary in def.get("upgrades", []):
		if u["id"] == upgrade_id:
			return u
	return {}


static func _delta(def: Dictionary, upgrade_id: String, stat: String) -> int:
	var u: Dictionary = upgrade_def(def, upgrade_id)
	if u.get("stat", "") == stat:
		return int(u["delta"])
	return 0


static func cost(def: Dictionary, upgrade_id: String) -> int:
	return maxi(0, int(def["cost"]) + _delta(def, upgrade_id, "cost"))


## Amount of a spell parameter (damage, armor, heal, poison, ...) after upgrade.
static func spell_amount(def: Dictionary, upgrade_id: String, key: String) -> int:
	var sp: Dictionary = def.get("spell", {})
	return int(sp.get(key, 0)) + _delta(def, upgrade_id, key)


## Battle-start values of a creature card instance.
static func unit_stats(def: Dictionary, upgrade_id: String, path_id: String = "", rank: int = 0) -> Dictionary:
	var st := {
		"attack": int(def.get("attack", 0)) + _delta(def, upgrade_id, "attack"),
		"max_hp": int(def.get("max_hp", 1)) + _delta(def, upgrade_id, "max_hp"),
		"armor": int(def.get("start_armor", 0)),
		"thorns": int(def.get("thorns", 0)),
		"growth": int(def.get("growth", 0)),
		"on_hit_poison": int(def.get("on_hit_poison", 0)),
		"bonus_vs_poisoned": int(def.get("bonus_vs_poisoned", 0)),
		"space": int(def.get("space", 1)),
	}
	if def.get("kind", "") == "champion" and path_id != "" and rank > 0:
		var p: Dictionary = Catalog.champion_path(def["id"], path_id)
		st["max_hp"] += int(p.get("max_hp_per_rank", 0)) * rank
		st["armor"] += int(p.get("start_armor_per_rank", 0)) * rank
		st["attack"] += int(p.get("attack_per_rank", 0)) * rank
		st["on_hit_poison"] += int(p.get("on_hit_poison_per_rank", 0)) * rank
	return st


## Legal camp upgrades for an instance: [] when the card cannot be upgraded
## (champions, B12, already upgraded once, or an upgrade with no effect).
static func legal_upgrades(def: Dictionary, current_upgrade: String) -> Array:
	if current_upgrade != "" or def.get("kind", "") == "champion":
		return []
	var out: Array = []
	for u: Dictionary in def.get("upgrades", []):
		if u["stat"] == "cost" and int(def["cost"]) <= 0:
			continue  # would sell an upgrade without effect (bible p.11)
		out.append(u)
	return out


## Rules text with the instance's real numbers filled in. `raw` is the
## (already translated) text template; the domain never touches Loc.
static func format_text(raw: String, def: Dictionary, upgrade_id: String, path_id: String = "", rank: int = 0) -> String:
	var vals := {}
	if def.get("kind", "") == "spell":
		for k in ["damage", "armor", "heal", "poison", "growth", "draw"]:
			vals[k] = spell_amount(def, upgrade_id, k)
	else:
		vals["on_hit_poison"] = unit_stats(def, upgrade_id, path_id, rank)["on_hit_poison"]
	return raw.format(vals)
