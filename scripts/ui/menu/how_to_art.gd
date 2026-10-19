class_name HowToArt
extends Control
## Small code-drawn diagrams for the "How to play" pages. They mirror the
## battle layout (StageLayout): allies left of the trunk, enemies right, the
## front (position 0) next to the trunk, Roots at the bottom, the Heart above
## the Crown. Labels are real, translated text.

var kind: String = "floors"
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 300)


func _process(delta: float) -> void:
	if SettingsService.reduced_motion:
		return
	_t += delta * SettingsService.anim_speed
	queue_redraw()


func _font() -> Font:
	return ThemeDB.fallback_font


func _text(pos: Vector2, s: String, size: int, col: Color, center: bool = true) -> void:
	var fs: int = UiKit.px(size)
	var w: float = _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p: Vector2 = pos - Vector2(w * 0.5 if center else 0.0, -fs * 0.35)
	draw_string_outline(_font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(UiKit.BG, 0.9))
	draw_string(_font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _token(c: Vector2, r: float, col: Color, label: String = "") -> void:
	draw_circle(c, r, Color(UiKit.BG, 0.9))
	draw_circle(c, r - 2.0, col.darkened(0.35))
	draw_arc(c, r - 2.0, 0, TAU, 24, col, 2.5, true)
	if label != "":
		_text(c, label, 14, UiKit.TEXT)


func _draw() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UiKit.BG, 0.8)
	bg.set_corner_radius_all(12)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	match kind:
		"floors": _floors(true, false)
		"sap": _sap()
		"target": _target()
		"forecast": _forecast()
		"climb": _floors(false, true)
		"status": _status()
		"boss": _boss()


## Three floors with trunk, front markers, allies left / enemies right.
func _floors(show_front: bool, show_climb: bool) -> void:
	var w: float = size.x
	var h: float = size.y
	var cx: float = w * 0.5
	var names: Array = [Loc.t("Roots"), Loc.t("Trunk"), Loc.t("Crown")]
	var top: float = h * 0.2
	var fh: float = (h - top - 16.0) / 3.0
	# Heart above the Crown.
	var hc := Vector2(cx, top * 0.55)
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(hc, 18.0 + pulse * 3.0, Color(UiKit.LIFE, 0.18))
	MetaIcon.draw_icon(self, "heart", hc - Vector2(14, 14), 28.0, UiKit.LIFE)
	_text(hc + Vector2(60, 0), Loc.t("Heart"), 15, UiKit.LIFE)
	# Trunk.
	draw_rect(Rect2(cx - 10.0, top - 6.0, 20.0, h - top - 10.0), Color("4a3424"))
	for f in 3:
		var y: float = h - 16.0 - fh * float(f) - fh * 0.3
		draw_rect(Rect2(16.0, y, w - 32.0, 6.0), Color("5a4a3a"))
		_text(Vector2(24.0, y - fh * 0.5), str(names[f]), 15, UiKit.TEXT_DIM, false)
	var y0: float = h - 16.0 - fh * 0.3 - 22.0
	if show_front:
		# Allies: front next to the trunk.
		_token(Vector2(cx - 40.0, y0), 18.0, UiKit.LIFE, "1")
		_token(Vector2(cx - 82.0, y0), 18.0, UiKit.LIFE, "2")
		_token(Vector2(cx + 40.0, y0), 18.0, UiKit.DANGER, "1")
		_token(Vector2(cx + 82.0, y0), 18.0, UiKit.DANGER, "2")
		_text(Vector2(cx, y0 - 44.0), Loc.t("Front"), 15, UiKit.AMBER)
		draw_line(Vector2(cx - 40.0, y0 - 30.0), Vector2(cx + 40.0, y0 - 30.0), UiKit.AMBER, 2.0, true)
		if w > 460:
			_text(Vector2(cx - 150.0, y0 + 2.0), Loc.t("Allies"), 15, UiKit.LIFE)
			_text(Vector2(cx + 150.0, y0 + 2.0), Loc.t("Enemies"), 15, UiKit.DANGER)
		# A second floor with one ally.
		_token(Vector2(cx - 40.0, y0 - fh), 18.0, UiKit.LIFE, "1")
	if show_climb:
		# Enemies climb one floor per turn, then hit the Heart.
		var x: float = cx + 60.0
		for f in 3:
			var y: float = y0 - fh * float(f)
			_token(Vector2(x, y), 16.0, UiKit.DANGER if f == 0 else Color(UiKit.DANGER, 0.45))
			var a: Vector2 = Vector2(x + 26.0, y - 6.0)
			var b: Vector2 = Vector2(x + 26.0, y - fh + 20.0) if f < 2 else Vector2(cx + 30.0, top * 0.55)
			var k: float = fposmod(_t * 0.6, 1.0)
			draw_line(a, b, Color(UiKit.DANGER, 0.7), 3.0, true)
			draw_circle(a.lerp(b, k), 4.0, UiKit.DANGER)
		var dmg: String = Loc.t("−attack to the Heart")
		var dw: float = _font().get_string_size(dmg, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.px(14)).x
		_text(Vector2(maxf(4.0, cx - 30.0 - dw), top * 0.55), dmg, 14, UiKit.DANGER, false)
		_token(Vector2(cx - 40.0, y0 - fh), 16.0, UiKit.LIFE)
		_text(Vector2(cx - 40.0, y0 - fh + 30.0), Loc.t("Defender"), 13, UiKit.LIFE)


