extends SceneTree
## Fixed-seed bot runs for both champions (bible p.22 "Spiltest og balance").
## godot --headless --path . --script res://tools/balance/run_balance.gd [-- --seeds=20]
## The bot is a regression signal, not proof of fun. Writes evidence/balance/.


func _init() -> void:
	var n := 20
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			n = int(a.get_slice("=", 1))
		if a.begins_with("--bot="):
			AutoPlayer.style = a.get_slice("=", 1)
		if a.begins_with("--meta="):
			AutoPlayer.meta_choice = a.get_slice("=", 1)
	# Balance experiments run on an in-memory copy of the catalog only; the
	# baseline files are never touched (AGENTS.md: balance changes need a decision).
	var difficulty := "standard"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--difficulty="):
			difficulty = a.get_slice("=", 1)
	var exp := {}
	for a in OS.get_cmdline_user_args():
		for key in ["enemy_hp", "enemy_atk", "heart", "resin", "boss_hp"]:
			if a.begins_with("--%s=" % key):
				exp[key] = float(a.get_slice("=", 1))
	if not exp.is_empty():
		var d: Dictionary = Catalog.data().duplicate(true)
		for e: Dictionary in d["enemies"]:
			e["max_hp"] = int(round(float(e["max_hp"]) * exp.get("enemy_hp", 1.0)))
			e["attack"] = int(round(float(e["attack"]) * exp.get("enemy_atk", 1.0)))
		d["boss"]["max_hp"] = int(round(float(d["boss"]["max_hp"]) * exp.get("boss_hp", exp.get("enemy_hp", 1.0))))
		d["boss"]["attack"] = int(round(float(d["boss"]["attack"]) * exp.get("enemy_atk", 1.0)))
		if exp.has("heart"):
			d["rules"]["heart_start"] = int(exp["heart"])
		if exp.has("resin"):
			d["rules"]["resin_start"] = int(exp["resin"])
		Catalog.install(d)
		print("EXPERIMENT ", exp)
	var rows: Array = []
	var summary := {}
	for faction in ["BARK", "SPORE"]:
		var wins := 0
		var heart_lost := 0
		var turns := 0
		var reached: Array = [0, 0, 0, 0, 0, 0, 0]
		var t0 := Time.get_ticks_msec()
		for i in n:
			var seed_value: int = 1000 + i
			var res: Dictionary = AutoPlayer.play_run(RunReducer.new_run(seed_value, faction, "full", difficulty))
			var run: Dictionary = res["run"]
			var won: bool = run["phase"] == "won"
			var bw: int = int(run["stats"]["battles_won"])
			reached[bw] += 1
			wins += 1 if won else 0
			heart_lost += int(run["stats"]["heart_lost"])
			turns += int(run["stats"]["turns"])
			var deck: Array = []
			for inst: Dictionary in run["deck"]:
				deck.append(inst["def_id"] + ("+" if inst["upgrade_id"] != "" else ""))
			rows.append({"faction": faction, "seed": seed_value, "won": won, "battles_won": bw,
				"heart_end": run["heart"], "heart_lost": run["stats"]["heart_lost"], "turns": run["stats"]["turns"],
				"cards_played": run["stats"]["cards_played"], "relics": run["relics"], "mutations": run["mutations"],
				"path": "%s %d" % [run["champion_path"], run["champion_rank"]], "deck": deck})
		summary[faction] = {"runs": n, "wins": wins, "winrate": float(wins) / float(n),
			"avg_heart_lost": float(heart_lost) / float(n), "avg_turns": float(turns) / float(n),
			"battles_won_histogram": reached, "ms": Time.get_ticks_msec() - t0}
		print("%s: %d/%d wins, avg heart lost %.1f, avg turns %.1f, reached %s" % [faction, wins, n,
			float(heart_lost) / float(n), float(turns) / float(n), reached])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/balance"))
	var tag: String = AutoPlayer.style + ("" if difficulty == "standard" else "_" + difficulty) + ("" if AutoPlayer.meta_choice == "first" else "_meta" + AutoPlayer.meta_choice)
	for k: String in exp.keys():
		tag += "_%s%s" % [k, str(exp[k])]
	var f := FileAccess.open("res://evidence/balance/balance_report_%s.json" % tag, FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine_version": Engine.get_version_info()["string"],
		"content_version": Catalog.data()["content_version"], "bot": "AutoPlayer " + AutoPlayer.style, "experiment": exp,
		"timestamp": Time.get_datetime_string_from_system(true), "summary": summary, "runs": rows}, "  ", true))
	f.close()
	quit()
