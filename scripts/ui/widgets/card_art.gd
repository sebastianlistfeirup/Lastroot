class_name CardArt
extends Control
## Illustration strip of a card: the creature's rendered portrait (cached,
## see CardPortraits) or, for spells, a code-drawn emblem for the spell's
## effect in faction colours. Purely decorative: every number and rule is
## real text elsewhere on the card. Redraws only when something changes.

var def: Dictionary = {}
var upgraded: bool = false
var portrait: Texture2D = null
## State markers drawn as glyphs, so selection / unplayable never rely on colour.
var selected: bool = false
var unplayable: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_def(d: Dictionary, p_upgraded: bool) -> void:
	def = d
	upgraded = p_upgraded
	portrait = null
	if Catalog.is_creature(def):
		var sid: String = "unit." + str(def.get("id", ""))
		portrait = CardPortraits.cached(sid)
		if portrait == null and not CardPortraits.is_cached(sid):
			CardPortraits.request(sid, _on_portrait)
	queue_redraw()


func _on_portrait(tex: Texture2D) -> void:
	portrait = tex
	queue_redraw()


func _draw() -> void:
	if def.is_empty():
		return
	var w: float = size.x
	var h: float = size.y
	var fc: Color = UiKit.faction_color(str(def.get("faction", "BARK")))
	var champ: bool = def.get("kind", "") == "champion"
	# Backdrop: night gradient tinted by faction, a soft glow behind the subject.
	var top: Color = UiKit.BG.lerp(fc, 0.10)
	var low: Color = UiKit.BG.lerp(fc, 0.30)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([top, top, low, low]))
	var c := Vector2(w * 0.5, h * 0.55)
	for i in 5:
		draw_circle(c, h * (0.62 - 0.1 * float(i)), Color(fc, 0.05))
	if portrait != null:
		var ts: Vector2 = portrait.get_size()
		var k: float = maxf(w / ts.x, h / ts.y)
		var ds: Vector2 = ts * k
		draw_texture_rect(portrait, Rect2((Vector2(w, h) - ds) * 0.5, ds), false)
	elif Catalog.is_creature(def):
		_silhouette(c, h, fc)
	else:
		_emblem(str(def.get("spell", {}).get("op", "")), c, minf(w, h) * 0.42, fc)
	# Ground line and frame inside.
	draw_rect(Rect2(0, h - 3.0, w, 3.0), Color(fc, 0.55))
	if champ:
		_star(Vector2(12, 12), 7.0, UiKit.AMBER)
	if selected:
		var sc := Vector2(13, h - 13)
		draw_circle(sc, 11.0, UiKit.LIFE)
		MetaIcon.draw_icon(self, "check", sc - Vector2(8, 8), 16.0, UiKit.BG)
	if unplayable:
		var uc := Vector2(w - 13, h - 13)
		draw_circle(uc, 11.0, Color(UiKit.BG, 0.95))
		draw_arc(uc, 10.0, 0, TAU, 20, UiKit.TEXT_DIM, 2.0, true)
		draw_line(uc + Vector2(-6, 6), uc + Vector2(6, -6), UiKit.TEXT_DIM, 2.5, true)
	if upgraded:
		# Upgrade ribbon in the corner (plus the text line on the card).
		var r := PackedVector2Array([Vector2(w - 34, 0), Vector2(w, 0), Vector2(w, 34)])
		draw_colored_polygon(r, UiKit.GOOD.darkened(0.15))
		var p := Vector2(w - 10, 10)
		draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), UiKit.BG, 2.5)
		draw_line(p + Vector2(0, -5), p + Vector2(0, 5), UiKit.BG, 2.5)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a: float = -PI * 0.5 + PI * float(i) / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


## Placeholder figure while the portrait renders (or when rendering is off).
func _silhouette(c: Vector2, h: float, fc: Color) -> void:
	var col := Color(fc.darkened(0.35), 0.9)
	var s: float = h * 0.38
	draw_circle(c + Vector2(0, -s * 0.55), s * 0.32, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.55, s * 0.9), c + Vector2(-s * 0.4, -s * 0.15),
		c + Vector2(s * 0.4, -s * 0.15), c + Vector2(s * 0.55, s * 0.9)]), col)


