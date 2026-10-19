#!/usr/bin/env python3
"""Single source for LASTROOT's visual slot data. Writes:

  data/art/asset_slots.json        slot registry (proxy spec, size, rig family, states)
  data/art/vendor_suggestions.json Synty / PolyPerfect / Mixamo search hints per slot
  data/art/animation_sets.json     rig family -> per-state clip name hints + contact times
  docs/ASSET_LEDGER.csv            one row per slot (review status PROXY until mapped)
  docs/ANIMATION_LEDGER.csv        one row per animated slot x required state

Hand edits that are KEPT on re-run: "scene", "scale", "offset", "rotation_y" in
asset_slots.json, and any ledger row whose review_status is not PROXY/NEEDED.

  python3 tools/synty/gen_slots.py
Python 3 stdlib only.
"""
import csv, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNVERIFIED = "unverified — check actual pack contents"

HUMANOID_STATES = ["idle", "summon", "attack", "hit", "death", "defend", "victory", "move"]
CASTER_STATES = ["idle", "summon", "cast", "attack", "hit", "death", "defend", "victory", "move"]
QUAD_STATES = ["idle", "summon", "attack", "hit", "death", "move"]
STATIC_STATES = ["idle", "summon", "hit", "death", "defend"]
ENEMY_STATES = ["idle", "summon", "attack", "hit", "death", "move"]
BOSS_STATES = ["idle", "summon", "attack", "hit", "death", "move", "victory"]

