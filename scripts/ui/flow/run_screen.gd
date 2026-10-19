class_name RunScreen
extends Control
## One scene for the run phases between battles: "reward", "route", "node".
## The screen never changes state: every action is a GameSession.cmd(), and
## the whole view is re-rendered from GameSession.run afterwards. When the
## phase belongs to another scene (battle, result) AppFlow takes over.

## Tests set this false and read `pending_scene` instead of changing scenes.
var auto_navigate: bool = true
var pending_scene: String = ""

var run: Dictionary = {}
var portrait: bool = false

# Local, purely visual selections (never saved; the reducer decides).
var sel_offer: String = ""
var sel_slot: String = ""
var sel_instance: int = -1
var sel_node: String = ""
var _sel_owner: String = ""

var _backdrop: MenuBackdrop
var _header: RunHeader
var _scroll: ScrollContainer
var _body: VBoxContainer
var _pad: MarginContainer
var _detail: PanelContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _deck: DeckViewer
var _pause: PauseMenu
var _detail_key: String = ""
var _offer_views: Array = []
var _confirm: Button
var _last_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = MenuBackdrop.new()
	_backdrop.tree_alpha = 0.22
	add_child(_backdrop)
	var outer := UiKit.margin(12)
	outer.name = "Outer"
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(outer)
	var col := UiKit.vbox(10)
	outer.add_child(col)
	_header = RunHeader.new()
	_header.name = "RunHeader"
	_header.detail_requested.connect(show_detail)
	_header.deck_requested.connect(func() -> void: _deck.show_deck(run))
	_header.menu_requested.connect(func() -> void: _pause.open())
	col.add_child(_header)
	_scroll = UiKit.vscroll()
	_scroll.name = "BodyScroll"
	col.add_child(_scroll)
	_pad = MarginContainer.new()
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pad)
	_body = UiKit.vbox(18)
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.add_child(_body)
	_build_detail()
	_build_toast()
	# Pause first, so overlays above it (deck viewer) get Esc before it does.
	_pause = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	_pause.name = "PauseMenu"
	_pause.corner_button = false
	add_child(_pause)
	_deck = DeckViewer.new()
	_deck.name = "DeckViewer"
	add_child(_deck)
	GameSession.run_changed.connect(_on_run_changed)
	GameSession.command_rejected.connect(_on_rejected)
	SettingsService.changed.connect(render)
	get_viewport().size_changed.connect(_on_resize)
	AudioService.play_music("music_menu")
	render()


func _on_resize() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	if s.distance_to(_last_size) > 2.0:
		render()


# ------------------------------------------------------------------ flow

func send(command: Dictionary) -> Dictionary:
	return GameSession.cmd(command)


func _on_run_changed(events: Array) -> void:
	for e: Dictionary in events:
		match str(e.get("kind", "")):
			"resin_gained": AudioService.play("resin")
			"card_added", "relic_gained": AudioService.play("reward")
			"mutation_gained": AudioService.play("mutation_grow")
			"champion_upgraded", "card_upgraded": AudioService.play("camp_upgrade")
			"card_removed": AudioService.play("ui_confirm")
			"heart_healed": AudioService.play("heal")
			"node_entered": AudioService.play("route_select")
			"reward_skipped": AudioService.play("ui_cancel")
	if not is_inside_tree():
		return
	render()


func _on_rejected(reason: String) -> void:
	AudioService.play("ui_invalid")
	toast(Loc.t(reason))


## Re-renders everything from GameSession.run (or leaves for another scene).
func render() -> void:
	if not is_inside_tree():
		return
	run = GameSession.run
	var target: String = GameSession.scene_for_phase()
	if target != "run":
		pending_scene = target
		if auto_navigate:
			AppFlow.goto_phase()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_last_size = vp
	portrait = UiKit.is_portrait(vp)
	var key: String = _selection_owner()
	if key != _sel_owner:
		sel_offer = ""
		sel_instance = -1
		sel_node = ""
		_sel_owner = key
	var keep_scroll: int = _scroll.scroll_vertical
	_header.build(run, portrait)
	var side: int = maxi(0, int((vp.x - 1560.0) * 0.5)) if not portrait else 0
	_pad.add_theme_constant_override("margin_left", side)
	_pad.add_theme_constant_override("margin_right", side)
	_pad.add_theme_constant_override("margin_bottom", 140)
	UiKit.clear(_body)
	_offer_views.clear()
	_confirm = null
	match GameSession.phase():
		"reward":
			_render_reward()
		"route":
			_render_route()
		"node":
			_render_node()
	_backdrop.tree_x = 0.86
	_backdrop.show_tree = not portrait
	_set_scroll.call_deferred(keep_scroll)


