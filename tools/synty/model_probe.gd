extends SceneTree
## Inspects an imported model (FBX/glTF/GLB) the way the wrapper builder sees it:
## node tree summary, skeletons with bone names, the humanoid bone-map result,
## animations (name, length, tracks, root travel), bounds (scale hint) and a facing guess.
##   godot --headless --path . --script res://tools/synty/model_probe.gd -- res://assets/imported/<pack>/<file>.fbx [--out=res://...json]


func _init() -> void:
	var path := ""
	var out := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("res://"):
			path = a
	print(JSON.stringify(probe(path), "  ") if out.is_empty() else "")
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(probe(path), "  "))
		f.close()
		print("probe written: ", out)
	quit()


static func probe(path: String) -> Dictionary:
	var r := {"path": path, "ok": false}
	var ps := load(path) as PackedScene
	if ps == null:
		r["error"] = "cannot load"
		return r
	var root := ps.instantiate()
	r["ok"] = true
	r["root_type"] = root.get_class()
	var counts := {}
	for n: Node in root.find_children("*", "", true, false):
		counts[n.get_class()] = int(counts.get(n.get_class(), 0)) + 1
	r["node_counts"] = counts
	var b := VisualSlots.bounds(root)
	r["bounds_m"] = {"min": [snappedf(b.position.x, 0.001), snappedf(b.position.y, 0.001), snappedf(b.position.z, 0.001)],
		"size": [snappedf(b.size.x, 0.001), snappedf(b.size.y, 0.001), snappedf(b.size.z, 0.001)]}
	var tallest := maxf(b.size.y, 0.0001)
	r["scale_hint"] = "centimetres? (x0.01)" if tallest > 50.0 else ("tiny (<5 cm): check units" if tallest < 0.05 else "metres")
	r["up_axis_hint"] = "Y up" if b.size.y >= maxf(b.size.x, b.size.z) * 0.5 else "flat/lying (Z-up export? check rotation)"
	var skels: Array = []
	for s: Node in root.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var names: Array = []
		for i: int in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		var bm := HumanoidBoneMapper.build(sk)
		skels.append({"path": str(root.get_path_to(sk)), "bones": sk.get_bone_count(), "bone_names": names,
			"humanoid_found": (bm["found"] as Dictionary).size(), "humanoid_missing_core": bm["missing_core"],
			"humanoid_mapping": bm["found"]})
	r["skeletons"] = skels
	var anims: Array = []
	for p: Node in root.find_children("*", "AnimationPlayer", true, false):
		var ap := p as AnimationPlayer
		for n: StringName in ap.get_animation_list():
			var an := ap.get_animation(n)
			var travel := 0.0
			for t: int in an.get_track_count():
				if an.track_get_type(t) == Animation.TYPE_POSITION_3D and an.track_get_key_count(t) > 1:
					var a0: Vector3 = an.track_get_key_value(t, 0)
					var a1: Vector3 = an.track_get_key_value(t, an.track_get_key_count(t) - 1)
					travel = maxf(travel, Vector2(a1.x - a0.x, a1.z - a0.z).length())
			anims.append({"name": String(n), "length_s": snappedf(an.length, 0.01), "tracks": an.get_track_count(), "max_position_travel": snappedf(travel, 0.001)})
	r["animations"] = anims
	var holder := Node3D.new()
	holder.add_child(root)
	r["facing_guess"] = RigLab.facing_of(holder)
	holder.free()
	return r
