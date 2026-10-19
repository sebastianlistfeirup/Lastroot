extends SceneTree
## Runtime half of the real-FBX dry run: loads the wrapper through VisualSlots (pointed
## at a test mapping), checks it is the model, that vendor cameras/lights are gone,
## that the embedded clip really moves bones via UnitAnimator, and that a missing clip
## still finishes. Writes JSON for evidence/asset_pipeline/fbx_dryrun.json.
##   godot --headless --path . --script res://tools/synty/fbx_runtime_check.gd -- --slot-scenes=res://... --slot=unit.B01 --out=res://...

var _r: Dictionary = {}


func _initialize() -> void:
	var slot := "unit.B01"
	var out := "res://evidence/asset_pipeline/fbx_runtime.json"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--slot-scenes="):
			VisualSlots.set_built_path(a.substr(14))
		elif a.begins_with("--slot="):
			slot = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
	_run(slot, out)


func _run(slot: String, out: String) -> void:
	await process_frame
	var v := VisualSlots.make(slot)
	root.add_child(v)
	await process_frame
	_r["slot"] = slot
	_r["is_model"] = not bool(v.get_meta("is_proxy", true))
	_r["cameras_in_instance"] = v.find_children("*", "Camera3D", true, false).size()
	_r["lights_in_instance"] = v.find_children("*", "Light3D", true, false).size()
	var an := v.get_node_or_null("UnitAnimator") as UnitAnimator
	_r["has_clip_idle"] = an != null and an.has_clip(&"idle")
	_r["has_clip_attack"] = an != null and an.has_clip(&"attack")
	var sk := v.find_children("*", "Skeleton3D", true, false)
	if not sk.is_empty() and an:
		var s := sk[0] as Skeleton3D
		var before: Array = []
		for i: int in s.get_bone_count():
			before.append(s.get_bone_pose_rotation(i))
		an.play(&"idle")
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 600:
			await process_frame
		var moved := 0.0
		for i: int in s.get_bone_count():
			moved = maxf(moved, rad_to_deg((before[i] as Quaternion).angle_to(s.get_bone_pose_rotation(i))))
		_r["idle_max_bone_rotation_deg"] = snappedf(moved, 0.1)
	var got := {"t": -1.0}
	var t1 := Time.get_ticks_msec()
	an.finished.connect(func(st: StringName) -> void:
		if st == &"attack" and float(got["t"]) < 0.0:
			got["t"] = float(Time.get_ticks_msec() - t1) / 1000.0)
	an.play(&"attack")
	while float(got["t"]) < 0.0 and Time.get_ticks_msec() - t1 < 4000:
		await process_frame
	_r["attack_missing_clip_finished_s"] = snappedf(float(got["t"]), 0.01)
	var audit := RigLab.audit(slot)
	_r["riglab_audit"] = audit
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_r, "  "))
	f.close()
	print("fbx runtime check written: ", out)
	quit()