func _set_scroll(v: int) -> void:
	_scroll.scroll_vertical = v


## Selections belong to one slot / node; a new one starts fresh.
func _selection_owner() -> String:
	match GameSession.phase():
		"reward":
			return "reward:" + str(RunReducer.current_slot(run).get("id", ""))
		"route":
			return "route:" + str(RunReducer.current_route(run).get("id", ""))
		"node":
			return "node:" + str(run.get("node", {}).get("id", ""))
	return ""


# ---------------------------------------------------------------- reward

func _render_reward() -> void:
	var reward: Dictionary = run["reward"]
	var k: int = int(reward["battle_number"])
	_title(Loc.t("Victory"), Loc.t("Battle %d of 6 won. Claim your rewards in order.") % k, UiKit.LIFE)
	_body.add_child(_slot_strip(reward["slots"]))
	var slot: Dictionary = RunReducer.current_slot(run)
	if slot.is_empty():
		_body.add_child(UiKit.label(Loc.t("All rewards are settled."), 20, UiKit.TEXT_DIM))
		return
	match str(slot["type"]):
		"card":
			_card_choice(slot, Loc.t("Choose a card for your deck"), Loc.t("Or skip it: a lean deck draws its best cards more often."))
		"mutation":
			_mutation_choice(slot)
		"champion":
			_champion_choice(slot)
		"relic":
			_relic_choice(slot)


