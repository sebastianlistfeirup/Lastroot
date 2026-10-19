class_name SlotWrapperBuilder
extends RefCounted
## Turns one imported model (Synty / PolyPerfect / Mixamo character) into a
## LASTROOT slot wrapper scene art/prefabs/<slot>.tscn. Shared by the command line
## (tools/synty/build_wrappers.gd) and the editor dock (addons/lastroot_slots).
##
## Wrapper layout (what VisualSlots.make instances):
##   <slot_id> (Node3D)              meta lr_source, lr_fit
##     Model    (the imported scene, read-only vendor file; scaled/rotated/positioned here)
##     LRAnimations (AnimationPlayer, root_node ../Model, library "lr" with state-named clips)
## UnitAnimator is added at runtime by VisualSlots.make, never stored in wrappers.
##
## Normalisation, per slot kind (override per choice: fit / extra_scale / align / rotation_y):
##   height    units, enemies, trunk, heart: uniform scale to the slot's height (size language)
##   footprint floors: uniform scale so the width is usable_width + 0.6 m, TOP at y=0
##   natural   props, backdrop, mutations: real size, only cm->m (x0.01) or x100 fixes
## then: centre x/z (units/props on the origin, stage pieces on the proxy centre), feet at y=0,
## facing -Z (rotation_y, default 180 for characters: they usually import facing +Z).

const PREFABS := "res://art/prefabs/"
const MATERIALS := "res://art/materials/"
const BUILD_STATUS := ["auto", "approved", "manual"]


static func fit_mode(slot_id: String) -> String:
	var s := VisualSlots.slot(slot_id)
	var f := str(s.get("fit", ""))
	if f in ["height", "footprint", "natural"]:
		return f
	return "natural"


