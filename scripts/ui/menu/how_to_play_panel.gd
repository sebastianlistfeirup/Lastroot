class_name HowToPlayPanel
extends MetaModal
## "How to play": seven short illustrated pages (from the main menu and the
## pause menu). Back / Next buttons and page dots; no swipe or hover needed.

var page: int = 0


func _init() -> void:
	super()
	max_size = Vector2(900, 780)
	accent = UiKit.LIFE


func open() -> void:
	title_text = Loc.t("How to play")
	super()


static func pages() -> Array:
	var b: Dictionary = Catalog.boss()
	return [
		{"art": "floors", "title": Loc.t("Three floors and the front"),
			"text": Loc.t("The tree has three floors: the Roots, the Trunk and the Crown. Your creatures stand left of the trunk, the ash on the right. Position 1, next to the trunk, is the front: it attacks first and is hit first. Floors fight from the Roots upward.")},
		{"art": "sap", "title": Loc.t("Sap and space"),
			"text": Loc.t("You get 3 Sap at the start of every turn; unused Sap is lost. Cards cost Sap. Each floor has 5 space: a creature takes its space value, your champion takes 2 and costs 0. Moving a creature one floor costs 1 Sap, once per turn.")},
		{"art": "target", "title": Loc.t("Card, target, confirm"),
			"text": Loc.t("Tap a card, then a highlighted target or a + spot on a floor, then Confirm. An invalid target spends nothing. Cancel or tap elsewhere to change your mind.")},
		{"art": "forecast", "title": Loc.t("The forecast"),
			"text": Loc.t("The forecast panel shows exactly what ending the turn will do: deaths, climbs and Heart damage. It runs the same rules as the battle, so you can plan without surprises.")},
		{"art": "climb", "title": Loc.t("Climbing ash and the Heart"),
			"text": Loc.t("New waves arrive on the Roots. After all floors fight, every surviving enemy climbs one floor. Enemies that climb past the Crown strike the Heart for their attack. At 0 Heart the run is lost.")},
		{"art": "status", "title": Loc.t("Statuses"),
			"text": "%s\n%s\n%s\n%s" % [
				Loc.t("◆ Armor: absorbs normal damage first. Poison ignores it."),
				Loc.t("☠ Poison: deals its value at the floor's poison phase, then drops by 1."),
				Loc.t("✶ Thorns: deals its value back to every direct attacker."),
				Loc.t("✚ Growth: heals its value at the end of the floor.")]},
		{"art": "boss", "title": Loc.field(b, "name"),
			"text": Loc.t("The sixth battle. After four waves the Ash Crown arrives on the Roots on turn %d. It stays on a floor while a living ally stands there; otherwise it climbs. If it leaves the Crown, the run is lost. From turn %d it gains +2 attack every turn.") % [int(b["arrival_turn"]), int(b["escalate_from_turn"])]},
	]


func _build() -> void:
	var all: Array = pages()
	page = clampi(page, 0, all.size() - 1)
	var p: Dictionary = all[page]
	var art := HowToArt.new()
	art.name = "Art"
	art.kind = p["art"]
	art.custom_minimum_size = Vector2(0, 240 if is_portrait() else 320)
	body.add_child(art)
	var t := UiKit.heading(p["title"], 26)
	t.name = "PageTitle"
	body.add_child(t)
	var l := UiKit.label(p["text"], 19, UiKit.TEXT)
	l.name = "PageText"
	body.add_child(l)
	var dots := UiKit.label("", 16, UiKit.TEXT_DIM)
	var marks: PackedStringArray = []
	for i in all.size():
		marks.append("●" if i == page else "○")
	dots.text = "%s   %d / %d" % [" ".join(marks), page + 1, all.size()]
	dots.autowrap_mode = TextServer.AUTOWRAP_OFF
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(dots)
	var prev := UiKit.button(Loc.t("Back"), UiKit.ASH)
	prev.name = "PrevPage"
	prev.disabled = page == 0
	prev.pressed.connect(func() -> void: goto_page(page - 1))
	footer.add_child(prev)
	var last: bool = page == all.size() - 1
	var nxt := UiKit.button(Loc.t("Done") if last else Loc.t("Next"), UiKit.LIFE)
	nxt.name = "NextPage"
	nxt.pressed.connect(func() -> void:
		if last:
			close()
		else:
			goto_page(page + 1))
	footer.add_child(nxt)


func goto_page(i: int) -> void:
	AudioService.play("ui_click")
	page = clampi(i, 0, pages().size() - 1)
	rebuild()


func page_count() -> int:
	return pages().size()