func _slot_strip(slots: Array) -> Control:
	var strip := UiKit.flow(10, false)
	strip.name = "SlotStrip"
	var current: String = str(RunReducer.current_slot(run).get("id", ""))
	for slot: Dictionary in slots:
		var st: String = str(slot["status"])
		var accent: Color = UiKit.LINE
		if st == "claimed":
			accent = UiKit.LIFE.darkened(0.2)
		elif slot["id"] == current:
			accent = UiKit.AMBER
		var p := PanelContainer.new()
		p.name = "Slot_" + str(slot["id"]).replace(".", "_")
		var sb := UiKit.panel_style(UiKit.PANEL_HI if slot["id"] == current else UiKit.PANEL, accent, 12, 3 if slot["id"] == current else 2)
		p.add_theme_stylebox_override("panel", sb)
		var h := UiKit.hbox(8)
		p.add_child(h)
		var ic := MetaIcon.make(RunText.slot_icon(slot["type"]), accent.lightened(0.3) if st != "offered" or slot["id"] == current else UiKit.TEXT_DIM, UiKit.px(26))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var v := UiKit.vbox(0)
		var t := UiKit.label(RunText.slot_title(slot["type"]), 14, UiKit.TEXT_DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(t)
		var res: String = RunText.slot_result(slot, run)
		if st == "offered" and slot["id"] != current:
			res = Loc.t("Next")
		var r := UiKit.label(res, 18, UiKit.TEXT if st != "skipped" else UiKit.TEXT_DIM, st == "claimed")
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(r)
		h.add_child(v)
		if st == "claimed":
			h.add_child(MetaIcon.make("check", UiKit.LIFE, UiKit.px(20)))
		strip.add_child(p)
	return strip


func _card_choice(slot: Dictionary, heading: String, sub: String) -> void:
	_section(heading, sub)
	var row := UiKit.flow(18, portrait)
	row.name = "Offers"
	for cid: String in slot["offer"]:
		var cv := CardView.new().setup(cid)
		cv.name = "Offer_" + cid
		cv.selected = cid == sel_offer
		cv.pressed.connect(func() -> void: select_offer(cid))
		row.add_child(cv)
		_offer_views.append(cv)
	_body.add_child(row)
	var buttons := _button_row()
	var take_text: String = Loc.t("Add to deck") if sel_offer == "" else Loc.t("Add %s to deck") % Loc.field(Catalog.card(sel_offer), "name")
	_confirm = _action(buttons, take_text, UiKit.LIFE, "ConfirmButton", func() -> void:
		if sel_offer != "":
			AudioService.play("ui_confirm")
			send({"type": "claim", "slot": slot["id"], "choice": sel_offer}))
	_confirm.disabled = sel_offer == ""
	_action(buttons, Loc.t("Skip"), UiKit.ASH, "SkipButton", func() -> void: send({"type": "skip", "slot": slot["id"]}))
	if sel_offer == "":
		_hint(Loc.t("Tap a card to select it, then confirm."))


func select_offer(id: String) -> void:
	AudioService.play("card_hover")
	sel_offer = id
	render()


func _mutation_choice(slot: Dictionary) -> void:
	_section(Loc.t("The tree mutates"), Loc.t("Choose one mutation. It lasts for the whole run. This choice cannot be skipped."))
	var row := UiKit.flow(16, portrait)
	row.name = "Offers"
	for mid: String in slot["offer"]:
		var m: Dictionary = Catalog.mutation(mid)
		var t := ChoiceTile.make(UiKit.GOOD)
		t.name = "Offer_" + mid
		t.custom_minimum_size = Vector2(_tile_w(4), 0)
		t.add_title("mutation", Loc.field(m, "name"))
		t.add_text(Loc.field(m, "text"), 18, UiKit.TEXT)
		t.add_text(_mutation_floor(mid), 15, UiKit.TEXT_DIM)
		t.selected = mid == sel_offer
		t.pressed.connect(func() -> void: select_offer(mid))
		row.add_child(t)
	_body.add_child(row)
	var buttons := _button_row()
	var text: String = Loc.t("Grow this mutation") if sel_offer == "" else Loc.t("Grow %s") % Loc.field(Catalog.mutation(sel_offer), "name")
	_confirm = _action(buttons, text, UiKit.GOOD, "ConfirmButton", func() -> void:
		if sel_offer != "":
			send({"type": "claim", "slot": slot["id"], "choice": sel_offer}))
	_confirm.disabled = sel_offer == ""
	if sel_offer == "":
		_hint(Loc.t("Tap an option to select it, then confirm."))


static func _mutation_floor(mid: String) -> String:
	match mid:
		"M01": return Loc.t("Affects: the Roots")
		"M02": return Loc.t("Affects: the Trunk")
		"M03": return Loc.t("Affects: the Crown")
		"M04": return Loc.t("Affects: the Heart")
	return ""


func _champion_choice(slot: Dictionary) -> void:
	var champ_id: String = str(run["champion_id"])
	var champ: Dictionary = Catalog.card(champ_id)
	var cur_path: String = str(run.get("champion_path", ""))
	var cur_rank: int = int(run.get("champion_rank", 0))
	if cur_path == "":
		_section(Loc.t("Choose %s's path") % Loc.field(champ, "name"),
			Loc.t("The first choice locks the path for the rest of the run. After battle 4 the same path rises to rank 2."))
	else:
		_section(Loc.t("%s grows stronger") % Loc.field(champ, "name"),
			Loc.t("Your path is locked: %s rises to rank 2.") % Loc.field(Catalog.champion_path(champ_id, cur_path), "name"))
	var row := UiKit.flow(20, portrait)
	row.name = "Offers"
	var offer: Array = slot["offer"]
	for pid: String in offer:
		var p: Dictionary = Catalog.champion_path(champ_id, pid)
		var t := ChoiceTile.make(UiKit.faction_color(str(champ["faction"])))
		t.name = "Offer_" + pid
		t.custom_minimum_size = Vector2(_tile_w(2, 600.0), 0)
		var to_rank: int = mini(2, cur_rank + 1)
		t.add_title("champion", "%s — %s %d" % [Loc.field(p, "name"), Loc.t("rank"), to_rank], 24)
		t.add_text(Loc.field(p, "text"), 17, UiKit.TEXT)
		var cards := UiKit.hbox(4 if portrait else 10)
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		var before := CardView.new().setup(champ_id, "", cur_path, cur_rank)
		before.name = "Before"
		var after := CardView.new().setup(champ_id, "", pid, to_rank)
		after.name = "After"
		after.selected = true
		cards.add_child(_labelled(before, Loc.t("Now")))
		cards.add_child(_arrow())
		cards.add_child(_labelled(after, Loc.t("After")))
		t.add(cards)
		for ch: Array in RunText.path_changes(champ_id, pid, cur_path, cur_rank, to_rank):
			t.add(_change_row(str(ch[0]), int(ch[1]), int(ch[2])))
		t.selected = pid == sel_offer
		t.pressed.connect(func() -> void: select_offer(pid))
		row.add_child(t)
	_body.add_child(row)
	if cur_path != "":
		for p: Dictionary in Catalog.champion_paths(champ_id):
			if p["id"] != cur_path:
				_hint(Loc.t("%s is closed: the path cannot change.") % Loc.field(p, "name"))
	if offer.size() == 1 and sel_offer == "":
		sel_offer = offer[0]
		(row.get_child(0) as ChoiceTile).selected = true
	var buttons := _button_row()
	var text: String = Loc.t("Choose a path") if sel_offer == "" else Loc.t("Take %s") % Loc.field(Catalog.champion_path(champ_id, sel_offer), "name")
	_confirm = _action(buttons, text, UiKit.faction_color(str(champ["faction"])), "ConfirmButton", func() -> void:
		if sel_offer != "":
			send({"type": "claim", "slot": slot["id"], "choice": sel_offer}))
	_confirm.disabled = sel_offer == ""
	if sel_offer == "":
		_hint(Loc.t("Tap an option to select it, then confirm."))


func _relic_choice(slot: Dictionary) -> void:
	_section(Loc.t("Choose a relic"), Loc.t("Relics are small permanent rules for the rest of the run. Take one of three."))
	var row := UiKit.flow(16, portrait)
	row.name = "Offers"
	for rid: String in slot["offer"]:
		var r: Dictionary = Catalog.relic(rid)
		var t := ChoiceTile.make(UiKit.ARMOR)
		t.name = "Offer_" + rid
		t.custom_minimum_size = Vector2(_tile_w(3), 0)
		t.add_title("relic", Loc.field(r, "name"))
		t.add_text(Loc.field(r, "text"), 18, UiKit.TEXT)
		t.selected = rid == sel_offer
		t.pressed.connect(func() -> void: select_offer(rid))
		row.add_child(t)
	_body.add_child(row)
	var buttons := _button_row()
	var text: String = Loc.t("Take relic") if sel_offer == "" else Loc.t("Take %s") % Loc.field(Catalog.relic(sel_offer), "name")
	_confirm = _action(buttons, text, UiKit.ARMOR, "ConfirmButton", func() -> void:
		if sel_offer != "":
			send({"type": "claim", "slot": slot["id"], "choice": sel_offer}))
	_confirm.disabled = sel_offer == ""
	if sel_offer == "":
		_hint(Loc.t("Tap an option to select it, then confirm."))


# ----------------------------------------------------------------- route

func _render_route() -> void:
	var route: Dictionary = RunReducer.current_route(run)
	var k: int = int(route.get("after_battle", 0))
	var next_name: String = RunText.battle_name(k)
	var sub: String = Loc.t("One of two places before %s. Both paths lead to the same battle.") % next_name
	if k == 5:
		sub = Loc.t("The last stop before the boss, %s.") % next_name
	_title(Loc.t("Choose your path"), sub, UiKit.AMBER)
	var map := RouteMap.new()
	map.name = "RouteMap"
	map.setup(run, portrait, sel_node)
	map.node_tapped.connect(_on_map_tapped)
	var options := UiKit.flow(20, portrait)
	options.name = "RouteOptions"
	for opt: Dictionary in route.get("options", []):
		options.add_child(_route_option(opt))
	if portrait:
		_body.add_child(options)
		_body.add_child(_map_frame(map))
	else:
		_body.add_child(_map_frame(map))
		_body.add_child(options)


func _map_frame(map: RouteMap) -> Control:
	var p := UiKit.panel(Color(UiKit.BG, 0.55), UiKit.LINE)
	p.add_child(map)
	return p


func _route_option(opt: Dictionary) -> Control:
	var type: String = opt["type"]
	var t := ChoiceTile.make(MetaIcon.node_color(type))
	t.name = "Option_" + str(opt["id"])
	t.custom_minimum_size = Vector2(_tile_w(2, 640.0), 0)
	t.add_title(type, RunText.node_name(type), 26)
	t.add_text(RunText.node_gives(type), 18, UiKit.TEXT)
	var warn: String = RunText.node_warning(type, run)
	if warn != "":
		t.add_text(warn, 16, UiKit.AMBER)
	t.selected = sel_node == opt["id"]
	var oid: String = opt["id"]
	t.pressed.connect(func() -> void:
		AudioService.play("ui_click")
		sel_node = oid
		render())
	var go := UiKit.button(Loc.t("Travel to %s") % RunText.node_name(type), MetaIcon.node_color(type), 20)
	go.name = "Go_" + oid
	go.custom_minimum_size = Vector2(0, 56)
	go.pressed.connect(func() -> void: choose_node(oid))
	t.add(go)
	return t


func choose_node(node_id: String) -> void:
	send({"type": "choose_node", "node": node_id})


func _on_map_tapped(node_id: String) -> void:
	var route: Dictionary = RunReducer.current_route(run)
	for opt: Dictionary in route.get("options", []):
		if opt["id"] == node_id:
			AudioService.play("ui_click")
			sel_node = node_id
			render()
			return
	# Any other node: explain it in the detail panel.
	if node_id.begins_with("B"):
		var i: int = int(node_id.substr(1))
		var waves: Array = BattleFactory.waves_for(i)
		var text: String = Loc.t("%d enemy waves.") % waves.size()
		if i == 5:
			text = Loc.t("The boss arrives on turn %d after four waves. It escalates from turn %d.") % [int(Catalog.boss()["arrival_turn"]), int(Catalog.boss()["escalate_from_turn"])]
		show_detail("boss" if i == 5 else "battle", RunText.battle_name(i), text, UiKit.DANGER if i == 5 else UiKit.TEXT)
		return
	for r: Dictionary in run.get("route", []):
		for opt: Dictionary in r["options"]:
			if opt["id"] == node_id:
				var state: String = Loc.t("Locked: opens after battle %d.") % int(r["after_battle"])
				if r["status"] == "chosen":
					state = Loc.t("You went here.") if r["chosen"] == node_id else Loc.t("Not taken.")
				show_detail(opt["type"], RunText.node_name(opt["type"]), RunText.node_gives(opt["type"]) + "\n" + state, MetaIcon.node_color(opt["type"]))
				return


# ------------------------------------------------------------------ nodes

func _render_node() -> void:
	var node: Dictionary = run["node"]
	match str(node["type"]):
		"camp":
			_render_camp()
		"removal":
			_render_removal()
		"encounter":
			_render_encounter()
		"card":
			_title(Loc.t("Card reward"), Loc.t("A free card for your deck."), MetaIcon.node_color("card"))
			var slot: Dictionary = {}
			for s: Dictionary in node.get("slots", []):
				if s["status"] == "offered":
					slot = s
			if slot.is_empty():
				_leave_row(Loc.t("Continue"))
			else:
				_card_choice(slot, Loc.t("Choose a card for your deck"), Loc.t("Or skip it and move on to the next battle."))


func _render_camp() -> void:
	_title(Loc.t("Camp"), Loc.t("Upgrade one card once by the fire, or rest and move on. You have %d Resin.") % int(run["resin"]), UiKit.AMBER)
	var sel: Dictionary = RunReducer.instance(run, sel_instance)
	var panel := UiKit.vbox(12)
	panel.name = "UpgradePanel"
	if sel.is_empty():
		panel.add_child(UiKit.label(Loc.t("Tap a card in your deck to see its upgrades."), 20, UiKit.TEXT_DIM))
	else:
		var def: Dictionary = Catalog.card(sel["def_id"])
		panel.add_child(UiKit.heading(Loc.field(def, "name"), 26))
		var legal: Array = CardStats.legal_upgrades(def, sel["upgrade_id"])
		if legal.is_empty():
			panel.add_child(UiKit.label(_no_upgrade_reason(def, sel), 18, UiKit.AMBER))
		for u: Dictionary in legal:
			panel.add_child(_upgrade_row(sel, def, u))
	var grid := _deck_grid(func(inst: Dictionary) -> String:
		var d: Dictionary = Catalog.card(inst["def_id"])
		if CardStats.legal_upgrades(d, inst["upgrade_id"]).is_empty():
			return _no_upgrade_reason(d, inst)
		return "")
	_split(panel, grid)
	_leave_row(Loc.t("Leave camp"))


func _no_upgrade_reason(def: Dictionary, inst: Dictionary) -> String:
	if def.get("kind", "") == "champion":
		return Loc.t("Champions grow through their path, not at camps.")
	if str(inst.get("upgrade_id", "")) != "":
		return Loc.t("Already upgraded. Each card can be upgraded once.")
	return Loc.t("This card has no upgrade.")


func _upgrade_row(inst: Dictionary, def: Dictionary, u: Dictionary) -> Control:
	var price: int = int(u["price"])
	var resin: int = int(run["resin"])
	var p := UiKit.panel(UiKit.PANEL_HI, UiKit.AMBER.darkened(0.4))
	p.name = "UpgradeRow_" + str(u["id"])
	if portrait:
		_tight(p, 4)
	var v := UiKit.vbox(10)
	p.add_child(v)
	var cards := UiKit.hbox(4 if portrait else 10)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_child(_labelled(CardView.new().setup(inst["def_id"], "", "", 0, int(inst["instance_id"])), Loc.t("Now")))
	cards.add_child(_arrow())
	var after := CardView.new().setup(inst["def_id"], str(u["id"]), "", 0, int(inst["instance_id"]))
	after.selected = true
	cards.add_child(_labelled(after, Loc.t("After")))
	v.add_child(cards)
	var b := UiKit.button(Loc.t("Upgrade: %s for %d Resin") % [CardView._upgrade_label(def, u["id"]), price], UiKit.AMBER, 20)
	b.name = "Upgrade_" + str(u["id"])
	b.custom_minimum_size = Vector2(0, 56)
	b.disabled = resin < price
	var iid: int = int(inst["instance_id"])
	var uid: String = u["id"]
	b.pressed.connect(func() -> void: send({"type": "camp_upgrade", "card": iid, "upgrade": uid}))
	v.add_child(b)
	if resin < price:
		v.add_child(UiKit.label(Loc.t("Not enough Resin: you need %d more.") % (price - resin), 16, UiKit.DANGER))
	return p


func _render_removal() -> void:
	var rules: Dictionary = Catalog.rules()
	var cost: int = int(rules["remove_cost"])
	var min_n: int = int(rules["min_normal_cards"])
	var normal: int = RunReducer.normal_card_count(run)
	_title(Loc.t("Removal"), Loc.t("Remove one normal card for %d Resin. You have %d Resin and %d normal cards (minimum %d).") % [cost, int(run["resin"]), normal, min_n], MetaIcon.node_color("removal"))
	var panel := UiKit.vbox(12)
	panel.name = "RemovePanel"
	var block: String = ""
	if normal - 1 < min_n:
		block = Loc.t("Your deck must keep at least %d normal cards.") % min_n
	elif int(run["resin"]) < cost:
		block = Loc.t("Not enough Resin: you need %d more.") % (cost - int(run["resin"]))
	var sel: Dictionary = RunReducer.instance(run, sel_instance)
	if sel.is_empty():
		panel.add_child(UiKit.label(Loc.t("Tap a card in your deck to choose what to remove."), 20, UiKit.TEXT_DIM))
	else:
		var def: Dictionary = Catalog.card(sel["def_id"])
		var cv := DeckViewer.card_for(run, sel)
		cv.selected = true
		var h := UiKit.hbox(16)
		h.add_child(cv)
		var v := UiKit.vbox(10)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.heading(Loc.field(def, "name"), 24))
		var b := UiKit.button(Loc.t("Remove for %d Resin") % cost, UiKit.DANGER, 20)
		b.name = "RemoveButton"
		b.custom_minimum_size = Vector2(0, 56)
		b.disabled = block != ""
		var iid: int = int(sel["instance_id"])
		b.pressed.connect(func() -> void: send({"type": "remove_card", "card": iid}))
		v.add_child(b)
		if block != "":
			v.add_child(UiKit.label(block, 16, UiKit.DANGER))
		h.add_child(v)
		panel.add_child(h)
	if block != "" and sel.is_empty():
		panel.add_child(UiKit.label(block, 17, UiKit.AMBER))
	var grid := _deck_grid(func(inst: Dictionary) -> String:
		if Catalog.card(inst["def_id"])["kind"] == "champion":
			return Loc.t("The champion cannot be removed.")
		return "")
	_split(panel, grid)
	_leave_row(Loc.t("Leave without removing"))


