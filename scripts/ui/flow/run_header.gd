class_name RunHeader
extends PanelContainer
## Always-visible run status: Heart, Resin, battle progress, champion path,
## relics, mutations, deck button and menu. Every item is a real button (48 px)
## that shows its explanation in the detail panel on tap: nothing needs hover.

signal detail_requested(icon: String, title: String, text: String, accent: Color)
signal deck_requested
signal menu_requested

var run: Dictionary = {}


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style(Color(UiKit.PANEL, 0.94), UiKit.LINE, 12, 2))


func build(p_run: Dictionary, portrait: bool) -> void:
	run = p_run
	UiKit.clear(self)
	var row := UiKit.flow(8, false)
	row.name = "HeaderRow"
	add_child(row)
	var rules: Dictionary = Catalog.rules()
	var heart: int = int(run.get("heart", 0))
	var heart_max: int = int(run.get("heart_max", 0))
	var heart_col: Color = UiKit.LIFE if heart * 3 > heart_max else UiKit.DANGER
	row.add_child(_item("HeartChip", "heart", "%d/%d" % [heart, heart_max], heart_col, Loc.t("Heart"),
		Loc.t("The world tree's Heart. Enemies that climb past the Crown damage it. At 0 the run is lost.") + "\n" +
		Loc.t("Current %d of %d.") % [heart, heart_max]))
	row.add_child(_item("ResinChip", "resin", str(int(run.get("resin", 0))), UiKit.AMBER, Loc.t("Resin"),
		Loc.t("Spent at camps (upgrades) and removals. Each won battle gives %d.") % int(rules["normal_win_resin"])))
	var bi: int = int(run.get("battle_index", 0))
	var phase: String = str(run.get("phase", ""))
	var next_battle: int = bi + 1
	if phase in ["reward", "route", "node"]:
		next_battle = bi + 2
	next_battle = mini(next_battle, 6)
	var bt: String = Loc.t("Battle %d/6") % next_battle
	row.add_child(_item("BattleChip", "boss" if next_battle == 6 else "battle", bt, UiKit.TEXT, Loc.t("Route progress"),
		Loc.t("Five battles and the boss, The Ash Crown, are always fought. Battles won: %d.") % int(run.get("stats", {}).get("battles_won", 0))))
	var champ: Dictionary = Catalog.card(str(run.get("champion_id", "")))
	var path: String = str(run.get("champion_path", ""))
	var ctext: String = Loc.t("Champion path: not chosen yet. You choose it after battle 2 and strengthen it after battle 4.")
	if path != "":
		var p: Dictionary = Catalog.champion_path(champ["id"], path)
		ctext = "%s — %s\n%s" % [Loc.field(p, "name"), Loc.field(p, "text"), Loc.t("Rank %d of 2.") % int(run.get("champion_rank", 0))]
	var cl: String = RunText.champion_line(run)
	if portrait and path != "":
		cl = "%s %d" % [Loc.field(Catalog.champion_path(champ["id"], path), "name"), int(run.get("champion_rank", 0))]
	row.add_child(_item("ChampionChip", "champion", cl,
		UiKit.faction_color(str(champ.get("faction", "BARK"))), Loc.field(champ, "name"), ctext))
	for rid: String in run.get("relics", []):
		var r: Dictionary = Catalog.relic(rid)
		row.add_child(_item("Relic_" + rid, "relic", "" if portrait else Loc.field(r, "name"), UiKit.ARMOR, Loc.field(r, "name"), Loc.field(r, "text")))
	for mid: String in run.get("mutations", []):
		var m: Dictionary = Catalog.mutation(mid)
		row.add_child(_item("Mutation_" + mid, "mutation", "" if portrait else Loc.field(m, "name"), UiKit.GOOD, Loc.field(m, "name"), Loc.field(m, "text")))
	var n_cards: int = (run.get("deck", []) as Array).size()
	var deck := _button("DeckButton", "deck", str(n_cards) if portrait else Loc.t("Deck (%d)") % n_cards, UiKit.TEXT)
	deck.pressed.connect(func() -> void:
		AudioService.play("ui_click")
		deck_requested.emit())
	row.add_child(deck)
	var menu := _button("MenuButton", "gear", "" if portrait else Loc.t("Menu"), UiKit.TEXT_DIM)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	row.add_child(menu)


func _item(node_name: String, icon: String, text: String, accent: Color, title: String, detail: String) -> Button:
	var b := _button(node_name, icon, text, accent)
	b.pressed.connect(func() -> void:
		AudioService.play("ui_click")
		detail_requested.emit(icon, title, detail, accent))
	return b


func _button(node_name: String, icon: String, text: String, accent: Color) -> Button:
	var b := UiKit.button("", accent.darkened(0.1), 18)
	b.name = node_name
	b.custom_minimum_size = Vector2(UiKit.MIN_HIT, UiKit.MIN_HIT)
	var h := UiKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := MetaIcon.make(icon, accent, UiKit.px(24))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	if text != "":
		var l := UiKit.label(text, 18, UiKit.TEXT, true)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
	b.add_child(h)
	b.set_meta("label_text", text)
	_fit.call_deferred(b, h)
	b.tooltip_text = ""
	return b


## Button width follows its icon + label once the theme is known.
static func _fit(b: Button, h: HBoxContainer) -> void:
	if not is_instance_valid(b) or not is_instance_valid(h):
		return
	b.custom_minimum_size = Vector2(maxf(UiKit.MIN_HIT, h.get_combined_minimum_size().x + 20.0), UiKit.MIN_HIT)
