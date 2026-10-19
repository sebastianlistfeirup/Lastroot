extends Node3D
## Dev view: the heart at health 1.0 / 0.5 / 0.2 side by side (HeartVisual.set_health).
##   godot --path . res://scenes/tests/heart_strip.tscn -- --capture=evidence/asset_pipeline/heart_health_strip.png
## --hurt plays hurt(0.3) on all three a moment before the capture.


func _ready() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0b0e1a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("4a4f7a")
	e.ambient_light_energy = 0.9
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_color = Color("ffd9a8")
	add_child(sun)
	var hurt := OS.get_cmdline_user_args().has("--hurt")
	var values := [1.0, 0.5, 0.2]
	for i: int in 3:
		var h := VisualSlots.make("stage.heart")
		h.position = Vector3(-3.4 + 3.4 * float(i), 0, 0)
		add_child(h)
		h.call("set_health", values[i])
		var l := Label3D.new()
		l.text = "health %.1f" % values[i]
		l.font_size = 48
		l.pixel_size = 0.006
		l.outline_size = 10
		l.position = h.position + Vector3(0, -0.4, 1.0)
		add_child(l)
		if hurt:
			var tw := h.create_tween()
			tw.tween_interval(0.8)
			tw.tween_callback(Callable(h, "hurt").bind(0.3))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.6
	cam.position = Vector3(0, 1.1, 10)
	add_child(cam)
	cam.current = true
	DioramaCapture.attach(self)
