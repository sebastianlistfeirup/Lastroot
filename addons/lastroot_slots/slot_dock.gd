@tool
extends VBoxContainer
## Asset-slots dock: every LASTROOT visual slot with its state (proxy/model), the
## vendor search hints, the matcher's choice, and buttons to map an imported model.
## Mapping = SlotWrapperBuilder.build_one (same rules as tools/synty/build.sh):
## fit by slot kind, pivot to feet, facing -Z, atlas via import settings, wrapper in
## art/prefabs/, mapping + measured height in data/art/slot_scenes.json.
## Dev tool: Danish text, not localized.

const SUGGESTIONS := "res://data/art/vendor_suggestions.json"
const CHOICES := "res://data/art/synty_choices.json"
const CATEGORIES := ["alle", "unit", "enemy", "stage", "prop", "mutation", "fx"]

var _tree: Tree
var _filter: LineEdit
var _category: OptionButton
var _only_proxy: CheckBox
var _count: Label
var _detail: RichTextLabel
var _rot: SpinBox
var _alts: HBoxContainer
var _status: Label
var _selected: String = ""
var _sugg: Dictionary = {}
var _choices: Dictionary = {}
var _builder := SlotWrapperBuilder.new()


func _ready() -> void:
	custom_minimum_size = Vector2(320, 420)
	var top := HBoxContainer.new()
	_count = Label.new()
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	top.add_child(_btn("↻", "Genindlæs slots, forslag og valg", refresh))
	add_child(top)
	var row := HBoxContainer.new()
	_filter = LineEdit.new()
	_filter.placeholder_text = "Søg slot…"
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.text_changed.connect(func(_t: String) -> void: _fill())
	row.add_child(_filter)
	_category = OptionButton.new()
	for c: String in CATEGORIES:
		_category.add_item(c)
	_category.item_selected.connect(func(_i: int) -> void: _fill())
	row.add_child(_category)
	add_child(row)
	_only_proxy = CheckBox.new()
	_only_proxy.text = "Kun slots, der stadig er proxy"
	_only_proxy.toggled.connect(func(_on: bool) -> void: _fill())
	add_child(_only_proxy)
	_tree = Tree.new()
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "Slot")
	_tree.set_column_title(1, "")
	_tree.set_column_title(2, "Model / forslag")
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(0, 150)
	_tree.set_column_custom_minimum_width(1, 24)
	_tree.set_column_clip_content(2, true)
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(0, 220)
	_tree.item_selected.connect(_on_select)
	add_child(_tree)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.custom_minimum_size = Vector2(0, 110)
	add_child(_detail)
	_alts = HBoxContainer.new()
	add_child(_alts)
	var rot_row := HBoxContainer.new()
	var rl := Label.new()
	rl.text = "Drej model (°):"
	rot_row.add_child(rl)
	_rot = SpinBox.new()
	_rot.min_value = -180
	_rot.max_value = 180
	_rot.step = 90
	rot_row.add_child(_rot)
	add_child(rot_row)
	var b1 := HBoxContainer.new()
	b1.add_child(_btn("Brug valgt fil", "Map modellen markeret i FileSystem (.fbx/.glb/.gltf/.tscn) til slottet", _use_selected_file))
	b1.add_child(_btn("Brug valg", "Byg slottet fra data/art/synty_choices.json", _use_choice))
	add_child(b1)
	var b2 := HBoxContainer.new()
	b2.add_child(_btn("Åbn wrapper", "Åbn wrapper-scenen", _open_wrapper))
	b2.add_child(_btn("Fjern", "Fjern mappingen; slottet viser proxyen igen", _unmap))
	add_child(b2)
	var b3 := HBoxContainer.new()
	b3.add_child(_btn("RigLab", "Åbn figur-testscenen", func() -> void: EditorInterface.open_scene_from_path("res://scenes/tests/rig_lab.tscn")))
	b3.add_child(_btn("Style gate", "Åbn line-up'en af alle figurer", func() -> void: EditorInterface.open_scene_from_path("res://scenes/tests/asset_gallery.tscn")))
	add_child(b3)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	refresh()


