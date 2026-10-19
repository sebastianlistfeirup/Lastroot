class_name UnitBadge
extends PanelContainer
## 2D readout above a unit: attack, HP, Armor, Poison, Thorns, Growth and the
## forecast line. Doubles as the unit's tap target (>= 48 px tall).

signal pressed(unit_id: int)

var unit_id: int = -1
var side: String = "ally"
var _stats: RichTextLabel
var _status: RichTextLabel
var _k: float = 1.0
var _fc: Label
var _highlight: String = ""  # "" | target | selected | invalid


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(UiKit.MIN_HIT * 1.6, UiKit.MIN_HIT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_stats = _rich()
	_status = _rich()
	_fc = UiKit.label("", 15, UiKit.AMBER, true)
	_fc.autowrap_mode = TextServer.AUTOWRAP_OFF
	_fc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l in [_stats, _status, _fc]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	_apply_fonts()
	_restyle()


## Rich one-line readout: each status is glyph + number in its colour, so it
## never depends on colour alone (bible p.16).
static func _rich() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.add_theme_color_override("default_color", UiKit.TEXT)
	r.add_theme_constant_override("outline_size", 4)
	r.add_theme_color_override("font_outline_color", Color(UiKit.BG, 0.9))
	return r


func _apply_fonts() -> void:
	var fs: int = int(17 * _k * UiKit.font_scale)
	for key in ["normal_font_size", "bold_font_size"]:
		_stats.add_theme_font_size_override(key, fs)
		_status.add_theme_font_size_override(key, int(15 * _k * UiKit.font_scale))


static func _part(kind: String, value: String) -> String:
	return "[color=#%s]%s[/color][b]%s[/b]" % [UiKit.status_color(kind).to_html(false), UiKit.status_glyph(kind), value]


## Compact badges for narrow portrait screens (smaller text, same information).
func set_compact(c: bool) -> void:
	var k: float = 0.72 if c else 1.0
	_k = k
	_apply_fonts()
	_fc.add_theme_font_size_override("font_size", int(15 * k * UiKit.font_scale))
	custom_minimum_size = Vector2(UiKit.MIN_HIT * (1.0 if c else 1.6), UiKit.MIN_HIT * (0.8 if c else 1.0))


func show_unit(u: Dictionary, attack_value: int, extra: String = "") -> void:
	unit_id = int(u["unit_id"])
	side = str(u["side"])
	var champ: String = "[color=#%s]★[/color] " % UiKit.AMBER.to_html(false) if u.get("is_champion", false) else ""
	if u.get("is_boss", false):
		champ = "[color=#%s]♛[/color] " % UiKit.DANGER.to_html(false)
	var hp_col: Color = UiKit.TEXT if int(u["hp"]) * 2 > int(u["max_hp"]) else UiKit.DANGER.lightened(0.2)
	_stats.text = "[center]%s%s  [color=#%s]%s[/color][b][color=#%s]%d[/color]/%d[/b][/center]" % [champ, _part("attack", str(attack_value)),
		UiKit.status_color("hp").to_html(false), UiKit.status_glyph("hp"), hp_col.to_html(false), int(u["hp"]), int(u["max_hp"])]
	var parts: PackedStringArray = []
	for k in ["armor", "poison", "thorns", "growth"]:
		if int(u.get(k, 0)) > 0:
			parts.append(_part(k, str(int(u[k]))))
	_status.text = ("[center]" + "  ".join(parts) + extra + "[/center]") if (not parts.is_empty() or extra != "") else ""
	_status.visible = _status.text != ""
	_restyle()


## Forecast line, e.g. "♥ 5→2", "✝ dies", "↑ Trunk", "→ Heart −3".
func show_forecast(text: String, danger: bool) -> void:
	_fc.text = text
	_fc.visible = text != ""
	_fc.add_theme_color_override("font_color", UiKit.DANGER if danger else UiKit.AMBER)


func set_highlight(h: String) -> void:
	_highlight = h
	_restyle()


func _restyle() -> void:
	var base: Color = UiKit.PANEL.lerp(UiKit.LIFE if side == "ally" else Color("ff6a2a"), 0.10)
	base.a = 0.88
	var border: Color = UiKit.LINE
	var w := 2
	match _highlight:
		"target":
			border = UiKit.LIFE
			w = 3
		"selected":
			border = UiKit.AMBER
			w = 4
		"invalid":
			border = UiKit.DANGER
	add_theme_stylebox_override("panel", UiKit.panel_style(base, border, 8, w))


func _gui_input(event: InputEvent) -> void:
	var press := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		press = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
		press = (event as InputEventScreenTouch).pressed
	if press:
		accept_event()
		pressed.emit(unit_id)
