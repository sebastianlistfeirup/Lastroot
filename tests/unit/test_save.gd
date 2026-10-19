extends TestCase
## LR-10: envelope, checksum, future versions, no reroll on load.


func test_roundtrip_is_identical() -> void:
	var run := RunReducer.new_run(55, "BARK")
	var d := SaveCodec.decode(SaveCodec.encode(run, {"pending": true}))
	check(d["ok"], "decodes")
	eq(JsonUtil.canonical(d["run"]), JsonUtil.canonical(run), "same run")
	eq(d["presentation"]["pending"], true, "presentation checkpoint kept")


func test_load_does_not_reroll_hand() -> void:
	var run := RunReducer.new_run(56, "SPORE")
	var hand: Array = run["battle"]["zones"]["hand"].duplicate()
	var d := SaveCodec.decode(SaveCodec.encode(run))
	eq(d["run"]["battle"]["zones"]["hand"], hand, "same hand")
	var a := RunReducer.apply(run, {"type": "battle", "cmd": {"type": "end_turn"}})
	var b := RunReducer.apply(d["run"], {"type": "battle", "cmd": {"type": "end_turn"}})
	eq(JsonUtil.canonical(a["run"]), JsonUtil.canonical(b["run"]), "continues identically")


func test_corrupt_detected() -> void:
	var text := SaveCodec.encode(RunReducer.new_run(57, "BARK"))
	var bad := text.replace("\"resin\":30", "\"resin\":999")
	check(bad != text, "tamper applied")
	var d := SaveCodec.decode(bad)
	check(not d["ok"], "rejected")
	eq(d["code"], "corrupt", "checksum mismatch")


func test_future_version_rejected() -> void:
	var env := SaveCodec.make_envelope(RunReducer.new_run(58, "BARK"))
	env["schema_version"] = 99
	var d := SaveCodec.decode(JSON.stringify(env))
	eq(d["code"], "future_version", "newer schema refused")


func test_garbage_and_foreign() -> void:
	eq(SaveCodec.decode("not json")["code"], "unreadable", "garbage")
	eq(SaveCodec.decode("{\"game_id\":\"GENESIS\"}")["code"], "not_lastroot", "foreign")


func test_reward_claim_survives_reload_once() -> void:
	var run := AutoPlayer.play_battle(RunReducer.new_run(59, "BARK"))
	var slot := RunReducer.current_slot(run)
	var r := RunReducer.apply(run, {"type": "claim", "slot": slot["id"], "choice": slot["offer"][1]})
	var d := SaveCodec.decode(SaveCodec.encode(r["run"]))
	check(not RunReducer.apply(d["run"], {"type": "claim", "slot": slot["id"], "choice": slot["offer"][1]})["ok"], "claim cannot repeat after load")


func test_fuzzed_saves_never_load_wrong_state() -> void:
	# LR-29 groundwork: flipping characters anywhere must give a clean refusal
	# (or, for whitespace-only changes, the identical run) — never a different run.
	var run := RunReducer.new_run(60, "SPORE")
	var text := SaveCodec.encode(run)
	var rng := RngStream.create(99, "fuzz")
	var canon := JsonUtil.canonical(run)
	var accepted_wrong := 0
	for i in 200:
		var pos: int = RngStream.next_int(rng, text.length())
		var ch: String = "0123456789abcdef{}[]\",:x"[RngStream.next_int(rng, 25)]
		var bad: String = text.substr(0, pos) + ch + text.substr(pos + 1)
		var d := SaveCodec.decode(bad)
		if d["ok"] and JsonUtil.canonical(d["run"]) != canon:
			accepted_wrong += 1
	eq(accepted_wrong, 0, "no corrupted save is accepted as a different run")


func test_truncated_save_rejected() -> void:
	var text := SaveCodec.encode(RunReducer.new_run(61, "BARK"))
	for cut in [10, text.length() / 2, text.length() - 2]:
		check(not SaveCodec.decode(text.substr(0, cut))["ok"], "truncated at %d refused" % cut)
