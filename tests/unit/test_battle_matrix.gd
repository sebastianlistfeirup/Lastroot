extends TestCase
## Bible p.21 test matrix T01-T10 plus the listed extra edges, hand-calculated.



func test_t01_poison_ignores_armor() -> void:
	var s := BattleBuilder.empty()
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 9, "hp": 5, "armor": 4, "poison": 3, "attack": 0})
	BattleBuilder.resolve(s)
	var u := BattleReducer.unit(s, e)
	eq(u["hp"], 2, "hp after poison phase")
	eq(u["poison"], 2, "poison reduced by 1")
	eq(u["armor"], 4, "armor untouched by poison")


func test_t02_snapshot_thorns_and_two_deaths() -> void:
	var s := BattleBuilder.empty()
	var target := BattleBuilder.ally(s, 0, {"max_hp": 3, "armor": 1, "thorns": 2, "attack": 0})
	var attacker := BattleBuilder.enemy(s, 0, {"attack": 5, "max_hp": 2})
	var ev: Array = []
	BattleReducer.attack(s, ev, attacker)
	check(not BattleReducer.unit(s, target)["alive"], "target dies")
	check(not BattleReducer.unit(s, attacker)["alive"], "attacker dies from snapshot thorns")
	eq(BattleBuilder.kinds(ev, "death").size(), 2, "exactly two death events")
	eq(BattleBuilder.kinds(ev, "thorns").size(), 1, "one thorns response, no recursion")


func test_t03_enemy_climbs_once_without_second_fight() -> void:
	var s := BattleBuilder.empty()
	var ally := BattleBuilder.ally(s, 1, {"attack": 1, "max_hp": 10})
	var e := BattleBuilder.enemy(s, 0, {"attack": 3, "max_hp": 30})
	var ev := BattleBuilder.resolve(s)
	eq(BattleReducer.unit(s, e)["floor"], 1, "enemy ends on the Trunk")
	eq(BattleReducer.unit(s, ally)["hp"], 10, "no fight on the Trunk this turn")
	eq(BattleBuilder.kinds(ev, "enemy_climbed").size(), 1, "one climb")


func test_t04_m02_is_derived_not_accumulated() -> void:
	var s := BattleBuilder.empty()
	s["mutations"] = ["M02"]
	var a := BattleBuilder.ally(s, 0, {"attack": 2})
	BattleBuilder.enemy(s, 2, {"max_hp": 99})
	s["energy"] = 9
	var r := BattleReducer.apply(s, {"type": "move", "unit": a, "floor": 1})
	check(r["ok"], "move up: " + str(r["error"]))
	eq(BattleReducer.attack_value(r["state"], BattleReducer.unit(r["state"], a)), 3, "attack 3 on the Trunk")
	var s2: Dictionary = r["state"]
	BattleReducer.unit(s2, a)["moved_this_turn"] = false
	r = BattleReducer.apply(s2, {"type": "move", "unit": a, "floor": 0})
	eq(BattleReducer.attack_value(r["state"], BattleReducer.unit(r["state"], a)), 2, "attack 2 outside")
	eq(BattleReducer.unit(r["state"], a)["attack"], 2, "stored attack never changes")


func test_t05_last_twig_removes_without_death() -> void:
	var s := BattleBuilder.empty()
	var colossus := BattleBuilder.ally(s, 0, {"attack": 6, "max_hp": 20, "space": 3}, "S06")
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 20})
	var hand_before: int = (s["zones"]["hand"] as Array).size()
	var iid := BattleBuilder.give_card(s, "B12")
	var r := BattleReducer.apply(s, {"type": "play_card", "card": iid, "target": colossus})
	check(r["ok"], "B12 legal: " + str(r["error"]))
	var ns: Dictionary = r["state"]
	eq(BattleBuilder.kinds(r["events"], "death").size(), 0, "no death event")
	eq(BattleReducer.unit(ns, e)["poison"], 0, "no Spore Colossus death poison")
	check((ns["zones"]["consumed"] as Array).has(iid), "B12 consumed")
	eq((ns["zones"]["hand"] as Array).size(), hand_before + 2, "drew two")
	check(not BattleReducer.floor_list(ns, 0, "ally").has(colossus), "unit removed from the floor")


