extends Node
## Scene flow (bible p.27): boot -> menu -> run (route/battle/reward) -> result -> menu.
## Screens never change game state themselves; they call GameSession.
## Also keeps the logical UI size sensible on every window shape: 1920x1080
## landscape, ~430 px wide portrait (phones), so 48 px hit areas stay finger-sized.

signal layout_changed(portrait: bool)

const SCENES := {
	"menu": "res://scenes/menu/main_menu.tscn",
	"battle": "res://scenes/battle/battle.tscn",
	"run": "res://scenes/flow/run_screen.tscn",
	"result": "res://scenes/flow/result_screen.tscn",
}

var current: String = ""
var portrait: bool = false


func _ready() -> void:
	_install_symbol_font()
	get_window().size_changed.connect(_apply_scale)
	_apply_scale()


## The built-in font has no ⚔♥◆☠ glyphs and web builds have no system fonts
## to fall back on, so DejaVu Sans (free license, assets/fonts/) is added as
## fallback of the default font everywhere.
func _install_symbol_font() -> void:
	var sym: Font = load("res://assets/fonts/DejaVuSans.ttf")
	var base: Font = ThemeDB.fallback_font
	if sym == null or base == null:
		return
	var fb: Array[Font] = base.fallbacks
	if not fb.has(sym):
		fb.append(sym)
		base.fallbacks = fb


func _apply_scale() -> void:
	var w := get_window()
	var sz: Vector2i = w.size
	if sz.x <= 0 or sz.y <= 0:
		return
	var p: bool = sz.y > sz.x
	var base: Vector2i
	if p:
		base = Vector2i(430, int(430.0 * float(sz.y) / float(sz.x)))
	elif sz.x < 1280:
		base = Vector2i(1280, int(1280.0 * float(sz.y) / float(sz.x)))
	else:
		base = Vector2i(1920, 1080)
	if w.content_scale_size != base:
		w.content_scale_size = base
	if p != portrait:
		portrait = p
		layout_changed.emit(p)


func goto(scene_id: String) -> void:
	if not SCENES.has(scene_id):
		push_error("AppFlow: unknown scene %s" % scene_id)
		return
	current = scene_id
	get_tree().call_deferred("change_scene_to_file", SCENES[scene_id])


## Opens the screen that matches the run's phase.
func goto_phase() -> void:
	goto(GameSession.scene_for_phase())


var _debug_input: bool = OS.get_cmdline_user_args().has("--debug-input")


func _input(event: InputEvent) -> void:
	if _debug_input and (event is InputEventScreenTouch or event is InputEventMouseButton):
		print("INPUT ", event.as_text(), " pos ", event.get("position"))
