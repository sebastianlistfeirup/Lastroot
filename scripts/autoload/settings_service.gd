extends Node
## Player settings (bible p.16: text size, reduced motion, language).
## Persisted to user://settings.cfg. Screens listen to `changed` and rebuild.

signal changed

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()


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
	for k: String in VOLUME_KEYS:
		cfg.set_value("volume", k, volumes[k])
	return cfg.save(path) == OK


## Plain snapshot (tests, debug).
func snapshot() -> Dictionary:
	return {"language": language, "text_scale": text_scale, "reduced_motion": reduced_motion,
		"anim_speed": anim_speed, "volumes": volumes.duplicate()}


func reset_defaults() -> void:
	language = "en"
	text_scale = 1.0
	reduced_motion = false
	anim_speed = 1.0
	volumes = {"master": 0.8, "music": 0.6, "sfx": 0.9}
