extends TestCase
## LR-14: one test per card type (24) with hand-calculated numbers, plus
## upgrades per instance and relic interactions on insert.


func _board() -> Dictionary:
	var s := BattleBuilder.empty()
	s["energy"] = 9
	return s


func _play(s: Dictionary, def_id: String, cmd: Dictionary, upgrade: String = "") -> Dictionary:
	var iid := BattleBuilder.give_card(s, def_id, upgrade)
	var c := {"type": "play_card", "card": iid}
	c.merge(cmd, true)
	var r := BattleReducer.apply(s, c)
	check(r["ok"], "%s legal: %s" % [def_id, r["error"]])
	return r


func _new_ally(r: Dictionary) -> Dictionary:
	var ins: Array = BattleBuilder.kinds(r["events"], "unit_inserted")
	return BattleReducer.unit(r["state"], ins[0]["target_id"]) if not ins.is_empty() else {}


func _creature(def_id: String, expect: Dictionary) -> void:
	var s := _board()
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var r := _play(s, def_id, {"floor": 0})
	var u := _new_ally(r)
	for k: String in expect.keys():
		eq(u.get(k), expect[k], "%s %s" % [def_id, k])


func test_b01_barkwarden() -> void:
	_creature("B01", {"attack": 4, "max_hp": 20, "armor": 8, "is_champion": true, "space": 2})


func test_b02_root_sprout() -> void:
	_creature("B02", {"attack": 2, "max_hp": 5, "armor": 0, "space": 1})


func test_b03_barkshield() -> void:
	_creature("B03", {"attack": 2, "max_hp": 14, "armor": 6, "space": 2})


func test_b04_thornhart() -> void:
	_creature("B04", {"attack": 5, "max_hp": 8, "thorns": 2, "space": 2})


func test_b05_sapbearer_heals_another() -> void:
	var s := _board()
	var a := BattleBuilder.ally(s, 1, {"max_hp": 10, "hp": 4})
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var iid := BattleBuilder.give_card(s, "B05")
	check(not BattleReducer.apply(s, {"type": "play_card", "card": iid, "floor": 0})["ok"], "needs a heal target when allies exist")
	var r := BattleReducer.apply(s, {"type": "play_card", "card": iid, "floor": 0, "target": a})
	eq(BattleReducer.unit(r["state"], a)["hp"], 7, "heal 3")


func test_b05_sapbearer_alone_still_inserts() -> void:
	var s := _board()
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var r := _play(s, "B05", {"floor": 0})
	eq(_new_ally(r).get("max_hp"), 7, "inserted without a heal target")


func test_b06_old_oak() -> void:
	_creature("B06", {"attack": 8, "max_hp": 22, "space": 3})


func test_b07_root_strike() -> void:
	var s := _board()
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 10, "armor": 2})
	var r := _play(s, "B07", {"target": e})
	eq([BattleReducer.unit(r["state"], e)["hp"], BattleReducer.unit(r["state"], e)["armor"]], [7, 0], "5 damage, armor first")
	r = _play(s, "B07", {"target": e}, "damage_3")
	eq(BattleReducer.unit(r["state"], e)["hp"], 4, "upgraded 8 damage")


func test_b08_barkskin() -> void:
	var s := _board()
	var a := BattleBuilder.ally(s, 0, {})
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	eq(BattleReducer.unit(_play(s, "B08", {"target": a})["state"], a)["armor"], 6, "6 armor")
	eq(BattleReducer.unit(_play(s, "B08", {"target": a}, "armor_2")["state"], a)["armor"], 8, "upgraded 8")


func test_b09_root_net() -> void:
	var s := _board()
	var e1 := BattleBuilder.enemy(s, 1, {"max_hp": 10})
	var e2 := BattleBuilder.enemy(s, 1, {"max_hp": 10})
	var e3 := BattleBuilder.enemy(s, 0, {"max_hp": 10})
	var r := _play(s, "B09", {"floor": 1})
	eq([BattleReducer.unit(r["state"], e1)["hp"], BattleReducer.unit(r["state"], e2)["hp"], BattleReducer.unit(r["state"], e3)["hp"]], [7, 7, 10], "3 to the chosen floor only")


func test_b10_branch_lift() -> void:
	var s := _board()
	var a := BattleBuilder.ally(s, 0, {})
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var r := _play(s, "B10", {"target": a})
	var u := BattleReducer.unit(r["state"], a)
	eq(u["floor"], 1, "lifted to the Trunk")
	eq(u["moved_this_turn"], false, "does not use its normal move")
	eq(CardStats.cost(Catalog.card("B10"), "cost_-1"), 0, "upgrade makes it free")


