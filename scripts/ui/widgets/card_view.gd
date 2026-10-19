class_name CardView
extends PanelContainer
## One card with real text (never baked into an image, bible LR-24): cost,
## space, attack/HP, rules text with the instance's actual numbers.
## Emits `pressed` on click/tap. Used by the hand, rewards, camp and deck lists.

signal pressed

const W := 168
const H := 236

var def_id: String = ""
var upgrade_id: String = ""
var path_id: String = ""
var rank: int = 0
var instance_id: int = -1
var selected: bool = false: set = set_selected
var playable: bool = true: set = set_playable
var cost_override: int = -1

var _name: Label
var _cost: Label
var _kind: Label
var _stats: Label
var _text: Label
var _upg: Label


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	_cost = UiKit.label("", 22, UiKit.LIFE, true)
	_cost.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_cost)
	_kind = UiKit.label("", 14, UiKit.TEXT_DIM)
	_kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_kind)
	_name = UiKit.label("", 19, UiKit.TEXT, true)
	v.add_child(_name)
	_stats = UiKit.label("", 18, UiKit.TEXT)
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(_stats)
	_text = UiKit.label("", 15, UiKit.TEXT_DIM)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_upg = UiKit.label("", 13, UiKit.AMBER)
	v.add_child(_upg)
	for c in [_name, _cost, _kind, _stats, _text, _upg]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Smaller text and footprint for narrow portrait hands (same information).
func set_compact(c: bool) -> CardView:
	var k: float = 0.78 if c else 1.0
	var sizes := [[_cost, 22], [_kind, 14], [_name, 19], [_stats, 18], [_text, 15], [_upg, 13]]
	for pair in sizes:
		(pair[0] as Label).add_theme_font_size_override("font_size", int(pair[1] * k * UiKit.font_scale))
	custom_minimum_size = Vector2(W * k, H * k * 0.92)
	return self


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
	var cost: int = CardStats.cost(def, upgrade_id) if cost_override < 0 else cost_override
	_cost.text = "%s %d" % [UiKit.status_glyph("sap"), cost]
	var kind_text: String = Loc.t("Champion") if def["kind"] == "champion" else (Loc.t("Creature") if def["kind"] == "unit" else Loc.t("Spell"))
	if Catalog.is_creature(def):
		kind_text += "  %s%d" % [UiKit.status_glyph("space"), def["space"]]
	_kind.text = kind_text
	_name.text = Loc.field(def, "name")
	if Catalog.is_creature(def):
		var st: Dictionary = CardStats.unit_stats(def, upgrade_id, path_id, rank)
		var line := "%s %d   %s %d" % [UiKit.status_glyph("attack"), st["attack"], UiKit.status_glyph("hp"), st["max_hp"]]
		if int(st["armor"]) > 0:
			line += "   %s %d" % [UiKit.status_glyph("armor"), st["armor"]]
		_stats.text = line
		_stats.visible = true
	else:
		_stats.visible = false
	_text.text = CardStats.format_text(Loc.field(def, "text"), def, upgrade_id, path_id, rank)
	if upgrade_id != "":
		_upg.text = Loc.t("Upgraded") + ": " + _upgrade_label(def, upgrade_id)
	elif def.get("upgrade_rule", "") == "none":
		_upg.text = Loc.t("Cannot be upgraded")
	else:
		_upg.text = ""
	_apply_style()


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
	var bg: Color = UiKit.PANEL.lerp(fc, 0.12)
	var border: Color = fc.darkened(0.25)
	if def.get("kind", "") == "champion":
		border = UiKit.AMBER
	if selected:
		border = UiKit.LIFE
		bg = bg.lightened(0.1)
	add_theme_stylebox_override("panel", UiKit.panel_style(bg, border, 12, 4 if selected else 2))
	modulate = Color(1, 1, 1, 1) if playable else Color(0.62, 0.62, 0.66, 1)


func _gui_input(event: InputEvent) -> void:
	var press := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		press = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
		# With mouse emulation on, the emulated click already arrives; don't fire twice.
		press = (event as InputEventScreenTouch).pressed
	if press:
		accept_event()
		pressed.emit()
