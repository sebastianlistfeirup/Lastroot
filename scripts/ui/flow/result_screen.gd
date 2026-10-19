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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = MenuBackdrop.new()
	_backdrop.show_tree = false
	add_child(_backdrop)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	SettingsService.changed.connect(render)
	get_viewport().size_changed.connect(render)
	render()


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
	m.add_child(scroll)
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
	main.add_child(tree)
	var right := UiKit.vbox(16)
	right.custom_minimum_size = Vector2(0 if portrait else 760, 0)
	main.add_child(right)
	right.add_child(_stats_panel(stats, portrait))
	var bp: Control = _battles_panel()
	if bp:
		right.add_child(bp)
	right.add_child(_build_panel())
	var buttons := UiKit.flow(16)
	buttons.name = "Actions"
	col.add_child(buttons)
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


## Per-battle rows. Uses run["battle_log"] when the domain provides it
## (list of {index, result, turns, heart, heart_lost}); otherwise the one
## battle the run records, run["last_battle"]. Never invents numbers.
static func battle_rows(run: Dictionary) -> Array:
	var entries: Array = run.get("battle_log", [])
	if not entries.is_empty():
		return entries
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
		if b.has("heart_lost"):
			parts.append("−%d" % int(b["heart_lost"]))
		var d := UiKit.label(" · ".join(parts), 16, UiKit.TEXT_DIM)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(d)
		v.add_child(h)
	return p


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