func _render_encounter() -> void:
	_title(Loc.t("Encounter"), Loc.t("A wandering spirit offers help. Choose one gift."), UiKit.LIFE)
	var row := UiKit.flow(20, portrait)
	row.name = "Offers"
	var resin: int = int(run["resin"])
	var heart: int = int(run["heart"])
	var hmax: int = int(run["heart_max"])
	var t1 := ChoiceTile.make(UiKit.AMBER)
	t1.name = "Encounter_resin_tile"
	t1.custom_minimum_size = Vector2(_tile_w(2, 520.0), 0)
	t1.add_title("resin", Loc.t("Gain 15 Resin"))
	t1.add_text(Loc.t("Resin %d → %d") % [resin, resin + 15], 20, UiKit.TEXT)
	var b1 := UiKit.button(Loc.t("Take 15 Resin"), UiKit.AMBER, 20)
	b1.name = "Encounter_resin"
	b1.custom_minimum_size = Vector2(0, 56)
	b1.pressed.connect(func() -> void: send({"type": "encounter", "choice": "resin"}))
	t1.add(b1)
	row.add_child(t1)
	var t2 := ChoiceTile.make(UiKit.LIFE)
	t2.name = "Encounter_heal_tile"
	t2.custom_minimum_size = Vector2(_tile_w(2, 520.0), 0)
	t2.add_title("heart", Loc.t("Heal the Heart 8"))
	t2.add_text(Loc.t("Heart %d/%d → %d/%d") % [heart, hmax, mini(hmax, heart + 8), hmax], 20, UiKit.TEXT)
	if heart >= hmax:
		t2.add_text(Loc.t("The Heart is already full: healing would do nothing."), 16, UiKit.AMBER)
	var b2 := UiKit.button(Loc.t("Heal the Heart"), UiKit.LIFE, 20)
	b2.name = "Encounter_heal"
	b2.custom_minimum_size = Vector2(0, 56)
	b2.pressed.connect(func() -> void: send({"type": "encounter", "choice": "heal"}))
	t2.add(b2)
	row.add_child(t2)
	_body.add_child(row)
	_leave_row(Loc.t("Leave without a gift"))