# id: (kind, name, builder, height, head_height, space, rig_family, states, fit, note)
UNITS = {
    "unit.B01": ("The Barkwarden", "barkwarden", 2.2, 2.55, 2, "humanoid", HUMANOID_STATES, "Champion. Heavy bark/stone golem, broad chest, amber eyes, plank shield (REF_02/03)."),
    "unit.B02": ("Root Sprout", "root_sprout", 1.05, 1.3, 1, "humanoid", HUMANOID_STATES, "Small sapling with root feet; smallest bark unit."),
    "unit.B03": ("Barkshield", "barkshield", 1.6, 1.9, 2, "humanoid", HUMANOID_STATES, "Squat wide guardian behind a tall plank shield (6 start armor)."),
    "unit.B04": ("Thornhart", "thornhart", 2.0, 2.25, 2, "quadruped", QUAD_STATES, "QUADRUPED stag of bark with thorn antlers (Thorns 2). Never a humanoid retarget."),
    "unit.B05": ("Sapbearer", "sapbearer", 1.3, 1.55, 1, "humanoid", HUMANOID_STATES, "Round healer carrying a glowing amber sap orb."),
    "unit.B06": ("Old Oak", "old_oak", 2.5, 2.8, 3, "humanoid", HUMANOID_STATES, "3-space walking oak; wide, low crown so its numbers stay visible."),
    "unit.S01": ("The Spore Sage", "spore_sage", 1.6, 1.85, 2, "humanoid", CASTER_STATES, "Champion. Small robed figure, huge violet-white mushroom hat, staff with turquoise glow (REF_02)."),
    "unit.S02": ("Sporeling", "sporeling", 0.95, 1.2, 1, "humanoid", HUMANOID_STATES, "Tiny mushroom creature with glowing antenna spores."),
    "unit.S03": ("Fungal Wall", "fungal_wall", 1.65, 1.9, 2, "static", STATIC_STATES, "Wide stack of shelf fungi; no skeleton needed (procedural motion only)."),
    "unit.S04": ("Nightcap", "nightcap", 1.4, 1.65, 1, "humanoid", HUMANOID_STATES, "Dark indigo assassin with pointed cap and thorn daggers (+3 vs poisoned)."),
    "unit.S05": ("Mycelium Keeper", "mycelium_keeper", 1.65, 1.9, 2, "humanoid", CASTER_STATES, "Keeper with a turquoise spore lantern; mycelium threads at the feet."),
    "unit.S06": ("Spore Colossus", "spore_colossus", 2.45, 2.75, 3, "humanoid", HUMANOID_STATES, "3-space mushroom giant with glowing spore sacs."),
}
ENEMIES = {
    "enemy.E01": ("Ashling", "ashling", 0.9, 1.15, "humanoid", ENEMY_STATES, "Small and quick: hunched ash imp with a long tail."),
    "enemy.E02": ("Coalshield", "coalshield", 1.2, 1.5, "humanoid", ENEMY_STATES, "Compact coal block behind a slab shield with ember rim (4 start armor)."),
    "enemy.E03": ("Emberhunter", "emberhunter", 1.5, 1.75, "humanoid", ENEMY_STATES, "Spiky, offensive, forward-leaning; ember spear."),
    "enemy.E04": ("Sootbearer", "sootbearer", 1.6, 1.85, "humanoid", ENEMY_STATES, "Round and heavy soot sack with an ember belly and chimney vents."),
    "enemy.E05": ("Stonebreaker", "stonebreaker", 1.9, 2.15, "humanoid", ENEMY_STATES, "Wide, armoured basalt brute with huge fists (6 start armor)."),
    "enemy.E06": ("The Ash Crown", "ash_crown", 3.0, 3.3, "humanoid", BOSS_STATES, "Boss ~3 m: charred crown of branches and stone, inner ember glow, clear face."),
}
STAGE = {
    "stage.floor_roots": ("Roots floor", "floor", {"variant": "roots"}, 0.2, "footprint", "Terrace: top y=0, usable x -5.5..5.5, depth 3.2 (z -1.6..1.6). Roots hang below. Props only on back edge."),
    "stage.floor_trunk": ("Trunk floor", "floor", {"variant": "trunk"}, 0.2, "footprint", "Same terrace rules; violet mushrooms on the back edge."),
    "stage.floor_crown": ("Crown floor", "floor", {"variant": "crown"}, 0.2, "footprint", "Same terrace rules; crystals and golden blossoms on the back edge."),
    "stage.trunk": ("Trunk segment", "trunk", {"height": 4.5}, 4.5, "height", "Segment y 0..4.5 centred x=0, z ~-2.9 (front z ~-1.3): always behind units. Amber doorway faces camera."),
    "stage.heart": ("Heart of the tree", "heart", {}, 2.0, "height", "Faceted turquoise heart crystal ~1.6 m on a branch cradle, own OmniLight. Has a UnitAnimator (idle/hit)."),
    "stage.backdrop": ("Backdrop", "backdrop", {}, 30.0, "natural", "Floating islands, rock spires, violet haze, moon. Everything at z < -15."),
}
PROPS = {
    "prop.lantern": ("Amber lantern", "lantern", 1.25, "Hanging amber lantern on a bent post."),
    "prop.mushroom_cluster": ("Glowing mushrooms", "mushroom_cluster", 0.75, "Violet caps, glowing gills, turquoise dots."),
    "prop.crystal": ("Turquoise crystal", "crystal", 1.0, "Cluster of faceted turquoise crystals."),
    "prop.root_arch": ("Root arch", "root_arch", 1.7, "Arch of bark root ~1.7 m wide."),
    "prop.rock": ("Mossy rock", "rock", 0.55, "Low mossy boulder pair."),
}
MUTATIONS = {
    "mutation.M01": ("Deep Roots", "m01_roots", "stage.floor_roots", "Extra roots over the Roots back edge and hanging below (floor frame)."),
    "mutation.M02": ("Strong Trunk", "m02_band", "stage.trunk", "Thick bark band with turquoise glow ring and veins (trunk-segment frame)."),
    "mutation.M03": ("Gentle Crown", "m03_blossoms", "stage.floor_crown", "Blossom clusters and golden flowers on the Crown back edge (floor frame)."),
    "mutation.M04": ("Great Heart", "m04_glow", "stage.heart", "Bigger halo, extra shards, stronger light (heart frame)."),
}
FX = {
    "fx.poison": (False, "Toxic green/violet bubbles rising around the unit (status loop)."),
    "fx.heal": (True, "Green-turquoise sparkles rising + expanding ring (one-shot)."),
    "fx.armor": (False, "Faint faceted shell + slow sparkles (status loop)."),
    "fx.thorns": (False, "Ring of thorn spikes at the feet (status loop)."),
    "fx.growth": (False, "Rising green leaves (status loop)."),
    "fx.spore_bolt": (True, "Turquoise orb with a world-space trail; fly it with FxBuilder.launch()."),
    "fx.bark_hit": (True, "Wood chips and amber sparks burst at the strike (one-shot)."),
    "fx.ash_death": (True, "Ash cloud and rising embers when an ash enemy dies (one-shot)."),
    "fx.heart_pulse": (False, "Turquoise ring pulse around the heart (loop)."),
    "fx.heart_damage": (True, "Red/turquoise shard burst + ring when the heart is hit (one-shot)."),
}

