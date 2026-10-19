class_name SettingsPanel
extends MetaModal
## Settings overlay, reusable from the main menu and the pause menu. Every
## change goes through SettingsService (persisted at once); screens rebuild on
## SettingsService.changed, and this panel rebuilds itself so new text size and
## language show immediately.

const LANGUAGE_NAMES := {"en": "English", "da": "Dansk"}


func _init() -> void:
	super()
	max_size = Vector2(820, 900)
	accent = UiKit.LIFE


func _ready() -> void:
	super()
	SettingsService.changed.connect(_on_settings_changed)


func open() -> void:
	title_text = Loc.t("Settings")
	super()


func _on_settings_changed() -> void:
	if visible:
		var fo: Control = get_viewport().gui_get_focus_owner()
		var fname: String = fo.name if fo != null and is_ancestor_of(fo) else ""
		title_text = Loc.t("Settings")
		rebuild()
		var t: Control = body.find_child(fname, true, false) as Control if fname != "" else null
		if t:
			t.grab_focus.call_deferred()


func _build() -> void:
	# Language names are shown in their own language on purpose.
	var langs: Array = []
	for code: String in Loc.LANGUAGES:
		langs.append([code, LANGUAGE_NAMES.get(code, code)])
	_row(Loc.t("Language"), langs, SettingsService.language, func(v: Variant) -> void: SettingsService.set_language(str(v)))
	var scales: Array = []
	for s: float in SettingsService.TEXT_SCALES:
		scales.append([s, "%d%%" % int(round(s * 100.0))])
	_row(Loc.t("Text size"), scales, SettingsService.text_scale, func(v: Variant) -> void: SettingsService.set_text_scale(float(v)))
	_row(Loc.t("Reduced motion"), [[false, Loc.t("Off")], [true, Loc.t("On")]], SettingsService.reduced_motion,
		func(v: Variant) -> void: SettingsService.set_reduced_motion(bool(v)),
		Loc.t("Keeps the camera still and turns off pulsing and drifting effects."))
	var speeds: Array = []
	for s: float in SettingsService.ANIM_SPEEDS:
		speeds.append([s, "%sx" % (str(s) if s != int(s) else str(int(s)))])
	_row(Loc.t("Animation speed"), speeds, SettingsService.anim_speed, func(v: Variant) -> void: SettingsService.set_anim_speed(float(v)),
		Loc.t("How fast battle animations replay. The outcome never changes."))
	_row(Loc.t("3D backgrounds"), [[false, Loc.t("Off")], [true, Loc.t("On")]], SettingsService.backgrounds_3d,
		func(v: Variant) -> void: SettingsService.set_backgrounds_3d(bool(v)),
		Loc.t("Animated 3D scenes behind the menu and the route. Turn off for slow devices."))
	body.add_child(UiKit.label(Loc.t("Volume"), 20, UiKit.TEXT, true))
	_slider(Loc.t("Master"), "master")
	_slider(Loc.t("Music"), "music")
	_slider(Loc.t("Sound effects"), "sfx")


func _row(title: String, options: Array, current: Variant, on_pick: Callable, hint: String = "") -> void:
	var box := UiKit.vbox(6)
	box.add_child(UiKit.label(title, 20, UiKit.TEXT, true))
	if hint != "":
		box.add_child(UiKit.label(hint, 15, UiKit.TEXT_DIM))
	var row := UiKit.flow(8, false)
	for opt: Array in options:
		var val: Variant = opt[0]
		var sel: bool = _same(val, current)
		var b := UiKit.button(("✓ " if sel else "") + str(opt[1]), UiKit.LIFE if sel else UiKit.ASH, 18)
		b.name = "Opt_%s_%s" % [title.to_snake_case().left(12), str(val).replace(".", "_")]
		b.custom_minimum_size = Vector2(UiKit.MIN_HIT * 2, UiKit.MIN_HIT)
		b.toggle_mode = true
		b.button_pressed = sel
		if sel:
			b.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.LIFE.darkened(0.6), UiKit.LIFE, 10, 3))
			b.add_theme_stylebox_override("pressed", UiKit.panel_style(UiKit.LIFE.darkened(0.6), UiKit.LIFE, 10, 3))
		b.pressed.connect(func() -> void:
			AudioService.play("ui_click")
			on_pick.call(val))
		row.add_child(b)
	box.add_child(row)
	body.add_child(box)


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return absf(float(a) - float(b)) < 0.001
	return a == b


func _slider(title: String, key: String) -> void:
	var row := UiKit.hbox(12)
	var l := UiKit.label(title, 18, UiKit.TEXT)
	l.custom_minimum_size = Vector2(UiKit.px(150), 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = round(SettingsService.volume(key) * 100.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(120, UiKit.MIN_HIT)
	var track := StyleBoxFlat.new()
	track.bg_color = UiKit.LINE
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	var filled := StyleBoxFlat.new()
	filled.bg_color = UiKit.LIFE.darkened(0.2)
	filled.set_corner_radius_all(4)
	filled.content_margin_top = 4
	filled.content_margin_bottom = 4
	s.add_theme_stylebox_override("grabber_area", filled)
	s.add_theme_stylebox_override("grabber_area_highlight", filled)
	s.name = "Volume_" + key
	row.add_child(s)
	var val := UiKit.label("%d%%" % int(s.value), 18, UiKit.TEXT_DIM)
	val.custom_minimum_size = Vector2(UiKit.px(64), 0)
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(val)
	# Live value while dragging; persist once the drag ends (and on tap/keys).
	s.value_changed.connect(func(v: float) -> void:
		val.text = "%d%%" % int(v)
		var idx: int = AudioServer.get_bus_index({"master": "Master", "music": "Music", "sfx": "SFX"}[key])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v / 100.0, 0.0001))))
	s.drag_ended.connect(func(_changed: bool) -> void: _store_volume(key, s.value))
	s.focus_exited.connect(func() -> void: _store_volume(key, s.value))
	s.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and not (e as InputEventMouseButton).pressed) or e is InputEventKey:
			_store_volume.call_deferred(key, s.value))
	body.add_child(row)


func _store_volume(key: String, v: float) -> void:
	if absf(SettingsService.volume(key) - v / 100.0) < 0.001:
		return
	# Persist without a full rebuild (the slider keeps focus while dragging).
	SettingsService.volumes[key] = clampf(v / 100.0, 0.0, 1.0)
	SettingsService.apply()
	SettingsService.save_settings()
	AudioService.play("ui_click")
