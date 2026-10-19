class_name MainMenu
extends Control
## Title screen and champion select. Never changes game state itself: it asks
## GameSession to start or continue a run, then AppFlow opens the right scene.

const FACTION_PITCH := {
	"BARK": "Armor, Thorns and sturdy bodies. The Barkwarden holds a floor like a wall and makes every blow cost the ash.",
	"SPORE": "Poison, Growth and healing. The Spore Sage weakens the ash before it climbs and keeps the grove alive.",
}
const FACTION_NAME := {"BARK": "Bark faction", "SPORE": "Spore faction"}

## View the next menu instance opens with (the result screen's "New run" sets "faction").
static var start_view: String = "title"

var view: String = "title"  # title | first_run | faction
## Tests set this false and read `pending_scene` instead of changing scenes.
var auto_navigate: bool = true
var pending_scene: String = ""

var _backdrop: MenuBackdrop
var _content: Control
var _settings: SettingsPanel
var _credits: CreditsPanel
var _howto: HowToPlayPanel
var _dialog: MessageDialog
var _last_portrait: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	view = start_view
	start_view = "title"
	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_settings = SettingsPanel.new()
	_settings.name = "SettingsPanel"
	add_child(_settings)
	_credits = CreditsPanel.new()
	_credits.name = "CreditsPanel"
	add_child(_credits)
	_howto = HowToPlayPanel.new()
	_howto.name = "HowToPlayPanel"
	add_child(_howto)
	_dialog = MessageDialog.new()
	_dialog.name = "MessageDialog"
	add_child(_dialog)
	SettingsService.changed.connect(_build)
	get_viewport().size_changed.connect(_on_resize)
	AudioService.play_music("music_menu")
	_build()


func _on_resize() -> void:
	if is_portrait() != _last_portrait:
		_build()


func is_portrait() -> bool:
	return UiKit.is_portrait(get_viewport().get_visible_rect().size)


func _build() -> void:
	_last_portrait = is_portrait()
	UiKit.clear(_content)
	_backdrop.tree_x = 0.5 if _last_portrait else 0.7
	_backdrop.tree_alpha = 0.35 if (_last_portrait or view == "faction") else 1.0
	_backdrop.tree_scale = 0.62 if _last_portrait else 0.86
	if view == "faction":
		_build_faction()
	elif view == "first_run":
		_build_first_run()
	else:
		_build_title()


# -------------------------------------------------------------- title view