func _emblem(op: String, c: Vector2, r: float, fc: Color) -> void:
	var lit: Color = fc.lightened(0.35)
	match op:
		"damage":  # root spikes bursting up
			for i in 5:
				var x: float = (float(i) - 2.0) * r * 0.38
				var hh: float = r * (1.25 - absf(float(i) - 2.0) * 0.25)
				draw_colored_polygon(PackedVector2Array([c + Vector2(x - r * 0.13, r * 0.8), c + Vector2(x + r * 0.13, r * 0.8),
					c + Vector2(x + r * 0.03, r * 0.8 - hh)]), lit if i == 2 else fc)
		"armor", "strip_damage":
			var sh := PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.75), c + Vector2(r * 0.7, -r * 0.75), c + Vector2(r * 0.7, r * 0.05),
				c + Vector2(0, r * 0.85), c + Vector2(-r * 0.7, r * 0.05)])
			draw_colored_polygon(sh, UiKit.ARMOR.darkened(0.25) if op == "armor" else fc.darkened(0.2))
			draw_polyline(sh + PackedVector2Array([sh[0]]), lit, 2.0, true)
			if op == "strip_damage":
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.1, -r * 0.75), c + Vector2(r * 0.15, -r * 0.2),
					c + Vector2(-r * 0.12, r * 0.2), c + Vector2(r * 0.08, r * 0.8)]), UiKit.BG, 3.0, true)
			else:
				draw_string(ThemeDB.fallback_font, c + Vector2(-r * 0.25, r * 0.2), UiKit.status_glyph("armor"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.7), Color.WHITE)
		"poison", "bloom":
			var drop := PackedVector2Array()
			for i in 25:
				var a: float = PI * float(i) / 24.0
				drop.append(c + Vector2(cos(a) * r * 0.55, sin(a) * r * 0.55 + r * 0.15))
			drop.append(c + Vector2(0, -r * 0.85))
			draw_colored_polygon(drop, UiKit.POISON.darkened(0.2))
			draw_circle(c + Vector2(-r * 0.18, r * 0.12), r * 0.12, Color(1, 1, 1, 0.5))
			for i in 3:
				draw_circle(c + Vector2(r * (0.65 + 0.12 * float(i)), -r * (0.2 + 0.3 * float(i))), r * (0.1 - 0.02 * float(i)), Color(UiKit.POISON, 0.7))
			if op == "bloom":
				for i in 6:
					var a2: float = TAU * float(i) / 6.0
					draw_circle(c + Vector2(cos(a2), sin(a2)) * r * 0.85, r * 0.18, Color(UiKit.SPORE, 0.8))
		"heal", "heal_growth":
			var pts: Array = []
			for i in 33:
				var t: float = TAU * float(i) / 32.0
				pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * r / 20.0)
			draw_colored_polygon(PackedVector2Array(pts), UiKit.LIFE.darkened(0.15))
			draw_line(c + Vector2(-r * 0.25, 0), c + Vector2(r * 0.25, 0), Color.WHITE, 3.0)
			draw_line(c + Vector2(0, -r * 0.25), c + Vector2(0, r * 0.25), Color.WHITE, 3.0)
			if op == "heal_growth":
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6, r * 0.6), c + Vector2(r * 1.05, r * 0.1),
					c + Vector2(r * 0.75, r * 0.65)]), UiKit.GOOD)
		"lift":
			for i in 3:
				draw_rect(Rect2(c + Vector2(-r, r * (0.75 - 0.6 * float(i))), Vector2(r * 2.0, 3.0)), Color(fc, 0.6))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.95), c + Vector2(r * 0.45, -r * 0.35), c + Vector2(r * 0.16, -r * 0.35),
				c + Vector2(r * 0.16, r * 0.6), c + Vector2(-r * 0.16, r * 0.6), c + Vector2(-r * 0.16, -r * 0.35), c + Vector2(-r * 0.45, -r * 0.35)]), lit)
		"remove_draw":
			var sb := StyleBoxFlat.new()
			sb.bg_color = fc.darkened(0.2)
			sb.set_corner_radius_all(4)
			draw_style_box(sb, Rect2(c + Vector2(-r * 0.75, -r * 0.65), Vector2(r * 0.7, r * 1.1)))
			sb.bg_color = lit
			draw_style_box(sb, Rect2(c + Vector2(r * 0.05, -r * 0.45), Vector2(r * 0.7, r * 1.1)))
			draw_line(c + Vector2(-r * 0.4, r * 0.75), c + Vector2(r * 0.4, r * 0.75), lit, 3.0)
		_:
			draw_circle(c, r * 0.6, fc)
