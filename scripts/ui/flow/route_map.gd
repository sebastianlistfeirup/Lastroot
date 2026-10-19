class_name RouteMap
extends Control
## REF_04 route as a 2D node map: five battles and the boss on a fixed path,
## with the two-way branch after each battle. Past choices show chosen /
## skipped, the open branch glows, later branches are visible but locked.
## Desktop runs left -> right; portrait climbs bottom -> top like the tree.
## Every node is a 64 px tap target that emits node_tapped(id).

signal node_tapped(node_id: String)

var run: Dictionary = {}
var vertical: bool = false
var selected: String = ""

var _t: float = 0.0
var _nodes: Array = []  # {id, kind, type, col, lane, state}
var _buttons: Dictionary = {}


func setup(p_run: Dictionary, p_vertical: bool, p_selected: String = "") -> void:
	run = p_run
	vertical = p_vertical
	selected = p_selected
	custom_minimum_size = Vector2(0, 1040) if vertical else Vector2(0, 470)
	_collect()
	_make_buttons()
	queue_redraw()


func _ready() -> void:
	resized.connect(_place_buttons)


func _process(delta: float) -> void:
	if SettingsService.reduced_motion:
		return
	_t += delta * SettingsService.anim_speed
	queue_redraw()


func won_count() -> int:
	return int(run.get("stats", {}).get("battles_won", 0))


func _collect() -> void:
	_nodes.clear()
	var won: int = won_count()
	for i in 6:
		var st: String = "won" if i < won else ("next" if i == won else "future")
		if str(run.get("phase", "")) == "battle" and i == int(run.get("battle_index", 0)):
			st = "current"
		_nodes.append({"id": "B%d" % i, "kind": "battle", "type": "boss" if i == 5 else "battle", "col": i * 2, "lane": 0, "state": st})
	for r: Dictionary in run.get("route", []):
		var k: int = int(r["after_battle"])
		var opts: Array = r["options"]
		for j in opts.size():
			var o: Dictionary = opts[j]
			var st: String = str(r["status"])  # locked | open | chosen
			if st == "chosen":
				st = "chosen" if r["chosen"] == o["id"] else "skipped"
			_nodes.append({"id": o["id"], "kind": "option", "type": o["type"], "col": k * 2 - 1, "lane": -1 if j == 0 else 1,
				"state": st, "route": r["id"]})


## Node centre in local coordinates.
func node_pos(col: int, lane: int) -> Vector2:
	var w: float = size.x
	var h: float = size.y
	if vertical:
		var pad: float = 70.0
		var y: float = h - pad - float(col) * (h - pad * 2.0) / 10.0
		return Vector2(w * 0.5 + float(lane) * w * 0.29, y)
	var padx: float = 80.0
	var x: float = padx + float(col) * (w - padx * 2.0) / 10.0
	var wave: float = sin(float(col) * 0.9) * h * 0.05 if lane == 0 else 0.0
	return Vector2(x, h * 0.46 + float(lane) * h * 0.29 + wave)


func radius(node: Dictionary) -> float:
	var base: float = 30.0 if vertical else 40.0
	if node["type"] == "boss":
		base *= 1.3
	return base


func _make_buttons() -> void:
	for b: Node in _buttons.values():
		b.queue_free()
	_buttons.clear()
	var empty := StyleBoxEmpty.new()
	for n: Dictionary in _nodes:
		var b := Button.new()
		b.name = "MapNode_" + str(n["id"])
		b.flat = true
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, empty)
		b.add_theme_stylebox_override("focus", UiKit.focus_round())
		b.custom_minimum_size = Vector2(64, 64)
		var nid: String = n["id"]
		b.pressed.connect(func() -> void: node_tapped.emit(nid))
		add_child(b)
		_buttons[nid] = b
	_place_buttons()


func _place_buttons() -> void:
	for n: Dictionary in _nodes:
		var b: Button = _buttons.get(n["id"])
		if b == null:
			continue
		var r: float = maxf(32.0, radius(n) + 6.0)
		b.position = node_pos(n["col"], n["lane"]) - Vector2(r, r)
		b.size = Vector2(r, r) * 2.0


