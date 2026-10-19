class_name ResultScreen
extends Control
## REF_10 run ending: headline, the run's tree (mutations, champion path,
## relics) and the real statistics from run["stats"]. No invented rewards.
## "New run" goes to champion select; "Main menu" to the title. Neither
## starts a run by itself, so a run can never be started twice from here.

var auto_navigate: bool = true
var pending_scene: String = ""
var run: Dictionary = {}

var _backdrop: MenuBackdrop
var _content: Control
var _played_sting: bool = false
var _logged: bool = false
# After-run feedback (kept across re-renders; saved only on "Save feedback").
var fb_stars: int = 0
var fb_forecast: String = ""
var fb_text: String = ""
var fb_saved: bool = false
var _fb_loaded: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = MenuBackdrop.new()
	_backdrop.show_tree = false
	add_child(_backdrop)
	_add_epilog_diorama()
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	SettingsService.changed.connect(render)
	get_viewport().size_changed.connect(render)
	render()


## REF_10: the run's own tree behind the summary (3D when allowed, else the 2D backdrop).
var _has_3d := false


func _add_epilog_diorama() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if not DioramaLayer.allowed(vp):
		return
	var layer: DioramaLayer = DioramaLayer.make("res://scenes/art/epilog_diorama.tscn", 0.45)
	if layer == null:
		return
	add_child(layer)
	_has_3d = true
	_backdrop.visible = false
	layer.set_portrait(vp.y > vp.x)
	if layer.diorama != null and layer.diorama.has_method("set_screen_anchor"):
		layer.diorama.call("set_screen_anchor", 0.5 if vp.y > vp.x else 0.24)
	var r: Dictionary = GameSession.run
	if layer.diorama != null and layer.diorama.has_method("set_run"):
		layer.diorama.call("set_run", r.get("mutations", []), str(r.get("main_faction", "BARK")),
			str(r.get("champion_path", "")), "won" if won_run(r) else "lost")


static func won_run(r: Dictionary) -> bool:
	return str(r.get("phase", "")) == "won" or str(r.get("result", "")) == "won"


func won() -> bool:
	return str(run.get("phase", "")) == "won" or str(run.get("result", "")) == "won"