func _deck_grid(reason_for: Callable) -> Control:
	var box := UiKit.vbox(8)
	box.add_child(UiKit.label(Loc.t("Your deck"), 20, UiKit.TEXT, true))
	var grid := UiKit.flow(12, portrait)
	grid.name = "DeckGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for inst: Dictionary in DeckViewer.sorted_deck(run):
		var cv := DeckViewer.card_for(run, inst)
		var reason: String = reason_for.call(inst)
		cv.playable = reason == ""
		cv.selected = int(inst["instance_id"]) == sel_instance
		var iid: int = int(inst["instance_id"])
		cv.pressed.connect(func() -> void: select_instance(iid))
		grid.add_child(cv)
	box.add_child(grid)
	return box


func select_instance(iid: int) -> void:
	AudioService.play("card_hover")
	sel_instance = iid
	render()


## Desktop: deck on the left, the action panel on the right. Portrait: stacked.
func _split(panel: Control, grid: Control) -> void:
	var framed := UiKit.panel(Color(UiKit.PANEL, 0.92), UiKit.AMBER.darkened(0.45))
	framed.add_child(panel)
	if portrait:
		_tight(framed, 6)
		_body.add_child(framed)
		_body.add_child(grid)
		return
	var h := UiKit.hbox(24)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(grid)
	framed.custom_minimum_size = Vector2(560, 0)
	framed.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(framed)
	_body.add_child(h)