func _find(id: String) -> Dictionary:
	for n: Dictionary in _nodes:
		if n["id"] == id:
			return n
	return {}


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var fs: int = UiKit.px(15 if vertical else 17)
	# Bridges first.
	for n: Dictionary in _nodes:
		if n["kind"] != "option":
			continue
		var k: int = (int(n["col"]) + 1) / 2
		var a: Dictionary = _find("B%d" % (k - 1))
		var b: Dictionary = _find("B%d" % k)
		var st: String = n["state"]
		var col: Color
		var w: float = 5.0
		match st:
			"chosen":
				col = Color(UiKit.LIFE, 0.85)
				w = 7.0
			"open":
				col = Color(MetaIcon.node_color(n["type"]), 0.6 + 0.3 * sin(_t * 3.0))
				w = 6.0
			"skipped":
				col = Color(UiKit.ASH, 0.25)
			_:
				col = Color(UiKit.LINE, 0.8)
		var pn: Vector2 = node_pos(n["col"], n["lane"])
		_bridge(node_pos(a["col"], a["lane"]), pn, col, w, st == "skipped" or st == "locked")
		_bridge(pn, node_pos(b["col"], b["lane"]), col, w, st == "skipped" or st == "locked")
	# Islands, icons, labels.
	for n: Dictionary in _nodes:
		var p: Vector2 = node_pos(n["col"], n["lane"])
		var r: float = radius(n)
		var st: String = n["state"]
		var accent: Color = MetaIcon.node_color(n["type"]) if n["kind"] == "option" else (UiKit.DANGER if n["type"] == "boss" else UiKit.TEXT)
		var dim: float = 1.0
		if st in ["skipped", "future", "locked"]:
			dim = 0.45
		if st == "skipped":
			dim = 0.3
		# Glow for open options and the selection.
		if st == "open" or n["id"] == selected:
			var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
			for i in 4:
				draw_circle(p, r * (1.7 - 0.15 * float(i)) + pulse * 4.0, Color(accent, 0.06 + 0.02 * float(i)))
		if n["type"] == "boss":
			for i in 3:
				draw_circle(p, r * (1.6 - 0.2 * float(i)), Color(UiKit.DANGER, 0.06 * dim))
		_island(p, r, dim, st)
		var ring_col: Color = Color(accent, 0.9 * dim)
		if st == "won" or st == "chosen":
			ring_col = Color(UiKit.LIFE, 0.9)
		if n["id"] == selected:
			ring_col = Color.WHITE
		draw_arc(p, r, 0, TAU, 40, ring_col, 4.0 if (st == "open" or n["id"] == selected) else 2.5, true)
		var ic: float = r * 1.05
		MetaIcon.draw_icon(self, n["type"], p - Vector2(ic, ic) * 0.5, ic, Color(accent, dim) if st != "won" else Color(UiKit.TEXT, 0.55))
		if st == "won" or st == "chosen":
			var cp: Vector2 = p + Vector2(r * 0.7, -r * 0.7)
			draw_circle(cp, r * 0.34, UiKit.LIFE.darkened(0.3))
			MetaIcon.draw_icon(self, "check", cp - Vector2(r, r) * 0.25, r * 0.5, Color.WHITE)
		elif st == "skipped":
			var cp2: Vector2 = p + Vector2(r * 0.7, -r * 0.7)
			draw_circle(cp2, r * 0.3, UiKit.PANEL)
			MetaIcon.draw_icon(self, "skip", cp2 - Vector2(r, r) * 0.2, r * 0.4, UiKit.TEXT_DIM)
		elif st == "locked":
			var cp3: Vector2 = p + Vector2(r * 0.7, -r * 0.7)
			draw_circle(cp3, r * 0.3, UiKit.PANEL)
			MetaIcon.draw_icon(self, "lock", cp3 - Vector2(r, r) * 0.2, r * 0.4, UiKit.TEXT_DIM)
		var label: String = _label(n)
		var tcol: Color = Color(UiKit.TEXT, 0.95 if dim > 0.9 else 0.6)
		var sub: String = _sublabel(n)
		var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ly: float = p.y + r + fs + 6.0
		_text(font, Vector2(p.x - lw * 0.5, ly), label, fs, tcol)
		if sub != "":
			var sw: float = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3).x
			var scol: Color = UiKit.LIFE if st in ["won", "chosen", "next", "open"] else UiKit.TEXT_DIM
			_text(font, Vector2(p.x - sw * 0.5, ly + fs + 2.0), sub, fs - 3, Color(scol, 0.9 if dim > 0.9 else 0.6))
	_marker()


