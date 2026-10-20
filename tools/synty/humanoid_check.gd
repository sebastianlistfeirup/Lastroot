extends SceneTree
## Runtime half of tools/synty/humanoid_dryrun.sh: loads the humanoid wrappers through
## VisualSlots (exactly what the battle does) and measures what the shared Mixamo-style
## clips do to each rig in a running tree:
##   - model, not proxy; GeneralSkeleton; LRAnimations with the clips; facing -Z; feet y=0
##   - idle arms hang down, victory arms up, attack arm points forward (-Z) at contact
##   - the SAME clip gives the SAME pose on an A-pose Synty rig and a T-pose Mixamo rig
##     (bone directions compared across rigs) = retargeting really works
##   - shared clips touch only %GeneralSkeleton bones; walking stays in place
##   - UnitAnimator.play emits contact + finished
##   godot --headless --path . --script res://tools/synty/humanoid_check.gd -- --slots=unit.B03,unit.S01 --out=res://...json

var _out := "res://evidence/asset_pipeline/humanoid_dryrun_runtime.json"
var _slots: PackedStringArray = ["unit.B03", "unit.S01", "enemy.E03", "enemy.E05"]
var _r: Dictionary = {}
var _got: Dictionary = {}

## state -> seconds into the clip to measure (Punching contact frame 9 at 30 fps).
const SAMPLE := {"idle": 0.0, "attack": 0.267, "victory": 1.0, "cast": 0.367, "hit": 0.167, "move": 0.0}
const BONES := [["LeftUpperArm", "LeftLowerArm"], ["RightUpperArm", "RightLowerArm"], ["LeftUpperLeg", "LeftLowerLeg"],
	["RightUpperLeg", "RightLowerLeg"], ["Hips", "Head"]]


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--slots="):
			_slots = a.substr(8).split(",", false)
	VisualSlots.reload()
	_run()


func _run() -> void:
	await process_frame
	var per: Dictionary = {}
	for id: String in _slots:
		per[id] = await _check(id)
	_r["slots"] = per
	# Same clip, same pose on every rig (max angle between bone directions, degrees).
	var cross: Dictionary = {}
	var ids: Array = per.keys()
	for state: String in SAMPLE.keys():
		var worst := 0.0
		for i: int in ids.size():
			for j: int in range(i + 1, ids.size()):
				var a: Dictionary = (per[ids[i]] as Dictionary).get("poses", {}).get(state, {})
				var b: Dictionary = (per[ids[j]] as Dictionary).get("poses", {}).get(state, {})
				for k: String in a.keys():
					if b.has(k):
						worst = maxf(worst, rad_to_deg(_v(a[k]).angle_to(_v(b[k]))))
		cross[state] = snappedf(worst, 0.1)
	_r["max_pose_difference_between_rigs_deg"] = cross
	var f := FileAccess.open(_out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_r, " ", true))
	f.close()
	print("humanoid runtime checks written: ", _out)
	quit()


func _check(id: String) -> Dictionary:
	var out: Dictionary = {}
	var v := VisualSlots.make(id)
	root.add_child(v)
	await process_frame
	out["is_model"] = not bool(v.get_meta("is_proxy", true))
	var skels := v.find_children("GeneralSkeleton", "Skeleton3D", true, false)
	out["general_skeleton"] = not skels.is_empty()
	var ap := v.get_node_or_null("LRAnimations") as AnimationPlayer
	var an := v.get_node_or_null("UnitAnimator") as UnitAnimator
	out["clips"] = Array(ap.get_animation_list()) if ap else []
	var audit := RigLab.audit(id)
	out["facing"] = audit["facing"]
	out["height_m"] = audit["height_m"]
	out["feet_y"] = audit["feet_y"]
	if ap == null or skels.is_empty() or an == null:
		v.queue_free()
		return out
	var sk := skels[0] as Skeleton3D
	# Shared clips may only animate bones.
	var foreign := 0
	for n: StringName in ap.get_animation_list():
		var anim := ap.get_animation(n)
		for t: int in anim.get_track_count():
			if not String(anim.track_get_path(t)).begins_with("%GeneralSkeleton:"):
				foreign += 1
	out["non_bone_tracks"] = foreign
	an.set_process(false)
	var poses: Dictionary = {}
	for state: String in SAMPLE.keys():
		var clip := "lr/" + state
		if not ap.has_animation(clip):
			continue
		ap.play(clip)
		ap.seek(float(SAMPLE[state]), true)
		var p: Dictionary = {}
		for pair: Array in BONES:
			p[pair[0]] = _arr(_dir(v, sk, str(pair[0]), str(pair[1])))
		poses[state] = p
	out["poses"] = poses
	# Walking: thighs swing, hips stay over the origin (in place).
	if ap.has_animation(&"lr/move"):
		var len_s := ap.get_animation(&"lr/move").length
		var swing := 0.0
		var drift := 0.0
		ap.play(&"lr/move")
		ap.seek(0.0, true)
		var d0 := _dir(v, sk, "LeftUpperLeg", "LeftLowerLeg")
		var h0 := _pos(v, sk, "Hips")
		for k: int in range(1, 11):
			ap.seek(len_s * k / 10.0, true)
			swing = maxf(swing, rad_to_deg(d0.angle_to(_dir(v, sk, "LeftUpperLeg", "LeftLowerLeg"))))
			var h := _pos(v, sk, "Hips")
			drift = maxf(drift, Vector2(h.x - h0.x, h.z - h0.z).length())
		out["move_thigh_swing_deg"] = snappedf(swing, 0.1)
		out["move_hips_drift_m"] = snappedf(drift, 0.001)
	ap.stop()
	# UnitAnimator drives the clip: contact + finished arrive.
	_got = {}
	an.contact.connect(func(s: StringName) -> void: _got["contact"] = String(s))
	an.finished.connect(func(s: StringName) -> void: _got["finished_" + String(s)] = true)
	var t0 := Time.get_ticks_msec()
	an.play(&"attack")
	out["unit_animator_uses_clip"] = not an.is_procedural(&"attack")
	while not _got.has("finished_attack") and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	out["attack_contact"] = _got.get("contact", "") == "attack"
	out["attack_finished_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.01) if _got.has("finished_attack") else -1.0
	v.queue_free()
	await process_frame
	return out


func _pos(v: Node3D, sk: Skeleton3D, bone: String) -> Vector3:
	var i := sk.find_bone(bone)
	return v.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO


func _dir(v: Node3D, sk: Skeleton3D, a: String, b: String) -> Vector3:
	return (_pos(v, sk, b) - _pos(v, sk, a)).normalized()


func _arr(x: Vector3) -> Array:
	return [snappedf(x.x, 0.01), snappedf(x.y, 0.01), snappedf(x.z, 0.01)]


func _v(a: Variant) -> Vector3:
	var l: Array = a as Array
	return Vector3(float(l[0]), float(l[1]), float(l[2]))