func test_t06_bloom_cap_never_lowers() -> void:
	for pair in [[7, 12], [14, 14], [3, 6]]:
		var s := BattleBuilder.empty()
		var e := BattleBuilder.enemy(s, 0, {"poison": pair[0], "max_hp": 50})
		var iid := BattleBuilder.give_card(s, "S11")
		s["energy"] = 3
		var r := BattleReducer.apply(s, {"type": "play_card", "card": iid, "target": e})
		check(r["ok"], "bloom legal")
		eq(BattleReducer.unit(r["state"], e)["poison"], pair[1], "bloom %d" % pair[0])


func test_t07_spore_lantern_lowest_id_and_preview() -> void:
	var s := BattleBuilder.empty()
	s["relics"] = ["R03"]
	s["next_unit_id"] = 3
	var low := BattleBuilder.enemy(s, 1, {"max_hp": 20})
	s["next_unit_id"] = 8
	var high := BattleBuilder.enemy(s, 1, {"max_hp": 20})
	# Enemy with id 8 stands in front, id 3 behind: the bonus still goes to id 3.
	s["floors"][1]["enemies"] = [high, low]
	var iid := BattleBuilder.give_card(s, "S08")
	s["energy"] = 3
	var pre := Forecast.after_command(s, {"type": "play_card", "card": iid, "floor": 1})
	check(pre["ok"], "preview ok")
	eq(s["flags"]["r03"], false, "preview does not use the flag")
	var r := BattleReducer.apply(s, {"type": "play_card", "card": iid, "floor": 1})
	eq(BattleReducer.unit(r["state"], low)["poison"], 3, "id 3 gets 3")
	eq(BattleReducer.unit(r["state"], high)["poison"], 2, "id 8 gets 2")


func test_t08_double_claim_pays_once() -> void:
	var run := _won_first_battle(77)
	check(run["phase"] == "reward", "in rewards")
	var resin: int = run["resin"]
	eq(resin, 50, "30 + 20 Resin")
	var slot: Dictionary = RunReducer.current_slot(run)
	var choice: String = slot["offer"][0]
	var r1 := RunReducer.apply(run, {"type": "claim", "slot": slot["id"], "choice": choice})
	check(r1["ok"], "first claim ok")
	var r2 := RunReducer.apply(r1["run"], {"type": "claim", "slot": slot["id"], "choice": choice})
	check(not r2["ok"], "second claim rejected")
	eq(r1["run"]["resin"], 50, "Resin not paid twice")
	eq((r1["run"]["deck"] as Array).size(), 13, "exactly one card added")


func test_t09_unplayed_champion_stays_and_draw_is_five() -> void:
	var run := BattleBuilder.run(5, "SPORE")
	var s: Dictionary = run["battle"]
	var champ: int = s["champion_iid"]
	check((s["zones"]["hand"] as Array).has(champ), "champion in first hand")
	eq((s["zones"]["hand"] as Array).size(), 6, "champion + 5 normal")
	var r := BattleReducer.apply(s, {"type": "end_turn"})
	var hand: Array = r["state"]["zones"]["hand"]
	check(hand.has(champ), "champion still in hand")
	eq(hand.size(), 6, "next turn draws 5 normal cards")


func test_t10_no_early_victory_before_last_wave() -> void:
	var run := BattleBuilder.run(9)
	var s: Dictionary = run["battle"]
	var e: int = BattleReducer.floor_list(s, 0, "enemy")[0]
	BattleReducer.unit(s, e)["poison"] = 99
	var r := BattleReducer.apply(s, {"type": "end_turn"})
	eq(r["state"]["terminal_result"], "", "no victory after wave 1")
	eq(r["state"]["wave_index"], 2, "wave 2 arrived on turn 2")


func test_invalid_target_spends_nothing() -> void:
	var s := BattleBuilder.empty()
	BattleBuilder.enemy(s, 0, {})
	var iid := BattleBuilder.give_card(s, "B07")
	s["energy"] = 3
	var before := JsonUtil.state_hash(s)
	var r := BattleReducer.apply(s, {"type": "play_card", "card": iid, "target": 4242})
	check(not r["ok"], "rejected")
	check(str(r["error"]).length() > 0, "has a reason")
	eq(JsonUtil.state_hash(s), before, "original untouched")
	eq(r["state"]["energy"], 3, "no Sap spent")