func _text(font: Font, pos: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(UiKit.BG, 0.9))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _label(n: Dictionary) -> String:
	if n["kind"] == "battle":
		return RunText.battle_name(int(n["col"]) / 2)
	return RunText.node_name(n["type"])


func _sublabel(n: Dictionary) -> String:
	if n["id"] == selected:
		return "✓ " + Loc.t("Selected")
	match str(n["state"]):
		"won": return Loc.t("Won")
		"next": return Loc.t("Next")
		"current": return Loc.t("Now")
		"chosen": return Loc.t("Chosen")
		"skipped": return Loc.t("Not taken")
		"open": return Loc.t("Choose")
	return ""


func _bridge(a: Vector2, b: Vector2, col: Color, w: float, dashed: bool) -> void:
	if dashed:
		draw_dashed_line(a, b, col, w * 0.6, 10.0, true, true)
		return
	draw_line(a, b, Color(UiKit.BG, 0.6), w + 4.0, true)
	draw_line(a, b, col, w, true)
	# Stepping stones (REF_04 bridges).
	var steps: int = int(a.distance_to(b) / 26.0)
	for i in range(1, steps):
		draw_circle(a.lerp(b, float(i) / float(steps)), w * 0.55, Color(col.lightened(0.35), col.a))


func _island(p: Vector2, r: float, dim: float, st: String) -> void:
	var top := Color("3a3550") if st != "won" else Color("2f4a48")
	top = Color(top, 0.55 + 0.45 * dim)
	var rock := Color(Color("1d1a2b"), 0.6 + 0.4 * dim)
	var under := PackedVector2Array([p + Vector2(-r * 1.15, r * 0.25), p + Vector2(r * 1.15, r * 0.25), p + Vector2(r * 0.6, r * 0.95),
		p + Vector2(0, r * 1.35), p + Vector2(-r * 0.6, r * 0.95)])
	draw_colored_polygon(under, rock)
	var pts := PackedVector2Array()
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		pts.append(p + Vector2(cos(a) * r * 1.15, sin(a) * r * 0.55 + r * 0.22))
	draw_colored_polygon(pts, top)
	draw_circle(p, r, Color(UiKit.PANEL, 0.92 * (0.6 + 0.4 * dim)))


## The player's token: on the last won battle, or on the chosen node.
func _marker() -> void:
	var phase: String = str(run.get("phase", ""))
	var at: Dictionary = {}
	if phase == "node":
		at = _find(str(run.get("node", {}).get("id", "")))
	if at.is_empty():
		at = _find("B%d" % maxi(0, won_count() - 1))
	if at.is_empty():
		return
	var p: Vector2 = node_pos(at["col"], at["lane"])
	var r: float = radius(at)
	var bob: float = sin(_t * 2.5) * 3.0
	var c: Vector2 = p + Vector2(-r * 1.25, -r * 0.2 + bob)
	draw_circle(c, r * 0.42, Color(UiKit.BG, 0.9))
	draw_circle(c, r * 0.36, UiKit.LIFE)
	draw_circle(c, r * 0.2, Color.WHITE)
	var font: Font = ThemeDB.fallback_font
	var fs: int = UiKit.px(13)
	var you: String = Loc.t("You")
	var w: float = font.get_string_size(you, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(font, c + Vector2(-w * 0.5, -r * 0.5), you, fs, UiKit.LIFE)
