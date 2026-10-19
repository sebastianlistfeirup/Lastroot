class_name MetaIcon
extends Control
## Vector icons drawn in code (no font glyphs, so they render the same on web
## and mobile). Always shown next to a text label: icons support, never
## replace, the words (bible p.16).

const KINDS: PackedStringArray = ["battle", "boss", "camp", "card", "encounter", "removal", "heart", "resin",
	"relic", "mutation", "champion", "deck", "check", "lock", "skip", "gear"]

var kind: String = "battle"
var color: Color = UiKit.TEXT
var fill_bg: bool = false
var bg_color: Color = UiKit.PANEL_HI


static func make(p_kind: String, p_color: Color = UiKit.TEXT, side: int = 28) -> MetaIcon:
	var m := MetaIcon.new()
	m.kind = p_kind
	m.color = p_color
	m.custom_minimum_size = Vector2(side, side)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	if fill_bg:
		draw_circle(o + Vector2(s, s) * 0.5, s * 0.5, bg_color)
		draw_arc(o + Vector2(s, s) * 0.5, s * 0.5 - 1.0, 0, TAU, 32, color.darkened(0.2), 2.0, true)
		o += Vector2(s, s) * 0.18
		s *= 0.64
	draw_icon(self, kind, o, s, color)


static func _p(o: Vector2, s: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(o + p * s)
	return out


## Draws `kind` into the square (o, s) on any CanvasItem.
static func draw_icon(ci: CanvasItem, k: String, o: Vector2, s: float, c: Color) -> void:
	var w: float = maxf(1.5, s * 0.09)
	match k:
		"battle":
			ci.draw_line(o + Vector2(0.18, 0.18) * s, o + Vector2(0.82, 0.82) * s, c, w, true)
			ci.draw_line(o + Vector2(0.82, 0.18) * s, o + Vector2(0.18, 0.82) * s, c, w, true)
			ci.draw_line(o + Vector2(0.12, 0.62) * s, o + Vector2(0.38, 0.88) * s, c, w, true)
			ci.draw_line(o + Vector2(0.88, 0.62) * s, o + Vector2(0.62, 0.88) * s, c, w, true)
		"boss":
			ci.draw_colored_polygon(_p(o, s, [Vector2(0.1, 0.8), Vector2(0.1, 0.3), Vector2(0.3, 0.55), Vector2(0.5, 0.18),
				Vector2(0.7, 0.55), Vector2(0.9, 0.3), Vector2(0.9, 0.8)]), c)
			ci.draw_circle(o + Vector2(0.5, 0.66) * s, s * 0.07, UiKit.BG)
		"camp":
			ci.draw_colored_polygon(_p(o, s, [Vector2(0.5, 0.12), Vector2(0.9, 0.82), Vector2(0.1, 0.82)]), c)
			ci.draw_colored_polygon(_p(o, s, [Vector2(0.5, 0.45), Vector2(0.64, 0.82), Vector2(0.36, 0.82)]), UiKit.BG)
			ci.draw_line(o + Vector2(0.05, 0.86) * s, o + Vector2(0.95, 0.86) * s, c, w, true)
		"card":
			_round_rect(ci, Rect2(o + Vector2(0.3, 0.14) * s, Vector2(0.5, 0.68) * s), c.darkened(0.35))
			_round_rect(ci, Rect2(o + Vector2(0.18, 0.22) * s, Vector2(0.5, 0.68) * s), c)
			ci.draw_line(o + Vector2(0.27, 0.4) * s, o + Vector2(0.58, 0.4) * s, UiKit.BG, w * 0.7)
			ci.draw_line(o + Vector2(0.27, 0.55) * s, o + Vector2(0.52, 0.55) * s, UiKit.BG, w * 0.7)
		"deck":
			for i in 3:
				var off: float = 0.08 * float(2 - i)
				_round_rect(ci, Rect2(o + Vector2(0.2 + off, 0.12 + off) * s, Vector2(0.48, 0.66) * s), c.darkened(0.3 * float(2 - i) / 2.0))
		"encounter":
			ci.draw_arc(o + Vector2(0.5, 0.5) * s, s * 0.38, 0, TAU, 32, c, w, true)
			ci.draw_arc(o + Vector2(0.5, 0.4) * s, s * 0.13, PI, TAU + PI * 0.5, 16, c, w, true)
			ci.draw_line(o + Vector2(0.5, 0.53) * s, o + Vector2(0.5, 0.62) * s, c, w, true)
			ci.draw_circle(o + Vector2(0.5, 0.73) * s, w * 0.6, c)
		"removal":
			_round_rect(ci, Rect2(o + Vector2(0.18, 0.14) * s, Vector2(0.46, 0.66) * s), c)
			ci.draw_line(o + Vector2(0.27, 0.36) * s, o + Vector2(0.55, 0.36) * s, UiKit.BG, w * 0.7)
			ci.draw_circle(o + Vector2(0.7, 0.72) * s, s * 0.2, UiKit.BG)
			ci.draw_line(o + Vector2(0.59, 0.72) * s, o + Vector2(0.81, 0.72) * s, c, w * 1.3, true)
		"heart":
			var pts: Array = []
			for i in 33:
				var t: float = TAU * float(i) / 32.0
				var x: float = 16.0 * pow(sin(t), 3)
				var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				pts.append(Vector2(0.5 + x / 38.0, 0.48 + y / 38.0))
			ci.draw_colored_polygon(_p(o, s, pts), c)
		"resin":
			var hex: Array = []
			for i in 6:
				var a: float = TAU * float(i) / 6.0 + PI / 6.0
				hex.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.4)
			ci.draw_colored_polygon(_p(o, s, hex), c)
			ci.draw_circle(o + Vector2(0.4, 0.4) * s, s * 0.08, Color(1, 1, 1, 0.55))
		"relic":
			ci.draw_colored_polygon(_p(o, s, [Vector2(0.5, 0.1), Vector2(0.85, 0.42), Vector2(0.5, 0.9), Vector2(0.15, 0.42)]), c)
			ci.draw_colored_polygon(_p(o, s, [Vector2(0.5, 0.1), Vector2(0.62, 0.42), Vector2(0.5, 0.9), Vector2(0.38, 0.42)]), c.lightened(0.3))
		"mutation":
			ci.draw_line(o + Vector2(0.5, 0.92) * s, o + Vector2(0.5, 0.35) * s, c, w, true)
			ci.draw_colored_polygon(_p(o, s, [Vector2(0.5, 0.55), Vector2(0.2, 0.4), Vector2(0.12, 0.15), Vector2(0.38, 0.25)]), c)
			ci.draw_colored_polygon(_p(o, s, [Vector2(0.5, 0.42), Vector2(0.8, 0.26), Vector2(0.9, 0.05), Vector2(0.62, 0.12)]), c)
		"champion":
			ci.draw_colored_polygon(_p(o, s, [Vector2(0.15, 0.15), Vector2(0.85, 0.15), Vector2(0.85, 0.5), Vector2(0.5, 0.9), Vector2(0.15, 0.5)]), c)
			ci.draw_colored_polygon(_p(o, s, [Vector2(0.5, 0.25), Vector2(0.72, 0.25), Vector2(0.72, 0.5), Vector2(0.5, 0.78)]), c.darkened(0.3))
		"check":
			ci.draw_polyline(_p(o, s, [Vector2(0.18, 0.52), Vector2(0.42, 0.76), Vector2(0.84, 0.24)]), c, w * 1.4, true)
		"skip":
			ci.draw_line(o + Vector2(0.2, 0.2) * s, o + Vector2(0.8, 0.8) * s, c, w * 1.2, true)
			ci.draw_line(o + Vector2(0.8, 0.2) * s, o + Vector2(0.2, 0.8) * s, c, w * 1.2, true)
		"lock":
			ci.draw_arc(o + Vector2(0.5, 0.42) * s, s * 0.2, PI, TAU, 16, c, w, true)
			ci.draw_line(o + Vector2(0.3, 0.42) * s, o + Vector2(0.3, 0.5) * s, c, w)
			ci.draw_line(o + Vector2(0.7, 0.42) * s, o + Vector2(0.7, 0.5) * s, c, w)
			_round_rect(ci, Rect2(o + Vector2(0.22, 0.5) * s, Vector2(0.56, 0.4) * s), c)
		"gear":
			ci.draw_arc(o + Vector2(0.5, 0.5) * s, s * 0.26, 0, TAU, 24, c, w * 1.6, true)
			for i in 8:
				var a: float = TAU * float(i) / 8.0
				ci.draw_line(o + (Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.3) * s,
					o + (Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.44) * s, c, w * 1.6)
		_:
			ci.draw_circle(o + Vector2(0.5, 0.5) * s, s * 0.3, c)


static func _round_rect(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(maxf(2.0, r.size.x * 0.15)))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


## Icon + accent colour of a route node type.
static func node_color(type: String) -> Color:
	match type:
		"camp": return UiKit.AMBER
		"card": return UiKit.ARMOR
		"encounter": return UiKit.LIFE
		"removal": return UiKit.DANGER.lightened(0.15)
		"boss": return UiKit.DANGER
	return UiKit.TEXT
