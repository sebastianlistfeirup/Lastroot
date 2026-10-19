class_name PauseMenu
extends CanvasLayer
## Pause overlay for the battle (and the run screens): Resume, Settings,
## Save & quit to menu. LASTROOT is turn-based, so nothing in the domain is
## paused; the overlay only blocks input below it. GameSession already saved
## after the last command, so "Save & quit" just returns to the menu.
##
## Opens with ui_cancel (Esc) when `esc_opens` is true, or with the visible
## corner button when `corner_button` is true, or by calling open().
## Hosts that use Esc for something else (e.g. cancelling a target) should
## mark that event handled first, or set esc_opens = false and call open().

signal closed
signal opened

@export var corner_button: bool = true
@export var esc_opens: bool = true

var is_open: bool = false
## Tests set this false and read `pending_scene` instead of changing scenes.
var auto_navigate: bool = true
var pending_scene: String = ""
## True while the in-page "Abandon this run?" confirmation is shown.
var confirming_abandon: bool = false

var _root: Control
var _corner: Button
var _settings: SettingsPanel
var _howto: HowToPlayPanel
var _panel_box: VBoxContainer


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_corner = UiKit.button(Loc.t("Menu"), UiKit.ASH, 18)
	_corner.name = "PauseCornerButton"
	_corner.custom_minimum_size = Vector2(UiKit.MIN_HIT * 2, UiKit.MIN_HIT)
	_corner.anchor_left = 1.0
	_corner.anchor_right = 1.0
	_corner.offset_left = -UiKit.MIN_HIT * 2 - 12
	_corner.offset_right = -12
	_corner.offset_top = 12
	_corner.offset_bottom = 12 + UiKit.MIN_HIT
	_corner.pressed.connect(open)
	_corner.visible = corner_button
	add_child(_corner)
	_root = Control.new()
	_root.name = "PauseRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	_settings = SettingsPanel.new()
	_settings.name = "SettingsPanel"
	_settings.closed.connect(func() -> void: _focus_first())
	add_child(_settings)
	_howto = HowToPlayPanel.new()
	_howto.name = "HowToPlayPanel"
	_howto.closed.connect(func() -> void: _focus_first())
	add_child(_howto)
	SettingsService.changed.connect(_rebuild)


func open() -> void:
	if is_open:
		return
	is_open = true
	confirming_abandon = false
	AudioService.play("ui_click")
	_rebuild()
	_root.visible = true
	_corner.visible = false
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_settings.visible = false
	_howto.visible = false
	_root.visible = false
	_corner.visible = corner_button
	AudioService.play("ui_cancel")
	closed.emit()


func open_settings() -> void:
	_settings.open()


func open_how_to_play() -> void:
	_howto.open()


func save_and_quit() -> void:
	AudioService.play("ui_confirm")
	_leave_to_menu()


## First press asks in the same panel; "Abandon run" there ends the run.
func ask_abandon() -> void:
	AudioService.play("ui_click")
	confirming_abandon = true
	_rebuild()


func cancel_abandon() -> void:
	AudioService.play("ui_cancel")
	confirming_abandon = false
	_rebuild()


func abandon_run() -> void:
	AudioService.play("ui_confirm")
	GameSession.abandon_run()
	_leave_to_menu()


func _leave_to_menu() -> void:
	is_open = false
	confirming_abandon = false
	_root.visible = false
	closed.emit()
	pending_scene = "menu"
	if auto_navigate:
		AppFlow.goto("menu")


func _rebuild() -> void:
	_corner.text = Loc.t("Menu")
	UiKit.clear(_root)
	_root.add_child(UiKit.dimmer(0.7))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var p := UiKit.panel(UiKit.PANEL, UiKit.LIFE.darkened(0.3))
	center.add_child(p)
	_panel_box = UiKit.vbox(14)
	_panel_box.custom_minimum_size = Vector2(minf(420.0, get_viewport().get_visible_rect().size.x - 64.0), 0)
	p.add_child(_panel_box)
	var t := UiKit.heading(Loc.t("Paused"), 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(t)
	var note := UiKit.label(Loc.t("Your run is saved after every action."), 16, UiKit.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(note)
	if confirming_abandon:
		var warn := UiKit.label(Loc.t("Abandon this run? It ends now and cannot be continued."), 20, UiKit.DANGER, true)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel_box.add_child(warn)
		_panel_box.add_child(_btn(Loc.t("Keep playing"), UiKit.LIFE, "KeepPlayingButton", cancel_abandon))
		_panel_box.add_child(_btn(Loc.t("Abandon run"), UiKit.DANGER, "ConfirmAbandonButton", abandon_run))
	else:
		_panel_box.add_child(_btn(Loc.t("Resume"), UiKit.LIFE, "ResumeButton", close))
		_panel_box.add_child(_btn(Loc.t("How to play"), UiKit.ASH, "PauseHowToButton", open_how_to_play))
		_panel_box.add_child(_btn(Loc.t("Settings"), UiKit.ASH, "PauseSettingsButton", open_settings))
		_panel_box.add_child(_btn(Loc.t("Save & quit to menu"), UiKit.AMBER, "SaveQuitButton", save_and_quit))
		if GameSession.has_run() and not (GameSession.phase() in ["won", "lost"]):
			_panel_box.add_child(_btn(Loc.t("Abandon run"), UiKit.DANGER, "AbandonButton", ask_abandon))
	if is_open:
		_focus_first()


func _btn(text: String, accent: Color, node_name: String, cb: Callable) -> Button:
	var b := UiKit.button(text, accent, 22)
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(cb)
	return b


func _focus_first() -> void:
	if _panel_box == null:
		return
	for c in _panel_box.get_children():
		if c is Button:
			(c as Button).grab_focus.call_deferred()
			return


func find_button(node_name: String) -> Button:
	return find_child(node_name, true, false) as Button


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings.visible or _howto.visible:
		return  # the overlay closes itself
	if confirming_abandon:
		get_viewport().set_input_as_handled()
		cancel_abandon()
		return
	if is_open:
		get_viewport().set_input_as_handled()
		close()
	elif esc_opens:
		get_viewport().set_input_as_handled()
		open()
