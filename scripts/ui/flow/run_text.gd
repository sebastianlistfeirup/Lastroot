class_name RunText
extends RefCounted
## Player-facing wording for run data (node types, reward slots, champion
## path numbers). Read-only helpers shared by the run, result and test scenes.

const PATH_STATS := {
	"max_hp_per_rank": ["max_hp", "Max HP"],
	"start_armor_per_rank": ["armor", "Starting Armor"],
	"attack_per_rank": ["attack", "Attack"],
	"on_hit_poison_per_rank": ["on_hit_poison", "On-hit Poison"],
	"floor_start_heal_per_rank": ["", "Heal on its floor at turn start"],
}


static func node_name(type: String) -> String:
	match type:
		"camp": return Loc.t("Camp")
		"card": return Loc.t("Card reward")
		"encounter": return Loc.t("Encounter")
		"removal": return Loc.t("Removal")
	return type


static func node_gives(type: String) -> String:
	var rules: Dictionary = Catalog.rules()
	match type:
		"camp":
			return Loc.t("Upgrade one card once: +2 attack or +5 max HP for creatures, a stronger effect for spells. Costs 25 or 35 Resin.")
		"card":
			return Loc.t("Choose one of three cards for your deck, or skip. Free.")
		"encounter":
			return Loc.t("Choose: gain 15 Resin, or heal the Heart 8.")
		"removal":
			return Loc.t("Remove one normal card from your deck for %d Resin. At least %d normal cards stay.") % [int(rules["remove_cost"]), int(rules["min_normal_cards"])]
	return ""


## Warning shown on a route option when it cannot be fully used right now.
static func node_warning(type: String, run: Dictionary) -> String:
	var rules: Dictionary = Catalog.rules()
	var resin: int = int(run.get("resin", 0))
	match type:
		"camp":
			var cheapest: int = 1 << 30
			for inst: Dictionary in run.get("deck", []):
				for u: Dictionary in CardStats.legal_upgrades(Catalog.card(inst["def_id"]), inst["upgrade_id"]):
					cheapest = mini(cheapest, int(u["price"]))
			if cheapest == 1 << 30:
				return Loc.t("No card in your deck can be upgraded.")
			if resin < cheapest:
				return Loc.t("You cannot afford an upgrade yet (needs %d Resin).") % cheapest
		"removal":
			if RunReducer.normal_card_count(run) <= int(rules["min_normal_cards"]):
				return Loc.t("Your deck is already at the minimum of %d normal cards.") % int(rules["min_normal_cards"])
			if resin < int(rules["remove_cost"]):
				return Loc.t("You cannot afford a removal yet (needs %d Resin).") % int(rules["remove_cost"])
		"encounter":
			if int(run.get("heart", 0)) >= int(run.get("heart_max", 0)):
				return Loc.t("The Heart is already full: healing would do nothing.")
	return ""


static func battle_name(index: int) -> String:
	if index >= 5:
		return Loc.field(Catalog.boss(), "name")
	return Loc.t("Battle %d") % (index + 1)


static func slot_title(type: String) -> String:
	match type:
		"resin": return Loc.t("Resin")
		"heart_heal": return Loc.t("Heart healed")
		"card": return Loc.t("Card")
		"mutation": return Loc.t("Tree mutation")
		"champion": return Loc.t("Champion path")
		"relic": return Loc.t("Relic")
	return type


static func slot_icon(type: String) -> String:
	match type:
		"resin": return "resin"
		"heart_heal": return "heart"
		"card": return "card"
		"mutation": return "mutation"
		"champion": return "champion"
		"relic": return "relic"
	return "card"


