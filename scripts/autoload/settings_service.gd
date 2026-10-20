extends Node
## Player settings (bible p.16: text size, reduced motion, language).
## Persisted to user://settings.cfg. Screens listen to `changed` and rebuild.

signal changed
## Keyboard/pad vs mouse/touch; drives the focus ring (UiKit.focus_visible).
signal nav_mode_changed(keyboard: bool)

const PATH := "user://settings.cfg"
const VERSION := 1
const TEXT_SCALES: PackedFloat32Array = [0.9, 1.0, 1.15, 1.3]
const ANIM_SPEEDS: PackedFloat32Array = [0.5, 1.0, 2.0]
const VOLUME_KEYS: PackedStringArray = ["master", "music", "sfx"]
## Same list as Loc.LANGUAGES; kept here so this script also compiles without
## autoloads (unit tests instantiate it directly).
const LANGUAGES: PackedStringArray = ["en", "da"]

var language: String = "en"
var text_scale: float = 1.0
var reduced_motion: bool = false
var anim_speed: float = 1.0
## Linear 0..1 per bus.
var volumes: Dictionary = {"master": 0.8, "music": 0.6, "sfx": 0.9}

var path: String = PATH  # tests point this at a scratch file
## Set once the first-run "How to play" offer was answered (shown or skipped).
var onboarding_done: bool = false
## 3D dioramas behind menu and route (off = the light 2D backdrop).
var backgrounds_3d: bool = true
var keyboard_nav: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()
	add_pad_ui_events()
	if "--debug-state" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.5
		t.autostart = true
		t.timeout.connect(_dump_state)
		add_child(t)


# ------------------------------------------- --debug-state (test harness only)
# Prints the run state and the on-screen tap targets whenever they change, so
# an outside driver (tools/web_phone_flow.js) can tap like a player. Output:
#   STATE phase=battle turn=2 energy=3 hand=4 allies=1 bphase=player champ=12 view=430x932
#   UI <name>|<text>|<cx>|<cy>|<w>|<h>   (logical viewport pixels)
var _last_dump: String = ""


func _dump_state() -> void:
	var gs: Node = get_node_or_null("/root/GameSession")
	var run: Dictionary = gs.get("run") if gs != null else {}
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var line := "STATE phase=%s" % str(run.get("phase", "none"))
	var b: Dictionary = run.get("battle", {}) if run.get("phase", "") == "battle" else {}
	if not b.is_empty():
		var allies := 0
		for u: Dictionary in (b.get("units", {}) as Dictionary).values():
			if u.get("side", "") == "ally" and u.get("alive", false):
				allies += 1
		line += " turn=%d energy=%d hand=%d allies=%d bphase=%s champ=%d battle=%d" % [int(b.get("turn", 0)), int(b.get("energy", 0)),
			(b.get("zones", {}).get("hand", []) as Array).size(), allies, str(b.get("phase", "")), int(b.get("champion_iid", -1)), int(b.get("battle_index", 0))]
	line += " view=%dx%d" % [int(vp.x), int(vp.y)]
	var ui: PackedStringArray = []
	_collect_targets(get_tree().root, ui)
	var out: String = line + "\n" + "\n".join(ui)
	if out != _last_dump:
		_last_dump = out
		print(line)
		for u: String in ui:
			print(u)
		print("STATE_END")


func _collect_targets(n: Node, out: PackedStringArray) -> void:
	if out.size() > 120:
		return
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is SubViewport or (n is CanvasLayer and not (n as CanvasLayer).visible):
		return
	if n is Control:
		var c: Control = n
		if c is ScrollContainer and c.is_visible_in_tree():
			var sr: Rect2 = c.get_global_rect()
			out.append("UI %s|scroll:%d|%d|%d|%d|%d|filter%d" % [c.name, (c as ScrollContainer).scroll_vertical, int(sr.get_center().x), int(sr.get_center().y), int(sr.size.x), int(sr.size.y), c.mouse_filter])
		var tappable: bool = c is BaseButton or c.has_signal("pressed")
		if tappable and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect()
			var label: String = str(c.get("text")) if c.get("text") != null else ""
			if c.get("instance_id") != null:
				label = "card:%d" % int(c.get("instance_id"))
			elif c.get("unit_id") != null:
				label = "unit:%d" % int(c.get("unit_id"))
			var dis: String = "|disabled" if c is BaseButton and (c as BaseButton).disabled else ""
			out.append("UI %s|%s|%d|%d|%d|%d%s" % [c.name, label.replace("|", "/").replace("\n", " "), int(r.get_center().x), int(r.get_center().y), int(r.size.x), int(r.size.y), dis])
	for ch in n.get_children():
		_collect_targets(ch, out)


## Focus ring only for keyboard / pad users: shown after the first key or pad
## input, hidden again by mouse or touch.
func _input(event: InputEvent) -> void:
	var kb := false
	var pointer := false
	if event is InputEventKey or event is InputEventJoypadButton:
		kb = event.is_pressed()
	elif event is InputEventJoypadMotion:
		kb = absf((event as InputEventJoypadMotion).axis_value) > 0.5
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		pointer = event.is_pressed()
	if kb and not keyboard_nav:
		set_keyboard_nav(true)
	elif pointer and keyboard_nav:
		set_keyboard_nav(false)