# ----------------------------------------------------------------- vendor hints
SYN_CHAR = "Synty POLYGON Fantasy Characters"
SYN_RIVALS = "Synty POLYGON Fantasy Rivals"
SYN_DARK = "Synty POLYGON Dark Fantasy"
SYN_ELVEN = "Synty POLYGON Elven Realm"
SYN_NATURE = "Synty POLYGON Nature"
SYN_KINGDOM = "Synty POLYGON Fantasy Kingdom"
SYN_DUNGEON = "Synty POLYGON Dungeons"
SYN_FX = "Synty POLYGON Particle FX"
PP_ANIMALS = "PolyPerfect Low Poly Animated Animals"
PP_ULTIMATE = "PolyPerfect Low Poly Ultimate Pack"
PP_UNIVERSAL = "PolyPerfect Poly Universal Pack"

MIXAMO = {
    "idle": ["Breathing Idle", "Standing Idle", "Happy Idle"],
    "summon": ["Standing Up", "Getting Up", "Jumping Down"],
    "attack": ["Punching", "Standing Melee Attack Downward", "Sword And Shield Slash"],
    "cast": ["Standing 1H Magic Attack 01", "Standing 2H Magic Attack 01", "Magic Spell Casting"],
    "hit": ["Hit Reaction", "Standing React Small From Front", "Big Hit To Head"],
    "death": ["Dying", "Standing Death Backward 01", "Falling Back Death"],
    "defend": ["Standing Block Idle", "Sword And Shield Block", "Blocking"],
    "victory": ["Victory", "Cheering", "Victory Idle"],
    "move": ["Walking", "Standing Walk Forward", "Jog Forward"],
}
MIXAMO_HEAVY = {"idle": ["Mutant Breathing Idle", "Breathing Idle"], "attack": ["Mutant Punch", "Mutant Swiping", "Punching"],
                "hit": ["Mutant Hit Reaction"] + MIXAMO["hit"], "death": ["Mutant Dying", "Dying"], "move": ["Mutant Walking", "Walking"],
                "victory": ["Mutant Roaring", "Victory"], "summon": ["Mutant Jumping"] + MIXAMO["summon"]}
MIXAMO_SMALL = {"idle": ["Happy Idle", "Breathing Idle"], "attack": ["Punching", "Goblin Attack"], "move": ["Sneak Walk", "Walking"], "victory": ["Jumping", "Victory"]}

