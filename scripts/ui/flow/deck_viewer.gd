class_name DeckViewer
extends MetaModal
## Every card instance in the run deck as a CardView with its real numbers
## (own upgrade, champion path and rank).

var run: Dictionary = {}


func _init() -> void:
	super()
	max_size = Vector2(1240, 940)
	accent = UiKit.AMBER


func show_deck(p_run: Dictionary) -> void:
	run = p_run
	var deck: Array = run.get("deck", [])
	title_text = Loc.t("Your deck (%d cards)") % deck.size()
	open()


static func sorted_deck(run: Dictionary) -> Array:
	var deck: Array = (run.get("deck", []) as Array).duplicate()
	deck.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: bool = Catalog.card(a["def_id"])["kind"] == "champion"
		var cb: bool = Catalog.card(b["def_id"])["kind"] == "champion"
		if ca != cb:
			return ca
		if a["def_id"] != b["def_id"]:
			return str(a["def_id"]) < str(b["def_id"])
		return int(a["instance_id"]) < int(b["instance_id"]))
	return deck


static func card_for(run: Dictionary, inst: Dictionary) -> CardView:
	var def: Dictionary = Catalog.card(inst["def_id"])
	var cv := CardView.new()
	if def.get("kind", "") == "champion":
		cv.setup(inst["def_id"], "", str(run.get("champion_path", "")), int(run.get("champion_rank", 0)), int(inst["instance_id"]))
	else:
		cv.setup(inst["def_id"], str(inst.get("upgrade_id", "")), "", 0, int(inst["instance_id"]))
	cv.name = "Card_%d" % int(inst["instance_id"])
	return cv


func _build() -> void:
	var rules: Dictionary = Catalog.rules()
	body.add_child(UiKit.label(Loc.t("%d normal cards and your champion. A deck keeps at least %d normal cards.") %
		[RunReducer.normal_card_count(run), int(rules["min_normal_cards"])], 16, UiKit.TEXT_DIM))
	var grid := UiKit.flow(12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for inst: Dictionary in sorted_deck(run):
		grid.add_child(card_for(run, inst))
	body.add_child(grid)