func _sap() -> void:
	var w: float = size.x
	var h: float = size.y
	# Three Sap orbs.
	for i in 3:
		var c := Vector2(w * 0.5 - 60.0 + 60.0 * float(i), h * 0.24)
		draw_circle(c, 20.0, Color(UiKit.LIFE, 0.25))
		draw_circle(c, 14.0, UiKit.LIFE)
	_text(Vector2(w * 0.5, h * 0.24 + 40.0), Loc.t("3 Sap every turn"), 16, UiKit.LIFE)
	# Space bar: 5 points on a floor, a champion (2) and a creature (1).
	var bw: float = minf(w - 48.0, 360.0)
	var x0: float = (w - bw) * 0.5
	var y: float = h * 0.66
	var seg: float = bw / 5.0
	for i in 5:
		var col: Color = UiKit.AMBER if i < 2 else (UiKit.LIFE if i == 2 else UiKit.LINE)
		var r := Rect2(x0 + seg * float(i) + 3.0, y, seg - 6.0, 30.0)
		draw_rect(r, Color(col, 0.75))
	_text(Vector2(x0 + seg, y + 50.0), Loc.t("Champion: 2"), 14, UiKit.AMBER)
	_text(Vector2(x0 + seg * 2.5, y - 16.0), Loc.t("Creature: 1"), 14, UiKit.LIFE)
	_text(Vector2(x0 + seg * 4.0, y + 50.0), Loc.t("Free"), 14, UiKit.TEXT_DIM)
	_text(Vector2(w * 0.5, y - 44.0), Loc.t("5 space per floor"), 15, UiKit.TEXT)


func _target() -> void:
	var w: float = size.x
	var h: float = size.y
	var steps: Array = [["card", Loc.t("1. Tap a card"), UiKit.ARMOR], ["battle", Loc.t("2. Tap a target"), UiKit.AMBER],
		["check", Loc.t("3. Confirm"), UiKit.LIFE]]
	var n: int = steps.size()
	for i in n:
		var c := Vector2(w * (float(i) + 0.5) / float(n), h * 0.42)
		var s: float = minf(64.0, w / 6.0)
		draw_circle(c, s * 0.75, Color(steps[i][2], 0.15))
		MetaIcon.draw_icon(self, steps[i][0], c - Vector2(s, s) * 0.5, s, steps[i][2])
		_text(c + Vector2(0, s * 0.75 + 22.0), str(steps[i][1]), 15, UiKit.TEXT)
		if i < n - 1:
			var a := c + Vector2(s * 0.85, 0)
			var b := Vector2(w * (float(i) + 1.5) / float(n), h * 0.42) - Vector2(s * 0.85, 0)
			draw_line(a, b, UiKit.TEXT_DIM, 3.0, true)
	_text(Vector2(w * 0.5, h * 0.88), Loc.t("Nothing is spent until you confirm."), 15, UiKit.TEXT_DIM)