func set_keyboard_nav(v: bool) -> void:
	keyboard_nav = v
	UiKit.set_focus_visible(v)
	# Cards and tiles draw their own ring: restyle the focused one.
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	var fo: Control = vp.gui_get_focus_owner() if vp else null
	if fo and fo.has_method("_on_focus_style"):
		fo.call("_on_focus_style")
	nav_mode_changed.emit(v)


func set_backgrounds_3d(v: bool) -> void:
	backgrounds_3d = v
	_commit()


func set_onboarding_done(v: bool = true) -> void:
	onboarding_done = v
	save_settings()


## Godot 4.5's default ui_accept / ui_cancel have no joypad buttons (the
## d-pad and left stick are already on ui_up/down/left/right). Adds Xbox-style
## A = accept, B and Start = cancel/back at runtime; project.godot stays as is.
static func add_pad_ui_events() -> void:
	var want := {"ui_accept": [JOY_BUTTON_A], "ui_cancel": [JOY_BUTTON_B, JOY_BUTTON_START]}
	for action: String in want.keys():
		if not InputMap.has_action(action):
			continue
		for btn: int in want[action]:
			var has := false
			for e: InputEvent in InputMap.action_get_events(action):
				if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == btn:
					has = true
			if not has:
				var ev := InputEventJoypadButton.new()
				ev.button_index = btn as JoyButton
				InputMap.action_add_event(action, ev)


## Pushes the values into the engine-side singletons (Loc, UiKit, audio buses).
func apply() -> void:
	var loc: Node = get_node_or_null("/root/Loc") if is_inside_tree() else null
	if loc != null and str(loc.get("language")) != language:
		loc.call("set_language", language)
	UiKit.font_scale = text_scale
	for k: String in VOLUME_KEYS:
		var bus: String = {"master": "Master", "music": "Music", "sfx": "SFX"}[k]
		var idx: int = AudioServer.get_bus_index(bus)
		if idx >= 0:
			var v: float = clampf(float(volumes.get(k, 1.0)), 0.0, 1.0)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(idx, v <= 0.001)


func set_language(lang: String) -> void:
	if not LANGUAGES.has(lang):
		lang = "en"
	language = lang
	_commit()


func set_text_scale(v: float) -> void:
	text_scale = clampf(v, 0.8, 1.5)
	_commit()


func set_reduced_motion(v: bool) -> void:
	reduced_motion = v
	_commit()


func set_anim_speed(v: float) -> void:
	anim_speed = clampf(v, 0.25, 4.0)
	_commit()


func set_volume(key: String, v: float) -> void:
	if not VOLUME_KEYS.has(key):
		return
	volumes[key] = clampf(v, 0.0, 1.0)
	_commit()


func volume(key: String) -> float:
	return float(volumes.get(key, 1.0))


## Seconds for a UI animation, honouring reduced motion and animation speed.
func anim_time(base: float) -> float:
	if reduced_motion:
		return 0.0
	return base / maxf(anim_speed, 0.01)


func _commit() -> void:
	apply()
	save_settings()
	changed.emit()


func load_settings() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	language = str(cfg.get_value("settings", "language", language))
	if not LANGUAGES.has(language):
		language = "en"
	text_scale = clampf(float(cfg.get_value("settings", "text_scale", text_scale)), 0.8, 1.5)
	reduced_motion = bool(cfg.get_value("settings", "reduced_motion", reduced_motion))
	anim_speed = clampf(float(cfg.get_value("settings", "anim_speed", anim_speed)), 0.25, 4.0)
	onboarding_done = bool(cfg.get_value("settings", "onboarding_done", onboarding_done))
	backgrounds_3d = bool(cfg.get_value("settings", "backgrounds_3d", backgrounds_3d))
	for k: String in VOLUME_KEYS:
		volumes[k] = clampf(float(cfg.get_value("volume", k, volumes[k])), 0.0, 1.0)
	return true


func save_settings() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("settings", "language", language)
	cfg.set_value("settings", "text_scale", text_scale)
	cfg.set_value("settings", "reduced_motion", reduced_motion)
	cfg.set_value("settings", "anim_speed", anim_speed)
	cfg.set_value("settings", "onboarding_done", onboarding_done)
	cfg.set_value("settings", "backgrounds_3d", backgrounds_3d)
	for k: String in VOLUME_KEYS:
		cfg.set_value("volume", k, volumes[k])
	return cfg.save(path) == OK


## Plain snapshot (tests, debug).
func snapshot() -> Dictionary:
	return {"language": language, "text_scale": text_scale, "reduced_motion": reduced_motion,
		"anim_speed": anim_speed, "volumes": volumes.duplicate(), "onboarding_done": onboarding_done}


func reset_defaults() -> void:
	language = "en"
	text_scale = 1.0
	reduced_motion = false
	anim_speed = 1.0
	volumes = {"master": 0.8, "music": 0.6, "sfx": 0.9}