## libs: {"humanoid": "res://art/animations/humanoid.res"} (built before wrappers).
func build_one(slot_id: String, c: Dictionary, prefab_dir: String = PREFABS, libs: Dictionary = {}, lib_dir: String = AnimationLibraryBuilder.LIB_DIR) -> Dictionary:
	var src := str(c.get("source", ""))
	var pack := src.trim_prefix("res://assets/imported/").get_slice("/", 0)
	var model_path := src if src.begins_with("res://") else "res://assets/imported/" + src
	var s := VisualSlots.slot(slot_id)
	if s.is_empty():
		return {"slot": slot_id, "ok": false, "error": "unknown slot id"}
	if not ResourceLoader.exists(model_path):
		return {"slot": slot_id, "ok": false, "error": "not staged/imported: %s (run tools/synty/stage.py, then godot --import)" % model_path}
	var ps := load(model_path) as PackedScene
	if ps == null:
		return {"slot": slot_id, "ok": false, "error": "could not load " + model_path}
	var kind := str(s.get("kind", ""))
	var character := kind in ["unit", "enemy"]
	var root := Node3D.new()
	root.name = slot_id.replace(".", "_")
	var model := ps.instantiate() as Node3D
	if model == null:
		root.free()
		return {"slot": slot_id, "ok": false, "error": "model root is not a Node3D"}
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	model.rotation_degrees.y = float(c.get("rotation_y", 180.0 if character else 0.0))
	var raw := VisualSlots.bounds(model, model.transform)
	if raw.size == Vector3.ZERO:
		root.free()
		return {"slot": slot_id, "ok": false, "error": "model has no visible geometry"}
	var proxy_node := ProxyBuilder.build(slot_id, s.get("proxy", {}) as Dictionary)
	var proxy := VisualSlots.bounds(proxy_node)
	proxy_node.free()
	var mode := str(c.get("fit", fit_mode(slot_id)))
	var declared := float(s.get("height", proxy.end.y))
	var sc := 1.0
	var notes: Array = []
	match mode:
		"height":
			sc = declared / maxf(raw.size.y, 0.001)
		"footprint":
			sc = (float(s.get("usable_width", 11.0)) + 0.6) / maxf(raw.size.x, 0.001)
		_:
			var ratio := maxf(proxy.size.y, 0.01) / maxf(raw.size.y, 0.001)
			if ratio < 0.05:
				sc = 0.01
				notes.append("centimetres -> metres (x0.01)")
			elif ratio > 20.0:
				sc = 100.0
				notes.append("x100 (file in units of 100 m?)")
	if mode != "natural" and absf(sc - 0.01) < 0.004:
		notes.append("file looks like centimetres (scale %.4f)" % sc)
	sc *= float(c.get("extra_scale", 1.0))
	model.scale = Vector3.ONE * sc
	var scaled := VisualSlots.bounds(model, model.transform)
	var align := str(c.get("align", "top" if mode == "footprint" else "base"))
	var centre := Vector3.ZERO if (character or kind == "prop") else proxy.get_center()
	var ty := -scaled.end.y if align == "top" else -scaled.position.y
	model.position += Vector3(centre.x - scaled.get_center().x, ty, centre.z - scaled.get_center().z)
	var final := VisualSlots.bounds(model, model.transform)
	# Animations
	var family := str(s.get("rig_family", ""))
	var rig := {}
	var lib_path := ""
	var has_skel := not model.find_children("*", "Skeleton3D", true, false).is_empty()
	var reimport := false
	var own_clips := false
	if character and has_skel and family == "humanoid":
		rig = HumanoidBoneMapper.apply_retarget(model_path)
		if not rig.get("ok", false) and rig.get("humanoid", true) == false:
			# Real-FBX lesson: generic bone names cannot be retargeted. Fall back to the
			# model's own embedded clips (map them via the choice's "clips": {state: clip}).
			notes.append(str(rig.get("error", "")))
			own_clips = true
		else:
			reimport = bool(rig.get("changed", false))
			if reimport:
				notes.append("humanoid bone map set (re-import, then build again)")
			if not Array(rig.get("missing_core", [])).is_empty():
				notes.append("bone map missing: " + ", ".join(rig["missing_core"]))
			lib_path = str(libs.get("humanoid", ""))
	if character and (family == "quadruped" or own_clips):
		var sets: Variant = JSON.parse_string(FileAccess.get_file_as_string(UnitAnimator.SETS_PATH)) if FileAccess.file_exists(UnitAnimator.SETS_PATH) else {}
		var kw: Dictionary = (sets as Dictionary).get("keywords", {}) if sets is Dictionary else {}
		var names: Dictionary = {}
		if sets is Dictionary and family == "quadruped":
			names = ((((sets as Dictionary).get("sets", {}) as Dictionary).get("quadruped", {}) as Dictionary).get("clips", {}) as Dictionary).duplicate()
		names.merge(c.get("clips", {}) as Dictionary, true)
		var lr := AnimationLibraryBuilder.build_from_embedded(slot_id, model_path, kw, names, lib_dir)
		var prev_missing: Array = rig.get("missing_core", []) as Array
		rig = {"skeleton": "own rig (no retarget)", "clips": lr.get("clips", {}), "errors": lr.get("errors", []),
			"embedded_clips": lr.get("embedded", []), "missing_core": prev_missing}
		lib_path = str(lr.get("library", ""))
		if (lr.get("clips", {}) as Dictionary).is_empty():
			notes.append("no embedded clip matched a state; set \"clips\": {\"idle\": \"<clip>\"} in the choice. Embedded: " + ", ".join(lr.get("embedded", [])))
	# Vendor scenes often carry their own Camera3D/lights: skip them on import.
	var extra := _skip_cameras_lights(model, model_path)
	if extra > 0:
		notes.append("%d camera/light node(s) skipped via import settings" % extra)
		reimport = true
	if not lib_path.is_empty() and ResourceLoader.exists(lib_path) and not reimport:
		var ap := AnimationPlayer.new()
		ap.name = "LRAnimations"
		root.add_child(ap)
		ap.owner = root
		ap.root_node = NodePath("../Model")
		ap.add_animation_library(UnitAnimator.LIB, load(lib_path) as AnimationLibrary)
	# Shared atlas material for untextured surfaces (FBX imports often lose the link).
	var need: Dictionary = {}
	_untextured_materials(model, need)
	var uses_atlas := _uses_material_dir(model, MATERIALS)
	if not need.is_empty():
		var atlas := _atlas_material(pack)
		if atlas:
			reimport = _use_external(model_path, need.keys(), atlas.resource_path) or reimport
		else:
			notes.append("no atlas texture staged for " + pack)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(prefab_dir))
	var scene_path := prefab_dir.path_join(slot_id + ".tscn")
	root.set_meta("lr_source", src)
	root.set_meta("lr_fit", mode)
	var facing: String = RigLab.facing_of(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, scene_path)
	root.free()
	if err != OK:
		return {"slot": slot_id, "ok": false, "error": "save failed (%d)" % err}
	var warn: Array = []
	if mode == "natural" and proxy.size.y > 0.01 and (final.size.y / proxy.size.y < 0.4 or final.size.y / proxy.size.y > 2.5):
		warn.append("height %.0f%% of the proxy: check scale or choose another model" % (final.size.y / proxy.size.y * 100.0))
	var limit := 1.2 * float(s.get("space", 1)) + 0.8 if kind == "unit" else 3.2
	if character and maxf(final.size.x, final.size.z) > limit:
		warn.append("footprint %.1f m is too wide for this slot (max ~%.1f): wrong model, lying/Z-up export, or use \"fit\": \"natural\"/\"extra_scale\"" % [maxf(final.size.x, final.size.z), limit])
	if character and facing == "+Z":
		warn.append("faces +Z: set rotation_y (0 or 180) in synty_choices.json")
	return {"slot": slot_id, "ok": true, "scene": scene_path, "source": src, "fit": mode, "scale": snappedf(sc, 0.0001),
		"size_m": [snappedf(final.size.x, 0.01), snappedf(final.size.y, 0.01), snappedf(final.size.z, 0.01)],
		"min_m": [snappedf(final.position.x, 0.01), snappedf(final.position.y, 0.01), snappedf(final.position.z, 0.01)],
		"height_m": snappedf(final.end.y, 0.01), "proxy_m": [snappedf(proxy.size.x, 0.01), snappedf(proxy.size.y, 0.01), snappedf(proxy.size.z, 0.01)],
		"facing": facing, "uses_atlas": uses_atlas, "atlas_materials": need.size(), "reimport": reimport,
		"rig": rig.get("skeleton", ""), "library": lib_path, "anim": rig.get("clips", {}), "notes": notes, "warnings": warn,
		"summary": "%s x%.4f -> %.2fx%.2fx%.2f m, facing %s%s%s" % [mode, sc, final.size.x, final.size.y, final.size.z, facing,
			(" · lib " + lib_path.get_file()) if not lib_path.is_empty() else "", ("  ▲ " + "; ".join(warn)) if not warn.is_empty() else ""]}


