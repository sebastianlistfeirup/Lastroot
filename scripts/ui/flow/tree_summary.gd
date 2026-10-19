class_name TreeSummary
extends Control
## REF_10: the run's tree with its three floors, the chosen mutations shown on
## the floor they changed, and the Heart lit (victory) or cracked (defeat).

var mutations: Array = []
var won: bool = true
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(360, 420)


func _process(delta: float) -> void:
	if SettingsService.reduced_motion:
		return
	_t += delta * SettingsService.anim_speed
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var cx: float = w * 0.5
	var font: Font = ThemeDB.fallback_font
	var fs: int = UiKit.px(16)
	var bark := Color("4a3424") if won else Color("3a3433")
	var tw: float = minf(w * 0.16, h * 0.1)
	# Roots.
	for i in 5:
		var dx: float = (float(i) - 2.0) * tw * 0.8
		draw_line(Vector2(cx + dx * 0.3, h * 0.86), Vector2(cx + dx * 1.7, h * 0.98), bark, tw * 0.18, true)
	# Trunk.
	draw_colored_polygon(PackedVector2Array([Vector2(cx - tw * 0.8, h * 0.9), Vector2(cx - tw * 0.45, h * 0.5), Vector2(cx - tw * 0.55, h * 0.22),
		Vector2(cx + tw * 0.55, h * 0.22), Vector2(cx + tw * 0.45, h * 0.5), Vector2(cx + tw * 0.8, h * 0.9)]), bark)
	if won:
		draw_line(Vector2(cx, h * 0.88), Vector2(cx + tw * 0.08, h * 0.25), Color(UiKit.LIFE, 0.4), tw * 0.08, true)
	# Floors: y, name, mutation id.
	var floors := [[0.8, Loc.t("Roots"), "M01"], [0.55, Loc.t("Trunk"), "M02"], [0.3, Loc.t("Crown"), "M03"]]
	for f: Array in floors:
		var y: float = h * float(f[0])
		var rw: float = tw * 2.3
		var has: bool = mutations.has(f[2])
		var col: Color = (UiKit.GOOD if has else Color("5a4a3a")) if won else Color("4a4646")
		draw_colored_polygon(PackedVector2Array([Vector2(cx - rw, y), Vector2(cx + rw, y), Vector2(cx + rw * 0.8, y + h * 0.035),
			Vector2(cx - rw * 0.8, y + h * 0.035)]), bark.darkened(0.25))
		draw_rect(Rect2(cx - rw, y - h * 0.012, rw * 2.0, h * 0.016), col)
		if has:
			for i in 3:
				var lx: float = cx - rw * 0.7 + float(i) * rw * 0.7
				draw_circle(Vector2(lx, y - h * 0.03), tw * 0.16, Color(UiKit.GOOD, 0.85))
		var name: String = str(f[1])
		var nw: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lx2: float = cx + rw + 10.0
		if lx2 + nw > w:
			lx2 = cx - rw - 10.0 - nw
		draw_string(font, Vector2(lx2, y + fs * 0.4), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.TEXT if has else UiKit.TEXT_DIM)
	# Canopy.
	var cc := Vector2(cx, h * 0.14)
	var leaf: Color = Color(0.16, 0.3, 0.24) if won else Color(0.22, 0.22, 0.24)
	for blob: Array in [[-1.6, 0.03, 1.2], [1.6, 0.03, 1.2], [-0.7, -0.02, 1.4], [0.7, -0.02, 1.4], [0.0, 0.04, 1.3]]:
		draw_circle(cc + Vector2(tw * float(blob[0]), h * float(blob[1])), tw * float(blob[2]), leaf)
	# Heart.
	var big: bool = mutations.has("M04")
	var hs: float = tw * (0.62 if big else 0.48)
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.0)
	var hc: Color = UiKit.LIFE if won else UiKit.ASH
	if won:
		for i in 12:
			draw_circle(cc, hs * (2.8 - 0.18 * float(i)) * (1.0 + 0.05 * pulse), Color(UiKit.LIFE, 0.022))
	draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -hs), cc + Vector2(hs * 0.68, 0), cc + Vector2(0, hs * 1.15), cc + Vector2(-hs * 0.68, 0)]), hc)
	if not won:
		draw_polyline(PackedVector2Array([cc + Vector2(-hs * 0.1, -hs * 0.8), cc + Vector2(hs * 0.15, -hs * 0.2), cc + Vector2(-hs * 0.15, hs * 0.3),
			cc + Vector2(hs * 0.05, hs * 0.9)]), UiKit.BG, 3.0, true)
