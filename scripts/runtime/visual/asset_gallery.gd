class_name AssetGallery
extends Node3D
## STYLE GATE (bible "Style gate"): every unit and enemy lined up under one light,
## plus a stage view (three floors, trunk, heart, backdrop) and a props/fx view.
## Shows proxies or the mapped purchased models, whichever VisualSlots.make gives.
## Keys: 1 lineup, 2 stage, 3 props/mutations/fx, A cycle animation state, R reduced motion.
## Capture: godot --path . res://scenes/tests/asset_gallery.tscn -- --mode=stage --capture=evidence/asset_pipeline/gallery_stage.png
## Dev tool: text not localized.

const STATES: Array[StringName] = [&"idle", &"attack", &"cast", &"hit", &"defend", &"victory", &"summon", &"death"]

@export_enum("lineup", "stage", "props", "gate") var mode: String = "lineup"

var _content: Node3D
var _cam: Camera3D
var _label: Label
var _state_i: int = 0
var _capture: String = ""
var _frames: int = 0
var _anim_state: StringName = &""
var _t0: int = 0
var _captured: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--capture="):
			_capture = a.substr(10)
		elif a.begins_with("--state="):
			_anim_state = StringName(a.substr(8))
		elif a == "--reduced-motion":
			UnitAnimator.reduced_motion = true
	_world()
	var ui := CanvasLayer.new()
	add_child(ui)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(_label)
	_show(mode)


func _world() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1b1530")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#7b6aa8")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = OS.get_cmdline_user_args().has("--glow")
	e.glow_intensity = 0.6
	e.fog_enabled = false
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe2b8")
	sun.light_energy = 1.25
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#6a7cff")
	rim.light_energy = 0.45
	rim.rotation_degrees = Vector3(-20, 150, 0)
	add_child(rim)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.far = 300.0
	add_child(_cam)
	_cam.current = true


func _show(m: String) -> void:
	mode = m
	if _content:
		_content.queue_free()
	_content = Node3D.new()
	add_child(_content)
	match m:
		"stage":
			_stage()
		"props":
			_props()
		"gate":
			_gate()
		_:
			_lineup()
	if _anim_state != &"":
		_play_all.call_deferred(_anim_state)


## Three shelves like the battle floors: Bark folk (top), Spore folk, ash enemies (bottom).
func _lineup() -> void:
	var rows := [["unit.B01", "unit.B02", "unit.B03", "unit.B04", "unit.B05", "unit.B06"],
		["unit.S01", "unit.S02", "unit.S03", "unit.S04", "unit.S05", "unit.S06"],
		["enemy.E01", "enemy.E02", "enemy.E03", "enemy.E04", "enemy.E05", "enemy.E06"]]
	for r: int in rows.size():
		var y := 8.0 - 4.0 * float(r)
		_shelf(y, 26.0)
		var ids: Array = rows[r]
		var widths: Array[float] = []
		var total := 0.0
		for id: String in ids:
			var w := _width(id)
			widths.append(w)
			total += w
		var gap := (24.0 - total) / float(ids.size() - 1)
		var x := -12.0
		for i: int in ids.size():
			_place(ids[i], Vector3(x + widths[i] * 0.5, y, 0.0), 120.0 if r == 2 else -120.0)
			x += widths[i] + gap
	_cam.size = 15.0
	_cam.position = Vector3(0, 10.6, 30)
	_cam.rotation_degrees = Vector3(-10, 0, 0)
	_label.text = "STYLE GATE · all units + enemies, one light, 1 m grid · 1 lineup  2 stage  3 props/fx  4 gate  A animate  R reduced motion"


## The bible's minimum gate: both champions, two normal units, two enemies, close up.
func _gate() -> void:
	_shelf(0.0, 14.0)
	var ids := ["unit.B01", "unit.S01", "unit.B02", "unit.S02", "enemy.E01", "enemy.E05"]
	var x := -4.7
	for id: String in ids:
		var w := _width(id)
		_place(id, Vector3(x + w * 0.5, 0, 0.0), 120.0 if id.begins_with("enemy") else -120.0)
		x += w + 0.45
	_cam.size = 6.2
	_cam.position = Vector3(0.9, 3.4, 20)
	_cam.rotation_degrees = Vector3(-6, 0, 0)
	_label.text = "STYLE GATE · champions B01 + S01, normal B02 + S02, enemies E01 + E05"


func _width(id: String) -> float:
	if id == "enemy.E06":
		return 2.6
	if id.begins_with("enemy"):
		return 1.6 if id == "enemy.E05" else 1.2
	return float(VisualSlots.slot(id).get("space", 1)) * 0.8 + 0.3


func _shelf(y: float, w: float) -> void:
	var ground := MeshInstance3D.new()
	ground.mesh = ProxyMesh.box(Vector3(w, 0.12, 3.2))
	ground.material_override = VisualPalette.mat("stone_dark")
	ground.position = Vector3(0, y - 0.06, 0)
	_content.add_child(ground)
	for i: int in range(-int(w * 0.5), int(w * 0.5) + 1):
		var line := MeshInstance3D.new()
		line.mesh = ProxyMesh.box(Vector3(0.025, 0.01, 3.2))
		line.material_override = VisualPalette.mat("stone")
		line.position = Vector3(i, y + 0.005, 0)
		_content.add_child(line)


