class_name TreeStage
extends Node3D
## The world tree diorama: three FloorViews, trunk, Heart, backdrop, lights and
## the locked orthographic side camera (bible p.16). Purely visual; floors are
## at StageLayout.FLOOR_Y. Mutations swap/add visuals on the same scene.

var camera: Camera3D
var heart: Node3D
var floor_views: Array[Node3D] = []
var _heart_light: OmniLight3D
var _mutation_nodes: Dictionary = {}
var _floor_lights: Array[OmniLight3D] = []


func build() -> void:
	name = "TreeStage"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0b0e1a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("4a4f7a")
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.12
	e.fog_enabled = true
	e.fog_light_color = Color("2a2246")
	e.fog_density = 0.008
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_color = Color("ffd9a8")
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_color = Color("8a7cff")
	rim.light_energy = 0.55
	add_child(rim)
	add_child(VisualBridge.make("stage.backdrop"))
	var floors := ["stage.floor_roots", "stage.floor_trunk", "stage.floor_crown"]
	for f in 3:
		var fv := Node3D.new()
		fv.name = "FloorView%d" % f
		fv.position.y = StageLayout.floor_y(f)
		fv.add_child(VisualBridge.make(floors[f]))
		var trunk := VisualBridge.make("stage.trunk")
		trunk.position.y = 0.0
		fv.add_child(trunk)
		add_child(fv)
		floor_views.append(fv)
		var l := OmniLight3D.new()
		l.position = Vector3(0, 2.2, 2.0)
		l.light_color = Color("ffb35c")
		l.light_energy = 0.0
		l.omni_range = 7.0
		fv.add_child(l)
		_floor_lights.append(l)
	heart = VisualBridge.make("stage.heart")
	heart.position = StageLayout.heart_pos()
	add_child(heart)
	_heart_light = OmniLight3D.new()
	_heart_light.position = StageLayout.heart_pos() + Vector3(0, 0, 1.2)
	_heart_light.light_color = UiKit.LIFE
	_heart_light.light_energy = 1.6
	_heart_light.omni_range = 9.0
	add_child(_heart_light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees.x = -7.0
	add_child(camera)
	frame_camera(false, 0.0)


## Desktop: tree on the left of the HUD's right panel. Portrait: fit width.
func frame_camera(portrait: bool, right_panel_ratio: float) -> void:
	if camera == null:
		return
	if portrait:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = 16.5
		camera.position = Vector3(0, 6.1, 30)
		camera.h_offset = 0.0
		camera.v_offset = -0.6
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.size = 21.6
		camera.position = Vector3(0, 6.1, 30)
		camera.h_offset = 21.6 * 16.0 / 9.0 * right_panel_ratio * 0.5
		camera.v_offset = 2.9


func highlight_floor(f: int, on: bool) -> void:
	if f >= 0 and f < _floor_lights.size():
		_floor_lights[f].light_energy = 1.2 if on else 0.0


func pulse_heart(strength: float = 1.0) -> void:
	var t := create_tween()
	t.tween_property(_heart_light, "light_energy", 1.6 + 2.5 * strength, 0.08)
	t.tween_property(_heart_light, "light_energy", 1.6, 0.35)
	var s := create_tween()
	s.tween_property(heart, "scale", Vector3.ONE * (1.0 + 0.18 * strength), 0.08)
	s.tween_property(heart, "scale", Vector3.ONE, 0.3)


func hurt_heart() -> void:
	var t := create_tween()
	_heart_light.light_color = UiKit.DANGER
	t.tween_property(_heart_light, "light_energy", 4.0, 0.06)
	t.tween_property(_heart_light, "light_energy", 1.6, 0.4)
	t.tween_callback(func() -> void: _heart_light.light_color = UiKit.LIFE)


## Shows owned mutations (visual only; never changes anchors or hit areas).
func apply_mutations(ids: Array) -> void:
	for mid: String in ["M01", "M02", "M03", "M04"]:
		var want: bool = ids.has(mid)
		if want and not _mutation_nodes.has(mid):
			var n := VisualBridge.make("mutation." + mid)
			if n.get_meta("is_proxy", false) and not ResourceLoader.exists(VisualBridge.VS_PATH):
				n.queue_free()
				continue
			var f: int = {"M01": 0, "M02": 1, "M03": 2, "M04": -1}[mid]
			n.position = StageLayout.heart_pos() if f < 0 else Vector3(0, StageLayout.floor_y(f), 0)
			add_child(n)
			_mutation_nodes[mid] = n
		elif not want and _mutation_nodes.has(mid):
			_mutation_nodes[mid].queue_free()
			_mutation_nodes.erase(mid)
	if ids.has("M04") and heart != null:
		heart.scale = Vector3.ONE * 1.15