func _btn(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(cb)
	return b


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func refresh() -> void:
	VisualSlots.reload()
	_sugg = _json(SUGGESTIONS).get("slots", {}) as Dictionary
	_choices = _json(CHOICES).get("choices", {}) as Dictionary
	_fill()
	if not _selected.is_empty():
		_show(_selected)


func _fill() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var cat: String = CATEGORIES[_category.selected]
	var total := 0
	var done := 0
	for id: String in VisualSlots.slot_ids():
		var has := VisualSlots.has_real_asset(id)
		total += 1
		done += 1 if has else 0
		if cat != "alle" and not id.begins_with(cat + "."):
			continue
		if _only_proxy.button_pressed and has:
			continue
		if not _filter.text.is_empty() and not _filter.text.to_lower() in id.to_lower() and not _filter.text.to_lower() in str(VisualSlots.slot(id).get("name", "")).to_lower():
			continue
		var it := _tree.create_item(root)
		it.set_text(0, id)
		it.set_tooltip_text(0, str(VisualSlots.slot(id).get("name", "")))
		it.set_metadata(0, id)
		it.set_text(1, "●" if has else "○")
		it.set_custom_color(1, Color("3ff2d6") if has else Color("8f8aa3"))
		var c: Dictionary = _choices.get(id, {})
		var src := VisualSlots.scene_path(id) if has else str(c.get("source", ""))
		it.set_text(2, src.get_file() if not src.is_empty() else "—")
		if not has and str(c.get("status", "")) == "weak":
			it.set_custom_color(2, Color("ffb238"))
		if id == _selected:
			it.select(0)
	_count.text = "%d / %d slots har en model" % [done, total]


func select(id: String) -> void:
	_selected = id
	_fill()
	_show(id)


func _on_select() -> void:
	var it := _tree.get_selected()
	if it:
		_show(str(it.get_metadata(0)))


func _show(id: String) -> void:
	_selected = id
	var s := VisualSlots.slot(id)
	var v: Dictionary = _sugg.get(id, {})
	var c: Dictionary = _choices.get(id, {})
	var has := VisualSlots.has_real_asset(id)
	var lines: Array = ["[b]%s[/b] · %s  %s" % [id, str(s.get("name", "")), "[color=#3ff2d6]model[/color]" if has else "[color=#8f8aa3]proxy[/color]"]]
	lines.append("Højde %.2f m · badge %.2f m · rig %s · fit %s" % [float(s.get("height", 0.0)), VisualSlots.head_height(id), str(s.get("rig_family", "—")), str(c.get("fit", SlotWrapperBuilder.fit_mode(id)))])
	if has:
		lines.append("Wrapper: " + VisualSlots.scene_path(id))
	if not v.is_empty():
		lines.append("Pakker: " + ", ".join(v.get("packs", []) as Array))
		lines.append("Søg: " + ", ".join(v.get("search", []) as Array))
		if not (v.get("attachments", []) as Array).is_empty():
			lines.append("Attachments: " + ", ".join(v.get("attachments", []) as Array))
		lines.append("[i]%s[/i] [color=#ffb238](%s)[/color]" % [str(v.get("notes", "")), str(v.get("status", ""))])
	if not c.is_empty():
		lines.append("Valg: %s (%s)" % [str(c.get("source", "—")), str(c.get("status", ""))])
	_detail.text = "\n".join(lines)
	_rot.value = float(c.get("rotation_y", 180.0 if str(s.get("kind", "")) in ["unit", "enemy"] else 0.0))
	for ch: Node in _alts.get_children():
		ch.queue_free()
	for alt: Variant in (c.get("alternatives", []) as Array).slice(0, 3):
		var a := str(alt)
		_alts.add_child(_btn(a.get_file().get_basename(), "Byg slottet med " + a, func() -> void: _build(a)))


func _use_selected_file() -> void:
	var paths := EditorInterface.get_selected_paths()
	if _selected.is_empty() or paths.is_empty():
		_status.text = "Vælg et slot i listen og en model i FileSystem-panelet."
		return
	_build(paths[0])


func _use_choice() -> void:
	var c: Dictionary = _choices.get(_selected, {})
	if str(c.get("source", "")).is_empty():
		_status.text = "Intet valg for %s (kør python3 tools/synty/match.py)." % _selected
		return
	_build(str(c["source"]))


func _libs() -> Dictionary:
	var p := AnimationLibraryBuilder.LIB_DIR.path_join("humanoid.res")
	return {"humanoid": p} if ResourceLoader.exists(p) else {}


func _build(source: String) -> void:
	if _selected.is_empty():
		return
	var c: Dictionary = (_choices.get(_selected, {}) as Dictionary).duplicate()
	c["source"] = source
	c["rotation_y"] = _rot.value
	var r := _builder.build_one(_selected, c, SlotWrapperBuilder.PREFABS, _libs())
	if r.get("reimport", false):
		var src := source if source.begins_with("res://") else "res://assets/imported/" + source
		EditorInterface.get_resource_filesystem().reimport_files(PackedStringArray([src]))
		r = _builder.build_one(_selected, c, SlotWrapperBuilder.PREFABS, _libs())
	if not r["ok"]:
		_status.text = "✕ " + str(r.get("error", ""))
		return
	var doc := _json(VisualSlots.BUILT_PATH)
	var scenes: Dictionary = doc.get("scenes", {})
	var heights: Dictionary = doc.get("heights", {})
	scenes[_selected] = r["scene"]
	heights[_selected] = r["height_m"]
	_save_mapping(scenes, heights)
	EditorInterface.get_resource_filesystem().scan()
	_status.text = "✓ " + str(r.get("summary", ""))
	refresh()


func _save_mapping(scenes: Dictionary, heights: Dictionary) -> void:
	var f := FileAccess.open(VisualSlots.BUILT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"_note": "Written by the LASTROOT asset builder/dock: slot -> wrapper scene and measured height. A non-empty \"scene\" in asset_slots.json wins.",
		"scenes": scenes, "heights": heights}, " ", true) + "\n")
	f.close()


func _open_wrapper() -> void:
	if VisualSlots.has_real_asset(_selected):
		EditorInterface.open_scene_from_path(VisualSlots.scene_path(_selected))


func _unmap() -> void:
	var doc := _json(VisualSlots.BUILT_PATH)
	var scenes: Dictionary = doc.get("scenes", {})
	var heights: Dictionary = doc.get("heights", {})
	if scenes.erase(_selected):
		heights.erase(_selected)
		_save_mapping(scenes, heights)
		_status.text = "%s viser proxyen igen (wrapper-filen er beholdt)." % _selected
		refresh()
	elif VisualSlots.has_real_asset(_selected):
		_status.text = "%s er mappet i asset_slots.json; ret \"scene\" dér." % _selected
