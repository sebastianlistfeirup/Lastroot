extends SceneTree
## Regenerates fixtures/forecast/scenarios.json (120 scenarios).
## godot --headless --path . --script res://tools/make_forecast_fixtures.gd
## Only regenerate after an intended rules change; commit with a DECISIONS note.


func _init() -> void:
	var sc: Array = ForecastScenarios.generate(120)
	var cov := {}
	for x: Dictionary in sc:
		for t: String in x["tags"]:
			cov[t] = int(cov.get(t, 0)) + 1
	var f := FileAccess.open("res://fixtures/forecast/scenarios.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"content_version": Catalog.data()["content_version"], "coverage": cov, "scenarios": sc}, "", true))
	f.close()
	print("scenarios: %d coverage: %s" % [sc.size(), cov])
	quit()