func test_b10_needs_space_above() -> void:
	var s := _board()
	var a := BattleBuilder.ally(s, 0, {})
	BattleBuilder.ally(s, 1, {"space": 5})
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var iid := BattleBuilder.give_card(s, "B10")
	check(not BattleReducer.apply(s, {"type": "play_card", "card": iid, "target": a})["ok"], "full Trunk refuses")


func test_b11_sap_flood() -> void:
	var s := _board()
	var a := BattleBuilder.ally(s, 1, {"max_hp": 10, "hp": 2})
	var b := BattleBuilder.ally(s, 1, {"max_hp": 10, "hp": 9})
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var r := _play(s, "B11", {"floor": 1})
	eq([BattleReducer.unit(r["state"], a)["hp"], BattleReducer.unit(r["state"], b)["hp"]], [7, 10], "heal 5, capped")


func test_b12_last_twig_not_champion() -> void:
	var s := _board()
	var ch := BattleBuilder.ally(s, 0, {"is_champion": true})
	BattleReducer.unit(s, ch)["is_champion"] = true
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var iid := BattleBuilder.give_card(s, "B12")
	check(not BattleReducer.apply(s, {"type": "play_card", "card": iid, "target": ch})["ok"], "champion cannot be removed")
	eq(CardStats.legal_upgrades(Catalog.card("B12"), "").size(), 0, "B12 has no upgrade")


func test_s01_spore_sage() -> void:
	_creature("S01", {"attack": 2, "max_hp": 16, "on_hit_poison": 2, "is_champion": true})


func test_s02_sporeling_on_hit() -> void:
	var s := _board()
	var a := BattleBuilder.ally(s, 0, {"attack": 1, "on_hit_poison": 1}, "S02")
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 10, "attack": 0})
	var ev: Array = []
	BattleReducer.attack(s, ev, a)
	eq(BattleReducer.unit(s, e)["poison"], 1, "poison 1 on a surviving target")
	var e2 := BattleBuilder.enemy(s, 1, {"max_hp": 1, "attack": 0})
	var a2 := BattleBuilder.ally(s, 1, {"attack": 1, "on_hit_poison": 1}, "S02")
	BattleReducer.attack(s, ev, a2)
	eq(BattleReducer.unit(s, e2)["poison"], 0, "no poison on a killed target")


func test_s03_fungal_wall() -> void:
	_creature("S03", {"attack": 1, "max_hp": 16, "growth": 2})


func test_s04_nightcap_bonus_vs_poisoned() -> void:
	var s := _board()
	var a := BattleBuilder.ally(s, 0, {"attack": 5, "bonus_vs_poisoned": 3}, "S04")
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 20, "poison": 1, "attack": 0})
	BattleReducer.attack(s, [], a)
	eq(BattleReducer.unit(s, e)["hp"], 12, "5 + 3 against a poisoned target")


func test_s05_mycelium_keeper() -> void:
	var s := _board()
	var other := BattleBuilder.ally(s, 1, {})
	var far := BattleBuilder.ally(s, 0, {})
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var r := _play(s, "S05", {"floor": 1})
	eq(BattleReducer.unit(r["state"], other)["growth"], 1, "same floor gets Growth 1")
	eq(BattleReducer.unit(r["state"], far)["growth"], 0, "other floors do not")
	eq(_new_ally(r)["growth"], 0, "not itself")


func test_s06_spore_colossus_on_death() -> void:
	var s := _board()
	var c := BattleBuilder.ally(s, 1, {"max_hp": 1, "attack": 0, "space": 3}, "S06")
	var killer := BattleBuilder.enemy(s, 1, {"attack": 5, "max_hp": 30})
	var other := BattleBuilder.enemy(s, 1, {"attack": 0, "max_hp": 30})
	var ev: Array = []
	BattleReducer.attack(s, ev, killer)
	eq([BattleReducer.unit(s, killer)["poison"], BattleReducer.unit(s, other)["poison"]], [3, 3], "Poison 3 to all enemies on the floor")
	check(not BattleReducer.unit(s, c)["alive"], "colossus dead")


func test_s07_toxic_breath() -> void:
	var s := _board()
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 10})
	eq(BattleReducer.unit(_play(s, "S07", {"target": e})["state"], e)["poison"], 3, "Poison 3")
	eq(BattleReducer.unit(_play(s, "S07", {"target": e}, "poison_1")["state"], e)["poison"], 4, "upgraded 4")


