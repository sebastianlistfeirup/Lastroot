extends TestCase
## LR-02: definitions, start decks, ids, validation reasons.


func test_24_types_22_normal_2_champions() -> void:
	var n := 0
	var c := 0
	var ids := {}
	for d: Dictionary in Catalog.cards():
		ids[d["id"]] = true
		if d["kind"] == "champion":
			c += 1
		else:
			n += 1
	eq(ids.size(), 24, "24 unique types")
	eq(n, 22, "22 normal")
	eq(c, 2, "2 champions")


func test_engine_data_matches_design_baseline() -> void:
	var design: Dictionary = JsonUtil.load_file("res://design/catalog.json")
	for d: Dictionary in design["cards"]:
		var e: Dictionary = Catalog.card(d["id"])
		eq(e["cost"], d["cost"], d["id"] + " cost")
		eq(e["space"], d["space"], d["id"] + " space")
		if d["attack"] != null:
			eq(e["attack"], d["attack"], d["id"] + " attack")
			eq(e["max_hp"], d["max_hp"], d["id"] + " max_hp")
	for d: Dictionary in design["enemies"]:
		var e: Dictionary = Catalog.enemy(d["id"])
		eq([e["attack"], e["max_hp"], e["start_armor"]], [d["attack"], d["max_hp"], d["start_armor"]], d["id"])


func test_both_start_decks_have_12_instances() -> void:
	for faction in ["BARK", "SPORE"]:
		var run := RunReducer.new_run(42, faction)
		eq((run["deck"] as Array).size(), 12, faction + " 12 cards")
		eq(RunReducer.normal_card_count(run), 11, faction + " 11 normal")
		var champ: String = run["deck"][0]["def_id"]
		eq(champ, "B01" if faction == "BARK" else "S01", faction + " champion")


func test_instance_ids_are_unique_and_monotone() -> void:
	var run := RunReducer.new_run(42, "BARK")
	var last := 0
	for inst: Dictionary in run["deck"]:
		check(int(inst["instance_id"]) > last, "monotone")
		last = inst["instance_id"]


func test_duplicate_id_rejected_with_reason() -> void:
	var d: Dictionary = (Catalog.data() as Dictionary).duplicate(true)
	d["cards"][1]["id"] = d["cards"][0]["id"]
	var errs := Catalog.validate(d)
	check(Array(errs).any(func(e: String) -> bool: return e.contains("duplicate card id B01")), "names the duplicate: %s" % [errs])


func test_unknown_effect_rejected_with_reason() -> void:
	var d: Dictionary = (Catalog.data() as Dictionary).duplicate(true)
	for c: Dictionary in d["cards"]:
		if c["id"] == "B07":
			c["spell"]["op"] = "explode"
	var errs := Catalog.validate(d)
	check(Array(errs).any(func(e: String) -> bool: return e.contains("B07: unknown effect 'explode'")), "names card and effect: %s" % [errs])
	check(not Catalog.install(d), "install refuses invalid data")
	eq(Catalog.card("B07")["spell"]["op"], "damage", "previous catalog kept")


func test_real_catalog_validates_clean() -> void:
	eq(Catalog.validate(Catalog.data()).size(), 0, "no errors")


func test_card_def_is_not_mutated_by_play() -> void:
	var before := JsonUtil.canonical(Catalog.data())
	var run := RunReducer.new_run(7, "SPORE")
	AutoPlayer.play_battle(run)
	eq(JsonUtil.canonical(Catalog.data()), before, "catalog unchanged after a battle")
