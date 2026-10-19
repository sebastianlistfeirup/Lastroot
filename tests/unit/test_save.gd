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
