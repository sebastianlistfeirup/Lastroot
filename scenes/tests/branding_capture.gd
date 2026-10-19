extends Node
## Renders the LASTROOT branding placeholders into assets/branding/ (own art only):
##   icon_png/icon_<n>.png  from assets/branding/icon.svg (16/32/64/128/256/512)
##   splash.png        1920x1080, menu diorama + wordmark
##   store/*_placeholder.png   header / small / main capsule, library hero + logo
## Each shot is a SubViewport with its own world, rendered supersampled and
## downscaled with Lanczos. Run via tools/synty/capture_branding.sh (needs xvfb).

const SRC := "res://assets/branding/"
## Output folder; -- --out=<res-relative dir> redirects it (tools/capture_all.sh).
var out_dir := "res://assets/branding/"
const ICON_SIZES := [16, 32, 64, 128, 256, 512]
const FRAMES := 70
const TURQ := Color("3ff2d6")
const TEXT := Color("e9eef7")

## name, size, diorama, ss (supersample), anchor, champion, wordmark rect (fractions
## x, y, w, h of the frame; empty = no wordmark), dim, transparent.
var shots: Array[Dictionary] = [
	{"out": "splash.png", "size": Vector2i(1920, 1080), "scene": "menu", "ss": 1, "anchor": 0.66,
		"champion": "BARK", "mark": Rect2(0.04, 0.42, 0.42, 0.16), "dim": 0.12, "fov": 40.0},
	{"out": "store/header_capsule_460x215_placeholder.png", "size": Vector2i(460, 215), "scene": "menu", "ss": 3,
		"anchor": 0.76, "champion": "BARK", "mark": Rect2(0.04, 0.36, 0.52, 0.28), "dim": 0.1, "fov": 46.0},
	{"out": "store/small_capsule_231x87_placeholder.png", "size": Vector2i(231, 87), "scene": "menu", "ss": 4,
		"anchor": 0.85, "champion": "", "mark": Rect2(0.03, 0.2, 0.66, 0.6), "dim": 0.25, "fov": 44.0},
	{"out": "store/main_capsule_616x353_placeholder.png", "size": Vector2i(616, 353), "scene": "menu", "ss": 3,
		"anchor": 0.7, "champion": "SPORE", "mark": Rect2(0.03, 0.40, 0.52, 0.2), "dim": 0.1, "fov": 42.0},
	{"out": "store/library_hero_1920x620_placeholder.png", "size": Vector2i(1920, 620), "scene": "menu", "ss": 1,
		"anchor": 0.6, "champion": "BARK", "mark": Rect2(), "dim": 0.05, "fov": 40.0},
	{"out": "store/library_logo_1280x720_placeholder.png", "size": Vector2i(1280, 720), "scene": "", "ss": 1,
		"anchor": 0.5, "champion": "", "mark": Rect2(0.06, 0.3, 0.88, 0.4), "dim": 0.0, "transparent": true},
]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			var o := a.substr(6).trim_suffix("/") + "/"
			out_dir = o if o.begins_with("res://") else "res://" + o
	_icons()
	for s: Dictionary in shots:
		await _shot(s)
	print("branding: done")
	get_tree().quit()


func _icons() -> void:
	var svg := FileAccess.get_file_as_string(SRC + "icon.svg")
	for n: int in ICON_SIZES:
		var img := Image.new()
		var err := img.load_svg_from_string(svg, float(n) / 512.0)
		if err != OK:
			push_error("icon render failed %d" % n)
			continue
		_save(img, "icon_png/icon_%d.png" % n)


