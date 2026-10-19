class_name MenuBackdrop
extends Control
## Calm, light backdrop drawn in code (web-friendly, no textures): night sky
## gradient, drifting spores, floating islands and the world tree with its
## three terraces (Roots, Trunk, Crown) and the pulsing turquoise Heart (REF_05).
## Reduced motion freezes the drift and the pulse.

## Horizontal position of the tree as a fraction of the width.
var tree_x: float = 0.68
## 0..1 how strongly the tree is drawn (lower behind dense UI).
var tree_alpha: float = 1.0
## Tree height as a fraction of the screen height.
var tree_scale: float = 0.86
var show_tree: bool = true

var _t: float = 0.0
var _motes: Array = []  # [pos(0..1), speed, radius, phase, violet]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for i in 46:
		_motes.append([Vector2(r.randf(), r.randf()), r.randf_range(0.004, 0.018), r.randf_range(1.2, 3.6),
			r.randf() * TAU, r.randf() < 0.45])


func _process(delta: float) -> void:
	if SettingsService.reduced_motion:
		return
	_t += delta * SettingsService.anim_speed
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# Sky gradient: deep night blue on top, violet haze near the horizon.
	var top := Color("0a0d17")
	var mid := Color("141a33")
	var low := Color("2a1f45")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.55), Vector2(0, h * 0.55)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.55), Vector2(w, h * 0.55), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([mid, mid, low, low]))
	# Distant floating islands.
	var isl := Color("1b1f35")
	for spec: Array in [[0.12, 0.62, 0.09], [0.3, 0.78, 0.06], [0.9, 0.7, 0.07], [0.5, 0.9, 0.11], [0.05, 0.86, 0.05]]:
		_island(Vector2(w * float(spec[0]), h * float(spec[1])), w * float(spec[2]), isl)
	# Fog band.
	for i in 3:
		var y: float = h * (0.8 + 0.06 * float(i))
		draw_rect(Rect2(0, y, w, h * 0.08), Color(0.5, 0.42, 0.7, 0.035))
	if show_tree:
		_tree(Vector2(w * tree_x, h), h * tree_scale)
	# Drifting spores / embers.
	for m: Array in _motes:
		var p: Vector2 = m[0]
		var sp: float = m[1]
		var y: float = fposmod(p.y - _t * sp, 1.0)
		var x: float = p.x + sin(_t * 0.3 + float(m[3])) * 0.01
		var c: Color = Color(UiKit.SPORE, 0.5) if m[4] else Color(UiKit.LIFE, 0.45)
		var a: float = 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 1.3 + float(m[3])))
		draw_circle(Vector2(x * w, y * h), float(m[2]), Color(c, c.a * a))


func _island(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, 0), c + Vector2(r * 0.55, r * 0.35),
		c + Vector2(0.1 * r, r * 0.9), c + Vector2(-r * 0.5, r * 0.4)]), col)
	draw_rect(Rect2(c + Vector2(-r, -r * 0.08), Vector2(r * 2.0, r * 0.1)), col.lightened(0.08))


func _tree(base: Vector2, th: float) -> void:
	var a: float = tree_alpha
	var bark := Color(0.23, 0.16, 0.12, a)
	var bark_hi := Color(0.36, 0.25, 0.17, a)
	var moss := Color(0.25, 0.34, 0.18, a)
	var tw: float = th * 0.13
	# Roots spreading at the bottom.
	for i in 5:
		var dx: float = (float(i) - 2.0) * tw * 0.9
		draw_line(base + Vector2(dx * 0.3, -th * 0.12), base + Vector2(dx * 1.6, 0), bark, tw * 0.22, true)
	# Trunk.
	draw_colored_polygon(PackedVector2Array([base + Vector2(-tw * 0.9, -th * 0.08), base + Vector2(-tw * 0.45, -th * 0.5),
		base + Vector2(-tw * 0.6, -th * 0.78), base + Vector2(tw * 0.6, -th * 0.78), base + Vector2(tw * 0.45, -th * 0.5),
		base + Vector2(tw * 0.9, -th * 0.08)]), bark)
	draw_line(base + Vector2(-tw * 0.1, -th * 0.1), base + Vector2(tw * 0.05, -th * 0.72), Color(UiKit.LIFE, 0.35 * a), tw * 0.06, true)
	draw_line(base + Vector2(tw * 0.3, -th * 0.2), base + Vector2(tw * 0.15, -th * 0.6), Color(UiKit.LIFE, 0.22 * a), tw * 0.04, true)
	# Three terraces: Roots, Trunk, Crown.
	var levels := [[0.16, 1.9, moss], [0.46, 1.6, Color(0.3, 0.2, 0.36, a)], [0.76, 1.75, bark_hi]]
	for lv: Array in levels:
		var y: float = -th * float(lv[0])
		var rw: float = tw * float(lv[1])
		var col: Color = lv[2]
		draw_colored_polygon(PackedVector2Array([base + Vector2(-rw, y), base + Vector2(rw, y), base + Vector2(rw * 0.8, y + th * 0.035),
			base + Vector2(-rw * 0.8, y + th * 0.035)]), bark.darkened(0.2))
		draw_rect(Rect2(base + Vector2(-rw, y - th * 0.012), Vector2(rw * 2.0, th * 0.016)), col)
	# Spore mushrooms on the middle terrace.
	for dx: float in [-1.2, 1.05]:
		var mp: Vector2 = base + Vector2(tw * dx, -th * 0.46 - th * 0.02)
		draw_line(mp, mp + Vector2(0, -th * 0.04), Color(0.8, 0.75, 0.85, a * 0.8), tw * 0.07)
		draw_circle(mp + Vector2(0, -th * 0.045), tw * 0.22, Color(UiKit.SPORE, 0.75 * a))
	# Canopy.
	var cc: Vector2 = base + Vector2(0, -th * 0.86)
	for blob: Array in [[-1.5, 0.02, 1.3], [1.5, 0.03, 1.25], [-0.6, -0.06, 1.5], [0.7, -0.07, 1.45], [0.0, 0.02, 1.4]]:
		draw_circle(cc + Vector2(tw * float(blob[0]), th * float(blob[1])), tw * float(blob[2]), Color(0.13, 0.22, 0.2, a * 0.92))
	# The Heart.
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.1)
	var hc: Vector2 = cc + Vector2(0, -th * 0.02)
	for i in 12:
		draw_circle(hc, tw * (1.5 - float(i) * 0.1) * (1.0 + 0.06 * pulse), Color(UiKit.LIFE, (0.018 + 0.008 * pulse) * a))
	var hs: float = tw * 0.5
	draw_colored_polygon(PackedVector2Array([hc + Vector2(0, -hs), hc + Vector2(hs * 0.65, 0), hc + Vector2(0, hs * 1.1),
		hc + Vector2(-hs * 0.65, 0)]), Color(UiKit.LIFE, 0.9 * a))
	draw_colored_polygon(PackedVector2Array([hc + Vector2(0, -hs), hc + Vector2(hs * 0.25, 0), hc + Vector2(0, hs * 1.1),
		hc + Vector2(-hs * 0.15, 0)]), Color(0.75, 1.0, 0.96, 0.8 * a))
