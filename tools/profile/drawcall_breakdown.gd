extends Node
## Draw-call breakdown per subsystem of the battle scene (needs a real renderer):
##   XDG_DATA_HOME=/tmp/xdg_x xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
##     --rendering-method gl_compatibility --resolution 1920x1080 res://tools/profile/drawcall_breakdown.tscn \
##     [-- --out=evidence/perf/drawcalls/breakdown.json] [--no-merge]
## For midbattle, boss and full_tree (same states as stress_profile.gd): total draw
## calls / objects / primitives of the 3D pass and the 2D canvas, then each
## subsystem hidden in turn (delta = its cost): backdrop, floors (floor + trunk
## per floor), heart, mutations, units, other 3D (fx, markers). Also a static
## count of visible GeometryInstance3D nodes, surfaces and overlays per subsystem,
## and the totals of the menu / route / epilog dioramas. --no-merge = ProxyMerge off.

const BATTLE := "res://scenes/battle/battle.tscn"
const DIORAMAS := ["res://scenes/art/menu_diorama.tscn", "res://scenes/art/route_diorama.tscn", "res://scenes/art/epilog_diorama.tscn"]
var out_path := "res://evidence/perf/drawcalls/breakdown.json"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
			if not out_path.begins_with("/") and not out_path.begins_with("res://"):
				out_path = "res://" + out_path
		elif a == "--no-merge" and ResourceLoader.exists("res://scripts/runtime/visual/proxy_merge.gd"):
			(load("res://scripts/runtime/visual/proxy_merge.gd") as GDScript).set("enabled", false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _info() -> Dictionary:
	var vp := get_viewport()
	var v := Viewport.RENDER_INFO_TYPE_VISIBLE
	return {
		"draw_calls_3d": vp.get_render_info(v, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"objects_3d": vp.get_render_info(v, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"primitives_3d": vp.get_render_info(v, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"draw_calls_shadow": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"draw_calls_canvas": vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"draw_calls_total": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects_total": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives_total": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}


func _category(n: Node) -> String:
	var nm := String(n.name)
	if nm.begins_with("stage_backdrop"):
		return "backdrop"
	if nm.begins_with("FloorView"):
		return "floors"
	if nm.begins_with("stage_heart"):
		return "heart"
	if nm.begins_with("mutation_"):
		return "mutations"
	if n is UnitView:
		return "units"
	if n is Node3D and not (n is Camera3D or n is Light3D or n is WorldEnvironment):
		return "other_3d"
	return ""


func _static_count(n: Node, acc: Dictionary) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is GeometryInstance3D:
		acc["instances"] = int(acc.get("instances", 0)) + 1
		var gi := n as GeometryInstance3D
		var surf := 1
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			surf = (n as MeshInstance3D).mesh.get_surface_count()
		elif n is MultiMeshInstance3D:
			acc["multimeshes"] = int(acc.get("multimeshes", 0)) + 1
		acc["surfaces"] = int(acc.get("surfaces", 0)) + surf
		if gi.material_overlay != null:
			acc["overlay_surfaces"] = int(acc.get("overlay_surfaces", 0)) + surf
	for c: Node in n.get_children():
		_static_count(c, acc)


func _profile(fx: String) -> Dictionary:
	var run: Dictionary
	if fx == "full_tree":
		var sp: Node = (load("res://tools/profile/stress_profile.gd") as GDScript).new()
		run = sp.call("_full_tree")
		sp.free()
	else:
		run = DebugFixtures.make(fx, "BARK", 2)
	GameSession.run = run
	GameSession.presentation_pending = false
	var scr: BattleScreen = (load(BATTLE) as PackedScene).instantiate() as BattleScreen
	add_child(scr)
	await _frames(60)
	var res := {"all": _info()}
	var stage: TreeStage = scr.stage
	var cats := {}
	for c: Node in stage.get_children():
		var k := _category(c)
		if k.is_empty():
			continue
		if not cats.has(k):
			cats[k] = []
		(cats[k] as Array).append(c)
	var stat := {}
	for k: String in cats:
		var acc := {}
		for n: Node in cats[k]:
			_static_count(n, acc)
		stat[k] = acc
	res["static"] = stat
	var delta := {}
	for k: String in cats:
		var was: Array = []
		for n: Node3D in cats[k]:
			was.append(n.visible)
			n.visible = false
		await _frames(3)
		var i := _info()
		delta[k] = {"draw_calls_3d": int(res["all"]["draw_calls_3d"]) - int(i["draw_calls_3d"]),
			"objects_3d": int(res["all"]["objects_3d"]) - int(i["objects_3d"]),
			"primitives_3d": int(res["all"]["primitives_3d"]) - int(i["primitives_3d"])}
		for j: int in (cats[k] as Array).size():
			(cats[k][j] as Node3D).visible = was[j]
		await _frames(2)
	res["delta_hidden"] = delta
	stage.visible = false
	await _frames(3)
	res["stage_hidden"] = _info()
	stage.visible = true
	scr.queue_free()
	await _frames(5)
	return res


func _main() -> void:
	var report := {"renderer": RenderingServer.get_current_rendering_method(),
		"window": [get_window().size.x, get_window().size.y]}
	for fx: String in ["midbattle", "boss", "full_tree"]:
		report[fx] = await _profile(fx)
		var r: Dictionary = report[fx]
		print("BREAKDOWN %s total=%d 3d=%d canvas=%d shadow=%d  %s" % [fx, r["all"]["draw_calls_total"], r["all"]["draw_calls_3d"],
			r["all"]["draw_calls_canvas"], r["all"]["draw_calls_shadow"], JSON.stringify(r["delta_hidden"])])
		print("STATIC %s %s" % [fx, JSON.stringify(r["static"])])
	var dio := {}
	for path: String in DIORAMAS:
		var d: Node = (load(path) as PackedScene).instantiate()
		add_child(d)
		await _frames(30)
		dio[path.get_file().get_basename()] = {"draw_calls_total": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects_total": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			"primitives_total": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
		print("DIORAMA %s %s" % [path.get_file(), JSON.stringify(dio[path.get_file().get_basename()])])
		d.queue_free()
		await _frames(5)
	report["dioramas"] = dio
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ", true))
	f.close()
	get_tree().quit(0)
