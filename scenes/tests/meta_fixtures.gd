class_name MetaFixtures
extends RefCounted
## Real run states for the meta screens, reached by the bot through the real
## RunReducer (no hand-made dictionaries), cached per process. Node fixtures
## pick the node type by choosing the matching option, or (if the generated
## route lacks it) by retyping the open option before entering - the only
## tweak, and it only changes which legal node type is offered.

static var _cache: Dictionary = {}


static func step(run: Dictionary, cmd: Dictionary) -> Dictionary:
	var r: Dictionary = RunReducer.apply(run, cmd)
	if not r["ok"]:
		push_error("MetaFixtures: rejected %s: %s" % [cmd, r["error"]])
		return run
	return r["run"]


## Bot until `pred` holds (or the run ends).
static func bot_until(run: Dictionary, pred: Callable, max_steps: int = 5000) -> Dictionary:
	var n := 0
	while n < max_steps and not pred.call(run) and run["phase"] in ["battle", "reward", "route", "node"]:
		run = step(run, AutoPlayer.choose_run(run))
		n += 1
	return run


static func reward_after(battle_number: int, seed_value: int = 21, faction: String = "BARK") -> Dictionary:
	var key := "reward%d_%d_%s" % [battle_number, seed_value, faction]
	if not _cache.has(key):
		var run: Dictionary = RunReducer.new_run(seed_value, faction)
		run = bot_until(run, func(r: Dictionary) -> bool:
			return r["phase"] == "reward" and int(r["reward"]["battle_number"]) == battle_number)
		_cache[key] = run
	return (_cache[key] as Dictionary).duplicate(true)


## Reward screen with the given slot type current (earlier slots claimed).
static func reward_slot(type: String, faction: String = "BARK") -> Dictionary:
	var k: int = 1
	match type:
		"champion", "relic":
			k = 2
		"champion2":
			k = 4
	var run: Dictionary = reward_after(k, 21, faction)
	var want: String = "champion" if type == "champion2" else type
	var guard := 0
	while run["phase"] == "reward" and RunReducer.current_slot(run).get("type", "") != want and guard < 10:
		var slot: Dictionary = RunReducer.current_slot(run)
		run = step(run, {"type": "claim", "slot": slot["id"], "choice": slot["offer"][0]})
		guard += 1
	return run


static func route(after_battle: int = 1, faction: String = "BARK") -> Dictionary:
	var run: Dictionary = reward_after(after_battle, 21, faction)
	return bot_until(run, func(r: Dictionary) -> bool: return r["phase"] == "route")


static func node(type: String, after_battle: int = 1, faction: String = "BARK") -> Dictionary:
	var run: Dictionary = route(after_battle, faction)
	var rt: Dictionary = RunReducer.current_route(run)
	var pick: Dictionary = {}
	for o: Dictionary in rt["options"]:
		if o["type"] == type:
			pick = o
	if pick.is_empty():
		for r: Dictionary in run["route"]:
			if r["id"] == rt["id"]:
				r["options"][0]["type"] = type
		pick = RunReducer.current_route(run)["options"][0]
	return step(run, {"type": "choose_node", "node": pick["id"]})


static func won(faction: String = "BARK") -> Dictionary:
	var key := "won_" + faction
	if not _cache.has(key):
		var best: Dictionary = {}
		for s in [21, 5, 8, 13, 34]:
			var r: Dictionary = AutoPlayer.play_run(RunReducer.new_run(s, faction))["run"]
			if r["phase"] == "won":
				best = r
				break
		_cache[key] = best
	return (_cache[key] as Dictionary).duplicate(true)


## A real defeat: the bot plays battle 3 with the Heart reduced to 3.
static func lost(faction: String = "SPORE") -> Dictionary:
	var key := "lost_" + faction
	if not _cache.has(key):
		var run: Dictionary = RunReducer.new_run(17, faction)
		run = bot_until(run, func(r: Dictionary) -> bool: return r["phase"] == "battle" and int(r["battle_index"]) == 2)
		run["heart"] = 3
		run["battle"]["heart"] = 3
		run = AutoPlayer.play_battle(run, 2000)
		_cache[key] = run
	return (_cache[key] as Dictionary).duplicate(true)
