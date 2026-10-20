class_name CardView
extends PanelContainer
## One card with real text (never baked into an image, bible LR-24): Sap cost
## orb, name, illustration (rendered portrait or spell emblem), type + space
## pips, attack/HP/Armor row with the battle glyphs, rules text with the
## instance's actual numbers and highlighted status keywords, upgrade line.
## Faction frame (Bark amber, Spore violet), gold champion frame, green
## upgrade ribbon. Emits `pressed` on click/tap. Used by the hand, rewards,
## camp and deck lists.

signal pressed

const W := 168
const H := 236
const ART_H := 62.0
var _art_base: float = ART_H  # picture height before large-text shrinking

var def_id: String = ""
var upgrade_id: String = ""
var path_id: String = ""
var rank: int = 0
var instance_id: int = -1
var selected: bool = false: set = set_selected
var playable: bool = true: set = set_playable
var cost_override: int = -1

var _k: float = 1.0
var _name: Label
var _cost: Label
var _cost_box: PanelContainer
var _kind: Label
var _pips: Label
var _art: CardArt
var _stats: RichTextLabel
var _text: RichTextLabel
var _upg: Label


## Max pointer travel (px) between press and release that still counts as a tap.
const TAP_SLOP := 14.0
var _press_at: Vector2 = Vector2(-1e9, -1e9)

func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	# PASS: a finger dragging over it still scrolls the list it sits in.
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL  # keyboard / pad: arrows move, ui_accept = tap
	focus_entered.connect(_apply_style)
	focus_exited.connect(_apply_style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	_cost_box = PanelContainer.new()
	_cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_cost_box)
	_cost = UiKit.label("", 20, UiKit.BG, true)
	_cost.autowrap_mode = TextServer.AUTOWRAP_OFF
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_box.add_child(_cost)
	_name = UiKit.label("", 16, UiKit.TEXT, true)
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.clip_text = true
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_name)
	_art = CardArt.new()
	_art.custom_minimum_size = Vector2(0, ART_H)
	v.add_child(_art)
	var kind_row := HBoxContainer.new()
	kind_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(kind_row)
	_kind = UiKit.label("", 12, UiKit.TEXT_DIM)
	_kind.autowrap_mode = TextServer.AUTOWRAP_OFF
	_kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kind_row.add_child(_kind)
	_pips = UiKit.label("", 12, UiKit.TEXT_DIM)
	_pips.autowrap_mode = TextServer.AUTOWRAP_OFF
	kind_row.add_child(_pips)
	_stats = _rich(16)
	v.add_child(_stats)
	_text = _rich(13)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_upg = UiKit.label("", 12, UiKit.GOOD, true)
	v.add_child(_upg)
	for c in [_name, _cost, _kind, _pips, _upg, kind_row, top]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.sort_children.connect(_fit_height)
	_name.resized.connect(_fit_name)


## Large text sizes (LR-28): the card keeps its footprint and the picture gives
## up height first, so rules text is never pushed out of a fixed-height hand.
func _fit_height() -> void:
	var v: Control = get_child(0) as Control
	var sb: StyleBox = get_theme_stylebox("panel")
	var avail: float = custom_minimum_size.y - (sb.get_minimum_size().y if sb else 0.0)
	var excess: float = v.get_combined_minimum_size().y - avail
	# Reversible: the first sort runs before the rules text knows its width
	# (it measures far too tall), so the picture grows back once it fits.
	if excess < -0.5 and _art.custom_minimum_size.y < _art_base:
		_art.custom_minimum_size.y = minf(_art_base, _art.custom_minimum_size.y - excess)
		_art.visible = _art.custom_minimum_size.y >= 12.0
		return
	if excess <= 0.5:
		return
	if _art.custom_minimum_size.y > 0.0:
		_art.custom_minimum_size.y = maxf(0.0, _art.custom_minimum_size.y - excess)
		_art.visible = _art.custom_minimum_size.y >= 12.0
	elif _upg.visible and _upg.text == Loc.t("Cannot be upgraded"):
		_upg.visible = false  # informational line only; the camp says it too
	else:
		# last resort: rules text one pixel smaller per pass (re-sorts, converges)
		var fs: int = _text.get_theme_font_size("normal_font_size")
		if fs > 10:
			for r: RichTextLabel in [_stats, _text]:
				r.add_theme_font_size_override("normal_font_size", fs - 1)
				r.add_theme_font_size_override("bold_font_size", fs - 1)