func _atlas_material(pack: String) -> Material:
	var path := MATERIALS.path_join(pack.to_snake_case() + "_atlas.tres")
	if ResourceLoader.exists(path):
		return load(path)
	var sp := "res://assets/imported/%s/staged.json" % pack
	var staged: Variant = JSON.parse_string(FileAccess.get_file_as_string(sp)) if FileAccess.file_exists(sp) else null
	var tex_path := ""
	if staged is Dictionary:
		for t: Variant in (staged as Dictionary).get("atlas", []) as Array:
			tex_path = "res://" + str(t)
			break
	if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
		return null
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex_path)
	m.roughness = 0.9
	m.metallic = 0.0
	m.resource_name = pack + " atlas"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIALS))
	ResourceSaver.save(m, path)
	return load(path)


func _uses_material_dir(n: Node, dir: String) -> bool:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mesh := (n as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat and mat.resource_path.begins_with(dir):
				return true
	for ch: Node in n.get_children():
		if _uses_material_dir(ch, dir):
			return true
	return false


func _untextured_materials(n: Node, out: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mesh := (n as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture == null and not mat.resource_name.is_empty() and not mat.resource_path.begins_with(MATERIALS):
				out[mat.resource_name] = true
	for ch: Node in n.get_children():
		_untextured_materials(ch, out)


## Marks Camera3D/Light3D nodes of an imported scene as "skip import" in its .import
## file. Returns how many were newly marked (re-import needed when > 0).
func _skip_cameras_lights(model: Node, model_path: String) -> int:
	var found: Array = model.find_children("*", "Camera3D", true, false) + model.find_children("*", "Light3D", true, false)
	if found.is_empty():
		return 0
	var cfg := ConfigFile.new()
	if cfg.load(model_path + ".import") != OK:
		return 0
	var sub: Dictionary = cfg.get_value("params", "_subresources", {})
	var nodes: Dictionary = sub.get("nodes", {})
	var changed := 0
	for n: Node in found:
		var key := "PATH:" + str(model.get_path_to(n))
		var cur: Dictionary = nodes.get(key, {})
		if not cur.get("import/skip_import", false):
			cur["import/skip_import"] = true
			nodes[key] = cur
			changed += 1
	if changed > 0:
		sub["nodes"] = nodes
		cfg.set_value("params", "_subresources", sub)
		cfg.save(model_path + ".import")
	return changed


## Points named materials of a model at an external material in its .import file
## (what Advanced Import Settings > Materials > Use External does). True = re-import needed.
func _use_external(model_path: String, names: Array, material_path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(model_path + ".import") != OK:
		return false
	var sub: Dictionary = cfg.get_value("params", "_subresources", {})
	var mats: Dictionary = sub.get("materials", {})
	var changed := false
	for n: Variant in names:
		var cur: Dictionary = mats.get(str(n), {})
		if cur.get("use_external/path", "") != material_path or not cur.get("use_external/enabled", false):
			cur["use_external/enabled"] = true
			cur["use_external/path"] = material_path
			mats[str(n)] = cur
			changed = true
	if changed:
		sub["materials"] = mats
		cfg.set_value("params", "_subresources", sub)
		cfg.save(model_path + ".import")
	return changed
