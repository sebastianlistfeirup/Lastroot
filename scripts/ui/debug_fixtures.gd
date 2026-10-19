class_name DebugFixtures
extends RefCounted
## Named game states for screenshots, smoke tests and quick manual checks.
## godot --path . -- --setup=<name> [--faction=BARK|SPORE] [--seed=N]
##   battle1      new run, first battle, turn 1
##   midbattle    first battle after the bot played two turns
##   battle<N>    bot-played run up to battle N (2..6), first turn
##   boss         the Ash Crown battle on the turn it arrives
##   reward       first reward screen; route; node:<type>; won; lost


static func make(name: String, faction: String = "BARK", seed_value: int = 1) -> Dictionary:
	var run := RunReducer.new_run(seed_value, faction)
	if name == "battle1":
		return run
	if name == "midbattle":
		for i in 40:
			var cmd: Dictionary = AutoPlayer.choose(run["battle"])
			run = RunReducer.apply(run, {"type": "battle", "cmd": cmd})["run"]
			if run["phase"] != "battle" or int(run["battle"]["turn"]) >= 3:
				break
		return run
	if name.begins_with("battle") or name == "boss":
		var target: int = 6 if name == "boss" else int(name.substr(6))
		while run["phase"] in ["battle", "reward", "route", "node"]:
			if run["phase"] == "battle" and int(run["battle_index"]) + 1 >= target:
				break
			var r: Dictionary = RunReducer.apply(run, AutoPlayer.choose_run(run))
			if not r["ok"]:
				break
			run = r["run"]
		if name == "boss":
			while run["phase"] == "battle" and int(run["battle"]["turn"]) < 5:
				run = RunReducer.apply(run, {"type": "battle", "cmd": AutoPlayer.choose(run["battle"])})["run"]
		return run
	if name in ["reward", "route", "won", "lost"] or name.begins_with("node"):
		run = AutoPlayer.play_battle(run)
		if name == "reward":
			return run
		while run["phase"] == "reward":
			run = RunReducer.apply(run, AutoPlayer.choose_run(run))["run"]
		if name == "route":
			return run
		if name.begins_with("node"):
			var want: String = name.get_slice(":", 1)
			var route: Dictionary = RunReducer.current_route(run)
			route["options"][0]["type"] = want if want != "" else route["options"][0]["type"]
			return RunReducer.apply(run, {"type": "choose_node", "node": route["options"][0]["id"]})["run"]
		if name == "lost":
			# A real defeat: the casual bot (no look-ahead) plays on until the Heart falls.
			var prev: String = AutoPlayer.style
			AutoPlayer.style = "casual"
			for attempt in 12:
				var res: Dictionary = AutoPlayer.play_run(RunReducer.new_run(seed_value + attempt * 101, faction))
				if res["run"]["phase"] == "lost":
					AutoPlayer.style = prev
					return res["run"]
			AutoPlayer.style = prev
			run["phase"] = "lost"
			run["result"] = "lost"
			return run
		var res: Dictionary = AutoPlayer.play_run(run)
		return res["run"]
	return run