static func _rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_color_override("default_color", UiKit.TEXT)
	r.set_meta("base_size", size)
	return r


## Smaller text and footprint for narrow portrait hands (same information).
func set_compact(c: bool) -> CardView:
	_k = 0.78 if c else 1.0
	(get_child(0) as VBoxContainer).add_theme_constant_override("separation", 1 if c else 3)
	_apply_fonts()
	_fit_name()
	custom_minimum_size = Vector2(W * _k, H * _k * 0.92)
	return self


func _apply_fonts() -> void:
	var k: float = _k * UiKit.font_scale
	for pair: Array in [[_cost, 20], [_kind, 12], [_pips, 12], [_name, 16], [_upg, 12]]:
		(pair[0] as Label).add_theme_font_size_override("font_size", int(round(float(pair[1]) * k)))
	for r: RichTextLabel in [_stats, _text]:
		var fs: int = int(round(float(r.get_meta("base_size")) * k))
		r.add_theme_font_size_override("normal_font_size", fs)
		r.add_theme_font_size_override("bold_font_size", fs)
	# Compact hands keep every line but give the picture less room.
	_art_base = ART_H * (0.55 if _k < 1.0 else 1.0)
	_art.custom_minimum_size = Vector2(0, _art_base)
	_art.visible = true
	var orb: float = 30.0 * k
	_cost_box.custom_minimum_size = Vector2(orb, orb)


func setup(p_def_id: String, p_upgrade: String = "", p_path: String = "", p_rank: int = 0, p_iid: int = -1) -> CardView:
	def_id = p_def_id
	upgrade_id = p_upgrade
	path_id = p_path
	rank = p_rank
	instance_id = p_iid
	refresh()
	return self


func refresh() -> void:
	var def: Dictionary = Catalog.card(def_id)
	if def.is_empty():
		return
	_apply_fonts()
	var base_cost: int = int(def["cost"])
	var cost: int = CardStats.cost(def, upgrade_id) if cost_override < 0 else cost_override
	_cost.text = str(cost)
	var orb := StyleBoxFlat.new()
	orb.bg_color = UiKit.LIFE if cost <= base_cost else UiKit.AMBER
	if cost < base_cost:
		orb.bg_color = UiKit.GOOD
	orb.set_corner_radius_all(40)
	orb.border_color = Color(1, 1, 1, 0.55)
	orb.set_border_width_all(2)
	_cost_box.add_theme_stylebox_override("panel", orb)
	var kind_text: String = Loc.t("Champion") if def["kind"] == "champion" else (Loc.t("Creature") if def["kind"] == "unit" else Loc.t("Spell"))
	_kind.text = kind_text
	if Catalog.is_creature(def):
		_pips.text = UiKit.status_glyph("space").repeat(int(def["space"])) + " %d" % int(def["space"])
		_pips.visible = true
	else:
		_pips.visible = false
	_name.text = Loc.field(def, "name")
	_fit_name()
	_art.set_def(def, upgrade_id != "")
	if Catalog.is_creature(def):
		var st: Dictionary = CardStats.unit_stats(def, upgrade_id, path_id, rank)
		var parts: PackedStringArray = [_stat("attack", int(st["attack"])), _stat("hp", int(st["max_hp"]))]
		if int(st["armor"]) > 0:
			parts.append(_stat("armor", int(st["armor"])))
		_stats.text = "  ".join(parts)
		_stats.visible = true
	else:
		_stats.visible = false
	_text.text = highlight(CardStats.format_text(Loc.field(def, "text"), def, upgrade_id, path_id, rank))
	if upgrade_id != "":
		_upg.text = "+ " + Loc.t("Upgraded") + ": " + _upgrade_label(def, upgrade_id)
		_upg.add_theme_color_override("font_color", UiKit.GOOD)
	elif def.get("upgrade_rule", "") == "none":
		_upg.text = Loc.t("Cannot be upgraded")
		_upg.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	else:
		_upg.text = ""
	_upg.visible = _upg.text != ""
	_apply_style()


## One line for the name: shrink the font (down to 11 px) until it fits.
func _fit_name() -> void:
	var k: float = _k * UiKit.font_scale
	var avail: float = W * _k - (16.0 if _k >= 1.0 else 10.0) - 30.0 * k - 6.0
	if _name.size.x > 1.0:
		avail = minf(avail, _name.size.x)  # the laid-out width wins (style margins differ)
	var fs: int = int(round(16.0 * k))
	var font: Font = _name.get_theme_font("font")
	while fs > 9 and font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 1
	_name.add_theme_font_size_override("font_size", fs)


