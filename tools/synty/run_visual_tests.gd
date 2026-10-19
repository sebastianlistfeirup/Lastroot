extends SceneTree
## Runs tests/unit/test_visual_slots.gd without the coordinator's runner.
##   godot --headless --path . --script res://tools/synty/run_visual_tests.gd
## Exit code 0 = all pass.


func _init() -> void:
	var t: RefCounted = (load("res://tests/unit/test_visual_slots.gd") as GDScript).new()
	var failed := 0
	var total := 0
	for m: Dictionary in t.get_method_list():
		var n := str(m["name"])
		if not n.begins_with("test_"):
			continue
		total += 1
		var fails: Array = t.call(n)
		if fails.is_empty():
			print("PASS ", n)
		else:
			failed += 1
			print("FAIL ", n)
			for s: Variant in fails:
				print("     - ", s)
	print("visual tests: %d/%d passed" % [total - failed, total])
	quit(1 if failed > 0 else 0)
