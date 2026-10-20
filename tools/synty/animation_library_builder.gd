class_name AnimationLibraryBuilder
extends RefCounted
## Builds AnimationLibrary resources whose clips are named after LASTROOT's
## animation states (idle, summon, attack, cast, hit, death, defend, victory, move),
## so UnitAnimator plays "lr/<state>" on any wrapper.
##   humanoid:  one library per rig family from retargeted clip files (Mixamo/Synty),
##              tracks on %GeneralSkeleton, so it plays on every humanoid wrapper.
##   quadruped: per slot, from the model's OWN embedded clips, matched by keyword
##              (no humanoid retarget on four legs - bible).
## Clips are made in-place (bible: root motion must not move the formation).

const LIB_DIR := "res://art/animations/"
const LOOPING := ["idle", "move"]
const STATES := ["idle", "summon", "attack", "cast", "hit", "death", "defend", "victory", "move"]


## states: {state: "res://.../Punching.fbx"}. Returns a report with the saved library path.
static func build_from_files(name: String, states: Dictionary, out_dir: String = LIB_DIR) -> Dictionary:
	var lib := AnimationLibrary.new()
	var report := {"set": name, "ok": true, "clips": {}, "errors": []}
	for state: String in states.keys():
		var src := str(states[state])
		var anim := take_clip(src, "")
		if anim == null:
			(report["errors"] as Array).append("%s: no clip in %s" % [state, src])
			continue
		var dropped := keep_skeleton_tracks(anim)
		_add(lib, state, anim, src, report)
		(report["clips"][state] as Dictionary)["dropped_node_tracks"] = dropped
	return _save(lib, name, out_dir, report)


## Maps the embedded clips of one model (e.g. a PolyPerfect animal) onto states by keyword.
## clip_names: optional {state: exact clip name} from animation_sets.json.
static func build_from_embedded(name: String, model_path: String, keywords: Dictionary, clip_names: Dictionary = {}, out_dir: String = LIB_DIR) -> Dictionary:
	var lib := AnimationLibrary.new()
	var report := {"set": name, "ok": true, "clips": {}, "errors": []}
	var ps := load(model_path) as PackedScene
	if ps == null:
		report["ok"] = false
		(report["errors"] as Array).append("cannot load " + model_path)
		return report
	var root := ps.instantiate()
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		root.free()
		report["ok"] = false
		(report["errors"] as Array).append("no embedded clips in " + model_path)
		return report
	var ap := players[0] as AnimationPlayer
	var names: Array = Array(ap.get_animation_list()).filter(func(n: StringName) -> bool: return n != &"RESET")
	report["embedded"] = names.map(func(n: StringName) -> String: return String(n))
	for state: String in STATES:
		var pick := ""
		var exact := str(clip_names.get(state, ""))
		for n: StringName in names:
			var base := String(n).get_slice("/", String(n).get_slice_count("/") - 1)
			if not exact.is_empty() and base == exact:
				pick = String(n)
				break
		if pick.is_empty():
			for n: StringName in names:
				var low := String(n).to_lower()
				for k: Variant in keywords.get(state, []) as Array:
					if str(k) in low:
						pick = String(n)
						break
				if not pick.is_empty():
					break
		if not pick.is_empty():
			_add(lib, state, (ap.get_animation(pick).duplicate(true)) as Animation, model_path + "::" + pick, report)
	root.free()
	return _save(lib, name, out_dir, report)


static func _add(lib: AnimationLibrary, state: String, anim: Animation, src: String, report: Dictionary) -> void:
	anim.loop_mode = Animation.LOOP_LINEAR if state in LOOPING else Animation.LOOP_NONE
	var travel := make_in_place(anim)
	lib.add_animation(StringName(state), anim)
	(report["clips"] as Dictionary)[state] = {"source": src, "length_s": snappedf(anim.length, 0.01),
		"removed_travel_m": snappedf(travel, 0.01), "retargeted": is_retargeted(anim)}


static func _save(lib: AnimationLibrary, name: String, out_dir: String, report: Dictionary) -> Dictionary:
	if lib.get_animation_list().is_empty():
		report["ok"] = false
		return report
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path := out_dir.path_join(name + ".res")
	var err := ResourceSaver.save(lib, path)
	if err != OK:
		report["ok"] = false
		(report["errors"] as Array).append("save failed %d" % err)
		return report
	report["library"] = path
	return report


static func take_clip(src: String, clip: String) -> Animation:
	if not ResourceLoader.exists(src):
		return null
	var ps := load(src) as PackedScene
	if ps == null:
		return null
	var root := ps.instantiate()
	var out: Animation = null
	var best := -1.0
	for p: Node in root.find_children("*", "AnimationPlayer", true, false):
		var ap := p as AnimationPlayer
		for n: StringName in ap.get_animation_list():
			if n == &"RESET":
				continue
			if not clip.is_empty():
				if String(n) == clip or String(n).ends_with("/" + clip):
					out = (ap.get_animation(n).duplicate(true)) as Animation
					best = INF
					break
				continue
			# No name given: real Mixamo FBX files carry an empty one-key "Take 001" next to
			# the real "mixamo.com" take, so pick the clip that actually moves (longest,
			# "mixamo" in the name wins), never simply the first one.
			var an := ap.get_animation(n)
			var moving := false
			for t: int in an.get_track_count():
				if an.track_get_key_count(t) > 1:
					moving = true
					break
			var s := (an.length if moving else -1.0) + (1000.0 if moving and "mixamo" in String(n).to_lower() else 0.0)
			if s > best:
				best = s
				out = (an.duplicate(true)) as Animation
		if best == INF:
			break
	root.free()
	return out


## Removes horizontal root travel from the hips/root position track. Returns metres removed.
static func make_in_place(anim: Animation) -> float:
	var removed := 0.0
	for t: int in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var p := String(anim.track_get_path(t)).to_lower()
		if not (p.ends_with(":hips") or p.ends_with(":root") or p.ends_with(":pelvis")):
			continue
		var n := anim.track_get_key_count(t)
		if n == 0:
			continue
		var first: Vector3 = anim.track_get_key_value(t, 0)
		var last: Vector3 = anim.track_get_key_value(t, n - 1)
		var travel := Vector2(last.x - first.x, last.z - first.z).length()
		if travel < 0.05:
			continue  # idle sway, not locomotion
		removed = maxf(removed, travel)
		for k: int in n:
			var v: Vector3 = anim.track_get_key_value(t, k)
			anim.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))
	return removed


## Shared humanoid clips must only touch bones. A clip file also animates its own scene
## nodes (an "Armature" node carrying the Blender/FBX Z-up rotation, a "Camera"...): on
## another rig those tracks either fail to resolve (a warning on every play) or, worse,
## hit a node with the same name (Mixamo/Blender characters also have "Armature") and
## tip the whole figure over. Returns the paths it removed.
static func keep_skeleton_tracks(anim: Animation) -> Array:
	var dropped: Array = []
	if not is_retargeted(anim):
		return dropped
	for t: int in range(anim.get_track_count() - 1, -1, -1):
		var p := String(anim.track_get_path(t))
		if not p.begins_with("%GeneralSkeleton:"):
			dropped.append(p)
			anim.remove_track(t)
	return dropped


static func is_retargeted(anim: Animation) -> bool:
	for t: int in anim.get_track_count():
		if String(anim.track_get_path(t)).begins_with("%GeneralSkeleton:"):
			return true
	return false