func test_zero_cost_spell_uses_dewdrop_flag() -> void:
	var s := BattleBuilder.empty()
	s["relics"] = ["R02"]
	var a := BattleBuilder.ally(s, 0, {"max_hp": 5}, "B02")
	BattleBuilder.enemy(s, 2, {"max_hp": 50})
	s["energy"] = 3
	var twig := BattleBuilder.give_card(s, "B12")
	var strike := BattleBuilder.give_card(s, "B07")
	var r := BattleReducer.apply(s, {"type": "play_card", "card": twig, "target": a})
	check(r["ok"], "twig ok")
	eq(r["state"]["flags"]["r02"], true, "flag used by the 0-cost spell")
	eq(BattleReducer.play_cost(r["state"], strike), 1, "next spell pays full price")


func test_wanderers_ring_only_normal_moves() -> void:
	var s := BattleBuilder.empty()
	s["relics"] = ["R08"]
	var a := BattleBuilder.ally(s, 0, {})
	var b := BattleBuilder.ally(s, 0, {})
	BattleBuilder.enemy(s, 2, {"max_hp": 50})
	s["energy"] = 3
	var lift := BattleBuilder.give_card(s, "B10")
	var r := BattleReducer.apply(s, {"type": "play_card", "card": lift, "target": a})
	eq(r["state"]["flags"]["r08"], false, "Branch Lift does not use the ring")
	r = BattleReducer.apply(r["state"], {"type": "move", "unit": b, "floor": 1})
	eq(r["state"]["energy"], 2, "first normal move free (3 - 1 lift)")
	eq(r["state"]["flags"]["r08"], true, "ring used")


func test_heart_zero_beats_victory() -> void:
	var s := BattleBuilder.empty()
	s["heart"] = 2
	var e := BattleBuilder.enemy(s, 2, {"attack": 5, "max_hp": 50})
	BattleBuilder.resolve(s)
	eq(s["terminal_result"], "lost", "heart 0 is defeat even with an empty board")
	check(not BattleReducer.unit(s, e)["alive"], "enemy left over the Crown")


func test_heart_damage_is_at_least_one() -> void:
	var s := BattleBuilder.empty()
	BattleBuilder.enemy(s, 2, {"attack": 0, "max_hp": 50})
	BattleBuilder.enemy(s, 0, {"attack": 1, "max_hp": 50})
	var before: int = s["heart"]
	BattleBuilder.resolve(s)
	eq(s["heart"], before - 1, "max(1, attack)")


func test_full_floor_rejects_insert_with_reason() -> void:
	var s := BattleBuilder.empty()
	BattleBuilder.enemy(s, 0, {})
	BattleBuilder.ally(s, 0, {"space": 5})
	var iid := BattleBuilder.give_card(s, "B02")
	s["energy"] = 3
	var r := BattleReducer.apply(s, {"type": "play_card", "card": iid, "floor": 0})
	check(not r["ok"], "full floor rejected")
	check(str(r["error"]).contains("No space"), "reason names space: " + str(r["error"]))


func test_m01_adds_root_space() -> void:
	var s := BattleBuilder.empty()
	s["mutations"] = ["M01"]
	eq(BattleReducer.capacity(s, 0), 6, "Roots 6")
	eq(BattleReducer.capacity(s, 1), 5, "Trunk 5")


func test_deterministic_same_input_same_output() -> void:
	var run := BattleBuilder.run(31337)
	var s: Dictionary = run["battle"]
	var a := BattleReducer.apply(s, {"type": "end_turn"})
	var b := BattleReducer.apply(s, {"type": "end_turn"})
	eq(JsonUtil.canonical(a["state"]), JsonUtil.canonical(b["state"]), "same state")
	eq(JsonUtil.canonical(a["events"]), JsonUtil.canonical(b["events"]), "same events")


func test_card_in_exactly_one_zone_and_dead_stay_out() -> void:
	var run := BattleBuilder.run(4)
	var s: Dictionary = run["battle"]
	var hand: Array = s["zones"]["hand"]
	var sprout := -1
	for iid: int in hand:
		if BattleReducer.card_def(s, iid)["id"] == "B02":
			sprout = iid
	check(sprout >= 0, "a Root Sprout in hand")
	var r := BattleReducer.apply(s, {"type": "play_card", "card": sprout, "floor": 0, "position": 0})
	check(r["ok"], "play sprout: " + str(r["error"]))
	s = r["state"]
	for t in 12:
		if s["terminal_result"] != "":
			break
		s = BattleReducer.apply(s, {"type": "end_turn"})["state"]
		var seen := {}
		for z: String in s["zones"].keys():
			for iid: int in s["zones"][z]:
				check(not seen.has(iid), "card %d in two zones" % iid)
				seen[iid] = z
		eq(seen.get(sprout, ""), "deployed", "played creature stays deployed")


