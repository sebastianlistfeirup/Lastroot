extends SceneTree
## Live-tree check of the procedural animations: for representative units and
## every state (plus play_hit and an interrupt), finished() must arrive within the
## state's duration + margin, contact() at contact_time, and the root must not move.
## Runs twice (normal + reduced motion). Writes evidence/asset_pipeline/anim_check.json.
##   godot --headless --path . --script res://tools/synty/anim_check.gd

const SLOTS := ["unit.B01", "unit.S01", "unit.B04", "unit.S03", "enemy.E01", "enemy.E06"]

var _rows: Array = []
var _fail: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	for reduced: bool in [false, true]:
		UnitAnimator.reduced_motion = reduced
		for id: String in SLOTS:
			var v := VisualSlots.make(id)
			v.position = Vector3(1.5, 4.5, 0.2)
			v.rotation_degrees.y = -90.0
			root.add_child(v)
			await process_frame
			var an := v.get_node("UnitAnimator") as UnitAnimator
			for st: StringName in UnitAnimator.STATES:
				await _one(v, an, id, st, reduced, false)
			await _one(v, an, id, &"hit", reduced, true)
			# Interrupt: attack cut by hit must still report attack finished at once.
			var got := {"attack": -1.0}
			var t0 := Time.get_ticks_msec()
			var cb := func(s: StringName) -> void:
				if s == &"attack" and got["attack"] < 0.0:
					got["attack"] = float(Time.get_ticks_msec() - t0) / 1000.0
			an.finished.connect(cb)
			an.play(&"attack")
			await process_frame
			an.play(&"hit")
			await process_frame
			an.finished.disconnect(cb)
			var ok := float(got["attack"]) >= 0.0 and float(got["attack"]) < 0.2
			_row(id, "interrupt attack->hit", reduced, float(got["attack"]), 0.2, ok, "")
			v.queue_free()
			await process_frame
	UnitAnimator.reduced_motion = false
	var f := FileAccess.open("res://evidence/asset_pipeline/anim_check.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"status": "PASS" if _fail == 0 else "FAIL", "failed": _fail, "rows": _rows}, " "))
	f.close()
	print("anim_check: %d rows, %d failed" % [_rows.size(), _fail])
	quit(1 if _fail > 0 else 0)


func _one(v: Node3D, an: UnitAnimator, id: String, st: StringName, reduced: bool, as_hit: bool) -> void:
	var got := {"done": -1.0, "contact": -1.0}
	var t0 := Time.get_ticks_msec()
	var cb := func(s: StringName) -> void:
		if s == st and float(got["done"]) < 0.0:
			got["done"] = float(Time.get_ticks_msec() - t0) / 1000.0
	var cc := func(s: StringName) -> void:
		if s == st:
			got["contact"] = float(Time.get_ticks_msec() - t0) / 1000.0
	an.finished.connect(cb)
	an.contact.connect(cc)
	var pos0 := v.position
	if as_hit:
		an.play_hit(9)
	else:
		an.play(st)
	var limit := float(UnitAnimator.DURATION.get(st, 0.5)) + UnitAnimator.TIMEOUT_MARGIN + 0.3
	var moved := false
	while float(got["done"]) < 0.0 and Time.get_ticks_msec() - t0 < int(limit * 1000.0) + 500:
		await process_frame
		moved = moved or v.position != pos0
	an.finished.disconnect(cb)
	an.contact.disconnect(cc)
	var ct := an.contact_time(st)
	var ok := float(got["done"]) >= 0.0 and float(got["done"]) <= limit and not moved
	var note := ""
	if ct > 0.0 and (float(got["contact"]) < 0.0 or absf(float(got["contact"]) - ct) > 0.12):
		ok = false
		note = "contact at %.2f, expected %.2f" % [got["contact"], ct]
	if moved:
		note += " root moved"
	_row(id, ("play_hit(9)" if as_hit else String(st)), reduced, float(got["done"]), limit, ok, note)
	# Let death/hide settle before the next state; play() makes it visible again.
	await process_frame


func _row(id: String, st: String, reduced: bool, t: float, limit: float, ok: bool, note: String) -> void:
	_rows.append({"slot": id, "state": st, "reduced_motion": reduced, "finished_s": snappedf(t, 0.01), "limit_s": snappedf(limit, 0.01), "ok": ok, "note": note})
	if not ok:
		_fail += 1
		print("FAIL %s %s reduced=%s t=%.2f %s" % [id, st, reduced, t, note])