## Short result text of a settled slot ("+20", "Root Sprout", "Skipped").
static func slot_result(slot: Dictionary, run: Dictionary) -> String:
	var st: String = str(slot.get("status", ""))
	if st == "skipped":
		return Loc.t("Skipped")
	if st == "offered":
		return Loc.t("Choose now")
	var c: String = str(slot.get("choice", ""))
	match str(slot["type"]):
		"resin":
			return "+%d" % int(slot.get("amount", 0))
		"heart_heal":
			return "+%d" % int(slot.get("amount", 0))
		"card":
			return Loc.field(Catalog.card(c), "name")
		"mutation":
			return Loc.field(Catalog.mutation(c), "name")
		"relic":
			return Loc.field(Catalog.relic(c), "name")
		"champion":
			return Loc.field(Catalog.champion_path(str(run.get("champion_id", "")), c), "name")
	return c


## [[label, before, after]] for a champion path rank-up, computed from the
## same CardStats the battle uses.
static func path_changes(champion_id: String, path_id: String, from_path: String, from_rank: int, to_rank: int) -> Array:
	var def: Dictionary = Catalog.card(champion_id)
	var p: Dictionary = Catalog.champion_path(champion_id, path_id)
	var before: Dictionary = CardStats.unit_stats(def, "", from_path, from_rank)
	var after: Dictionary = CardStats.unit_stats(def, "", path_id, to_rank)
	var out: Array = []
	for key: String in PATH_STATS.keys():
		if not p.has(key):
			continue
		var stat: String = PATH_STATS[key][0]
		var label: String = path_label(key)
		if stat != "":
			out.append([label, int(before[stat]), int(after[stat])])
		else:
			var b: int = int(p[key]) * from_rank if from_path == path_id else 0
			out.append([label, b, int(p[key]) * to_rank])
	return out


static func path_label(key: String) -> String:
	match key:
		"max_hp_per_rank": return Loc.t("Max HP")
		"start_armor_per_rank": return Loc.t("Starting Armor")
		"attack_per_rank": return Loc.t("Attack")
		"on_hit_poison_per_rank": return Loc.t("On-hit Poison")
		"floor_start_heal_per_rank": return Loc.t("Heal on its floor at turn start")
	return key


static func champion_line(run: Dictionary) -> String:
	var champ: Dictionary = Catalog.card(str(run.get("champion_id", "")))
	var path: String = str(run.get("champion_path", ""))
	if path == "":
		return Loc.field(champ, "name")
	var p: Dictionary = Catalog.champion_path(champ["id"], path)
	return "%s · %s %d" % [Loc.field(p, "name"), Loc.t("rank"), int(run.get("champion_rank", 0))]


static func faction_name(faction: String) -> String:
	return Loc.t("Bark") if faction == "BARK" else Loc.t("Spore")


## Waves of a battle as [[turn, "2× Ashling", [enemy ids]]], catalog order.
static func wave_rows(battle_index: int) -> Array:
	var out: Array = []
	for w: Dictionary in BattleFactory.waves_for(battle_index):
		var counts: Dictionary = {}
		var order: Array = []
		for eid: String in w["enemies"]:
			if not counts.has(eid):
				order.append(eid)
				counts[eid] = 0
			counts[eid] = int(counts[eid]) + 1
		var parts: PackedStringArray = []
		for eid: String in order:
			parts.append("%d× %s" % [int(counts[eid]), Loc.field(Catalog.enemy(eid), "name")])
		out.append([int(w["turn"]), ", ".join(parts), order])
	return out


## "⚔2 ♥5 ◆4" for an enemy definition.
static func enemy_stats(eid: String) -> String:
	var e: Dictionary = Catalog.enemy(eid)
	var s: String = "%s%d %s%d" % [UiKit.status_glyph("attack"), int(e.get("attack", 0)), UiKit.status_glyph("hp"), int(e.get("max_hp", 0))]
	if int(e.get("start_armor", 0)) > 0:
		s += " %s%d" % [UiKit.status_glyph("armor"), int(e["start_armor"])]
	return s


static func boss_rules() -> String:
	var b: Dictionary = Catalog.boss()
	return Loc.t("Arrives on the Roots on turn %d after four waves. It stays on a floor while a living ally stands there; otherwise it climbs. If it leaves the Crown, the run is lost. From turn %d it gains +2 attack every turn.") % [int(b["arrival_turn"]), int(b["escalate_from_turn"])]
