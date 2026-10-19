extends SceneTree
## Domain test runner: godot --headless --path . --script res://tests/run_tests.gd
## Writes evidence/test_report.json. Exit code 1 on any failure.

const DIR := "res://tests/unit/"


func _init() -> void:
	var files: PackedStringArray = []
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var total := 0
	var failed: PackedStringArray = []
	var per_file := {}
	var names: PackedStringArray = []
	for f in files:
		var script: GDScript = load(DIR + f)
		if script == null or not script.can_instantiate():
			failed.append("%s: script failed to load (parse error)" % f)
			continue
		var inst: Object = script.new()
		if not (inst is TestCase):
			# Specialist tests (RefCounted with test_* returning Array of failures).
			var n := 0
			for m in inst.get_method_list():
				var name: String = m["name"]
				if name.begins_with("test_"):
					n += 1
					total += 1
					var res: Variant = inst.call(name)
					if typeof(res) == TYPE_ARRAY:
						for x: Variant in res:
							failed.append("%s/%s: %s" % [f, name, x])
			per_file[f] = n
			continue
		var tc: TestCase = inst
		var count := 0
		for m in tc.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			count += 1
			total += 1
			tc.current = "%s/%s" % [f.get_basename(), name]
			names.append(tc.current)
			var t0 := Time.get_ticks_msec()
			if OS.get_environment("LR_TEST_VERBOSE") != "":
				print("> ", tc.current)
			tc.call(name)
			if OS.get_environment("LR_TEST_VERBOSE") != "":
				print("  %s %d ms" % [tc.current, Time.get_ticks_msec() - t0])
		per_file[f] = count
		failed.append_array(tc.failures)
	for x in failed:
		print("FAIL ", x)
	print("%d tests, %d failures" % [total, failed.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence"))
	var rep := FileAccess.open("res://evidence/test_report.json", FileAccess.WRITE)
	rep.store_string(JSON.stringify({
		"engine_version": Engine.get_version_info()["string"],
		"timestamp": Time.get_datetime_string_from_system(true),
		"tests": total, "failures": failed, "files": per_file, "names": names,
		"status": "PASS" if failed.is_empty() else "FAIL",
	}, "  ", true))
	rep.close()
	quit(0 if failed.is_empty() else 1)