static func _tight(p: PanelContainer, m: int) -> void:
	var sb: StyleBoxFlat = (p.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	sb.content_margin_left = m
	sb.content_margin_right = m
	p.add_theme_stylebox_override("panel", sb)


func _leave_row(text: String) -> void:
	var buttons := _button_row()
	_action(buttons, text, UiKit.ASH, "LeaveButton", func() -> void: send({"type": "leave_node"}))


# ---------------------------------------------------------------- pieces

func _title(text: String, sub: String, accent: Color) -> void:
	var v := UiKit.vbox(4)
	v.name = "PhaseTitle"
	var t := UiKit.heading(text, 34 if portrait else 44, accent.lightened(0.15))
	v.add_child(t)
	v.add_child(UiKit.label(sub, 18 if portrait else 20, UiKit.TEXT_DIM))
	_body.add_child(v)


func _section(text: String, sub: String) -> void:
	var v := UiKit.vbox(2)
	v.add_child(UiKit.heading(text, 26 if portrait else 30))
	if sub != "":
		v.add_child(UiKit.label(sub, 17, UiKit.TEXT_DIM))
	_body.add_child(v)


func _hint(text: String) -> void:
	_body.add_child(UiKit.label(text, 16, UiKit.TEXT_DIM))


func _button_row() -> HFlowContainer:
	var row := UiKit.flow(12, portrait)
	row.name = "Actions"
	_body.add_child(row)
	return row


func _action(row: Control, text: String, accent: Color, node_name: String, cb: Callable) -> Button:
	var b := UiKit.button(text, accent, 22)
	b.name = node_name
	b.custom_minimum_size = Vector2(240 if not portrait else 180, 60)
	b.pressed.connect(cb)
	row.add_child(b)
	return b


func _labelled(c: Control, text: String) -> Control:
	var v := UiKit.vbox(4)
	var l := UiKit.label(text, 15, UiKit.TEXT_DIM, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(c)
	return v


func _arrow() -> Control:
	var l := UiKit.label("→", 22 if portrait else 34, UiKit.AMBER, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _change_row(label: String, before: int, after: int) -> Control:
	var h := UiKit.hbox(8)
	var l := UiKit.label(label, 17, UiKit.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var v := UiKit.label("%d  →  %d" % [before, after], 19, UiKit.GOOD if after > before else UiKit.TEXT, true)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(v)
	return h


## Width of one tile so `per_row` fit on desktop; full width on portrait.
func _tile_w(per_row: int, max_w: float = 460.0) -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if portrait:
		return vp.x - 24.0 - 8.0
	var avail: float = minf(vp.x, 1560.0) - 48.0
	return minf(max_w, (avail - 16.0 * float(per_row - 1)) / float(per_row))


# ---------------------------------------------------- detail panel, toast

func _build_detail() -> void:
	_detail = PanelContainer.new()
	_detail.name = "DetailPanel"
	_detail.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_HI, UiKit.LIFE, 14, 2))
	_detail.visible = false
	add_child(_detail)


func show_detail(icon: String, title: String, text: String, accent: Color) -> void:
	var key: String = title
	if _detail.visible and key == _detail_key:
		hide_detail()
		return
	_detail_key = key
	UiKit.clear(_detail)
	_detail.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_HI, accent, 14, 3))
	var h := UiKit.hbox(14)
	_detail.add_child(h)
	var ic := MetaIcon.make(icon, accent, UiKit.px(44))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := UiKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := UiKit.label(title, 22, UiKit.TEXT, true)
	tl.name = "DetailTitle"
	v.add_child(tl)
	var bl := UiKit.label(text, 18, UiKit.TEXT_DIM)
	bl.name = "DetailText"
	v.add_child(bl)
	h.add_child(v)
	var close := UiKit.button(Loc.t("Close"), UiKit.ASH, 18)
	close.name = "DetailClose"
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(hide_detail)
	h.add_child(close)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = minf(760.0, vp.x - 24.0)
	_detail.visible = true
	_detail.size = Vector2(w, 0)
	_detail.reset_size()
	_detail.size.x = w
	_place_detail.call_deferred()


func _place_detail() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_detail.size.y = _detail.get_combined_minimum_size().y
	_detail.position = Vector2((vp.x - _detail.size.x) * 0.5, vp.y - _detail.size.y - 16.0)


func hide_detail() -> void:
	_detail.visible = false
	_detail_key = ""


func detail_text() -> String:
	var l: Label = _detail.find_child("DetailText", true, false) as Label
	return l.text if l and _detail.visible else ""


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.add_theme_stylebox_override("panel", UiKit.panel_style(Color("3a1c22"), UiKit.DANGER, 12, 2))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UiKit.label("", 20, UiKit.TEXT, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.visible = false
	add_child(_toast)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func() -> void: _toast.visible = false)
	add_child(_toast_timer)


func toast(text: String) -> void:
	_toast_label.text = text
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = minf(720.0, vp.x - 24.0)
	_toast.visible = true
	_toast.size = Vector2(w, 0)
	_toast.reset_size()
	_toast.size.x = w
	_toast.position = Vector2((vp.x - w) * 0.5, vp.y * 0.5)
	_toast_timer.start(3.5)


func last_toast() -> String:
	return _toast_label.text if _toast.visible else ""