func _shot(s: Dictionary) -> void:
	var size: Vector2i = s["size"]
	var ss: int = int(s["ss"])
	var vp := SubViewport.new()
	vp.size = size * ss
	vp.own_world_3d = true
	vp.transparent_bg = bool(s.get("transparent", false))
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var d: Node = null
	match str(s["scene"]):
		"menu":
			d = (load("res://scenes/art/menu_diorama.tscn") as PackedScene).instantiate()
		"route":
			d = (load("res://scenes/art/route_diorama.tscn") as PackedScene).instantiate()
	if d:
		vp.add_child(d)
		d.set("dim", float(s["dim"]))
		if d.has_method("set_progress"):
			var ch: Array = []
			for k: int in range(1, 4):
				ch.append(Vector2i(2 * k - 1, -1 if k % 2 == 0 else 1))
			d.call("set_progress", 3, ch)
		if d.has_method("set_champion"):
			d.call("set_champion", str(s["champion"]))
		if s.has("fov"):
			# wider framing for short, wide capsules (set once; the orbit keeps it)
			(d.get("_cam") as Camera3D).fov = float(s["fov"])
		d.call("set_screen_anchor", float(s["anchor"]))
	var mark: Rect2 = s["mark"]
	if mark.size != Vector2.ZERO:
		var layer := CanvasLayer.new()
		layer.layer = 20
		vp.add_child(layer)
		var w := Wordmark.new()
		w.position = Vector2(size * ss) * mark.position
		w.size = Vector2(size * ss) * mark.size
		w.shade = not vp.transparent_bg
		layer.add_child(w)
	for i: int in FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if ss > 1:
		img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	_save(img, str(s["out"]))
	vp.queue_free()
	await get_tree().process_frame


func _save(img: Image, rel: String) -> void:
	var p := ProjectSettings.globalize_path(out_dir + rel)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	img.save_png(p)
	print("branding: ", rel, " ", img.get_size())


## LASTROOT wordmark, drawn with the project font (DejaVu Sans, emboldened and
## tracked out) so it fits its rect at any size; a turquoise root line with a
## small heart-diamond underlines it.
class Wordmark:
	extends Control
	var shade: bool = true
	var _pool: ImageTexture   # kept as a member: a texture freed after _draw renders white

	func _draw() -> void:
		var base := load("res://assets/fonts/DejaVuSans.ttf") as Font
		var f := FontVariation.new()
		f.base_font = base
		f.variation_embolden = 1.1
		var text := "LASTROOT"
		# Fit: measure at 100 px, scale to the rect (text gets ~72% of the height).
		var probe := 100
		f.spacing_glyph = int(probe * 0.12)
		var w100 := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, probe).x
		var fs := int(minf(size.x / w100 * probe, size.y * 0.72))
		f.spacing_glyph = int(fs * 0.12)
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := (size.x - tw) * 0.5
		var base_y := size.y * 0.72
		if shade:
			# soft dark radial pool so the mark reads on any part of the diorama
			var img := Image.create(128, 64, false, Image.FORMAT_RGBA8)
			for py: int in 64:
				for px: int in 128:
					var d := Vector2((px - 63.5) / 64.0, (py - 31.5) / 32.0).length()
					var k := clampf(1.0 - d, 0.0, 1.0)
					img.set_pixel(px, py, Color(0.02, 0.03, 0.08, 0.62 * k * k * (3.0 - 2.0 * k)))
			_pool = ImageTexture.create_from_image(img)
			draw_texture_rect(_pool, Rect2(Vector2(x - fs * 0.9, base_y - fs * 1.35), Vector2(tw + fs * 1.8, fs * 2.0)), false)
		var outline := maxi(2, int(fs * 0.06))
		draw_string_outline(f, Vector2(x, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline,
			Color(0.02, 0.04, 0.1, 0.85))
		draw_string(f, Vector2(x, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT)
		# root line + heart diamond
		var ly := base_y + fs * 0.16
		var th := maxf(1.5, fs * 0.045)
		var mid := x + tw * 0.5
		var gap := fs * 0.22
		draw_line(Vector2(x + fs * 0.1, ly), Vector2(mid - gap, ly), TURQ, th, true)
		draw_line(Vector2(mid + gap, ly), Vector2(x + tw - fs * 0.1, ly), TURQ, th, true)
		var r2 := fs * 0.13
		draw_colored_polygon(PackedVector2Array([Vector2(mid, ly - r2), Vector2(mid + r2, ly),
			Vector2(mid, ly + r2), Vector2(mid - r2, ly)]), TURQ)
