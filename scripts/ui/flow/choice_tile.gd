class_name ChoiceTile
extends PanelContainer
## A large tappable option (mutation, relic, champion path, route node,
## encounter). Tap / click / Enter emits `pressed`; `selected` draws a bright
## border. Children go into `box`.

signal pressed

var accent: Color = UiKit.LIFE
var selected: bool = false: set = set_selected
var enabled: bool = true: set = set_enabled
var box: VBoxContainer
var _mark: ChoiceMark


## Draws the "selected" check badge in the corner (glyph, not just colour).
class ChoiceMark extends Control:
	var tile: ChoiceTile

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if tile == null or not tile.selected:
			return
		var c := Vector2(size.x - 6, 6)
		draw_circle(c, 13.0, UiKit.LIFE)
		MetaIcon.draw_icon(self, "check", c - Vector2(9, 9), 18.0, UiKit.BG)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(UiKit.MIN_HIT * 4, UiKit.MIN_HIT * 2)
	box = UiKit.vbox(8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_mark = ChoiceMark.new()
	_mark.tile = self
	add_child(_mark)
	focus_entered.connect(_style)
	focus_exited.connect(_style)
	_style()


static func make(p_accent: Color) -> ChoiceTile:
	var t := ChoiceTile.new()
	t.accent = p_accent
	t._style()
	return t


## Adds an icon + title row.
func add_title(icon: String, title: String, size: int = 24) -> HBoxContainer:
	var h := UiKit.hbox(12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := MetaIcon.make(icon, accent, UiKit.px(40))
	ic.fill_bg = true
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UiKit.label(title, size, UiKit.TEXT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	box.add_child(h)
	_ignore(h)
	return h


func add_text(text: String, size: int = 18, color: Color = UiKit.TEXT_DIM) -> Label:
	var l := UiKit.label(text, size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l


func add(c: Control) -> void:
	box.add_child(c)
	_ignore(c)


static func _ignore(c: Node) -> void:
	if c is Control and not (c is BaseButton):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in c.get_children():
		_ignore(k)


func set_selected(v: bool) -> void:
	selected = v
	_style()


func set_enabled(v: bool) -> void:
	enabled = v
	_style()


func _style() -> void:
	var bg: Color = UiKit.PANEL.lerp(accent, 0.07)
	var border: Color = accent.darkened(0.35)
	var bw: int = 2
	if selected:
		bg = UiKit.PANEL.lerp(accent, 0.18)
		border = Color.WHITE.lerp(accent, 0.3)
		bw = 4
	var sb := UiKit.panel_style(bg, border, 14, bw)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	if has_focus():
		sb.expand_margin_left = 4
		sb.expand_margin_right = 4
		sb.expand_margin_top = 4
		sb.expand_margin_bottom = 4
		sb.shadow_color = Color(1, 1, 1, 0.9)
		sb.shadow_size = 3
	add_theme_stylebox_override("panel", sb)
	modulate = Color.WHITE if enabled else Color(0.7, 0.7, 0.75, 1)
	if _mark:
		_mark.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var press := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		press = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
		press = (event as InputEventScreenTouch).pressed  # otherwise the emulated mouse press handles it
	elif event.is_action_pressed("ui_accept") and has_focus():
		press = true
	if press:
		accept_event()
		pressed.emit()