VENDOR = {
    "unit.B01": ([SYN_DARK, SYN_RIVALS, SYN_NATURE], ["*Golem*", "*Rock*Giant*", "*Treant*", "SK_Chr_*Giant*"], "Heavy humanoid base (giant/golem/treant) + bark plates and rocks from POLYGON Nature as attachments (Rock_*, Bark/Log_*). Keep the existing rig.", MIXAMO_HEAVY),
    "unit.B02": ([SYN_NATURE, PP_ULTIMATE, SYN_ELVEN], ["*Sapling*", "*Sprout*", "*Stump*", "SK_Chr_*Goblin*"], "Small humanoid base (goblin/child scale) + sapling/leaf attachments, or a PolyPerfect stump creature if one exists.", MIXAMO_SMALL),
    "unit.B03": ([SYN_KINGDOM, SYN_CHAR, SYN_NATURE], ["SK_Chr_*Knight*", "SM_Wep_Shield_*Wood*", "*Shield*Tower*"], "Stocky humanoid + big wooden tower shield (SM_Wep_Shield_* is a typical Synty prefix) recoloured to bark.", {"defend": ["Sword And Shield Block", "Standing Block Idle"], "attack": ["Sword And Shield Bash", "Sword And Shield Slash"]}),
    "unit.B04": ([PP_ANIMALS, PP_ULTIMATE, SYN_NATURE], ["*Deer*", "*Stag*", "*Elk*", "*Moose*"], "QUADRUPED: PolyPerfect animated deer/stag with its own clips (idle/attack/hit/death names vary per pack) + thorn antler attachments built from POLYGON Nature branches. Do NOT retarget humanoid clips.", {}),
    "unit.B05": ([SYN_NATURE, SYN_CHAR, PP_ULTIMATE], ["SK_Chr_*Dwarf*", "*Jar*", "*Barrel*Small*", "*Honey*"], "Short round humanoid (dwarf/child) carrying a jar/lantern prop with an amber emissive material.", MIXAMO_SMALL),
    "unit.B06": ([SYN_NATURE, SYN_DARK], ["*Treant*", "*Tree*Monster*", "SM_Env_Tree_Oak*", "SM_Env_Tree_*Large*"], "Treant/tree creature rig if one exists; otherwise a giant humanoid wearing an oak crown cut from SM_Env_Tree_* (keep crown low).", MIXAMO_HEAVY),
    "unit.S01": ([SYN_CHAR, SYN_ELVEN, SYN_NATURE], ["SK_Chr_*Wizard*", "SK_Chr_*Druid*", "SM_Env_Mushroom*", "SM_Wep_Staff_*"], "Small humanoid (gnome/child scale) + oversized mushroom-cap attachment (SM_Env_Mushroom_* scaled up, violet recolour) + staff with turquoise emissive tip. Hat and staff must read.", {"cast": ["Standing 1H Magic Attack 01", "Standing 2H Magic Attack 01"]}),
    "unit.S02": ([SYN_NATURE, PP_ULTIMATE], ["*Mushroom*", "SK_Chr_*Goblin*", "*Imp*"], "Tiny creature/goblin base + mushroom cap attachment.", MIXAMO_SMALL),
    "unit.S03": ([SYN_NATURE, SYN_DUNGEON], ["SM_Env_Mushroom*", "*Fungus*", "*Shelf*Mushroom*"], "Static: a cluster of POLYGON Nature mushrooms on a rock, no rig (procedural motion).", {}),
    "unit.S04": ([SYN_DARK, SYN_CHAR], ["SK_Chr_*Assassin*", "SK_Chr_*Rogue*", "SM_Wep_Dagger*"], "Slim rogue/assassin base + pointed dark cap attachment + twin daggers.", {"attack": ["Stabbing", "Punching"], "idle": ["Sneaking Idle", "Breathing Idle"]}),
    "unit.S05": ([SYN_ELVEN, SYN_CHAR, SYN_NATURE], ["SK_Chr_*Druid*", "SK_Chr_*Monk*", "SM_Prop_Lantern*"], "Robed humanoid + mushroom cap + lantern with turquoise emissive.", {"cast": ["Standing 1H Magic Attack 01", "Magic Spell Casting"]}),
    "unit.S06": ([SYN_DARK, SYN_NATURE], ["SK_Chr_*Giant*", "SK_Chr_*Ogre*", "*Troll*", "SM_Env_Mushroom_Large*"], "Giant/ogre base + very large mushroom cap and glowing sacs.", MIXAMO_HEAVY),
    "enemy.E01": ([SYN_DARK, SYN_RIVALS, SYN_DUNGEON], ["SK_Chr_*Imp*", "SK_Chr_*Goblin*", "*Ghoul*"], "Rig family A (small humanoid). Charcoal recolour + ember emissive eyes; quick tempo (play speed 1.2-1.4).", MIXAMO_SMALL),
    "enemy.E02": ([SYN_DARK, SYN_DUNGEON], ["SK_Chr_*Skeleton*Shield*", "SK_Chr_*Golem*", "SM_Wep_Shield_*"], "Rig family B (stocky humanoid) + slab shield attachment; ember rim material.", {"defend": ["Standing Block Idle"]}),
    "enemy.E03": ([SYN_DARK, SYN_RIVALS], ["SK_Chr_*Hunter*", "SK_Chr_*Demon*", "SM_Wep_Spear*"], "Rig family A/B + spikes + spear; lean forward.", {"attack": ["Standing Melee Attack Downward", "Spear Stab"]}),
    "enemy.E04": ([SYN_DARK, SYN_DUNGEON], ["SK_Chr_*Fat*", "SK_Chr_*Ogre*", "*Blob*"], "Rig family B scaled round (or a fat zombie/ogre) + soot sack/chimney attachments.", MIXAMO_HEAVY),
    "enemy.E05": ([SYN_DARK, SYN_DUNGEON, SYN_RIVALS], ["SK_Chr_*Golem*", "SK_Chr_*Brute*", "SK_Chr_*Giant*"], "Rig family C (heavy) + basalt plate attachments.", MIXAMO_HEAVY),
    "enemy.E06": ([SYN_DARK, SYN_RIVALS], ["SK_Chr_*King*", "SK_Chr_*Lich*", "SK_Chr_*Giant*", "*Crown*"], "Boss: large humanoid rig (family C, scaled to ~3 m) + custom charred crown of branches/stone (attachment to the head bone) + emissive core. Do not cover its own HP/armor badge.", MIXAMO_HEAVY),
    "stage.floor_roots": ([SYN_NATURE, SYN_KINGDOM], ["SM_Env_Rock_Flat*", "SM_Env_Tree_Root*", "SM_Env_Ground_*", "*Platform*"], "Build TreeStage from rocks, roots and flagstones; top must be flat at y=0 and 11 m wide usable.", {}),
    "stage.floor_trunk": ([SYN_NATURE, SYN_KINGDOM], ["SM_Env_Rock_Flat*", "SM_Env_Path_*", "*Platform*"], "Same as Roots floor; mushrooms at back edge.", {}),
    "stage.floor_crown": ([SYN_NATURE, SYN_ELVEN], ["SM_Env_Rock_Flat*", "*Platform*", "SM_Env_Tree_Branch*"], "Same; crystals/blossoms at back edge.", {}),
    "stage.trunk": ([SYN_NATURE, SYN_ELVEN], ["SM_Env_Tree_Trunk*", "SM_Env_Tree_Dead*", "SM_Env_Tree_Giant*", "SM_Bld_*Door*"], "Giant trunk segments (scaled tree trunks) + doorway with amber light.", {}),
    "stage.heart": ([SYN_ELVEN, SYN_DUNGEON, SYN_FX], ["SM_Prop_Crystal*", "*Gem*", "*Heart*"], "Keep the procedural faceted heart unless a crystal heart model exists; recolour turquoise emissive.", {}),
    "stage.backdrop": ([SYN_NATURE, SYN_ELVEN], ["SM_Env_Rock_Large*", "SM_Env_Cliff*", "*Floating*Island*", "SM_Env_Rock_Spire*"], "Floating islands and spires far behind (z < -15); low detail is fine.", {}),
    "prop.lantern": ([SYN_KINGDOM, SYN_ELVEN, SYN_DUNGEON], ["SM_Prop_Lantern*", "SM_Prop_Lamp*"], "Amber emissive lantern.", {}),
    "prop.mushroom_cluster": ([SYN_NATURE, SYN_ELVEN], ["SM_Env_Mushroom*", "*Mushroom*Group*"], "Violet recolour with emissive gills.", {}),
    "prop.crystal": ([SYN_DUNGEON, SYN_ELVEN, SYN_DARK], ["SM_Prop_Crystal*", "SM_Env_Crystal*"], "Turquoise emissive crystals.", {}),
    "prop.root_arch": ([SYN_NATURE], ["SM_Env_Tree_Root*", "*Arch*Root*", "SM_Env_Rock_Arch*"], "Root/rock arch for the back edge.", {}),
    "prop.rock": ([SYN_NATURE, PP_ULTIMATE], ["SM_Env_Rock_0*", "SM_Env_Rock_Small*", "*Rock*"], "Mossy rocks.", {}),
    "mutation.M01": ([SYN_NATURE], ["SM_Env_Tree_Root*"], "Extra roots placed in the Roots-floor frame.", {}),
    "mutation.M02": ([SYN_NATURE, SYN_ELVEN], ["*Vine*", "*Ring*"], "Band around the trunk + emissive veins.", {}),
    "mutation.M03": ([SYN_NATURE, SYN_ELVEN], ["SM_Env_Flower*", "SM_Env_Bush_Flower*", "*Blossom*"], "Blossoms along the Crown back edge.", {}),
    "mutation.M04": ([SYN_FX, SYN_ELVEN], ["FX_*Glow*", "SM_Prop_Crystal*"], "Bigger glow/halo around the heart.", {}),
}
FX_HINT = (["Synty POLYGON Particle FX"], ["FX_*Poison*", "FX_*Heal*", "FX_*Magic*", "FX_*Smoke*", "FX_*Spark*", "FX_*Hit*"],
           "Unity particle systems do not convert: rebuild in Godot (CPUParticles3D, see scripts/runtime/visual/fx_builder.gd) and reuse only the pack's textures.")