func test_s08_spore_fog() -> void:
	var s := _board()
	var e1 := BattleBuilder.enemy(s, 2, {"max_hp": 10})
	var e2 := BattleBuilder.enemy(s, 2, {"max_hp": 10})
	var r := _play(s, "S08", {"floor": 2})
	eq([BattleReducer.unit(r["state"], e1)["poison"], BattleReducer.unit(r["state"], e2)["poison"]], [2, 2], "Poison 2 each")
	var iid := BattleBuilder.give_card(s, "S08")
	check(not BattleReducer.apply(s, {"type": "play_card", "card": iid, "floor": 0})["ok"], "empty floor refused")


func test_s09_lifethread() -> void:
	var s := _board()
	var a := BattleBuilder.ally(s, 0, {"max_hp": 10, "hp": 3})
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var u := BattleReducer.unit(_play(s, "S09", {"target": a})["state"], a)
	eq([u["hp"], u["growth"]], [7, 1], "heal 4 + Growth 1")
	u = BattleReducer.unit(_play(s, "S09", {"target": a}, "heal_2")["state"], a)
	eq([u["hp"], u["growth"]], [9, 1], "upgraded heal 6, Growth unchanged")


func test_s10_decompose() -> void:
	var s := _board()
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 20, "armor": 10})
	var u := BattleReducer.unit(_play(s, "S10", {"target": e})["state"], e)
	eq([u["armor"], u["hp"]], [0, 19], "strip 8 then 3 damage (2 armor absorbs)")


func test_s11_bloom_needs_poison() -> void:
	var s := _board()
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 20})
	var iid := BattleBuilder.give_card(s, "S11")
	check(not BattleReducer.apply(s, {"type": "play_card", "card": iid, "target": e})["ok"], "needs a poisoned enemy")


func test_s12_spore_rain_consumed() -> void:
	var s := _board()
	var e1 := BattleBuilder.enemy(s, 0, {"max_hp": 20})
	var e2 := BattleBuilder.enemy(s, 2, {"max_hp": 20})
	var iid := BattleBuilder.give_card(s, "S12")
	var r := BattleReducer.apply(s, {"type": "play_card", "card": iid})
	eq([BattleReducer.unit(r["state"], e1)["poison"], BattleReducer.unit(r["state"], e2)["poison"]], [1, 1], "every floor")
	check((r["state"]["zones"]["consumed"] as Array).has(iid), "consumed")


func test_upgrade_is_per_instance() -> void:
	var run := RunReducer.new_run(3, "BARK")
	var b: Dictionary = BattleFactory.create(run, 0)["state"]
	var ids: Array = []
	for key: String in b["deck"].keys():
		if b["deck"][key]["def_id"] == "B07":
			ids.append(int(key))
	b["deck"][str(ids[0])]["upgrade_id"] = "damage_3"
	eq(CardStats.spell_amount(Catalog.card("B07"), BattleReducer.card_upgrade(b, ids[0]), "damage"), 8, "upgraded copy 8")
	eq(CardStats.spell_amount(Catalog.card("B07"), BattleReducer.card_upgrade(b, ids[1]), "damage"), 5, "other copy 5")


func test_relics_on_insert() -> void:
	var s := _board()
	s["relics"] = ["R01", "R07"]
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	var bark := _new_ally(_play(s, "B02", {"floor": 0}))
	eq([bark["armor"], bark["max_hp"]], [3, 8], "Bark Pearl +3 armor, Amber Core +3 max HP")
	var champ := _new_ally(_play(s, "B01", {"floor": 1}))
	eq([champ["armor"], champ["max_hp"]], [11, 20], "champion gets R01 but not R07")
	var spore := _new_ally(_play(s, "S02", {"floor": 2}))
	eq([spore["armor"], spore["max_hp"]], [0, 9], "Spore creature: no R01")


func test_sun_seed_and_leaf_book_first_turn() -> void:
	var run := RunReducer.new_run(8, "SPORE")
	run["relics"] = ["R04", "R06"]
	var b: Dictionary = BattleFactory.create(run, 0)["state"]
	eq(b["energy"], 4, "Sun Seed +1 Sap on turn 1")
	eq((b["zones"]["hand"] as Array).size(), 7, "champion + 6 with Leaf Book")
	var r := BattleReducer.apply(b, {"type": "end_turn"})
	eq(r["state"]["energy"], 3, "turn 2 back to 3")


func test_lifeweaver_and_gentle_crown_turn_start() -> void:
	var s := _board()
	s["champion_path"] = "LIFEWEAVER"
	s["champion_rank"] = 2
	s["mutations"] = ["M03"]
	var ch := BattleBuilder.ally(s, 2, {"max_hp": 20, "hp": 10})
	BattleReducer.unit(s, ch)["is_champion"] = true
	var mate := BattleBuilder.ally(s, 2, {"max_hp": 20, "hp": 10})
	BattleBuilder.enemy(s, 0, {"max_hp": 99, "attack": 0})
	BattleReducer.begin_turn(s, [])
	eq([BattleReducer.unit(s, ch)["hp"], BattleReducer.unit(s, mate)["hp"]], [14, 14], "M03 2 + Lifeweaver 2")