func _forecast() -> void:
	var w: float = size.x
	var h: float = size.y
	var pw: float = minf(w - 40.0, 380.0)
	var r := Rect2((w - pw) * 0.5, h * 0.12, pw, h * 0.74)
	var sb := UiKit.panel_style(UiKit.PANEL_HI, UiKit.LIFE, 12, 2)
	draw_style_box(sb, r)
	var x: float = r.position.x + 16.0
	var y: float = r.position.y + 28.0
	_text(Vector2(x, y), Loc.t("If you end the turn now:"), 15, UiKit.LIFE, false)
	MetaIcon.draw_icon(self, "heart", Vector2(x, y + 22.0), 22.0, UiKit.DANGER)
	_text(Vector2(x + 30.0, y + 34.0), "%s 60 → 55" % Loc.t("Heart"), 16, UiKit.TEXT, false)
	_text(Vector2(x, y + 72.0), "✕ " + Loc.t("Ashling dies"), 15, UiKit.GOOD, false)
	_text(Vector2(x, y + 102.0), "▲ " + Loc.t("Coalshield climbs to the Trunk"), 15, UiKit.AMBER, false)
	_text(Vector2(w * 0.5, r.end.y + 22.0), Loc.t("Same rules, same result: what you see is what happens."), 14, UiKit.TEXT_DIM)


func _status() -> void:
	var w: float = size.x
	var h: float = size.y
	var rows: Array = [["armor", Loc.t("Armor")], ["poison", Loc.t("Poison")], ["thorns", Loc.t("Thorns")], ["growth", Loc.t("Growth")]]
	var cols: int = 4 if w > 520 else 2
	for i in rows.size():
		var cx: float = w * (float(i % cols) + 0.5) / float(cols)
		var cy: float = (h * (0.22 if i < cols else 0.66)) if cols == 2 else h * 0.4
		var rad: float = 26.0 if cols == 2 else 34.0
		var k: String = rows[i][0]
		var col: Color = UiKit.status_color(k)
		draw_circle(Vector2(cx, cy), rad, Color(col, 0.14))
		draw_arc(Vector2(cx, cy), rad, 0, TAU, 32, Color(col, 0.7), 2.0, true)
		_text(Vector2(cx, cy - 4.0), UiKit.status_glyph(k), 26 if cols == 2 else 30, col)
		_text(Vector2(cx, cy + rad + 18.0), str(rows[i][1]), 16, UiKit.TEXT)


func _boss() -> void:
	var w: float = size.x
	var h: float = size.y
	var c := Vector2(w * 0.5, h * 0.36)
	for i in 6:
		draw_circle(c, 70.0 - float(i) * 9.0, Color(UiKit.DANGER, 0.05))
	MetaIcon.draw_icon(self, "boss", c - Vector2(48, 48), 96.0, UiKit.DANGER)
	var b: Dictionary = Catalog.boss()
	var line: String = "%s %d   %s %d   %s %d" % [UiKit.status_glyph("attack"), int(b["attack"]), UiKit.status_glyph("hp"), int(b["max_hp"]),
		UiKit.status_glyph("armor"), int(b["start_armor"])]
	_text(Vector2(w * 0.5, h * 0.36 + 72.0), Loc.field(b, "name"), 20, UiKit.TEXT)
	_text(Vector2(w * 0.5, h * 0.36 + 102.0), line, 18, UiKit.AMBER)
	_text(Vector2(w * 0.5, h * 0.9), Loc.t("Arrives on turn %d · +2 attack every turn from turn %d") % [int(b["arrival_turn"]), int(b["escalate_from_turn"])], 14, UiKit.TEXT_DIM)
