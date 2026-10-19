class_name VisualPalette
extends RefCounted
## Shared material palette for every procedural proxy (bible: bark/amber,
## mushrooms/violet, turquoise life, dark ash enemies with ember glow).
## Colours live in data/art/palette.json so the owner can tune them without
## code; the defaults below are used when the file is missing.
## Materials are cached and shared: never mutate a returned material. For a
## per-unit effect (hit flash) use GeometryInstance3D.material_overlay.

const PATH := "res://data/art/palette.json"

const DEFAULTS := {
	"bark": "#6b4a2f", "bark_dark": "#3f2a1b", "bark_light": "#8f6a43", "wood_plank": "#7a5634",
	"moss": "#5f7f2e", "moss_light": "#8aa63c", "leaf": "#3f7a3a", "leaf_light": "#6fa64a",
	"stone": "#625d58", "stone_dark": "#403c39", "stone_warm": "#6f6253",
	"amber": "#ffb238", "amber_soft": "#e88a1f",
	"cap_violet": "#7a4cd6", "cap_violet_dark": "#5b2f94", "cap_white": "#ece4f5", "cap_pale": "#ddd0ee", "cap_gill": "#c9b6e6",
	"spore_body": "#4a2f6e", "spore_skin": "#2a1d3d", "beard": "#e8e2ee",
	"turquoise": "#3ff2d6", "turquoise_soft": "#22b8a6",
	"ash_black": "#1b1a1d", "ash_grey": "#4a464a", "ash_light": "#77706c", "charcoal": "#2b2624",
	"ember": "#ff7a1f", "ember_hot": "#ffd060", "ember_red": "#e8401c",
	"blossom": "#f3c6de", "blossom_gold": "#ffd98a",
	"poison": "#9be04e", "poison_violet": "#b26cf0", "heal": "#7dffb0", "armor": "#c9d4dd", "thorns": "#8fbf3a",
	"haze": "#5a3f8c", "haze_dark": "#24193d", "island": "#2c2635", "island_top": "#3b4a2c",
	"missing": "#ff00ff",
}
## Palette keys that are drawn as emissive light sources (energy multiplier).
const EMISSIVE := {"amber": 2.2, "amber_soft": 1.4, "turquoise": 2.6, "turquoise_soft": 1.5, "ember": 2.4, "ember_hot": 3.0,
	"ember_red": 1.8, "poison": 1.6, "poison_violet": 1.6, "heal": 2.0, "blossom_gold": 1.2, "cap_gill": 0.35}

static var _colors: Dictionary = {}
static var _cache: Dictionary = {}


static func color(key: String) -> Color:
	if _colors.is_empty():
		_colors = DEFAULTS.duplicate()
		if FileAccess.file_exists(PATH):
			var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if v is Dictionary and (v as Dictionary).get("colors") is Dictionary:
				var c: Dictionary = (v as Dictionary)["colors"]
				for k: Variant in c.keys():
					_colors[str(k)] = str(c[k])
	if key.begins_with("#"):
		return Color.from_string(key, Color.MAGENTA)
	return Color.from_string(str(_colors.get(key, DEFAULTS["missing"])), Color.MAGENTA)


## Lit, rough, flat material for a palette key (or "#rrggbb").
## Emissive keys (amber, turquoise, ember...) glow automatically.
static func mat(key: String, emissive: float = -1.0, alpha: float = 1.0) -> StandardMaterial3D:
	var energy: float = emissive if emissive >= 0.0 else float(EMISSIVE.get(key, 0.0))
	var ck := "%s|%.2f|%.2f" % [key, energy, alpha]
	if _cache.has(ck):
		return _cache[ck]
	var c := color(key)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 0.9
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED if energy <= 0.0 else BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.resource_name = "lr_" + key
	_cache[ck] = m
	return m


## Unshaded glowing material (eyes, crystals, particles). Reads well in any light.
static func glow(key: String, alpha: float = 1.0, additive: bool = false) -> StandardMaterial3D:
	var ck := "glow|%s|%.2f|%s" % [key, alpha, additive]
	if _cache.has(ck):
		return _cache[ck]
	var c := color(key)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0 or additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.resource_name = "lr_glow_" + key
	_cache[ck] = m
	return m


## Particle material: unshaded billboard, vertex colour (for colour ramps).
static func particle(key: String, additive: bool = true) -> StandardMaterial3D:
	var ck := "particle|%s|%s" % [key, additive]
	if _cache.has(ck):
		return _cache[ck]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color(key)
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[ck] = m
	return m


static func reload() -> void:
	_colors.clear()
	_cache.clear()
