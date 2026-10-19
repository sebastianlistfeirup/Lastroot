class_name DioramaLayer
extends SubViewportContainer
## Embeds one 3D diorama (MenuDiorama / RouteDiorama) behind a 2D screen, per
## docs/SCENE_ASSEMBLY.md: stretched container that ignores the mouse, own 3D
## world, MSAA off, child index 0 of the screen. The screen frees it when it
## leaves the tree, so only one diorama SubViewport exists at a time.
## Falls back to the 2D backdrop when 3D is off in Settings, when running
## headless (tests), or on very small screens.

const MENU := "res://scenes/art/menu_diorama.tscn"
const ROUTE := "res://scenes/art/route_diorama.tscn"
## Below this logical size the 2D backdrop is used (keeps tiny screens light).
const MIN_SIDE := 360.0

var diorama: Node = null
var _vp: SubViewport


## True when a 3D background may be shown on a viewport of this size.
static func allowed(vp_size: Vector2) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if not SettingsService.backgrounds_3d:
		return false
	return minf(vp_size.x, vp_size.y) >= MIN_SIDE


## Builds the layer, or returns null when 3D is not allowed / fails to load.
static func make(scene_path: String, dim: float) -> DioramaLayer:
	if not ResourceLoader.exists(scene_path):
		return null
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		return null
	var inst: Node = ps.instantiate()
	if inst == null:
		return null
	var layer := DioramaLayer.new()
	layer.name = "Diorama3D"
	layer.stretch = true
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.focus_mode = Control.FOCUS_NONE
	layer._vp = SubViewport.new()
	layer._vp.own_world_3d = true
	layer._vp.transparent_bg = false
	layer._vp.msaa_3d = Viewport.MSAA_DISABLED
	layer._vp.handle_input_locally = false
	layer._vp.gui_disable_input = true
	layer.add_child(layer._vp)
	layer._vp.add_child(inst)
	layer.diorama = inst
	layer.set_dim(dim)
	return layer


func set_dim(d: float) -> void:
	if diorama and "dim" in diorama:
		diorama.set("dim", clampf(d, 0.0, 1.0))


func set_portrait(p: bool) -> void:
	if diorama and diorama.has_method("set_portrait"):
		diorama.call("set_portrait", p)


## RouteDiorama progress from a run: lit battles up to the current one and the
## middle nodes the player actually chose, in route_map coordinates.
static func chosen_nodes(run: Dictionary) -> Array:
	var out: Array = []
	for r: Dictionary in run.get("route", []):
		if str(r.get("status", "")) != "chosen":
			continue
		var opts: Array = r.get("options", [])
		for j in opts.size():
			if (opts[j] as Dictionary).get("id", "") == r.get("chosen", ""):
				out.append(Vector2i(int(r["after_battle"]) * 2 - 1, -1 if j == 0 else 1))
	return out


func show_run(run: Dictionary) -> void:
	if diorama == null or not diorama.has_method("set_progress"):
		return
	var idx: int = int(run.get("battle_index", 0))
	if str(run.get("phase", "")) in ["reward", "route", "node"]:
		idx = maxi(0, int(run.get("stats", {}).get("battles_won", idx + 1)) - 1)
	diorama.call("set_progress", idx, chosen_nodes(run))
	if diorama.has_method("focus"):
		diorama.call("focus", idx)
