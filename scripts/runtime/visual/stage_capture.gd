extends Node3D
## ART GATE for the TreeStage (REF_05): builds the real TreeStage, applies the
## chosen mutations and places a few units at the real StageLayout anchors, so the
## stage art can be judged with units and mutations together.
##   godot --path . --rendering-method gl_compatibility --resolution 1920x1080 \
##     res://scenes/tests/stage_mutations.tscn -- --mutations=M01,M02,M03,M04 \
##     --capture=evidence/asset_pipeline/stage_mutations_all.png [--frames=90] [--portrait] [--no-units]
## Dev tool: text not localized.

var _capture: String = ""
var _frames: int = 90
var _n: int = 0


func _ready() -> void:
	var muts := ["M01", "M02", "M03", "M04"]
	var portrait := false
	var units := true
	var markers := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mutations="):
			muts = Array(a.substr(12).split(",", false))
		elif a.begins_with("--capture="):
			_capture = a.substr(10)
		elif a.begins_with("--frames="):
			_frames = int(a.substr(9))
		elif a == "--portrait":
			portrait = true
		elif a == "--no-units":
			units = false
		elif a == "--markers":
			markers = true
	var stage := TreeStage.new()
	add_child(stage)
	stage.build()
	stage.frame_camera(portrait, 0.0 if portrait else 0.23)
	stage.apply_mutations(muts)
	if units:
		_units(markers)
	if markers:
		var strip := VisualSlots.make("fx.floor_target") as TargetMarker
		strip.position.y = StageLayout.floor_y(1)
		add_child(strip)
		strip.set_kind(&"target")
	var ui := CanvasLayer.new()
	add_child(ui)
	var l := Label.new()
	l.text = "TreeStage art gate · mutations: %s" % (", ".join(muts) if not muts.is_empty() else "none")
	l.position = Vector2(16, 12)
	l.add_theme_font_size_override("font_size", 22)
	ui.add_child(l)


## A representative line-up at the real anchors: allies left, enemies right.
## markers: side rims/discs on every unit and one ring of each kind
## (B01 selected, E01 target, E02 danger, S02 invalid, E06 target).
func _units(markers: bool = false) -> void:
	var kinds := {"unit.B01": &"selected", "enemy.E01": &"target", "enemy.E02": &"danger", "unit.S02": &"invalid", "enemy.E06": &"target"}
	var rows := [[0, ["unit.B01", "unit.S02", "unit.B02"], ["enemy.E01", "enemy.E02", "enemy.E04"]],
		[1, ["unit.S01", "unit.B04"], ["enemy.E03", "enemy.E05"]],
		[2, ["unit.B06"], ["enemy.E06"]]]
	for row: Array in rows:
		var f: int = row[0]
		var ids: Array = row[1]
		var spaces: Array = ids.map(func(id: Variant) -> int: return int(VisualSlots.slot(str(id)).get("space", 1)))
		for i: int in ids.size():
			var v := VisualSlots.make(str(ids[i]))
			v.position = StageLayout.ally_pos(f, i, spaces)
			v.rotation_degrees.y = -90.0
			add_child(v)
			if markers:
				_mark(v, str(ids[i]), &"ally", kinds)
		var es: Array = row[2]
		for i: int in es.size():
			var v := VisualSlots.make(str(es[i]))
			v.position = StageLayout.enemy_pos(f, i, es.size(), str(es[i]) == "enemy.E06")
			v.rotation_degrees.y = 90.0
			add_child(v)
			if markers:
				_mark(v, str(es[i]), &"enemy", kinds)


func _mark(v: Node3D, id: String, side: StringName, kinds: Dictionary) -> void:
	VisualSlots.apply_side(v, side)
	if kinds.has(id):
		var ring := VisualSlots.make("fx.ring") as TargetMarker
		ring.position = v.position
		add_child(ring)
		ring.set_radius(VisualSlots.footprint_radius(id))
		ring.set_kind(kinds[id])


func _process(_dt: float) -> void:
	if _capture.is_empty():
		return
	_n += 1
	if _n == _frames:
		var path := ProjectSettings.globalize_path(_capture if _capture.begins_with("res://") else "res://" + _capture)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		get_viewport().get_texture().get_image().save_png(path)
		print("captured ", _capture)
		get_tree().quit()
