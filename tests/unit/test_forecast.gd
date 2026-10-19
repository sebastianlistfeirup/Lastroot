extends TestCase
## LR-06 / LR-19: forecast == real resolution for every stored scenario
## (canonical next_state hash AND ordered events), original never mutated,
## and identical after a save/load roundtrip of the state.

const FIX := "res://fixtures/forecast/scenarios.json"


func _scenarios() -> Array:
	var d: Variant = JsonUtil.load_file(FIX)
	if typeof(d) != TYPE_DICTIONARY:
		return []
	return d["scenarios"]


func test_at_least_100_scenarios_stored() -> void:
	check(_scenarios().size() >= 100, "found %d" % _scenarios().size())


func test_forecast_matches_real_resolution() -> void:
	var n := 0
	for sc: Dictionary in _scenarios():
		var s: Dictionary = sc["state"]
		var before := JsonUtil.state_hash(s)
		Forecast.clear_cache()
		var f := Forecast.end_turn(s)
		eq(JsonUtil.state_hash(s), before, sc["id"] + " original untouched")
		eq(f["hash"], sc["expected_hash"], sc["id"] + " forecast state == stored expectation")
		eq(JsonUtil.state_hash(f["events"]), sc["expected_events"], sc["id"] + " forecast events == stored")
		var real := BattleReducer.apply(s, {"type": "end_turn"})
		check(real["ok"], sc["id"] + " end_turn legal")
		eq(real["resolved_hash"], f["hash"], sc["id"] + " real resolved state == forecast")
		var res_ev: Array = (real["events"] as Array).filter(func(e: Dictionary) -> bool: return e["stage"] == "resolution")
		eq(JsonUtil.canonical(res_ev), JsonUtil.canonical(f["events"]), sc["id"] + " real events == forecast events")
		n += 1
	check(n >= 100, "ran %d" % n)


func test_forecast_after_save_roundtrip() -> void:
	var i := 0
	for sc: Dictionary in _scenarios():
		i += 1
		if i % 5 != 0:
			continue
		var s: Dictionary = sc["state"]
		var copy: Dictionary = JsonUtil.parse(JsonUtil.canonical(s))
		Forecast.clear_cache()
		eq(Forecast.end_turn(copy)["hash"], sc["expected_hash"], sc["id"] + " same after JSON roundtrip")


func test_coverage_spans_required_cases() -> void:
	var cov := {}
	for sc: Dictionary in _scenarios():
		for t: String in sc["tags"]:
			cov[t] = true
	for need in ["death", "thorns", "poison", "moved", "mutation", "relic", "boss", "heart_damage", "climb"]:
		check(cov.has(need), "scenario coverage includes " + need)


func test_preview_uses_no_sap_flags_or_rng() -> void:
	var run := RunReducer.new_run(2024, "SPORE")
	var s: Dictionary = run["battle"]
	var before := JsonUtil.state_hash(s)
	for cmd: Dictionary in AutoPlayer.legal_commands(s):
		Forecast.after_command(s, cmd)
	eq(JsonUtil.state_hash(s), before, "no preview mutates the battle")
