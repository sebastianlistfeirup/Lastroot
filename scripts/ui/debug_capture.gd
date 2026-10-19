class_name DebugCapture
extends Node
## Saves a screenshot after N frames and quits (evidence/shots, QA).

var path: String = "user://capture.png"
var frames: int = 90
var _n := 0


func _process(_dt: float) -> void:
	_n += 1
	if _n < frames:
		return
	var img: Image = get_viewport().get_texture().get_image()
	var abs_path: String = path if path.is_absolute_path() else ProjectSettings.globalize_path("res://" + path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	img.save_png(abs_path)
	print("CAPTURE ", abs_path, " ", img.get_size())
	get_tree().quit()