func _build_title() -> void:
	var portrait: bool = _last_portrait
	var m := UiKit.margin(16 if portrait else 96)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(m)
	var col := UiKit.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	if portrait:
		m.add_child(col)
	else:
		var row := UiKit.hbox(0)
		m.add_child(row)
		col.custom_minimum_size = Vector2(700, 0)
		row.add_child(col)
	var title := UiKit.label("LASTROOT", 64 if portrait else 128, UiKit.TEXT, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_theme_color_override("font_shadow_color", Color(UiKit.LIFE, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 10)
	title.name = "Title"
	if portrait:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var tag := UiKit.label(Loc.t("Defend the last world tree. Build a deck that can take root."), 22 if portrait else 28, UiKit.TEXT_DIM)
	tag.name = "Tagline"
	if portrait:
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24 if portrait else 40)
	col.add_child(gap)
	var buttons := UiKit.vbox(12)
	buttons.custom_minimum_size = Vector2(0 if portrait else 440, 0)
	if not portrait:
		buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(buttons)
	if SaveService.has_save():
		var summary: String = _save_summary()
		var cont := _menu_button(Loc.t("Continue"), UiKit.LIFE, "ContinueButton", _on_continue)
		buttons.add_child(cont)
		if summary != "":
			var s := UiKit.label(summary, 16, UiKit.TEXT_DIM)
			s.name = "ContinueSummary"
			buttons.add_child(s)
	buttons.add_child(_menu_button(Loc.t("New Run"), UiKit.AMBER, "NewRunButton", _on_new_run))
	buttons.add_child(_menu_button(Loc.t("How to play"), UiKit.LIFE.darkened(0.2), "HowToButton", func() -> void: _howto.open()))
	buttons.add_child(_menu_button(Loc.t("Settings"), UiKit.ASH, "SettingsButton", _on_settings))
	buttons.add_child(_menu_button(Loc.t("Credits"), UiKit.ASH, "CreditsButton", _on_credits))
	if show_quit():
		buttons.add_child(_menu_button(Loc.t("Quit"), UiKit.ASH, "QuitButton", _on_quit))
	var foot := UiKit.label("v%s · %s" % [ProjectSettings.get_setting("application/config/version", "0"),
		Loc.t("Work in progress: placeholder art and sound")], 14, Color(UiKit.TEXT_DIM, 0.7))
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 16
	foot.offset_top = -34
	foot.offset_bottom = -8
	foot.autowrap_mode = TextServer.AUTOWRAP_OFF
	_content.add_child(foot)
	var first: Button = buttons.get_child(0) as Button
	if first:
		first.grab_focus.call_deferred()


static func show_quit() -> bool:
	return not (OS.has_feature("web") or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"))


func _menu_button(text: String, accent: Color, node_name: String, cb: Callable) -> Button:
	var b := UiKit.button(text, accent, 26)
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		AudioService.play("ui_click")
		cb.call())
	return b


func _save_summary() -> String:
	var res: Dictionary = SaveService.load_run()
	if not res.get("ok", false):
		return Loc.t("The saved run needs attention.")
	var run: Dictionary = res["run"]
	var champ: Dictionary = Catalog.card(str(run.get("champion_id", "")))
	var where: String
	match str(run.get("phase", "")):
		"won":
			where = Loc.t("Run won")
		"lost":
			where = Loc.t("Run lost")
		"battle":
			where = Loc.t("Battle %d of 6") % (int(run.get("battle_index", 0)) + 1)
		_:
			where = Loc.t("Before battle %d of 6") % (int(run.get("battle_index", 0)) + 2)
	return "%s · %s · %s %d/%d" % [Loc.field(champ, "name"), where, Loc.t("Heart"), int(run.get("heart", 0)), int(run.get("heart_max", 0))]


func _on_continue() -> void:
	var res: Dictionary = GameSession.continue_run()
	if res.get("ok", false):
		_goto_phase()
		return
	match str(res.get("code", "")):
		"future_version":
			_dialog.show_message(Loc.t("Newer save"),
				Loc.t("This save was made by a newer version of LASTROOT. Update the game to continue it. The file is kept untouched."),
				[[Loc.t("OK"), UiKit.ASH, func() -> void: pass]])
		"missing":
			_dialog.show_message(Loc.t("No save"), Loc.t("There is no saved run to continue."), [[Loc.t("OK"), UiKit.ASH, _build]])
		_:
			if res.get("backup_available", false):
				_dialog.show_message(Loc.t("Damaged save"),
					Loc.t("Your save is damaged. A backup from one step earlier is available. The damaged file is kept."),
					[[Loc.t("Cancel"), UiKit.ASH, func() -> void: pass], [Loc.t("Load backup"), UiKit.LIFE, _on_load_backup]])
			else:
				_dialog.show_message(Loc.t("Damaged save"),
					Loc.t("Your save is damaged and no backup could be read. The file is kept so it can be recovered. You can start a new run."),
					[[Loc.t("OK"), UiKit.ASH, func() -> void: pass]])


func _on_load_backup() -> void:
	var res: Dictionary = GameSession.continue_run(true)
	if res.get("ok", false):
		_goto_phase()
	else:
		_dialog.show_message(Loc.t("Damaged save"), Loc.t("The backup could not be read either.") + "\n" + Loc.t(str(res.get("error", ""))),
			[[Loc.t("OK"), UiKit.ASH, func() -> void: pass]])


func _on_new_run() -> void:
	if SaveService.has_save() and SaveService.load_run().get("ok", false) and not (str(SaveService.load_run()["run"].get("phase", "")) in ["won", "lost"]):
		_dialog.show_message(Loc.t("Start a new run?"), Loc.t("Your current run will end. This cannot be undone."),
			[[Loc.t("Cancel"), UiKit.ASH, func() -> void: pass], [Loc.t("New Run"), UiKit.AMBER, _start_new_run_flow]])
		return
	_start_new_run_flow()


## First run ever: offer the guide before champion select (asked once).
func _start_new_run_flow() -> void:
	if not SettingsService.onboarding_done:
		view = "first_run"
		_build()
		return
	show_faction_select()


func _build_first_run() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(center)
	var p := UiKit.panel(Color(UiKit.PANEL, 0.96), UiKit.LIFE.darkened(0.2))
	p.name = "FirstRunPrompt"
	center.add_child(p)
	var v := UiKit.vbox(14)
	v.custom_minimum_size = Vector2(minf(620.0, get_viewport().get_visible_rect().size.x - 48.0), 0)
	p.add_child(v)
	var art := HowToArt.new()
	art.kind = "floors"
	art.custom_minimum_size = Vector2(0, 200)
	v.add_child(art)
	v.add_child(UiKit.heading(Loc.t("New to LASTROOT?"), 30))
	v.add_child(UiKit.label(Loc.t("A short illustrated guide shows the floors, Sap, cards, the forecast and the boss. You can open it again any time from the menu."), 19, UiKit.TEXT))
	var row := UiKit.flow(12, false)
	v.add_child(row)
	var show_b := UiKit.button(Loc.t("Show me how to play"), UiKit.LIFE, 22)
	show_b.name = "ShowGuideButton"
	show_b.custom_minimum_size = Vector2(0, 60)
	show_b.pressed.connect(_on_show_guide)
	row.add_child(show_b)
	var skip := UiKit.button(Loc.t("Skip"), UiKit.ASH, 22)
	skip.name = "SkipGuideButton"
	skip.custom_minimum_size = Vector2(160, 60)
	skip.pressed.connect(_on_skip_guide)
	row.add_child(skip)
	show_b.grab_focus.call_deferred()


func _on_show_guide() -> void:
	AudioService.play("ui_confirm")
	SettingsService.set_onboarding_done(true)
	_howto.page = 0
	_howto.open()
	_howto.closed.connect(show_faction_select, CONNECT_ONE_SHOT)


func _on_skip_guide() -> void:
	AudioService.play("ui_click")
	SettingsService.set_onboarding_done(true)
	show_faction_select()


func show_faction_select() -> void:
	view = "faction"
	_build()


func show_title() -> void:
	view = "title"
	_build()


func _on_settings() -> void:
	_settings.open()


func _on_credits() -> void:
	_credits.open()


func _on_quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible or _credits.visible or _howto.visible or _dialog.visible:
		return
	if view in ["faction", "first_run"] and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioService.play("ui_cancel")
		show_title()


# ------------------------------------------------------------ faction view

func _build_faction() -> void:
	var portrait: bool = _last_portrait
	var m := UiKit.margin(16 if portrait else 48)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(m)
	var col := UiKit.vbox(16)
	m.add_child(col)
	var head: BoxContainer = UiKit.vbox(8) if portrait else UiKit.hbox(16)
	col.add_child(head)
	var back := UiKit.button(Loc.t("Back"), UiKit.ASH)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.name = "BackButton"
	back.pressed.connect(func() -> void:
		AudioService.play("ui_cancel")
		show_title())
	head.add_child(back)
	var t := UiKit.heading(Loc.t("Choose your champion"), 28 if portrait else 40)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_OFF if not portrait else TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	var scroll := UiKit.vscroll()
	col.add_child(scroll)
	var holder: BoxContainer = UiKit.vbox(16) if portrait else UiKit.hbox(32)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	for f: String in ["BARK", "SPORE"]:
		holder.add_child(_faction_panel(f, portrait))
	var first: Button = holder.find_child("Choose_BARK", true, false) as Button
	(first if first else back).grab_focus.call_deferred()


func _faction_panel(faction: String, portrait: bool) -> Control:
	var fc: Color = UiKit.faction_color(faction)
	var p := UiKit.panel(UiKit.PANEL.lerp(fc, 0.06), fc.darkened(0.2))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.name = "Faction_" + faction
	var v := UiKit.vbox(14)
	p.add_child(v)
	var champ_id: String = Catalog.champion_for(faction)
	var champ: Dictionary = Catalog.card(champ_id)
	var top: BoxContainer = UiKit.vbox(10) if portrait else UiKit.hbox(20)
	v.add_child(top)
	var pic := FactionPortrait.new()
	pic.faction = faction
	pic.custom_minimum_size = Vector2(0, 190) if portrait else Vector2(300, 320)
	top.add_child(pic)
	var info := UiKit.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(UiKit.label(Loc.t(FACTION_NAME[faction]).to_upper(), 16, fc, true))
	info.add_child(UiKit.heading(Loc.field(champ, "name"), 30 if portrait else 38))
	info.add_child(UiKit.label(Loc.t(FACTION_PITCH[faction]), 18, UiKit.TEXT))
	var paths := UiKit.vbox(4)
	paths.add_child(UiKit.label(Loc.t("Champion paths (chosen after battle 2):"), 15, UiKit.TEXT_DIM))
	for path: Dictionary in Catalog.champion_paths(champ_id):
		paths.add_child(UiKit.label("• %s — %s" % [Loc.field(path, "name"), Loc.field(path, "text")], 15, UiKit.TEXT_DIM))
	info.add_child(paths)
	var mid: BoxContainer = UiKit.vbox(12) if portrait else UiKit.hbox(16)
	v.add_child(mid)
	var cv := CardView.new().setup(champ_id)
	cv.name = "ChampionCard"
	cv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_FILL
	mid.add_child(cv)
	var deck := UiKit.vbox(2)
	deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck.add_child(UiKit.label(Loc.t("Starting deck (12 cards)"), 17, UiKit.TEXT, true))
	deck.add_child(_deck_row(1, champ))
	var counts: Dictionary = Catalog.data()["start_deck"]["normal_counts"]
	var ids: Array = counts.keys()
	ids.sort()
	for cid: String in ids:
		deck.add_child(_deck_row(int(counts[cid]), Catalog.card(cid)))
	mid.add_child(deck)
	var choose := UiKit.button(Loc.t("Defend the tree as %s") % Loc.field(champ, "name"), fc, 22)
	choose.name = "Choose_" + faction
	choose.custom_minimum_size = Vector2(0, 64)
	choose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choose.pressed.connect(func() -> void: choose_faction(faction))
	v.add_child(choose)
	return p


func _deck_row(count: int, def: Dictionary) -> Control:
	var row := UiKit.hbox(6)
	var n := UiKit.label("%d×" % count, 15, UiKit.AMBER, true)
	n.custom_minimum_size = Vector2(UiKit.px(30), 0)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(n)
	var dot := ColorRect.new()
	dot.color = UiKit.faction_color(str(def.get("faction", "BARK")))
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var kind: String = Loc.t("Champion") if def["kind"] == "champion" else (Loc.t("Creature") if def["kind"] == "unit" else Loc.t("Spell"))
	var l := UiKit.label("%s  ·  %s  ·  %d %s" % [Loc.field(def, "name"), kind, int(def["cost"]), Loc.t("Sap")], 15, UiKit.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func choose_faction(faction: String) -> void:
	AudioService.play("ui_confirm")
	GameSession.new_run(faction)
	_goto_phase()


func _goto_phase() -> void:
	pending_scene = GameSession.scene_for_phase()
	if auto_navigate:
		AppFlow.goto_phase()
