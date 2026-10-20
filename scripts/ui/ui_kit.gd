class_name UiKit
extends RefCounted
## Shared look for every screen (REF_01-05 palette: deep night blue, bark
## amber, spore violet, turquoise life, ash grey). Colors are always paired
## with icons/text so information never depends on color alone (bible p.16).

const BG := Color("0d1019")
const PANEL := Color("161c2a")
const PANEL_HI := Color("1f2840")
const LINE := Color("2c3854")
const TEXT := Color("e9eef7")
const TEXT_DIM := Color("9aa6bd")
const AMBER := Color("f0a646")
const BARK := Color("c98a4b")
const SPORE := Color("b07cf0")
const LIFE := Color("3fe0c8")
const ASH := Color("8a8f99")
const DANGER := Color("ff5d5d")
const GOOD := Color("7ce38b")
const POISON := Color("9be35a")
const ARMOR := Color("8fb7ff")

const MIN_HIT := 48  # logical px (bible p.16)

static var font_scale: float = 1.0


static func faction_color(faction: String) -> Color:
	return BARK if faction == "BARK" else SPORE


static func panel_style(color: Color = PANEL, border: Color = LINE, radius: int = 10, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func panel(color: Color = PANEL, border: Color = LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color, border))
	return p


static func label(text: String, size: int = 20, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size * font_scale))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 1)
		l.add_theme_color_override("font_outline_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, accent: Color = AMBER, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(MIN_HIT * 2, MIN_HIT)
	b.add_theme_font_size_override("font_size", int(size * font_scale))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)
	b.add_theme_stylebox_override("normal", panel_style(PANEL_HI, accent.darkened(0.35), 10, 2))
	b.add_theme_stylebox_override("hover", panel_style(PANEL_HI.lightened(0.08), accent, 10, 2))
	b.add_theme_stylebox_override("pressed", panel_style(accent.darkened(0.55), accent, 10, 3))
	b.add_theme_stylebox_override("focus", focus_box())
	b.add_theme_stylebox_override("disabled", panel_style(PANEL, LINE, 10, 1))
	return b


## A full-screen dark background ColorRect.
static func backdrop() -> ColorRect:
	var c := ColorRect.new()
	c.color = BG
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Status icon glyphs (text + color; readable without color).
static func status_glyph(kind: String) -> String:
	match kind:
		"armor": return "◆"
		"poison": return "☠"
		"thorns": return "✶"
		"growth": return "✚"
		"attack": return "⚔"
		"hp": return "♥"
		"sap": return "●"
		"space": return "▮"
		"resin": return "⬢"
	return "•"


static func status_color(kind: String) -> Color:
	match kind:
		"armor": return ARMOR
		"poison": return POISON
		"thorns": return AMBER
		"growth": return LIFE
		"attack": return Color("ffcf7a")
		"hp": return Color("ff8a8a")
		"sap": return LIFE
		"resin": return AMBER
	return TEXT


static func is_portrait(vp: Vector2) -> bool:
	return vp.y > vp.x


# ------------------------------------------------- meta-screen helpers (added)

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


## Wrapping row (cards, chips); centered by default so portrait stays tidy.
static func flow(separation: int = 12, centered: bool = true) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", separation)
	f.add_theme_constant_override("v_separation", separation)
	if centered:
		f.alignment = FlowContainer.ALIGNMENT_CENTER
	return f


static func margin(all: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, all)
	return m


## Section heading.
static func heading(text: String, size: int = 30, color: Color = TEXT) -> Label:
	var l := label(text, size, color, true)
	return l


## Small pill with text, used for status strips.
static func chip(text: String, accent: Color = LINE, size: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := panel_style(PANEL_HI, accent, 16, 2)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, size, TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p


## Full-rect dimmer that also blocks input to what lies below.
static func dimmer(alpha: float = 0.72) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(BG, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


## Vertical scroll area that never scrolls sideways.
static func vscroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true  # keyboard / pad focus scrolls into view
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.sort_children.connect(touch_pass.bind(s))
	return s


## Touch drag-scrolling: a finger that lands on a panel or label inside a
## ScrollContainer must reach the container, so non-button Controls that would
## swallow the press (MOUSE_FILTER_STOP, e.g. PanelContainer) pass it on.
## Buttons, cards and tiles keep their own taps.
static func touch_pass(n: Node) -> void:
	for c in n.get_children():
		if c is Control and not (c is BaseButton or c is Range or c is LineEdit or c is TextEdit or c.has_signal("pressed")):
			if (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		touch_pass(c)


static func px(v: float) -> int:
	return int(round(v * font_scale))


# ------------------------------------------------ focus ring (keyboard / pad)

## True after the first key / pad input, false again after mouse or touch
## (SettingsService switches it). Mouse and touch users never see the ring.
static var focus_visible: bool = false
static var _focus_box: StyleBoxFlat = null
static var _focus_round: StyleBoxFlat = null


## Shared focus stylebox for buttons: one instance, so showing/hiding the ring
## updates every button at once.
static func focus_box() -> StyleBoxFlat:
	if _focus_box == null:
		_focus_box = StyleBoxFlat.new()
		_focus_box.draw_center = false
		_focus_box.set_corner_radius_all(10)
		_focus_box.set_border_width_all(3)
		_focus_box.expand_margin_left = 2
		_focus_box.expand_margin_right = 2
		_focus_box.expand_margin_top = 2
		_focus_box.expand_margin_bottom = 2
		_apply_focus_color(_focus_box)
	return _focus_box


## Round variant (route map nodes).
static func focus_round() -> StyleBoxFlat:
	if _focus_round == null:
		_focus_round = focus_box().duplicate()
		_focus_round.set_corner_radius_all(40)
		_apply_focus_color(_focus_round)
	return _focus_round


static func _apply_focus_color(sb: StyleBoxFlat) -> void:
	sb.border_color = Color(1, 1, 1, 1) if focus_visible else Color(1, 1, 1, 0)


static func set_focus_visible(v: bool) -> void:
	if v == focus_visible:
		return
	focus_visible = v
	for sb: StyleBoxFlat in [focus_box(), focus_round()]:
		_apply_focus_color(sb)
