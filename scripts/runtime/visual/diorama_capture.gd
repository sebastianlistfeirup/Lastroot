class_name DioramaCapture
extends Node
## Dev helper for the art dioramas: reads --capture=<png> [--frames=N] from the
## command line and saves the viewport after N frames, then quits. Does nothing
## without --capture (so it is harmless when the scene is embedded in the game).


static func attach(owner_node: Node) -> void:
	var path := ""
	var frames := 60
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			path = a.substr(10)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
	if path.is_empty() or not owner_node.is_inside_tree() or owner_node.get_tree().current_scene != owner_node:
		return
	var c := DioramaCapture.new()
	c.set_meta("path", path)
	c.set_meta("frames", frames)
	owner_node.add_child(c)


var _n: int = 0


func _process(_dt: float) -> void:
	_n += 1
	if _n == int(get_meta("frames")):
		var p := str(get_meta("path"))
		var abs_path := ProjectSettings.globalize_path(p if p.begins_with("res://") else "res://" + p)
		DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
		get_viewport().get_texture().get_image().save_png(abs_path)
		print("captured ", p)
		get_tree().quit()
