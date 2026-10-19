extends Node
## Parse/compile check of every script in the project.
## godot --headless --path . res://scenes/tests/compile_all.tscn


func _ready() -> void:
	var files: PackedStringArray = []
	_collect("res://", files)
	var failed: PackedStringArray = []
	for f in files:
		var s: Variant = load(f)
		if s == null or not (s as GDScript).can_instantiate():
			failed.append(f)
	for f in failed:
		print("COMPILE FAIL ", f)
	print("COMPILE %d scripts, %d failed" % [files.size(), failed.size()])
	get_tree().quit(0 if failed.is_empty() else 1)


func _collect(dir: String, out: PackedStringArray) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d in ["builds", "archive"]:
			continue
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