func _place(id: String, pos: Vector3, yaw: float, label: bool = true) -> Node3D:
	var v := VisualSlots.make(id)
	v.position = pos
	v.rotation_degrees.y = yaw
	_content.add_child(v)
	if label:
		var l := Label3D.new()
		var s := VisualSlots.slot(id)
		l.text = "%s\n%s · %.1f m%s" % [str(s.get("name", id)), id, float(s.get("height", 0.0)), "" if v.get_meta("is_proxy", true) else " · MODEL"]
		l.font_size = 32
		l.pixel_size = 0.0035 if mode != "gate" else 0.0018
		l.outline_size = 10
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = pos + Vector3(0, 0.12, 1.25)
		_content.add_child(l)
		var badge := Label3D.new()
		badge.text = "▼"
		badge.modulate = Color("#ffd060")
		badge.font_size = 48
		badge.pixel_size = 0.004
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.position = pos + Vector3(0, VisualSlots.head_height(id), 0)
		_content.add_child(badge)
	return v


## The battle composition: floors at y 0 / 4.5 / 9, trunk behind, heart on top.
func _stage() -> void:
	_content.add_child(VisualSlots.make("stage.backdrop"))
	var floors := ["stage.floor_roots", "stage.floor_trunk", "stage.floor_crown"]
	for i: int in 3:
		var f := VisualSlots.make(floors[i])
		f.position.y = 4.5 * i
		_content.add_child(f)
		var t := VisualSlots.make("stage.trunk")
		t.position.y = 4.5 * i - 4.5
		_content.add_child(t)
	var heart := VisualSlots.make("stage.heart")
	heart.position = Vector3(0, 9.0, -2.6)
	_content.add_child(heart)
	var pulse := VisualSlots.make("fx.heart_pulse")
	pulse.position = heart.position
	_content.add_child(pulse)
	var layout := [
		[0, ["unit.B01", "unit.S02", "unit.B02"], ["enemy.E01", "enemy.E02", "enemy.E01"]],
		[1, ["unit.S01", "unit.B04"], ["enemy.E03", "enemy.E05"]],
		[2, ["unit.B03", "unit.S04"], ["enemy.E06"]],
	]
	for row: Array in layout:
		var y := 4.5 * float(row[0])
		var ax := -4.8
		for id: String in row[1]:
			var w := float(VisualSlots.slot(id).get("space", 1)) * 0.95
			_place(id, Vector3(ax + w * 0.5, y, 0.1), -115.0, false)
			ax += w + 0.2
		var ex := 4.8
		for id: String in row[2]:
			var w := 2.4 if id == "enemy.E06" else 1.2
			_place(id, Vector3(ex - w * 0.5, y, 0.1), 115.0, false)
			ex -= w + 0.25
	var poison := VisualSlots.make("fx.poison")
	poison.position = Vector3(4.2, 0, 0.1)
	_content.add_child(poison)
	_cam.size = 17.0
	_cam.position = Vector3(0, 13.0, 30)
	_cam.rotation_degrees = Vector3(-12, 0, 0)
	_label.text = "STAGE · floors y=0/4.5/9, trunk behind (z<-1.2), heart on top · front edges free"


func _props() -> void:
	var g := MeshInstance3D.new()
	g.mesh = ProxyMesh.box(Vector3(30, 0.1, 10))
	g.material_override = VisualPalette.mat("stone_dark")
	g.position = Vector3(0, -0.05, -1)
	_content.add_child(g)
	var x := -12.0
	for id: String in VisualSlots.ids_of_kind("prop"):
		_place(id, Vector3(x, 0, 1.5), 0.0)
		x += 2.6
	x = -12.0
	for id: String in VisualSlots.ids_of_kind("fx"):
		_place(id, Vector3(x, 0, -2.5), 0.0)
		x += 2.6
	_place("mutation.M04", Vector3(10, 0, 1.0), 0.0)
	_place("stage.heart", Vector3(10, 0, 1.0), 0.0, false)
	_cam.size = 14.0
	_cam.position = Vector3(0, 8, 16)
	_cam.rotation_degrees = Vector3(-22, 0, 0)
	_label.text = "PROPS (front) · FX (back) · M04 on the heart"


func _play_all(state: StringName) -> void:
	for n: Node in _content.find_children("UnitAnimator", "UnitAnimator", true, false):
		(n as UnitAnimator).play(state)


func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_1:
			_show("lineup")
		KEY_2:
			_show("stage")
		KEY_3:
			_show("props")
		KEY_4:
			_show("gate")
		KEY_A:
			_state_i = (_state_i + 1) % STATES.size()
			_play_all(STATES[_state_i])
			_label.text = "state: " + String(STATES[_state_i])
		KEY_R:
			UnitAnimator.reduced_motion = not UnitAnimator.reduced_motion
			_label.text = "reduced motion: %s" % UnitAnimator.reduced_motion


func _process(_dt: float) -> void:
	if _capture.is_empty():
		return
	_frames += 1
	if _frames == 1:
		_t0 = Time.get_ticks_msec()
	# Mid-animation (near the contact frame) for --state captures, settled particles otherwise.
	var ready_now := (Time.get_ticks_msec() - _t0 >= 280 and _frames > 3) if _anim_state != &"" else _frames == 45
	if ready_now and not _captured:
		_captured = true
		var img := get_viewport().get_texture().get_image()
		var path := _capture if _capture.begins_with("res://") or _capture.begins_with("/") else "res://" + _capture
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		img.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
		print("captured ", path)
		get_tree().quit()
