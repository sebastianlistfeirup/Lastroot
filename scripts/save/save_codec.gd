class_name SaveCodec
extends RefCounted
## SaveEnvelope (bible p.20): game_id, build_id, schema_version, checksum,
## timestamp, run (with battle and pending reward inside) and the
## presentation checkpoint. Pure: no file access (SaveService does I/O).

const GAME_ID := "LASTROOT"
const SCHEMA_VERSION := 1
const BUILD_ID := "lastroot-0.1.0"


static func make_envelope(run: Dictionary, presentation: Dictionary = {}) -> Dictionary:
	var payload := {"run": run, "presentation_checkpoint": presentation}
	return {
		"game_id": GAME_ID, "build_id": BUILD_ID, "schema_version": SCHEMA_VERSION,
		"content_version": run.get("content_version", ""),
		"timestamp": Time.get_datetime_string_from_system(true),
		"checksum": JsonUtil.canonical(payload).sha256_text(),
		"payload": payload,
	}


static func encode(run: Dictionary, presentation: Dictionary = {}) -> String:
	return JSON.stringify(make_envelope(run, presentation), "", true)


## {ok, error, code, run, presentation}. code: ok | not_lastroot | future_version
## | corrupt | unreadable. Never repairs silently.
static func decode(text: String) -> Dictionary:
	var env: Variant = JsonUtil.parse(text)
	if typeof(env) != TYPE_DICTIONARY:
		return _fail("unreadable", "The save file cannot be read.")
	var e: Dictionary = env
	if e.get("game_id", "") != GAME_ID:
		return _fail("not_lastroot", "This is not a LASTROOT save.")
	var ver: int = int(e.get("schema_version", -1))
	if ver > SCHEMA_VERSION:
		return _fail("future_version", "This save comes from a newer version of the game (schema %d)." % ver)
	if ver < 1 or typeof(e.get("payload")) != TYPE_DICTIONARY:
		return _fail("corrupt", "The save is damaged.")
	var payload: Dictionary = e["payload"]
	if JsonUtil.canonical(payload).sha256_text() != str(e.get("checksum", "")):
		return _fail("corrupt", "The save is damaged (checksum mismatch).")
	var run: Variant = payload.get("run")
	if typeof(run) != TYPE_DICTIONARY or not (run as Dictionary).has("deck"):
		return _fail("corrupt", "The save has no run.")
	return {"ok": true, "error": "", "code": "ok", "run": run,
		"presentation": payload.get("presentation_checkpoint", {}), "envelope": e}


static func _fail(code: String, msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "code": code, "run": {}, "presentation": {}}
