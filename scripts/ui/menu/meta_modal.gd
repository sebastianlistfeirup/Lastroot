class_name MetaModal
extends Control
## Base overlay: dimmed full-screen backdrop, one centred panel with a title,
## a scrolling body and a close button (Esc / ui_cancel also closes). Works as
## a child of any Control or CanvasLayer. Subclasses fill `body` in _build().

signal closed

var title_text: String = ""
var max_size: Vector2 = Vector2(900, 860)
var accent: Color = UiKit.LIFE

var body: VBoxContainer
var footer: HBoxContainer
var close_button: Button
var _panel: PanelContainer
var _scroll: ScrollContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)


func open() -> void:
	visible = true
	rebuild()
	var f: Control = initial_focus()
	if f:
		f.grab_focus.call_deferred()


## Control that gets keyboard / pad focus when the overlay opens.
func initial_focus() -> Control:
	return close_button


func close() -> void:
	if not visible:
		return
	visible = false
	AudioService.play("ui_cancel")
	closed.emit()


func rebuild() -> void:
	UiKit.clear(self)
	add_child(UiKit.dimmer(0.78))
	_panel = PanelContainer.new()
	var sb := UiKit.panel_style(UiKit.PANEL, accent.darkened(0.3), 16, 2)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := UiKit.vbox(12)
	_panel.add_child(v)
	var head := UiKit.hbox(12)
	v.add_child(head)
	var t := UiKit.heading(title_text, 30, UiKit.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	close_button = UiKit.button(Loc.t("Close"), UiKit.ASH)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	var line := ColorRect.new()
	line.color = UiKit.LINE
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	_scroll = UiKit.vscroll()
	v.add_child(_scroll)
	body = UiKit.vbox(14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	footer = UiKit.hbox(12)
	footer.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(footer)
	_build()
	footer.visible = footer.get_child_count() > 0
	_layout()
	_relayout_after_wrap.call_deferred()


## Override: add content to `body` (and optional buttons to `footer`).
func _build() -> void:
	pass


func _layout() -> void:
	if _panel == null or not is_inside_tree():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var gutter: float = 16.0 if vp.x < 700 else 48.0
	var w: float = minf(max_size.x, vp.x - gutter * 2.0)
	var h: float = minf(max_size.y, vp.y - gutter * 2.0)
	# Shrink to the content when it is shorter (measured at the final width).
	if body:
		_panel.custom_minimum_size = Vector2(w, 0)
		body.custom_minimum_size.x = w - 48.0
		var chrome: float = 16.0 * 2.0 + 12.0 * 3.0 + 2.0 + close_button.get_combined_minimum_size().y
		if footer and footer.visible:
			chrome += footer.get_combined_minimum_size().y + 12.0
		var need: float = chrome + body.get_combined_minimum_size().y + 8.0
		h = minf(h, maxf(need, 200.0))
	_panel.position = (vp - Vector2(w, h)) * 0.5
	_panel.size = Vector2(w, h)
	_panel.custom_minimum_size = Vector2(w, h)


func is_portrait() -> bool:
	return UiKit.is_portrait(get_viewport().get_visible_rect().size)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Wrapped labels know their height only after one layout pass at the real
## width; measure again then (twice: the first pass may change the width).
func _relayout_after_wrap() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_layout()
	await get_tree().process_frame
	_layout()