ANIM_KEYWORDS = {
    "idle": ["idle", "breathing", "stand"],
    "summon": ["summon", "spawn", "emerge", "getting_up", "standing_up", "stand_up", "jump_down", "appear"],
    "attack": ["attack", "punch", "slash", "swing", "stab", "bite", "strike", "swipe", "melee"],
    "cast": ["cast", "spell", "magic"],
    "hit": ["hit", "react", "impact", "damage", "hurt"],
    "death": ["death", "dying", "die", "dead"],
    "defend": ["block", "defend", "guard", "shield"],
    "victory": ["victory", "cheer", "celebrat", "roar", "win"],
    "move": ["walk", "jog", "run", "move", "trot", "gallop"],
}

ANIMATION_SETS = {
    "_note": "Rig family -> clip name hints. 'clips' maps a state to a clip name inside the model's own AnimationPlayer "
             "(used when no 'lr/<state>' library clip exists, e.g. PolyPerfect animals with built-in clips). 'contact' = seconds "
             "from start to the hit frame at speed 1.0 (UnitAnimator.contact_time). Per-slot overrides under 'slots'. "
             "tools/synty/build_wrappers.gd fills 'lr' libraries from Mixamo/Synty clips; you rarely need to edit this. " + UNVERIFIED + ".",
    "keywords": ANIM_KEYWORDS,
    "sets": {
        "humanoid": {"rig": "humanoid", "retarget": "SkeletonProfileHumanoid", "clips": {}, "contact": {"attack": 0.3, "cast": 0.38},
                     "mixamo": MIXAMO, "notes": "Mixamo: download FBX, 30 fps, 'In Place' ticked, 'Without Skin' for clip files. Synty and Mixamo bone names both map."},
        "quadruped": {"rig": "quadruped", "retarget": "none", "clips": {"idle": "Idle", "attack": "Attack", "hit": "Hit", "death": "Death", "move": "Walk"},
                      "contact": {"attack": 0.32}, "notes": "PolyPerfect-style animals ship their own clips; names vary (e.g. Idle_A, Attack_1) — set the real names here or let the builder match by keyword."},
        "static": {"rig": "none", "clips": {}, "contact": {}, "notes": "No skeleton: UnitAnimator uses procedural motion."},
    },
    "slots": {},
}


