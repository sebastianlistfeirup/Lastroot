#!/usr/bin/env python3
"""Build data/definitions/*.json (engine data) from design/catalog.json (baseline).

Numbers always come from the design catalog; this script only adds English
names, structured effect fields and target types. Re-run after a balance change
in design/catalog.json and commit both files (AGENTS.md rule 7).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
src = json.loads((ROOT / "design/catalog.json").read_text())
out = ROOT / "data/definitions"
out.mkdir(parents=True, exist_ok=True)

EN = {
    "B01": "The Barkwarden", "B02": "Root Sprout", "B03": "Barkshield", "B04": "Thornhart",
    "B05": "Sapbearer", "B06": "Old Oak", "B07": "Root Strike", "B08": "Barkskin",
    "B09": "Root Net", "B10": "Branch Lift", "B11": "Sap Flood", "B12": "Last Twig",
    "S01": "The Spore Sage", "S02": "Sporeling", "S03": "Fungal Wall", "S04": "Nightcap",
    "S05": "Mycelium Keeper", "S06": "Spore Colossus", "S07": "Toxic Breath", "S08": "Spore Fog",
    "S09": "Lifethread", "S10": "Decompose", "S11": "Bloom", "S12": "Spore Rain",
    "E01": "Ashling", "E02": "Coalshield", "E03": "Emberhunter", "E04": "Sootbearer",
    "E05": "Stonebreaker", "E06": "The Ash Crown",
    "R01": "Bark Pearl", "R02": "Dewdrop", "R03": "Spore Lantern", "R04": "Sun Seed",
    "R05": "Home Root", "R06": "Leaf Book", "R07": "Amber Core", "R08": "Wanderer's Ring",
    "M01": "Deep Roots", "M02": "Strong Trunk", "M03": "Gentle Crown", "M04": "Great Heart",
}
TEXT = {
    "B01": "Champion. Starts with {armor} Armor.",
    "B02": "No extra effect.",
    "B03": "Starts with {armor} Armor.",
    "B04": "Thorns 2.",
    "B05": "On play: heal another ally 3.",
    "B06": "No extra effect.",
    "B07": "Deal {damage} damage to one enemy.",
    "B08": "Give one ally {armor} Armor.",
    "B09": "Deal {damage} damage to all enemies on one floor.",
    "B10": "Move an ally one floor up if there is space. Does not use its move.",
    "B11": "Heal all allies on one floor {heal}.",
    "B12": "Remove one of your normal creatures (not a death). Draw 2. Consume.",
    "S01": "Champion. Surviving attack targets get {on_hit_poison} Poison.",
    "S02": "Surviving attack targets get {on_hit_poison} Poison.",
    "S03": "Growth 2.",
    "S04": "+3 attack damage against a poisoned target.",
    "S05": "On play: other allies on this floor get Growth 1.",
    "S06": "On death: give all enemies on this floor 3 Poison.",
    "S07": "Give one enemy {poison} Poison.",
    "S08": "Give all enemies on one floor {poison} Poison.",
    "S09": "Heal one ally {heal} and give Growth 1.",
    "S10": "Remove up to 8 Armor from one enemy, then deal {damage} damage.",
    "S11": "Double a poisoned enemy's Poison, up to 12. Never lowers Poison.",
    "S12": "Give every enemy on every floor {poison} Poison. Consume.",
}
# Structured rules. Keys read by scripts/domain/card_effects.gd.
UNIT_FX = {
    "B01": {"start_armor": 8}, "B03": {"start_armor": 6}, "B04": {"thorns": 2},
    "B05": {"on_play": {"op": "heal_other_ally", "amount": 3}},
    "S01": {"on_hit_poison": 2}, "S02": {"on_hit_poison": 1}, "S03": {"growth": 2},
    "S04": {"bonus_vs_poisoned": 3},
    "S05": {"on_play": {"op": "growth_floor_others", "amount": 1}},
    "S06": {"on_death": {"op": "poison_enemy_floor", "amount": 3}},
}
SPELL_FX = {
    "B07": {"op": "damage", "target": "enemy", "damage": 5},
    "B08": {"op": "armor", "target": "ally", "armor": 6},
    "B09": {"op": "damage", "target": "enemy_floor", "damage": 3},
    "B10": {"op": "lift", "target": "ally"},
    "B11": {"op": "heal", "target": "ally_floor", "heal": 5},
    "B12": {"op": "remove_draw", "target": "ally_normal", "draw": 2},
    "S07": {"op": "poison", "target": "enemy", "poison": 3},
    "S08": {"op": "poison", "target": "enemy_floor", "poison": 2},
    "S09": {"op": "heal_growth", "target": "ally", "heal": 4, "growth": 1},
    "S10": {"op": "strip_damage", "target": "enemy", "strip": 8, "damage": 3},
    "S11": {"op": "bloom", "target": "enemy_poisoned", "cap": 12},
    "S12": {"op": "poison", "target": "all_enemies", "poison": 1},
}
UP_KEY = {"damage": "damage", "armor": "armor", "healing": "heal", "poison": "poison", "cost": "cost"}

cards = []
for c in src["cards"]:
    d = {
        "id": c["id"], "name": EN[c["id"]], "name_da": c["name"], "faction": c["faction"],
        "kind": c["kind"], "cost": c["cost"], "space": c["space"], "consume": c["consume"],
        "text": TEXT[c["id"]], "text_da": c["effect_text"],
    }
    if c["kind"] in ("unit", "champion"):
        d["attack"] = c["attack"]
        d["max_hp"] = c["max_hp"]
        d.update({"start_armor": 0, "thorns": 0, "growth": 0, "on_hit_poison": 0, "bonus_vs_poisoned": 0})
        d.update(UNIT_FX.get(c["id"], {}))
    else:
        d["spell"] = SPELL_FX[c["id"]]
    up = c["upgrade"]
    if up == "CHAMPION_PATH_ONLY":
        d["upgrades"] = []
        d["upgrade_rule"] = "champion_path"
    elif up is None:
        d["upgrades"] = []
        d["upgrade_rule"] = "none"
    elif isinstance(up, dict):
        d["upgrades"] = [{"id": "%s_%s" % (ch["stat"], ch["delta"]), "stat": ch["stat"], "delta": ch["delta"], "price": ch["price"]} for ch in up["choices"]]
        d["upgrade_rule"] = "unit_choice"
    else:
        stat, delta, price = up
        d["upgrades"] = [{"id": "%s_%s" % (UP_KEY[stat], delta), "stat": UP_KEY[stat], "delta": delta, "price": price}]
        d["upgrade_rule"] = "spell"
    cards.append(d)

enemies = [dict(e, name=EN[e["id"]], name_da=e["name"]) for e in src["enemies"]]
boss = dict(src["boss"], name=EN["E06"], name_da=src["boss"]["name"])
relics = [dict(r, name=EN[r["id"]], name_da=r["name"], text_da=r.pop("effect_text")) for r in src["relics"]]
REL_EN = {
    "R01": "Your Bark creatures get 3 Armor when played (champion included).",
    "R02": "The first spell you play each turn costs 1 less (minimum 0).",
    "R03": "Your first Poison each turn gives +1 to its first target (lowest id on areas).",
    "R04": "+1 Sap on the first turn of every battle.",
    "R05": "Heal the Heart 4 after a won battle.",
    "R06": "Draw one extra normal card on the first turn of a battle.",
    "R07": "Your normal creatures get +3 max HP when played (not the champion).",
    "R08": "The first normal move each turn is free.",
}
for r in relics:
    r["text"] = REL_EN[r["id"]]
MUT_EN = {
    "M01": "The Roots gain +1 space.",
    "M02": "Allies on the Trunk get +1 attack while they stand there.",
    "M03": "Allies on the Crown heal 2 at the start of each turn.",
    "M04": "+15 max and current Heart, once.",
}
mutations = [dict(m, name=EN[m["id"]], name_da=m["name"], text=MUT_EN[m["id"]], text_da=m["effect_text"]) for m in src["mutations"]]
PATH_EN = {"VÆRN": ("BULWARK", "Bulwark", "+8 max HP and +4 starting Armor per rank."),
           "VREDE": ("WRATH", "Wrath", "+3 attack and +2 max HP per rank."),
           "GIFTMESTER": ("VENOM", "Venom Master", "+1 on-hit Poison per rank."),
           "LIVSVÆVER": ("LIFEWEAVER", "Lifeweaver", "At turn start, heal all allies on its floor 1 per rank.")}
paths = {}
for champ, ps in src["champion_paths"].items():
    paths[champ] = []
    for key, vals in ps.items():
        pid, name, text = PATH_EN[key]
        paths[champ].append(dict(vals, id=pid, name=name, name_da=key.capitalize(), text=text))

catalog = {
    "schema_version": 1, "content_version": "0.1.0+" + src["content_version"],
    "cards": cards, "start_deck": src["start_deck"], "enemies": enemies, "boss": boss,
    "normal_battles": src["normal_battles"], "relics": relics, "mutations": mutations,
    "champion_paths": paths, "rules": src["rules"],
    "floors": [{"id": 0, "name": "Roots", "name_da": "Rødderne"}, {"id": 1, "name": "Trunk", "name_da": "Stammen"}, {"id": 2, "name": "Crown", "name_da": "Kronen"}],
}
(out / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n")
print("wrote", out / "catalog.json", len(cards), "cards")
