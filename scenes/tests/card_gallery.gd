extends Node
## Card gallery capture (LR-24): every card of the catalog, every legal
## upgrade variant and the champions at path rank 2, as real CardViews.
##   xvfb-run -a godot --path . --rendering-method gl_compatibility res://scenes/tests/card_gallery.tscn
## Writes evidence/meta_screens/cards_desktop.png (normal), cards_compact.png
## (portrait hand size, 430 wide), cards_text130.png (UiKit.font_scale 1.3),
## cards_da.png (Danish) and cards_badges.png (UnitBadge samples). Also
## checks that no card's text overflows its frame (prints CARD_GALLERY).

const OUT := "res://evidence/meta_screens/"

var problems: PackedStringArray = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _shot("cards_desktop", Vector2i(1920, 1500), false, 1.0, "en")
	await _shot("cards_compact", Vector2i(430, 4300), true, 1.0, "en")
	await _shot("cards_text130", Vector2i(1920, 2000), false, 1.3, "en")
	await _shot("cards_da", Vector2i(1920, 1500), false, 1.0, "da")
	await _badges()
	print("CARD_GALLERY %d problems" % problems.size())
	for p in problems:
		print("  ", p)
	get_tree().quit(0 if problems.is_empty() else 1)


static func variants() -> Array:
	var out: Array = []
	for c: Dictionary in Catalog.cards():
		out.append([c["id"], "", "", 0])
		if c["kind"] == "champion":
			for p: Dictionary in Catalog.champion_paths(c["id"]):
				out.append([c["id"], "", p["id"], 2])
		for u: Dictionary in CardStats.legal_upgrades(c, ""):
			out.append([c["id"], u["id"], "", 0])
	return out


func _shot(file: String, size: Vector2i, compact: bool, scale: float, lang: String) -> void:
	Loc.set_language(lang)
	UiKit.font_scale = scale
	var sv := SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.size = Vector2(size)
	sv.add_child(bg)
	var m := MarginContainer.new()
	m.position = Vector2(12, 12)
	m.custom_minimum_size = Vector2(size.x - 24, 0)
	sv.add_child(m)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	m.add_child(flow)
	var cards: Array = []
	for v: Array in variants():
		var cv := CardView.new().setup(v[0], v[1], v[2], v[3])
		if compact:
			cv.set_compact(true)
		if v[0] == "B03":
			cv.selected = true
		if v[0] == "S11" and v[1] == "":
			cv.playable = false
		flow.add_child(cv)
		cards.append(cv)
	# Wait for the lazily rendered portraits (one off-screen render each).
	for i in 400:
		await get_tree().process_frame
		if i > 20 and _portraits_done():
			break
	await get_tree().process_frame
	_check_fit(file, cards)
	sv.get_texture().get_image().save_png(OUT + file + ".png")
	sv.queue_free()
	Loc.set_language("en")
	UiKit.font_scale = 1.0
	await get_tree().process_frame


func _portraits_done() -> bool:
	for c: Dictionary in Catalog.cards():
		if Catalog.is_creature(c) and not CardPortraits.is_cached("unit." + str(c["id"])):
			return false
	return true


## A card is fine when its content fits inside its own rect.
func _check_fit(file: String, cards: Array) -> void:
	for cv: CardView in cards:
		var inner: Control = cv.get_child(0) as Control
		var need: Vector2 = inner.get_combined_minimum_size()
		var have: Vector2 = cv.size
		if need.x > have.x + 0.5 or need.y > have.y + 0.5:
			problems.append("%s: %s%s content %s > card %s" % [file, cv.def_id, ("/" + cv.upgrade_id) if cv.upgrade_id != "" else "", need, have])
		var std: Vector2 = cv.custom_minimum_size
		if cv.size.y > std.y + 0.5 and UiKit.font_scale <= 1.0:
			problems.append("%s: %s grows taller than the standard card (%d > %d)" % [file, cv.def_id, int(cv.size.y), int(std.y)])


func _badges() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(900, 260)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var bg := ColorRect.new()
	bg.color = Color("1a1f30")
	bg.size = Vector2(sv.size)
	sv.add_child(bg)
	var row := HFlowContainer.new()
	row.position = Vector2(16, 16)
	row.custom_minimum_size = Vector2(868, 0)
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 14)
	sv.add_child(row)
	var samples := [
		[{"unit_id": 1, "side": "ally", "hp": 20, "max_hp": 20, "armor": 8, "is_champion": true}, 4, "", false, ""],
		[{"unit_id": 2, "side": "ally", "hp": 3, "max_hp": 6, "poison": 0, "growth": 2}, 1, "♥ 3→5", false, "target"],
		[{"unit_id": 3, "side": "enemy", "hp": 9, "max_hp": 9, "armor": 4, "poison": 3}, 3, "☠ dies", true, ""],
		[{"unit_id": 4, "side": "enemy", "hp": 60, "max_hp": 60, "armor": 8, "is_boss": true}, 8, "↑ Trunk", true, "selected"],
		[{"unit_id": 5, "side": "ally", "hp": 8, "max_hp": 8, "thorns": 2}, 3, "", false, "invalid"],
	]
	for compact: bool in [false, true]:
		for s: Array in samples:
			var b := UnitBadge.new()
			row.add_child(b)
			b.set_compact(compact)
			b.show_unit(s[0], s[1])
			b.show_forecast(s[2], s[3])
			b.set_highlight(s[4])
	for i in 6:
		await get_tree().process_frame
	sv.get_texture().get_image().save_png(OUT + "cards_badges.png")
	sv.queue_free()