func test_boss_anchored_with_defender() -> void:
	var s := BattleBuilder.empty()
	BattleBuilder.ally(s, 0, {"max_hp": 999, "attack": 0})
	var boss := BattleBuilder.enemy(s, 0, {"attack": 8, "max_hp": 60, "armor": 8, "is_boss": true}, "E06")
	BattleBuilder.resolve(s)
	eq(BattleReducer.unit(s, boss)["floor"], 0, "boss stays on the Roots with a living defender")


func test_boss_climbs_once_without_defender() -> void:
	var s := BattleBuilder.empty()
	var boss := BattleBuilder.enemy(s, 0, {"attack": 8, "max_hp": 60, "is_boss": true}, "E06")
	BattleBuilder.ally(s, 1, {"max_hp": 999, "attack": 0})
	var ev := BattleBuilder.resolve(s)
	eq(BattleReducer.unit(s, boss)["floor"], 1, "boss climbs to the Trunk once")
	eq(BattleBuilder.kinds(ev, "attack").size(), 0, "boss does not attack again after climbing")


func test_boss_leaving_crown_loses() -> void:
	var s := BattleBuilder.empty()
	s["heart"] = 60
	BattleBuilder.enemy(s, 2, {"attack": 8, "max_hp": 60, "is_boss": true}, "E06")
	BattleBuilder.resolve(s)
	eq(s["terminal_result"], "lost", "boss over the Crown is defeat")
	eq(s["heart"], 60, "regardless of heart")


func test_boss_escalates_from_turn_ten() -> void:
	var s := BattleBuilder.empty()
	var boss := BattleBuilder.enemy(s, 0, {"attack": 8, "max_hp": 60, "is_boss": true}, "E06")
	BattleBuilder.ally(s, 0, {"max_hp": 9999, "attack": 0})
	s["turn"] = 8
	var ev: Array = []
	BattleReducer.begin_turn(s, ev)
	eq(BattleReducer.unit(s, boss)["attack"], 8, "turn 9 no escalation")
	BattleReducer.begin_turn(s, ev)
	eq(BattleReducer.unit(s, boss)["attack"], 10, "turn 10 +2")
	BattleReducer.begin_turn(s, ev)
	eq(BattleReducer.unit(s, boss)["attack"], 12, "turn 11 +2")


func test_growth_heals_to_max_and_cannot_revive() -> void:
	var s := BattleBuilder.empty()
	var a := BattleBuilder.ally(s, 1, {"max_hp": 10, "hp": 9, "growth": 5, "attack": 0})
	BattleBuilder.enemy(s, 2, {"max_hp": 50, "attack": 0})
	BattleBuilder.resolve(s)
	eq(BattleReducer.unit(s, a)["hp"], 10, "capped at max_hp")


func test_new_poison_does_not_tick_twice() -> void:
	# Spore Colossus dies in the poison phase; its death poison lands on an
	# enemy that already ticked and must not tick again this phase.
	var s := BattleBuilder.empty()
	var col := BattleBuilder.ally(s, 0, {"max_hp": 20, "hp": 1, "space": 3, "attack": 0}, "S06")
	BattleReducer.unit(s, col)["poison"] = 1
	var e := BattleBuilder.enemy(s, 0, {"max_hp": 30, "attack": 0, "poison": 2})
	var ev := BattleBuilder.resolve(s)
	var ticks: Array = BattleBuilder.kinds(ev, "poison_tick")
	eq(ticks.size(), 2, "two ticks (colossus, enemy)")
	# enemy: 30 - 2 = 28; poison 2 -> 1 then +3 from death = 4 (death happens
	# after the colossus tick, before the enemy tick in id order: colossus id lower).
	eq(BattleReducer.unit(s, e)["hp"] if BattleReducer.unit(s, e)["alive"] else -1, 28, "ticked once by the snapshot amount")
	eq(BattleReducer.unit(s, e)["floor"], 1, "enemy climbed")


func _won_first_battle(seed_value: int) -> Dictionary:
	var run := AutoPlayer.play_battle(BattleBuilder.run(seed_value))
	check(run["phase"] == "reward", "bot wins battle 1 (seed %d, phase %s)" % [seed_value, run["phase"]])
	return run
