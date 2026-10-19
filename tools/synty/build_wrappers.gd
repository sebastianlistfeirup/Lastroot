extends SceneTree
## Builds LASTROOT slot wrappers from data/art/synty_choices.json (after stage.py + import).
##   godot --headless --path . --script res://tools/synty/build_wrappers.gd [-- options]
## Options (the selftest uses them to stay out of the real mappings):
##   --choices=res://data/art/synty_choices.json  --prefabs=res://art/prefabs/
##   --slot-scenes=res://data/art/slot_scenes.json --anim-dir=res://art/animations/
##   --report=res://evidence/asset_pipeline/build_report.json
## Order: 1. humanoid clip files get the shared bone map (import settings) and are
## collected into one "humanoid" AnimationLibrary; 2. every chosen slot gets a wrapper
## (SlotWrapperBuilder): fit, pivot, facing, atlas material, LRAnimations player;
## 3. slot -> wrapper (+ measured height) goes to slot_scenes.json, which VisualSlots reads.
## "import settings updated" = run godot --import once more and build again (build.sh does).

const BUILD_STATUS := ["auto", "approved", "manual"]


func _init() -> void:
	var choices_path := "res://data/art/synty_choices.json"
	var prefab_dir := SlotWrapperBuilder.PREFABS
	var scenes_path := VisualSlots.BUILT_PATH
	var lib_dir := AnimationLibraryBuilder.LIB_DIR
	var report_path := "res://evidence/asset_pipeline/build_report.json"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--choices="):
			choices_path = a.substr(10)
		elif a.begins_with("--prefabs="):
			prefab_dir = a.substr(10)
		elif a.begins_with("--slot-scenes="):
			scenes_path = a.substr(14)
		elif a.begins_with("--anim-dir="):
			lib_dir = a.substr(11)
		elif a.begins_with("--report="):
			report_path = a.substr(9)
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(choices_path)) if FileAccess.file_exists(choices_path) else null
	if not doc is Dictionary:
		push_error("build_wrappers: cannot read " + choices_path)
		quit(1)
		return
	var reimport := false
	# 1. Animation libraries per rig family (humanoid clip files).
	var libs: Dictionary = {}
	var anim_reports: Array = []
	var anims: Dictionary = (doc as Dictionary).get("animations", {}) as Dictionary
	for fam: String in anims.keys():
		var an: Dictionary = anims[fam]
		if not str(an.get("status", "")) in BUILD_STATUS:
			continue
		var states: Dictionary = {}
		var pending := false
		for state: String in (an.get("states", {}) as Dictionary).keys():
			var src := str(an["states"][state])
			var mp := src if src.begins_with("res://") else "res://assets/imported/" + src
			var rt := HumanoidBoneMapper.apply_retarget(mp)
			if not rt.get("ok", false):
				anim_reports.append({"set": fam, "state": state, "ok": false, "error": rt.get("error", "")})
				continue
			pending = pending or bool(rt.get("changed", false))
			states[state] = mp
		if pending:
			reimport = true
			print("%-22s bone map set on %d clips (re-import, then build again)" % ["anim." + fam, states.size()])
			continue
		var lr := AnimationLibraryBuilder.build_from_files(fam, states, lib_dir)
		anim_reports.append(lr)
		if lr["ok"]:
			libs[fam] = lr["library"]
		print("%-22s %s library %s" % ["anim." + fam, "OK  " if lr["ok"] else "FAIL", ", ".join((lr["clips"] as Dictionary).keys())])
	# 2. Wrappers.
	var prev: Variant = JSON.parse_string(FileAccess.get_file_as_string(scenes_path)) if FileAccess.file_exists(scenes_path) else null
	var mapped: Dictionary = (prev as Dictionary).get("scenes", {}) if prev is Dictionary else {}
	var heights: Dictionary = (prev as Dictionary).get("heights", {}) if prev is Dictionary else {}
	var builder := SlotWrapperBuilder.new()
	var report: Array = []
	var failed := 0
	var choices: Dictionary = (doc as Dictionary).get("choices", {}) as Dictionary
	for slot: String in choices.keys():
		var c: Dictionary = choices[slot]
		if not str(c.get("status", "")) in BUILD_STATUS or str(c.get("source", "")).is_empty():
			continue
		var r := builder.build_one(slot, c, prefab_dir, libs, lib_dir)
		report.append(r)
		if r["ok"]:
			mapped[slot] = r["scene"]
			heights[slot] = r["height_m"]
			reimport = reimport or bool(r.get("reimport", false))
		else:
			failed += 1
		print("%-22s %s %s" % [slot, "OK  " if r["ok"] else "FAIL", r.get("summary", r.get("error", ""))])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scenes_path).get_base_dir())
	var out := FileAccess.open(scenes_path, FileAccess.WRITE)
	out.store_string(JSON.stringify({"_note": "Written by tools/synty/build_wrappers.gd: slot -> wrapper scene and measured height. A non-empty \"scene\" in asset_slots.json wins.",
		"scenes": mapped, "heights": heights}, " ", true) + "\n")
	out.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path).get_base_dir())
	var ev := FileAccess.open(report_path, FileAccess.WRITE)
	ev.store_string(JSON.stringify({"built": report.size() - failed, "failed": failed, "reimport_needed": reimport, "slots": report, "animations": anim_reports}, "  "))
	ev.close()
	print("wrappers: %d built, %d failed -> %s" % [report.size() - failed, failed, scenes_path])
	if reimport:
		print("import settings updated: run  godot --headless --path . --import  and build again")
	quit(1 if failed > 0 else 0)