static func _stat(kind: String, v: int) -> String:
	return "[color=#%s]%s[/color] [b]%d[/b]" % [UiKit.status_color(kind).to_html(false), UiKit.status_glyph(kind), v]


## Rules text as BBCode: numbers bold, status keywords in their status colour
## with the battle glyph (English and Danish keywords).
static func highlight(text: String) -> String:
	var t: String = text.replace("[", "(").replace("]", ")")
	var num := RegEx.new()
	num.compile("(?<![#\\w])(\\d+)")
	t = num.sub(t, "[b]$1[/b]", true)
	var kw := {"armor": "armor|panser|startpanser", "poison": "poison|gift", "thorns": "thorns|torne", "growth": "growth|vækst"}
	for k: String in kw.keys():
		var re := RegEx.new()
		re.compile("(?i)\\b(" + str(kw[k]) + ")\\b")
		t = re.sub(t, "[color=#%s]%s $1[/color]" % [UiKit.status_color(k).to_html(false), UiKit.status_glyph(k)], true)
	return t


static func _upgrade_label(def: Dictionary, uid: String) -> String:
	var u: Dictionary = CardStats.upgrade_def(def, uid)
	if u.is_empty():
		return uid
	var stat_names := {"attack": "attack", "max_hp": "max HP", "damage": "damage", "armor": "Armor",
		"heal": "healing", "poison": "Poison", "cost": "cost"}
	return "%+d %s" % [int(u["delta"]), Loc.t(stat_names.get(u["stat"], u["stat"]))]


func set_selected(v: bool) -> void:
	selected = v
	_apply_style()


func set_playable(v: bool) -> void:
	playable = v
	_apply_style()


func _apply_style() -> void:
	var def: Dictionary = Catalog.card(def_id)
	var fc: Color = UiKit.faction_color(def.get("faction", "BARK"))
	var champ: bool = def.get("kind", "") == "champion"
	var bg: Color = UiKit.PANEL.lerp(fc, 0.10)
	var border: Color = fc.darkened(0.15)
	var bw: int = 2
	if champ:
		border = UiKit.AMBER.lightened(0.15)
		bg = UiKit.PANEL.lerp(UiKit.AMBER, 0.10)
		bw = 3
	if upgrade_id != "" and not selected:
		border = border.lerp(UiKit.GOOD, 0.45)
	if selected:
		border = UiKit.LIFE
		bg = bg.lightened(0.08)
		bw = 4
	var sb := UiKit.panel_style(bg, border, 12, bw)
	var mg: int = 8 if _k >= 1.0 else 5
	sb.content_margin_left = mg
	sb.content_margin_right = mg
	sb.content_margin_top = mg - 1
	sb.content_margin_bottom = mg - 1
	if champ:
		sb.shadow_color = Color(UiKit.AMBER, 0.25)
		sb.shadow_size = 4
	if selected:
		sb.shadow_color = Color(UiKit.LIFE, 0.35)
		sb.shadow_size = 8
	if has_focus() and UiKit.focus_visible:
		# Focus ring: white outline outside the frame, independent of state colours.
		sb.expand_margin_left = 4
		sb.expand_margin_right = 4
		sb.expand_margin_top = 4
		sb.expand_margin_bottom = 4
		sb.shadow_color = Color(1, 1, 1, 0.9)
		sb.shadow_size = 3
	add_theme_stylebox_override("panel", sb)
	if _art:
		_art.selected = selected
		_art.unplayable = not playable
		_art.queue_redraw()
	modulate = Color(1, 1, 1, 1) if playable else Color(0.62, 0.62, 0.66, 1)


func _gui_input(event: InputEvent) -> void:
	var press := false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# Tap = press and release without a drag, so swiping a list never picks.
		var mb: InputEventMouseButton = event
		if mb.pressed:
			_press_at = mb.global_position
		elif _press_at.x > -1e8:
			press = mb.global_position.distance_to(_press_at) <= TAP_SLOP
			_press_at = Vector2(-1e9, -1e9)
	elif event is InputEventScreenTouch and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
		# With mouse emulation on, the emulated click already arrives; don't fire twice.
		press = (event as InputEventScreenTouch).pressed
	elif event.is_action_pressed("ui_accept") and has_focus():
		press = true
	if press:
		accept_event()
		pressed.emit()


## Called by SettingsService when keyboard / pointer mode flips.
func _on_focus_style() -> void:
	_apply_style()