def proxy_spec(builder, extra=None):
    d = {"builder": builder}
    d.update(extra or {})
    return d


def main() -> int:
    slots_path = os.path.join(ROOT, "data", "art", "asset_slots.json")
    prev = {}
    if os.path.exists(slots_path):
        prev = json.load(open(slots_path, encoding="utf-8")).get("slots", {})
    slots = {}

    def keep(sid, d):
        p = prev.get(sid, {})
        for k in ("scene", "scale", "offset", "rotation_y"):
            if k in p:
                d[k] = p[k]
        d.setdefault("scene", "")
        d.setdefault("scale", 1.0)
        d.setdefault("offset", [0, 0, 0])
        d.setdefault("rotation_y", 0)
        slots[sid] = d

    for sid, (name, b, h, hh, space, fam, states, note) in UNITS.items():
        keep(sid, {"kind": "unit", "name": name, "card_id": sid.split(".")[1], "space": space, "height": h, "head_height": hh,
                   "rig_family": fam, "fit": "height", "animation_states": states, "proxy": proxy_spec(b), "notes": note})
    for sid, (name, b, h, hh, fam, states, note) in ENEMIES.items():
        keep(sid, {"kind": "enemy", "name": name, "enemy_id": sid.split(".")[1], "height": h, "head_height": hh,
                   "rig_family": fam, "fit": "height", "animation_states": states, "proxy": proxy_spec(b), "notes": note})
    for sid, (name, b, extra, h, fit, note) in STAGE.items():
        d = {"kind": "stage", "name": name, "height": h, "fit": fit, "proxy": proxy_spec(b, extra), "notes": note}
        if sid.startswith("stage.floor"):
            d["usable_width"] = 11.0
            d["depth"] = 3.2
        if sid == "stage.heart":
            d["rig_family"] = "static"
            d["animation_states"] = ["idle", "hit"]
        keep(sid, d)
    for sid, (name, b, h, note) in PROPS.items():
        keep(sid, {"kind": "prop", "name": name, "height": h, "fit": "natural", "proxy": proxy_spec(b),
                   "placement": "back edge only (z ~ -1.45); never on the front edge", "notes": note})
    for sid, (name, b, frame, note) in MUTATIONS.items():
        keep(sid, {"kind": "mutation", "name": name, "mutation_id": sid.split(".")[1], "frame": frame, "height": 1.0, "fit": "natural",
                   "proxy": proxy_spec(b), "notes": note + " Visual only: never changes collision or click targets."})
    for sid, (one_shot, note) in FX.items():
        keep(sid, {"kind": "fx", "name": sid[3:].replace("_", " "), "one_shot": one_shot, "height": 1.0, "fit": "none",
                   "proxy": proxy_spec(sid[3:]), "notes": note})

    doc = {"_note": "LASTROOT visual slot registry (generated by tools/synty/gen_slots.py; your scene/scale/offset/rotation_y edits are kept). "
                    "Set \"scene\" to a wrapper res://art/prefabs/<slot>.tscn to replace the proxy everywhere, or let tools/synty/build.sh map it "
                    "(data/art/slot_scenes.json). Origin = feet/base centre, facing -Z, metres. head_height = HP/attack badge anchor.",
           "slots": slots}
    os.makedirs(os.path.dirname(slots_path), exist_ok=True)
    with open(slots_path, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=1, ensure_ascii=False)
        fh.write("\n")

    # Vendor suggestions
    vs = {}
    for sid in slots:
        if sid.startswith("fx."):
            packs, search, notes = FX_HINT
            mix = {}
        else:
            packs, search, notes, mix = VENDOR[sid]
        entry = {"packs": packs, "search": search, "notes": notes, "verified": False, "status": UNVERIFIED}
        st = slots[sid].get("animation_states")
        fam = slots[sid].get("rig_family", "")
        if st and fam == "humanoid":
            entry["mixamo"] = {s: (mix.get(s) or MIXAMO.get(s, [])) for s in st}
        elif st and fam == "quadruped":
            entry["clips"] = {s: "use the pack's own %s clip (names vary: e.g. %s)" % (s, ", ".join(ANIM_KEYWORDS[s][:3])) for s in st}
        vs[sid] = entry
    vdoc = {"_note": "Search hints for which purchased pack/model could fill each slot. NOTHING here is verified against the real pack files "
                     "(verified=false everywhere): pack names are real product lines, but model names/patterns are typical naming conventions "
                     "used as search hints, not facts. Godot-ready downloads exist for some Synty packs (uncertain which — check each pack's "
                     "download page); otherwise use the FBX 'Source Files'. PolyPerfect ships Unity packages (FBX inside): unpack.py extracts them. "
                     "Mixamo clip names are search terms on mixamo.com. Rig families: one humanoid family covers all bipeds (Synty + Mixamo bone "
                     "names are mapped to SkeletonProfileHumanoid); Thornhart is a quadruped with its own clips; ash enemies reuse 2-3 humanoid "
                     "rigs with recolours/attachments; the boss is a large humanoid + custom crown attachment.",
            "status": UNVERIFIED, "slots": vs}
    with open(os.path.join(ROOT, "data", "art", "vendor_suggestions.json"), "w", encoding="utf-8") as fh:
        json.dump(vdoc, fh, indent=1, ensure_ascii=False)
        fh.write("\n")

    # Animation sets
    asets = json.loads(json.dumps(ANIMATION_SETS))
    for sid, d in slots.items():
        if d.get("rig_family"):
            asets["slots"][sid] = {"set": d["rig_family"], "states": d.get("animation_states", [])}
    asets["slots"]["enemy.E01"]["speed"] = 1.3
    with open(os.path.join(ROOT, "data", "art", "animation_sets.json"), "w", encoding="utf-8") as fh:
        json.dump(asets, fh, indent=1, ensure_ascii=False)
        fh.write("\n")

    # Ledgers (keep reviewed rows)
    def merge_csv(path, header, rows, key):
        old = {}
        if os.path.exists(path):
            with open(path, encoding="utf-8") as fh:
                for r in csv.DictReader(fh):
                    if r.get("review_status") not in ("PROXY", "NEEDED", None, ""):
                        old[r[key]] = r
        with open(path, "w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=header, lineterminator="\n")
            w.writeheader()
            for r in rows:
                w.writerow(old.get(r[key], r))

    rows = []
    for sid, d in slots.items():
        v = vs[sid]
        rows.append({"asset_id": "asset_" + sid.replace(".", "_"), "source_pack": " / ".join(v["packs"]), "source_path": "", "checksum": "",
                     "format": "procedural" if sid.startswith("fx.") else "FBX/GLB", "rig_id": d.get("rig_family", ""),
                     "scale_m": d.get("height", ""), "target_scene": "battle" if d["kind"] != "stage" else "battle/TreeStage",
                     "rights_status": "purchased_unverified", "slot_id": sid, "review_status": "PROXY"})
    merge_csv(os.path.join(ROOT, "docs", "ASSET_LEDGER.csv"),
              ["asset_id", "source_pack", "source_path", "checksum", "format", "rig_id", "scale_m", "target_scene", "rights_status", "slot_id", "review_status"],
              rows, "asset_id")
    arows = []
    for sid, d in slots.items():
        for st in d.get("animation_states", []):
            loop = st in ("idle", "move")
            ev = "contact" if st in ("attack", "cast") else ""
            arows.append({"clip_id": "%s_%s" % (sid.replace(".", "_"), st), "source_asset_id": "asset_" + sid.replace(".", "_"),
                          "rig_id": d.get("rig_family", ""), "state": st, "duration_s": "", "loop": str(loop).lower(), "in_place": "true",
                          "event_times": ev, "interrupt_policy": "any" if loop else "finish_or_timeout", "blend_in_s": "0.12", "blend_out_s": "0.12",
                          "review_status": "NEEDED" if d.get("rig_family") != "static" else "PROCEDURAL"})
    merge_csv(os.path.join(ROOT, "docs", "ANIMATION_LEDGER.csv"),
              ["clip_id", "source_asset_id", "rig_id", "state", "duration_s", "loop", "in_place", "event_times", "interrupt_policy", "blend_in_s", "blend_out_s", "review_status"],
              arows, "clip_id")
    print("slots: %d (units %d, enemies %d, stage %d, props %d, mutations %d, fx %d)" % (
        len(slots), len(UNITS), len(ENEMIES), len(STAGE), len(PROPS), len(MUTATIONS), len(FX)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
