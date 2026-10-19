extends SceneTree
## Runtime half of tools/synty/selftest.sh: loads the wrappers built from the FAKE
## packs through VisualSlots (pointed at the selftest mapping) and checks that the
## result really works in a running tree: model instead of proxy, retargeted clips
## move bones, UnitAnimator always emits finished (also for a missing clip).
##   godot --headless --path . --script res://tools/synty/selftest_check.gd -- --slot-scenes=res://... --out=res://...

var _out_path := "res://evidence/asset_pipeline/selftest_runtime.json"
var _r: Dictionary = {}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--slot-scenes="):
			VisualSlots.set_built_path(a.substr(14))
		elif a.begins_with("--out="):
			_out_path = a.substr(6)
	VisualSlots.reload()
	_run()


func _run() -> void:
	await process_frame
	# Humanoid champion from the Synty-style golem + Mixamo-style clips.
	var b01 := VisualSlots.make("unit.B01")
	root.add_child(b01)
	await process_frame
	var an := b01.get_node_or_null("UnitAnimator") as UnitAnimator
	_r["b01_is_model"] = not bool(b01.get_meta("is_proxy", true))
	_r["b01_has_unit_animator"] = an != null
	_r["b01_has_clip_attack"] = an != null and an.has_clip(&"attack")
	_r["b01_has_clip_idle"] = an != null and an.has_clip(&"idle")
	_r["b01_missing_victory"] = an != null and not an.has_clip(&"victory")
	var skels := b01.find_children("GeneralSkeleton", "Skeleton3D", true, false)
	_r["b01_retargeted_skeleton"] = not skels.is_empty()
	var ap := b01.get_node_or_null("LRAnimations") as AnimationPlayer
	if ap and not skels.is_empty():
		var sk := skels[0] as Skeleton3D
		var bi := sk.find_bone("RightUpperArm")
		ap.play(&"lr/idle")
		ap.seek(0.0, true)
		var before := sk.get_bone_pose_rotation(bi)
		ap.play(&"lr/attack")
		ap.seek(0.45, true)
		var after := sk.get_bone_pose_rotation(bi)
		_r["b01_attack_rotates_arm_deg"] = snappedf(rad_to_deg(before.angle_to(after)), 0.1)
		var hips := sk.find_bone("Hips")
		ap.seek(0.0, true)
		var p0 := sk.get_bone_pose_position(hips)
		ap.seek(0.85, true)
		var p1 := sk.get_bone_pose_position(hips)
		_r["b01_attack_hips_travel_m"] = snappedf(Vector2(p1.x - p0.x, p1.z - p0.z).length(), 0.001)
		ap.stop()
	var audit := RigLab.audit("unit.B01")
	_r["b01_facing"] = audit["facing"]
	_r["b01_height_m"] = audit["height_m"]
	_r["b01_feet_y"] = audit["feet_y"]
	_r["b01_reported_missing"] = audit["missing_clips"]
	_r["b01_finished_attack_s"] = await _finish_time(an, &"attack")
	_r["b01_contact_fired"] = _contact
	_r["b01_finished_victory_fallback_s"] = await _finish_time(an, &"victory")
	_r["b01_finished_death_s"] = await _finish_time(an, &"death")
	# Quadruped from the PolyPerfect-style deer: own clips, no humanoid retarget.
	var b04 := VisualSlots.make("unit.B04")
	root.add_child(b04)
	await process_frame
	var dn := b04.get_node_or_null("UnitAnimator") as UnitAnimator
	_r["b04_is_model"] = not bool(b04.get_meta("is_proxy", true))
	_r["b04_no_humanoid_retarget"] = b04.find_children("GeneralSkeleton", "Skeleton3D", true, false).is_empty()
	_r["b04_has_clip_attack"] = dn != null and dn.has_clip(&"attack")
	_r["b04_has_clip_move"] = dn != null and dn.has_clip(&"move")
	_r["b04_missing_hit"] = dn != null and not dn.has_clip(&"hit")
	_r["b04_facing"] = RigLab.facing_of(b04)
	_r["b04_finished_hit_fallback_s"] = await _finish_time(dn, &"hit")
	# Stage piece and prop through the same entry point.
	var floor := VisualSlots.make("stage.floor_roots")
	var fb := VisualSlots.bounds(floor)
	_r["floor_is_model"] = not bool(floor.get_meta("is_proxy", true))
	_r["floor_width_m"] = snappedf(fb.size.x, 0.01)
	_r["floor_top_y"] = snappedf(fb.end.y, 0.01)
	floor.free()
	# Unmapped slot still a proxy; unknown id never null.
	var s02 := VisualSlots.make("unit.S02")
	_r["s02_still_proxy"] = bool(s02.get_meta("is_proxy", false))
	s02.free()
	var bad := VisualSlots.make("unit.DOES_NOT_EXIST")
	_r["unknown_not_null"] = bad != null
	bad.free()
	var f := FileAccess.open(_out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_r, "  "))
	f.close()
	print("selftest runtime checks written: ", _out_path)
	quit()


var _contact := false


## Seconds until finished(state) arrives, or -1 after a 5 s timeout.
func _finish_time(an: UnitAnimator, state: StringName) -> float:
	if an == null:
		return -1.0
	var got := {"done": false}
	_contact = false
	var cb := func(s: StringName) -> void:
		if s == state:
			got["done"] = true
	var cc := func(_s: StringName) -> void:
		_contact = true
	an.finished.connect(cb)
	an.contact.connect(cc)
	var t0 := Time.get_ticks_msec()
	an.play(state)
	while not got["done"] and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	an.finished.disconnect(cb)
	an.contact.disconnect(cc)
	return snappedf(float(Time.get_ticks_msec() - t0) / 1000.0, 0.01) if got["done"] else -1.0
