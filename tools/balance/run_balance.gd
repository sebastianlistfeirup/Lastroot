extends SceneTree
## Fixed-seed bot runs for both champions (bible p.22 "Spiltest og balance").
## godot --headless --path . --script res://tools/balance/run_balance.gd [-- --seeds=20]
## The bot is a regression signal, not proof of fun. Writes evidence/balance/.


func _init() -> void:
	var n := 20
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			n = int(a.get_slice("=", 1))
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
			var res: Dictionary = AutoPlayer.play_run(RunReducer.new_run(seed_value, faction))
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
	var f := FileAccess.open("res://evidence/balance/balance_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine_version": Engine.get_version_info()["string"],
		"content_version": Catalog.data()["content_version"], "bot": "AutoPlayer greedy forecast v1",
		"timestamp": Time.get_datetime_string_from_system(true), "summary": summary, "runs": rows}, "  ", true))
	f.close()
	quit()