func test_venom_master_and_bulwark_stats() -> void:
	eq(CardStats.unit_stats(Catalog.card("S01"), "", "VENOM", 2)["on_hit_poison"], 4, "2 + 2")
	var st := CardStats.unit_stats(Catalog.card("B01"), "", "BULWARK", 1)
	eq([st["max_hp"], st["armor"]], [28, 12], "20+8 / 8+4")


func test_bloom_does_not_use_spore_lantern() -> void:
	# D14: S11 doubles existing Poison and does not count as the R03 "first Poison".
	var s := _board()
	s["relics"] = ["R03"]
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 50, "poison": 2})
	var r := _play(s, "S11", {"target": e})
	var s2: Dictionary = r["state"]
	eq(s2["flags"]["r03"], false, "Bloom leaves the Spore Lantern unused")
	var r2 := _play(s2, "S07", {"target": e})
	eq(BattleReducer.unit(r2["state"], e)["poison"], 8, "4 after Bloom + 3 + 1 from R03")


## Upgrade matrix (LR-14): every card x every catalog upgrade, played through
## the real reducer on the same board as the plain card. The upgraded copy
## changes exactly its stat; B01/B12/S01 have no upgrades.
func _matrix_board() -> Dictionary:
	var s := _board()
	for f in 3:
		BattleBuilder.enemy(s, f, {"max_hp": 99, "poison": 3})
	BattleBuilder.ally(s, 0, {"max_hp": 30, "hp": 4})
	BattleBuilder.ally(s, 1, {"max_hp": 30, "hp": 4})
	return s


func _legal_cmd(def_id: String) -> Dictionary:
	var s := _matrix_board()
	var iid := BattleBuilder.give_card(s, def_id)
	var targets: Array = [-1]
	for k: String in (s["units"] as Dictionary).keys():
		targets.append(int(k))
	for f in [-1, 0, 1, 2]:
		for t: int in targets:
			var c := {"type": "play_card", "card": iid, "floor": f, "target": t}
			if BattleReducer.validate(s, c) == "":
				return {"floor": f, "target": t}
	return {}


func _sum(events: Array, kind: String) -> Array:
	var total := 0
	var n := 0
	for e: Dictionary in events:
		if e.get("kind", "") == kind:
			total += int(e.get("amount", 0))
			n += 1
	return [total, n]


func test_upgrade_matrix_all_cards() -> void:
	var stat_event := {"damage": "damage", "poison": "poison_applied", "heal": "heal", "armor": "armor_gained"}
	var covered := 0
	for c: Dictionary in Catalog.data()["cards"]:
		var cid: String = c["id"]
		var ups: Array = c.get("upgrades", [])
		if cid in ["B01", "B12", "S01"]:
			eq(ups.size(), 0, "%s has no upgrades" % cid)
			continue
		check(not ups.is_empty(), "%s has an upgrade" % cid)
		var cmd := _legal_cmd(cid)
		if cmd.is_empty():
			check(false, "%s: no legal play found on the matrix board" % cid)
			continue
		for u: Dictionary in ups:
			var uid: String = u["id"]
			var base := _play(_matrix_board(), cid, cmd)
			var up := _play(_matrix_board(), cid, cmd, uid)
			var stat: String = uid.rsplit("_", true, 1)[0]
			var delta: int = int(uid.rsplit("_", true, 1)[1])
			if stat in ["attack", "max_hp"]:
				eq(int(_new_ally(up).get(stat, 0)) - int(_new_ally(base).get(stat, 0)), delta, "%s+%s on the unit" % [cid, uid])
			elif stat == "cost":
				var s := _matrix_board()
				var a := BattleBuilder.give_card(s, cid)
				var b := BattleBuilder.give_card(s, cid, uid)
				eq(BattleReducer.play_cost(s, b) - BattleReducer.play_cost(s, a), delta, "%s %s cost" % [cid, uid])
				eq(int(base["state"]["energy"]) - int(up["state"]["energy"]), delta, "%s %s Sap paid" % [cid, uid])
			else:
				var kb: Array = _sum(base["events"], stat_event[stat])
				var ku: Array = _sum(up["events"], stat_event[stat])
				check(int(ku[1]) > 0, "%s %s produces %s" % [cid, uid, stat_event[stat]])
				eq(int(ku[0]) - int(kb[0]), delta * int(ku[1]), "%s %s adds %d per hit" % [cid, uid, delta])
			covered += 1
	eq(covered, 31, "card x upgrade pairs covered")