func render() -> void:
	if not is_inside_tree():
		return
	run = GameSession.run
	if GameSession.scene_for_phase() != "result" and not run.is_empty():
		pending_scene = GameSession.scene_for_phase()
		if auto_navigate:
			AppFlow.goto_phase()
		return
	if not _logged:
		_logged = true
		PlaytestLog.record_run(run)  # once per run_id, local only
	if not _fb_loaded:
		_fb_loaded = true
		var fb: Dictionary = PlaytestLog.feedback_of(str(run.get("run_id", "")))
		if not fb.is_empty():
			fb_stars = int(fb.get("stars", 0))
			fb_forecast = str(fb.get("forecast_clear", ""))
			fb_text = str(fb.get("text", ""))
			fb_saved = true
	if not _played_sting:
		_played_sting = true
		AudioService.stop_music()
		AudioService.play("victory" if won() else "defeat")
	UiKit.clear(_content)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = UiKit.is_portrait(vp)
	var m := UiKit.margin(16 if portrait else 48)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(m)
	var scroll := UiKit.vscroll()
	# Buttons live in a fixed bar under the scrolling summary: always visible,
	# always reachable by keyboard / pad, and the headline stays in view.
	var outer := UiKit.vbox(12)
	m.add_child(outer)
	outer.add_child(scroll)
	var col := UiKit.vbox(18)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var accent: Color = UiKit.LIFE if won() else UiKit.DANGER
	var head := UiKit.heading(Loc.t("The tree stands") if won() else Loc.t("The Heart has fallen"), 40 if portrait else 64, accent.lightened(0.1))
	head.name = "Headline"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var stats: Dictionary = run.get("stats", {})
	var sub: String
	if won():
		sub = Loc.t("Victory. The Ash Crown is broken and the last world tree takes root again.")
	else:
		var lb: Dictionary = run.get("last_battle", {})
		sub = Loc.t("Defeat in %s. The ash reached the Heart.") % RunText.battle_name(int(lb.get("index", run.get("battle_index", 0))))
	var s := UiKit.label(sub, 18 if portrait else 22, UiKit.TEXT_DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(s)
	var main: BoxContainer = UiKit.vbox(16) if portrait else UiKit.hbox(32)
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(main)
	var tree := TreeSummary.new()
	tree.name = "TreeSummary"
	tree.won = won()
	tree.mutations = run.get("mutations", [])
	tree.custom_minimum_size = Vector2(0, 360) if portrait else Vector2(460, 560)
	if _has_3d:
		tree.self_modulate = Color(1, 1, 1, 0)  # the 3D epilog tree shows through this space
	main.add_child(tree)
	var right := UiKit.vbox(16)
	right.custom_minimum_size = Vector2(0 if portrait else 760, 0)
	main.add_child(right)
	right.add_child(_stats_panel(stats, portrait))
	var bp: Control = _battles_panel()
	if bp:
		right.add_child(bp)
	right.add_child(_build_panel())
	right.add_child(_feedback_panel(portrait))
	var buttons := UiKit.flow(16)
	buttons.name = "Actions"
	outer.add_child(buttons)
	var nb := UiKit.button(Loc.t("New run"), UiKit.AMBER, 24)
	nb.name = "NewRunButton"
	nb.custom_minimum_size = Vector2(280, 64)
	nb.pressed.connect(new_run)
	buttons.add_child(nb)
	var mb := UiKit.button(Loc.t("Main menu"), UiKit.ASH, 24)
	mb.name = "MainMenuButton"
	mb.custom_minimum_size = Vector2(280, 64)
	mb.pressed.connect(main_menu)
	buttons.add_child(mb)
	nb.grab_focus.call_deferred()


func _stats_panel(stats: Dictionary, portrait: bool) -> Control:
	var p := UiKit.panel(Color(UiKit.PANEL, 0.94), UiKit.LINE)
	p.name = "StatsPanel"
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(UiKit.heading(Loc.t("Run statistics"), 24))
	var grid := UiKit.flow(12, false)
	v.add_child(grid)
	var rows := [
		["check", Loc.t("Battles won"), "%d / 6" % int(stats.get("battles_won", 0)), UiKit.LIFE],
		["battle", Loc.t("Turns played"), str(int(stats.get("turns", 0))), UiKit.TEXT],
		["card", Loc.t("Cards played"), str(int(stats.get("cards_played", 0))), UiKit.ARMOR],
		["heart", Loc.t("Heart damage taken"), str(int(stats.get("heart_lost", 0))), UiKit.DANGER],
		["heart", Loc.t("Heart at the end"), "%d / %d" % [int(run.get("heart", 0)), int(run.get("heart_max", 0))], UiKit.LIFE],
		["deck", Loc.t("Deck size"), str((run.get("deck", []) as Array).size()), UiKit.TEXT],
	]
	for r: Array in rows:
		var cell := UiKit.panel(UiKit.PANEL_HI, UiKit.LINE)
		cell.custom_minimum_size = Vector2(168 if portrait else 228, 0)
		var h := UiKit.hbox(10)
		cell.add_child(h)
		var ic := MetaIcon.make(str(r[0]), r[3], UiKit.px(30))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var c := UiKit.vbox(0)
		var l := UiKit.label(str(r[1]), 14, UiKit.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if portrait else TextServer.AUTOWRAP_OFF
		l.custom_minimum_size = Vector2(100 if portrait else 0, 0)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(l)
		var val := UiKit.label(str(r[2]), 26, UiKit.TEXT, true)
		val.name = "Stat_" + str(r[1]).replace(" ", "_")
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		c.add_child(val)
		h.add_child(c)
		grid.add_child(cell)
	return p


## Per-battle rows from run["history"] ({index, battle_def_id, result, turns,
## heart_start, heart_end, deployed}); old saves without it fall back to the
## one battle they record, run["last_battle"]. Never invents numbers.
static func battle_rows(run: Dictionary) -> Array:
	var out: Array = []
	for h: Dictionary in run.get("history", []):
		var row := {"index": int(h.get("index", 0)), "result": str(h.get("result", "")), "turns": int(h.get("turns", 0)),
			"heart": int(h.get("heart_end", 0))}
		if h.has("heart_start"):
			row["heart_lost"] = maxi(0, int(h["heart_start"]) - int(h.get("heart_end", 0)))
		if h.has("deployed"):
			row["deployed"] = int(h["deployed"])
		out.append(row)
	if not out.is_empty():
		return out
	var lb: Dictionary = run.get("last_battle", {})
	return [] if lb.is_empty() else [lb]


func _battles_panel() -> Control:
	var rows: Array = battle_rows(run)
	if rows.is_empty():
		return null
	var p := UiKit.panel(Color(UiKit.PANEL, 0.94), UiKit.LINE)
	p.name = "BattlesPanel"
	var v := UiKit.vbox(6)
	p.add_child(v)
	v.add_child(UiKit.heading(Loc.t("Battles") if rows.size() > 1 else Loc.t("Final battle"), 22))
	for b: Dictionary in rows:
		var won_b: bool = str(b.get("result", "")) == "won"
		var h := UiKit.hbox(10)
		h.name = "BattleRow_%d" % int(b.get("index", 0))
		var ic := MetaIcon.make("check" if won_b else "skip", UiKit.LIFE if won_b else UiKit.DANGER, UiKit.px(22))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var name_l := UiKit.label(RunText.battle_name(int(b.get("index", 0))), 17, UiKit.TEXT, true)
		name_l.custom_minimum_size = Vector2(UiKit.px(150), 0)
		h.add_child(name_l)
		var parts: PackedStringArray = [Loc.t("Won") if won_b else Loc.t("Lost"), Loc.t("%d turns") % int(b.get("turns", 0)),
			"%s %d" % [Loc.t("Heart"), int(b.get("heart", 0))]]
		if b.has("heart_lost") and int(b["heart_lost"]) > 0:
			parts.append(Loc.t("lost %d") % int(b["heart_lost"]))
		if b.has("deployed"):
			parts.append(Loc.t("%d creatures played") % int(b["deployed"]))
		var d := UiKit.label(" · ".join(parts), 16, UiKit.TEXT_DIM)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(d)
		v.add_child(h)
	return p


## Optional after-run questions for playtesters (all skippable).
func _feedback_panel(portrait: bool) -> Control:
	var p := UiKit.panel(Color(UiKit.PANEL, 0.94), UiKit.LIFE.darkened(0.4))
	p.name = "FeedbackPanel"
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(UiKit.heading(Loc.t("How was this run?"), 22))
	v.add_child(UiKit.label(Loc.t("Optional. Saved only on this device, in your playtest log."), 15, UiKit.TEXT_DIM))
	var stars := UiKit.hbox(6)
	for i in range(1, 6):
		var on: bool = i <= fb_stars
		var b := UiKit.button(("★" if on else "☆") + " %d" % i, UiKit.AMBER if on else UiKit.ASH, 20)
		b.name = "Star_%d" % i
		b.custom_minimum_size = Vector2(UiKit.MIN_HIT * (1.2 if portrait else 1.5), UiKit.MIN_HIT)
		var val: int = i
		b.pressed.connect(func() -> void:
			AudioService.play("ui_click")
			fb_stars = val
			fb_saved = false
			render())
		stars.add_child(b)
	v.add_child(stars)
	v.add_child(UiKit.label(Loc.t("Did the forecast make sense?"), 17, UiKit.TEXT, true))
	var fc := UiKit.flow(8, false)
	for opt: Array in [["yes", Loc.t("Yes")], ["partly", Loc.t("Partly")], ["no", Loc.t("No")]]:
		var sel: bool = fb_forecast == opt[0]
		var b2 := UiKit.button(("✓ " if sel else "") + str(opt[1]), UiKit.LIFE if sel else UiKit.ASH, 18)
		b2.name = "Forecast_" + str(opt[0])
		var key: String = opt[0]
		b2.pressed.connect(func() -> void:
			AudioService.play("ui_click")
			fb_forecast = key
			fb_saved = false
			render())
		fc.add_child(b2)
	v.add_child(fc)
	var te := TextEdit.new()
	te.name = "FeedbackText"
	te.placeholder_text = Loc.t("Anything confusing, fun or frustrating? (optional)")
	te.text = fb_text
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size = Vector2(0, UiKit.px(90))
	te.add_theme_font_size_override("font_size", UiKit.px(16))
	te.text_changed.connect(func() -> void:
		if te.text.length() > PlaytestLog.MAX_TEXT:
			te.text = te.text.left(PlaytestLog.MAX_TEXT)
			te.set_caret_column(te.text.length())
		fb_text = te.text
		fb_saved = false)
	v.add_child(te)
	var row := UiKit.hbox(12)
	var save := UiKit.button(Loc.t("Save feedback"), UiKit.LIFE, 20)
	save.name = "SaveFeedbackButton"
	save.custom_minimum_size = Vector2(220, 56)
	save.pressed.connect(save_feedback)
	row.add_child(save)
	if fb_saved:
		var ok_l := UiKit.label("✓ " + Loc.t("Thank you! Feedback saved."), 16, UiKit.GOOD, true)
		ok_l.name = "FeedbackSaved"
		ok_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ok_l)
	v.add_child(row)
	return p


func save_feedback() -> void:
	AudioService.play("ui_confirm")
	fb_saved = PlaytestLog.set_feedback(str(run.get("run_id", "")), fb_stars, fb_forecast, fb_text)
	render()


func _build_panel() -> Control:
	var p := UiKit.panel(Color(UiKit.PANEL, 0.94), UiKit.LINE)
	p.name = "BuildPanel"
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(UiKit.heading(Loc.t("Your tree"), 24))
	var champ: Dictionary = Catalog.card(str(run.get("champion_id", "")))
	var path: String = str(run.get("champion_path", ""))
	var ctext: String = Loc.t("No path chosen")
	if path != "":
		var cp: Dictionary = Catalog.champion_path(champ["id"], path)
		ctext = "%s, %s %d — %s" % [Loc.field(cp, "name"), Loc.t("rank"), int(run.get("champion_rank", 0)), Loc.field(cp, "text")]
	v.add_child(_line("champion", UiKit.faction_color(str(champ.get("faction", "BARK"))), Loc.field(champ, "name"), ctext))
	var muts: Array = run.get("mutations", [])
	if muts.is_empty():
		v.add_child(_line("mutation", UiKit.GOOD, Loc.t("Mutations"), Loc.t("None")))
	for mid: String in muts:
		var m: Dictionary = Catalog.mutation(mid)
		v.add_child(_line("mutation", UiKit.GOOD, Loc.field(m, "name"), Loc.field(m, "text")))
	var rels: Array = run.get("relics", [])
	if rels.is_empty():
		v.add_child(_line("relic", UiKit.ARMOR, Loc.t("Relics"), Loc.t("None")))
	for rid: String in rels:
		var r: Dictionary = Catalog.relic(rid)
		v.add_child(_line("relic", UiKit.ARMOR, Loc.field(r, "name"), Loc.field(r, "text")))
	return p


func _line(icon: String, accent: Color, title: String, text: String) -> Control:
	var h := UiKit.hbox(12)
	var ic := MetaIcon.make(icon, accent, UiKit.px(30))
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label(title, 18, UiKit.TEXT, true))
	v.add_child(UiKit.label(text, 16, UiKit.TEXT_DIM))
	h.add_child(v)
	return h


func new_run() -> void:
	AudioService.play("ui_confirm")
	MainMenu.start_view = "faction"
	_go("menu")


func main_menu() -> void:
	AudioService.play("ui_click")
	MainMenu.start_view = "title"
	_go("menu")


func _go(scene_id: String) -> void:
	pending_scene = scene_id
	if auto_navigate:
		AppFlow.goto(scene_id)
