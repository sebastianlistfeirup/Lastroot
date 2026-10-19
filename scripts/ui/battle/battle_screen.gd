class_name BattleScreen
extends Node
## Battle scene (bible p.16): 3D tree diorama + real Control HUD.
## Flow: tap card -> tap legal target -> forecast preview -> Confirm (or tap
## the same target again). Tap an own creature to move it. Input is locked
## while the presenter replays a resolution. The HUD never edits state.

var stage: TreeStage
var presenter: BattlePresenter
var battle: Dictionary = {}      # authoritative (GameSession)
var prev_battle: Dictionary = {}  # what is on screen before playback
var disp: Dictionary = {}         # unit_id(str) -> displayed snapshot
var views: Dictionary = {}        # unit_id(int) -> UnitView
var badges: Dictionary = {}       # unit_id(int) -> UnitBadge

var locked: bool = false
var mode: String = "idle"         # idle | card | move
var selected_card: int = -1
var selected_unit: int = -1
var pending: Dictionary = {}
var awaiting_heal_target: bool = false
var legal_units: Array = []
var legal_floors: Array = []
var portrait: bool = false
var hints_dismissed: bool = false
var battle_over: bool = false

# HUD nodes
var hud: CanvasLayer
var root: Control
var overlay: Control
var top_bar: HFlowContainer
var lbl_heart: Label
var lbl_sap: Label
var lbl_turn: Label
var lbl_wave: Label
var lbl_piles: Label
var lbl_relics: Label
var right_panel: PanelContainer
var forecast_box: VBoxContainer
var inspector: Label
var btn_confirm: Button
var btn_cancel: Button
var btn_end: Button
var btn_speed: Button
var btn_skip: Button
var btn_menu: Button
var hand_scroll: ScrollContainer
var hand_box: HBoxContainer
var toast_box: VBoxContainer
var hint_panel: PanelContainer
var hint_label: Label
var reason_label: Label
var end_banner: PanelContainer
var ghost_nodes: Array[Control] = []
var floor_buttons: Array[Button] = []


func _ready() -> void:
	stage = TreeStage.new()
	add_child(stage)
	stage.build()
	presenter = BattlePresenter.new()
	presenter.screen = self
	add_child(presenter)
	_build_hud()
	UnitAnimator.reduced_motion = SettingsService.reduced_motion
	SettingsService.changed.connect(_on_settings_changed)
	GameSession.run_changed.connect(_on_run_changed)
	GameSession.command_rejected.connect(_on_rejected)
	AppFlow.layout_changed.connect(func(_p: bool) -> void: _relayout())
	get_viewport().size_changed.connect(_relayout)
	battle = GameSession.battle()
	if battle.is_empty():
		AppFlow.goto_phase()
		return
	_full_sync()
	_relayout()
	call_deferred("_relayout")
	AudioBridge.play("music_boss" if battle.get("is_boss", false) else "music_battle")


# ------------------------------------------------------------------ HUD build

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	# Floor tap targets (spells aimed at a floor) live under the badges.
	for f in 3:
		var fb := Button.new()
		fb.flat = true
		fb.focus_mode = Control.FOCUS_NONE
		fb.visible = false
		fb.add_theme_stylebox_override("normal", UiKit.panel_style(Color(0.25, 0.9, 0.8, 0.10), UiKit.LIFE, 14, 2))
		fb.add_theme_stylebox_override("hover", UiKit.panel_style(Color(0.25, 0.9, 0.8, 0.20), UiKit.LIFE, 14, 3))
		fb.add_theme_stylebox_override("pressed", UiKit.panel_style(Color(0.25, 0.9, 0.8, 0.3), UiKit.LIFE, 14, 3))
		fb.add_theme_font_size_override("font_size", 20)
		fb.pressed.connect(_on_floor_pressed.bind(f))
		overlay.add_child(fb)
		floor_buttons.append(fb)
	# Top bar
	var top := UiKit.panel(Color(0.06, 0.08, 0.13, 0.92), UiKit.LINE)
	top.name = "TopBar"
	root.add_child(top)
	top_bar = HFlowContainer.new()
	top_bar.add_theme_constant_override("h_separation", 22)
	top.add_child(top_bar)
	lbl_heart = _top_label(UiKit.LIFE)
	lbl_sap = _top_label(UiKit.LIFE)
	lbl_turn = _top_label(UiKit.TEXT)
	lbl_wave = _top_label(Color("ff9a5a"))
	lbl_piles = _top_label(UiKit.TEXT_DIM)
	lbl_piles.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl_piles.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_toggle_piles())
	lbl_relics = _top_label(UiKit.AMBER)
	btn_speed = UiKit.button("1×", UiKit.LIFE, 18)
	btn_speed.custom_minimum_size = Vector2(UiKit.MIN_HIT * 1.3, UiKit.MIN_HIT)
	btn_speed.pressed.connect(_cycle_speed)
	top_bar.add_child(btn_speed)
	btn_menu = UiKit.button(Loc.t("Menu"), UiKit.TEXT_DIM, 18)
	btn_menu.pressed.connect(_open_menu)
	top_bar.add_child(btn_menu)
	# Right panel: forecast, inspector, actions
	right_panel = UiKit.panel(Color(0.07, 0.09, 0.15, 0.94), UiKit.LINE)
	right_panel.name = "RightPanel"
	root.add_child(right_panel)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right_panel.add_child(rv)
	rv.add_child(UiKit.label(Loc.t("Forecast — end of turn"), 20, UiKit.LIFE, true))
	var fscroll := ScrollContainer.new()
	fscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(fscroll)
	forecast_box = VBoxContainer.new()
	forecast_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fscroll.add_child(forecast_box)
	inspector = UiKit.label("", 16, UiKit.TEXT_DIM)
	rv.add_child(inspector)
	reason_label = UiKit.label("", 16, UiKit.DANGER)
	rv.add_child(reason_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	rv.add_child(row)
	btn_cancel = UiKit.button(Loc.t("Cancel"), UiKit.TEXT_DIM)
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.pressed.connect(_cancel)
	row.add_child(btn_cancel)
	btn_confirm = UiKit.button(Loc.t("Confirm"), UiKit.LIFE)
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.pressed.connect(_confirm)
	row.add_child(btn_confirm)
	btn_end = UiKit.button(Loc.t("End turn"), UiKit.AMBER, 22)
	btn_end.custom_minimum_size.y = 64
	btn_end.pressed.connect(_end_turn)
	rv.add_child(btn_end)
	btn_skip = UiKit.button(Loc.t("Skip animation"), UiKit.TEXT_DIM)
	btn_skip.visible = false
	btn_skip.pressed.connect(func() -> void: presenter.skip())
	rv.add_child(btn_skip)
	# Hand
	hand_scroll = ScrollContainer.new()
	hand_scroll.name = "Hand"
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(hand_scroll)
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 10)
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.add_child(hand_box)
	# Toasts + hints
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(toast_box)
	hint_panel = UiKit.panel(Color(0.08, 0.12, 0.16, 0.95), UiKit.LIFE)
	var hv := HBoxContainer.new()
	hint_panel.add_child(hv)
	hint_label = UiKit.label("", 17, UiKit.TEXT)
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(hint_label)
	var got := UiKit.button(Loc.t("Got it"), UiKit.LIFE, 16)
	got.pressed.connect(func() -> void:
		hints_dismissed = true
		hint_panel.visible = false)
	hv.add_child(got)
	root.add_child(hint_panel)


func _top_label(c: Color) -> Label:
	var l := UiKit.label("", 20, c, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.y = UiKit.MIN_HIT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(l)
	return l


func _relayout() -> void:
	if root == null:
		return
	var vp: Vector2 = root.get_viewport_rect().size
	portrait = UiKit.is_portrait(vp)
	var top: Control = root.get_node("TopBar")
	top.position = Vector2(8, 6)
	top.size = Vector2(vp.x - 16, 0)
	var top_h: float = top.get_combined_minimum_size().y
	for l in [lbl_heart, lbl_sap, lbl_turn, lbl_wave, lbl_piles, lbl_relics]:
		l.add_theme_font_size_override("font_size", int((15 if portrait else 20) * UiKit.font_scale))
	lbl_piles.visible = not portrait
	for uid: int in badges.keys():
		(badges[uid] as UnitBadge).set_compact(portrait)
	inspector.visible = not portrait
	btn_end.custom_minimum_size.y = 50 if portrait else 64
	(right_panel.get_child(0).get_child(0) as Control).visible = not portrait
	if portrait:
		top_h = top.get_combined_minimum_size().y
		var card_h := 176.0
		hand_scroll.position = Vector2(4, vp.y - card_h - 6)
		hand_scroll.size = Vector2(vp.x - 8, card_h)
		right_panel.position = Vector2(6, vp.y - card_h - 230)
		right_panel.size = Vector2(vp.x - 12, 222)
		hint_label.custom_minimum_size.x = vp.x - 150
		hint_panel.position = Vector2(8, vp.y - card_h - 230 - 4)
		hint_panel.size = Vector2(vp.x - 16, 0)
		hint_panel.reset_size()
		toast_box.position = Vector2(vp.x * 0.5 - 180, top_h + 90)
		toast_box.size = Vector2(360, 120)
		for c in hand_box.get_children():
			(c as Control).scale = Vector2.ONE
		stage.frame_camera(true, 0.0)
	else:
		var rw := 440.0
		right_panel.position = Vector2(vp.x - rw - 8, top_h + 16)
		right_panel.size = Vector2(rw, vp.y - top_h - 24)
		var hand_h := 252.0
		hand_scroll.position = Vector2(8, vp.y - hand_h - 8)
		hand_scroll.size = Vector2(vp.x - rw - 24, hand_h)
		hint_label.custom_minimum_size.x = minf(680.0, vp.x - rw - 180)
		hint_panel.position = Vector2(12, 78)
		hint_panel.size = Vector2(minf(820.0, vp.x - rw - 40), 0)
		hint_panel.reset_size()
		toast_box.position = Vector2((vp.x - rw) * 0.5 - 220, top_h + 80)
		toast_box.size = Vector2(440, 160)
		stage.frame_camera(false, rw / vp.x)
	if not battle.is_empty():
		_refresh_top()
	_refresh_hand()


# ------------------------------------------------------------------ syncing

func unit_snapshot(uid: int) -> Dictionary:
	return battle.get("units", {}).get(str(uid), {})


func view(uid: int) -> UnitView:
	return views.get(uid)


func spawn_view(u: Dictionary, at: Vector3) -> UnitView:
	var uid: int = int(u["unit_id"])
	if views.has(uid):
		return views[uid]
	var v := UnitView.new()
	stage.add_child(v)
	v.setup(u)
	v.position = at
	views[uid] = v
	var b := UnitBadge.new()
	b.pressed.connect(_on_badge_pressed)
	b.set_compact(portrait)
	overlay.add_child(b)
	badges[uid] = b
	refresh_badge(uid)
	return v


func remove_view(uid: int) -> void:
	if views.has(uid):
		(views[uid] as Node).queue_free()
		views.erase(uid)
	if badges.has(uid):
		(badges[uid] as Node).queue_free()
		badges.erase(uid)


func refresh_badge(uid: int) -> void:
	if not badges.has(uid) or not disp.has(str(uid)):
		return
	var u: Dictionary = disp[str(uid)]
	var b: UnitBadge = badges[uid]
	var atk: int = int(u.get("attack", 0))
	if u.get("side", "") == "ally" and int(u.get("floor", 0)) == 1 and (battle.get("mutations", []) as Array).has("M02"):
		atk += 1
	b.show_unit(u, atk)


## Order of the living display units on a floor, following the authoritative
## lists where they exist so nothing ever swaps places visually by accident.
func _floor_order(f: int, side: String, d: Dictionary) -> Array:
	var final_list: Array = battle.get("floors", [{}, {}, {}])[f].get("allies" if side == "ally" else "enemies", []) if not battle.is_empty() else []
	var prev_list: Array = prev_battle.get("floors", [{}, {}, {}])[f].get("allies" if side == "ally" else "enemies", []) if not prev_battle.is_empty() else []
	var ids: Array = []
	for key: String in d.keys():
		var u: Dictionary = d[key]
		if u.get("alive", true) and str(u.get("side", "")) == side and int(u.get("floor", -1)) == f and views.has(int(key)):
			ids.append(int(key))
	ids.sort_custom(func(a: int, b: int) -> bool:
		var ka: int = final_list.find(a) if final_list.has(a) else 1000 + prev_list.find(a)
		var kb: int = final_list.find(b) if final_list.has(b) else 1000 + prev_list.find(b)
		if ka == kb:
			return a < b
		return ka < kb)
	return ids


func layout_floor(f: int, d: Dictionary, dur: float) -> void:
	var allies: Array = _floor_order(f, "ally", d)
	var spaces: Array = []
	for uid: int in allies:
		spaces.append(int(d[str(uid)].get("space", 1)))
	for i in allies.size():
		(views[allies[i]] as UnitView).move_to(StageLayout.ally_pos(f, i, spaces), dur)
		(views[allies[i]] as UnitView).set_meta("slot_index", i)
	var enemies: Array = _floor_order(f, "enemy", d)
	for i in enemies.size():
		var u: Dictionary = d[str(enemies[i])]
		(views[enemies[i]] as UnitView).move_to(StageLayout.enemy_pos(f, i, enemies.size(), u.get("is_boss", false)), dur)
		(views[enemies[i]] as UnitView).set_meta("slot_index", i)


func layout_all(d: Dictionary, dur: float) -> void:
	for f in 3:
		layout_floor(f, d, dur)


## Snap everything to the authoritative state (after load, skip or playback).
func _full_sync() -> void:
	battle = GameSession.battle()
	if battle.is_empty():
		return
	var living := {}
	for key: String in battle["units"].keys():
		var u: Dictionary = battle["units"][key]
		if u["alive"]:
			living[int(key)] = true
	for uid: int in views.keys().duplicate():
		if not living.has(uid):
			remove_view(uid)
	disp = {}
	for uid: int in living.keys():
		var u: Dictionary = battle["units"][str(uid)]
		disp[str(uid)] = u.duplicate()
		spawn_view(u, Vector3.ZERO)
	prev_battle = battle
	layout_all(disp, 0.0)
	for uid: int in living.keys():
		refresh_badge(uid)
	stage.apply_mutations(battle.get("mutations", []))
	_clear_selection()
	_refresh_all()


# ------------------------------------------------------------- command flow

func _on_run_changed(events: Array) -> void:
	if GameSession.phase() != "battle" and GameSession.battle().is_empty() and events.is_empty():
		return
	if events.is_empty():
		_full_sync()
		return
	var visual_events: Array = events.filter(func(e: Dictionary) -> bool: return not (e["kind"] in ["card_drawn"]))
	battle = GameSession.battle() if not GameSession.battle().is_empty() else battle
	_set_locked(true)
	_clear_targets()
	presenter.speed = _anim_speed()
	var long_play: bool = events.any(func(e: Dictionary) -> bool: return e.get("kind", "") == "resolution_end")
	btn_skip.visible = long_play
	await presenter.play(visual_events, disp)
	btn_skip.visible = false
	GameSession.presentation_done()
	if GameSession.phase() == "battle":
		_full_sync()
		_set_locked(false)
		if _rebuild_pending:
			_rebuild_hud()
	else:
		_show_end_banner()


## Text size / language / motion changed in the pause menu: rebuild the
## screen from the saved state (the battle itself is untouched).
var _rebuild_pending := false


func _on_settings_changed() -> void:
	UnitAnimator.reduced_motion = SettingsService.reduced_motion
	presenter.speed = _anim_speed()
	if locked or presenter.playing:
		_rebuild_pending = true
		return
	_rebuild_hud()


func _rebuild_hud() -> void:
	_rebuild_pending = false
	var keep_pause := _pause != null and bool(_pause.get("is_open"))
	for uid: int in badges.keys():
		(badges[uid] as Node).queue_free()
	badges.clear()
	hud.queue_free()
	if _pause != null:
		_pause.queue_free()
		_pause = null
	ghost_nodes.clear()
	floor_buttons.clear()
	_piles_panel = null
	_build_hud()
	for uid: int in views.keys():
		var b := UnitBadge.new()
		b.pressed.connect(_on_badge_pressed)
		overlay.add_child(b)
		badges[uid] = b
		refresh_badge(uid)
	_relayout()
	_refresh_all()
	if keep_pause:
		_open_menu()


func _on_rejected(reason: String) -> void:
	reason_label.text = reason
	AudioBridge.play("ui_invalid")


func _set_locked(v: bool) -> void:
	locked = v
	btn_end.disabled = v
	btn_confirm.disabled = v or pending.is_empty()
	btn_cancel.disabled = v
	for c in hand_box.get_children():
		(c as CardView).playable = (not v) and _card_playable((c as CardView).instance_id)


func _end_turn() -> void:
	if locked or battle_over:
		return
	_clear_selection()
	AudioBridge.play("ui_confirm")
	GameSession.battle_cmd({"type": "end_turn"})


func _confirm() -> void:
	if locked or pending.is_empty():
		return
	var cmd: Dictionary = pending
	_clear_selection()
	AudioBridge.play("ui_confirm")
	var r: Dictionary = GameSession.battle_cmd(cmd)
	if not r["ok"]:
		_refresh_all()


func _cancel() -> void:
	_clear_selection()
	AudioBridge.play("ui_cancel")
	_refresh_all()


func _clear_selection() -> void:
	mode = "idle"
	selected_card = -1
	selected_unit = -1
	pending = {}
	awaiting_heal_target = false
	legal_units = []
	legal_floors = []
	if reason_label != null:
		reason_label.text = ""
	_clear_targets()


# --------------------------------------------------------------- selection

func _card_playable(iid: int) -> bool:
	if battle.is_empty() or battle["phase"] != "player":
		return false
	return BattleReducer.play_cost(battle, iid) <= int(battle["energy"])


func _on_card_pressed(iid: int) -> void:
	if locked or battle_over:
		return
	if selected_card == iid:
		_cancel()
		return
	_clear_selection()
	AudioBridge.play("ui_click")
	var def: Dictionary = BattleReducer.card_def(battle, iid)
	selected_card = iid
	mode = "card"
	if not _card_playable(iid):
		reason_label.text = Loc.t("Not enough Sap (needs %d).") % BattleReducer.play_cost(battle, iid)
	if Catalog.is_creature(def):
		_show_insert_slots(int(def["space"]))
		inspector.text = Loc.t("Tap a + spot on a floor to place it. The front is next to the trunk.")
	else:
		var legal: Dictionary = BattleReducer.spell_targets(battle, def)
		legal_units = legal["units"]
		legal_floors = legal["floors"]
		var tgt: String = def["spell"]["target"]
		if tgt == "all_enemies":
			if legal_floors.is_empty():
				reason_label.text = Loc.t("There are no enemies to affect.")
			else:
				pending = {"type": "play_card", "card": iid}
				_preview()
		elif legal_units.is_empty() and legal_floors.is_empty():
			reason_label.text = BattleReducer.validate(battle, {"type": "play_card", "card": iid, "target": -1, "floor": -1})
		inspector.text = Loc.t("Choose a highlighted target.") if pending.is_empty() else ""
	_refresh_all()


func _on_badge_pressed(uid: int) -> void:
	if locked or battle_over:
		return
	var u: Dictionary = unit_snapshot(uid)
	if mode == "card" and awaiting_heal_target:
		if legal_units.has(uid):
			pending["target"] = uid
			awaiting_heal_target = false
			_preview()
		return
	if mode == "card" and legal_units.has(uid):
		if pending.get("target", -2) == uid:
			_confirm()
			return
		pending = {"type": "play_card", "card": selected_card, "target": uid}
		_preview()
		return
	if mode == "move" and selected_unit == uid:
		_cancel()
		return
	# Inspect; own creatures enter move mode.
	_clear_selection()
	inspector.text = _describe_unit(u)
	if not u.is_empty() and u["side"] == "ally" and battle["phase"] == "player":
		if u["moved_this_turn"]:
			reason_label.text = Loc.t("It has already moved this turn.")
		else:
			mode = "move"
			selected_unit = uid
			_show_move_slots(u)
			inspector.text += "\n" + Loc.t("Move: tap a + spot on this or a neighbouring floor (%d Sap).") % BattleReducer.move_cost(battle)
	_refresh_all()


func _on_slot_pressed(f: int, pos: int) -> void:
	if locked:
		return
	if mode == "card":
		var def: Dictionary = BattleReducer.card_def(battle, selected_card)
		var cmd := {"type": "play_card", "card": selected_card, "floor": f, "position": pos}
		if pending.get("floor", -1) == f and pending.get("position", -1) == pos and not awaiting_heal_target:
			_confirm()
			return
		pending = cmd
		if def.get("on_play", {}).get("op", "") == "heal_other_ally" and not BattleReducer.all_allies(battle).is_empty():
			awaiting_heal_target = true
			legal_units = BattleReducer.all_allies(battle)
			inspector.text = Loc.t("Now tap another ally to heal.")
			_refresh_all()
			return
		_preview()
	elif mode == "move":
		var cmd := {"type": "move", "unit": selected_unit, "floor": f, "position": pos}
		if pending.get("floor", -1) == f and pending.get("position", -1) == pos:
			_confirm()
			return
		pending = cmd
		_preview()


func _on_floor_pressed(f: int) -> void:
	if locked or mode != "card" or not legal_floors.has(f):
		return
	if pending.get("floor", -1) == f:
		_confirm()
		return
	pending = {"type": "play_card", "card": selected_card, "floor": f}
	_preview()


func _preview() -> void:
	var err: String = BattleReducer.validate(battle, pending)
	if err != "":
		reason_label.text = err
		pending = {}
		_refresh_all()
		return
	reason_label.text = ""
	inspector.text = Loc.t("Preview shown. Confirm, or tap the same target again.")
	_refresh_all()


# ------------------------------------------------------------ target ghosts

func _clear_targets() -> void:
	for n in ghost_nodes:
		n.queue_free()
	ghost_nodes.clear()
	for fb in floor_buttons:
		fb.visible = false
	for uid: int in badges.keys():
		(badges[uid] as UnitBadge).set_highlight("")


func _ghost(f: int, pos: int, world: Vector3, ok: bool, text: String) -> void:
	var b := UiKit.button(text, UiKit.LIFE if ok else UiKit.DANGER, 22)
	b.custom_minimum_size = Vector2(UiKit.MIN_HIT, UiKit.MIN_HIT)
	b.disabled = not ok
	b.set_meta("world", world)
	if ok:
		b.pressed.connect(_on_slot_pressed.bind(f, pos))
	overlay.add_child(b)
	ghost_nodes.append(b)


func _floor_spaces(f: int, exclude: int = -1) -> Array:
	var sp: Array = []
	for uid: int in BattleReducer.floor_list(battle, f, "ally"):
		if uid != exclude:
			sp.append(int(unit_snapshot(uid)["space"]))
	return sp


func _show_insert_slots(space: int) -> void:
	for f in 3:
		var used: int = BattleReducer.used_space(battle, f)
		var cap: int = BattleReducer.capacity(battle, f)
		var sp: Array = _floor_spaces(f)
		if used + space > cap:
			_ghost(f, 0, StageLayout.ally_slot_pos(f, 0, sp) + Vector3(-1.2, 0.9, 0), false, Loc.t("Full %d/%d") % [used, cap])
			continue
		for i in sp.size() + 1:
			_ghost(f, i, StageLayout.ally_slot_pos(f, i, sp) + Vector3(0, 0.9, 0), true, "+")


func _show_move_slots(u: Dictionary) -> void:
	var uid: int = int(u["unit_id"])
	var from_f: int = int(u["floor"])
	for f in [from_f - 1, from_f, from_f + 1]:
		if f < 0 or f > 2:
			continue
		var sp: Array = _floor_spaces(f, uid)
		if f != from_f and BattleReducer.used_space(battle, f) + int(u["space"]) > BattleReducer.capacity(battle, f):
			_ghost(f, 0, StageLayout.ally_slot_pos(f, 0, sp) + Vector3(-1.2, 0.9, 0), false, Loc.t("Full"))
			continue
		var cur: int = BattleReducer.floor_list(battle, f, "ally").find(uid)
		for i in sp.size() + 1:
			if f == from_f and i == cur:
				continue
			_ghost(f, i, StageLayout.ally_slot_pos(f, i, sp) + Vector3(0, 0.9, 0), true, "+")


func _process(_dt: float) -> void:
	if stage == null or stage.camera == null:
		return
	var cam: Camera3D = stage.camera
	for uid: int in badges.keys():
		if not views.has(uid):
			continue
		var b: UnitBadge = badges[uid]
		var p: Vector2 = cam.unproject_position((views[uid] as UnitView).head_world())
		b.size = b.get_combined_minimum_size()
		# Alternate badge heights so neighbours never cover each other.
		var lift: float = 40.0 if int((views[uid] as Node).get_meta("slot_index", 0)) % 2 == 1 else 0.0
		b.position = p - Vector2(b.size.x * 0.5, b.size.y + lift)
	for g in ghost_nodes:
		var w: Vector3 = g.get_meta("world")
		g.size = g.get_combined_minimum_size()
		g.position = cam.unproject_position(w) - g.size * 0.5
	for f in 3:
		var fb: Button = floor_buttons[f]
		if not fb.visible:
			continue
		var a: Vector2 = cam.unproject_position(Vector3(-5.8, StageLayout.floor_y(f) + 2.7, 0))
		var c: Vector2 = cam.unproject_position(Vector3(5.8, StageLayout.floor_y(f) - 0.3, 0))
		fb.position = Vector2(minf(a.x, c.x), minf(a.y, c.y))
		fb.size = (c - a).abs()


# --------------------------------------------------------------- refreshing

func _refresh_all() -> void:
	if battle.is_empty():
		return
	_refresh_top()
	_refresh_hand()
	_refresh_targets()
	_refresh_forecast()
	_refresh_hints()
	btn_confirm.disabled = locked or pending.is_empty()
	btn_cancel.disabled = locked or (mode == "idle")
	btn_end.disabled = locked or battle["phase"] != "player"


func _refresh_top() -> void:
	lbl_heart.text = "%s %d/%d" % [UiKit.status_glyph("hp"), battle["heart"], battle["heart_max"]]
	lbl_heart.tooltip_text = Loc.t("World Heart")
	lbl_sap.text = "%s %d %s" % [UiKit.status_glyph("sap"), battle["energy"], Loc.t("Sap")]
	if portrait:
		lbl_turn.text = Loc.t("B%d · T%d") % [int(battle["battle_index"]) + 1, battle["turn"]]
	else:
		lbl_turn.text = Loc.t("Battle %d/6 · Turn %d") % [int(battle["battle_index"]) + 1, battle["turn"]]
	var waves: Array = battle["waves"]
	var wi: int = int(battle["wave_index"])
	if wi < waves.size():
		var w: Dictionary = waves[wi]
		var counts := {}
		for eid: String in w["enemies"]:
			counts[eid] = int(counts.get(eid, 0)) + 1
		var parts: PackedStringArray = []
		for eid: String in counts.keys():
			parts.append("%d× %s" % [counts[eid], Loc.field(Catalog.enemy(eid), "name")])
		var when: int = int(w["turn"]) - int(battle["turn"])
		lbl_wave.text = (Loc.t("Next turn: %s") if when <= 1 else Loc.t("In %d turns: %s").replace("%d", str(when))) % ", ".join(parts)
	else:
		lbl_wave.text = Loc.t("Last wave is in") if portrait else Loc.t("Last wave is in · defeat every enemy")
	var z: Dictionary = battle["zones"]
	lbl_piles.text = Loc.t("Draw %d · Discard %d · Played %d") % [(z["draw"] as Array).size(), (z["discard"] as Array).size(), (z["deployed"] as Array).size() + (z["consumed"] as Array).size()]
	var rel: PackedStringArray = []
	for rid: String in battle["relics"]:
		rel.append(Loc.field(Catalog.relic(rid), "name"))
	for mid: String in battle["mutations"]:
		rel.append(Loc.field(Catalog.mutation(mid), "name"))
	lbl_relics.text = " · ".join(rel)
	lbl_relics.visible = not rel.is_empty()
	btn_speed.text = "%s×" % str(_anim_speed()).trim_suffix(".0")


func _refresh_hand() -> void:
	if hand_box == null or battle.is_empty():
		return
	for c in hand_box.get_children():
		c.queue_free()
	for iid: int in battle["zones"]["hand"]:
		var inst: Dictionary = battle["deck"][str(iid)]
		var cv := CardView.new()
		cv.cost_override = BattleReducer.play_cost(battle, iid)
		cv.setup(inst["def_id"], inst["upgrade_id"], str(battle["champion_path"]), int(battle["champion_rank"]), iid)
		cv.selected = iid == selected_card
		cv.playable = (not locked) and _card_playable(iid)
		cv.pressed.connect(_on_card_pressed.bind(iid))
		if portrait:
			cv.set_compact(true)
		hand_box.add_child(cv)


func _refresh_targets() -> void:
	for uid: int in badges.keys():
		var h := ""
		if mode == "card" and legal_units.has(uid):
			h = "target"
		if pending.get("target", -1) == uid or (mode == "move" and selected_unit == uid):
			h = "selected"
		(badges[uid] as UnitBadge).set_highlight(h)
		if views.has(uid):
			(views[uid] as UnitView).set_ring(StringName(h) if h != "" else &"none")
	for f in 3:
		var show: bool = mode == "card" and legal_floors.has(f) and not awaiting_heal_target
		floor_buttons[f].visible = show
		floor_buttons[f].text = Catalog.floor_name(f) if show else ""
		if show and pending.get("floor", -1) == f:
			floor_buttons[f].text = "✔ " + Loc.t(Catalog.floor_name(f))


func _refresh_forecast() -> void:
	for c in forecast_box.get_children():
		c.queue_free()
	var fc: Dictionary
	var title: String
	if not pending.is_empty() and not awaiting_heal_target:
		fc = Forecast.after_command(battle, pending)
		title = Loc.t("If you confirm and then end the turn:")
	else:
		fc = Forecast.end_turn(battle)
		title = Loc.t("If you end the turn now:")
	if not fc.get("ok", false):
		forecast_box.add_child(UiKit.label(str(fc.get("error", "")), 16, UiKit.DANGER))
		return
	var sm: Dictionary = fc["summary"]
	forecast_box.add_child(UiKit.label(title, 16, UiKit.TEXT_DIM))
	var heart_line := UiKit.label("%s %s %d → %d" % [UiKit.status_glyph("hp"), Loc.t("Heart"), battle["heart"], sm["heart_after"]], 20,
		UiKit.DANGER if int(sm["heart_damage"]) > 0 else UiKit.GOOD, true)
	forecast_box.add_child(heart_line)
	match str(sm["result"]):
		"won":
			forecast_box.add_child(UiKit.label(Loc.t("Victory: every wave is defeated."), 18, UiKit.GOOD, true))
		"lost":
			forecast_box.add_child(UiKit.label(Loc.t("DEFEAT: the Heart falls.") if not sm["boss_escapes"] else Loc.t("DEFEAT: the Ash Crown leaves the Crown."), 18, UiKit.DANGER, true))
	if sm["boss_on_crown"] and not sm["boss_escapes"]:
		forecast_box.add_child(UiKit.label(Loc.t("Warning: the Ash Crown is on the Crown. Keep a defender there."), 16, UiKit.AMBER))
	var after: Dictionary = fc["state"]
	for key: String in sm["units"].keys():
		var d: Dictionary = sm["units"][key]
		var u: Dictionary = battle["units"][key]
		var nm: String = _unit_name(u)
		var line := ""
		var col: Color = UiKit.TEXT
		var badge_text := ""
		var danger := false
		if d["dies"]:
			line = "✝ %s %s" % [nm, Loc.t("dies")]
			col = UiKit.GOOD if u["side"] == "enemy" else UiKit.DANGER
			badge_text = "✝"
			danger = u["side"] == "ally"
		elif d["escapes"]:
			var dmg: int = maxi(1, int(after["units"][key]["attack"]))
			line = "→ %s %s −%d" % [nm, Loc.t("reaches the Heart"), dmg]
			col = UiKit.DANGER
			badge_text = "→ ♥ −%d" % dmg
			danger = true
		else:
			if d["floor"][0] != d["floor"][1]:
				line = "↑ %s → %s" % [nm, Loc.t(Catalog.floor_name(int(d["floor"][1])))]
				badge_text = "↑ " + Loc.t(Catalog.floor_name(int(d["floor"][1])))
				col = Color("ffb07a")
			if d["hp"][0] != d["hp"][1]:
				var hp_txt := "♥ %d→%d" % [d["hp"][0], d["hp"][1]]
				line = (line + "  " if line != "" else nm + " ") + hp_txt
				badge_text = (badge_text + " " if badge_text != "" else "") + hp_txt
				danger = u["side"] == "ally" and int(d["hp"][1]) < int(d["hp"][0])
		if badges.has(int(key)):
			(badges[int(key)] as UnitBadge).show_forecast(badge_text, danger)
		if line != "":
			forecast_box.add_child(UiKit.label(line, 16, col))


func _refresh_hints() -> void:
	if hints_dismissed or int(battle.get("battle_index", 0)) != 0 or int(battle["turn"]) > 3:
		hint_panel.visible = false
		return
	hint_panel.visible = true
	var champ_in_hand: bool = (battle["zones"]["hand"] as Array).has(int(battle["champion_iid"]))
	if int(battle["turn"]) == 1 and champ_in_hand:
		hint_label.text = Loc.t("Tap your champion, then a + spot on a floor. Champions cost 0 Sap and hold the line.")
	elif int(battle["energy"]) > 0:
		hint_label.text = Loc.t("Spend your Sap: creatures guard a floor, spells act at once. Card → target → Confirm.")
	else:
		hint_label.text = Loc.t("The forecast is exactly what ending the turn will do. Enemies climb a floor each turn; past the Crown they strike the Heart.")
	hint_panel.call_deferred("reset_size")


# ------------------------------------------------------------- feedback

func popup(uid: int, text: String, color: Color) -> void:
	if not views.has(uid) or stage.camera == null:
		return
	var l := UiKit.label(text, 26, color, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(l)
	var p: Vector2 = stage.camera.unproject_position((views[uid] as UnitView).head_world())
	l.position = p + Vector2(-20 + randf_range(-14, 14), -70)
	var t := l.create_tween()
	var rise: float = 10.0 if _reduced_motion() else 46.0
	t.tween_property(l, "position:y", l.position.y - rise, 0.8 / _anim_speed())
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.8 / _anim_speed()).set_delay(0.35 / _anim_speed())
	t.tween_callback(l.queue_free)


func toast(text: String, color: Color) -> void:
	var p := UiKit.panel(Color(0.05, 0.07, 0.11, 0.88), color.darkened(0.2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, 20, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var t := p.create_tween()
	t.tween_interval(1.1 / _anim_speed())
	t.tween_property(p, "modulate:a", 0.0, 0.4)
	t.tween_callback(p.queue_free)


## Short, skippable boss introduction with the rules that matter (bible p.14).
func boss_intro() -> void:
	var p := UiKit.panel(Color(0.08, 0.05, 0.05, 0.95), UiKit.DANGER)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UiKit.label(Loc.t("The Ash Crown"), 34, UiKit.DANGER, true))
	for line in [Loc.t("Stays on its floor while a living ally stands there."), Loc.t("If it leaves the Crown, the run is lost."), Loc.t("From turn 10 it gains +2 attack every turn.")]:
		v.add_child(UiKit.label("• " + line, 18, UiKit.TEXT))
	root.add_child(p)
	var vp: Vector2 = root.get_viewport_rect().size
	p.size = Vector2(minf(560.0, vp.x - 24), 0)
	p.reset_size()
	p.position = Vector2((vp.x - p.size.x) * 0.5 - (0.0 if portrait else 220.0), vp.y * 0.28)
	var t := p.create_tween()
	t.tween_interval(2.4 / _anim_speed())
	t.tween_property(p, "modulate:a", 0.0, 0.4)
	t.tween_callback(p.queue_free)


func heart_hit(amount: int, after: int, def_id: String) -> void:
	lbl_heart.text = "%s %d/%d" % [UiKit.status_glyph("hp"), after, battle.get("heart_max", 60)]
	var nm: String = Loc.field(Catalog.enemy(def_id), "name") if def_id != "" else Loc.t("An enemy")
	toast(Loc.t("%s reached the Heart: −%d") % [nm, amount], UiKit.DANGER)


## One-shot visual effect at a unit (fx.* slots free themselves).
func fx_at(uid: int, slot_id: String) -> void:
	if not views.has(uid):
		return
	var n: Node3D = VisualBridge.make(slot_id)
	stage.add_child(n)
	n.global_position = (views[uid] as UnitView).global_position + Vector3(0, 0.6, 0.3)
	if n.get_meta("is_proxy", false) and not n.has_method("emit") and n.get_child_count() == 0:
		n.queue_free()
		return
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())


## Spore bolt from attacker to target (cast feedback, never decides a hit).
func bolt(from_uid: int, to_uid: int, duration: float) -> void:
	if not views.has(from_uid) or not views.has(to_uid) or not ResourceLoader.exists("res://scripts/runtime/visual/fx_builder.gd"):
		return
	var fb: GDScript = load("res://scripts/runtime/visual/fx_builder.gd")
	fb.call("launch", stage, (views[from_uid] as UnitView).head_world() - Vector3(0, 0.3, 0),
		(views[to_uid] as UnitView).head_world() - Vector3(0, 0.4, 0), duration)


var _piles_panel: PanelContainer


## Draw pile (sorted, never in draw order), discard and played cards.
func _toggle_piles() -> void:
	if _piles_panel != null:
		_piles_panel.queue_free()
		_piles_panel = null
		return
	_piles_panel = UiKit.panel(Color(0.05, 0.07, 0.11, 0.97), UiKit.LIFE)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_piles_panel.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var close := UiKit.button(Loc.t("Close"), UiKit.TEXT_DIM, 18)
	close.pressed.connect(_toggle_piles)
	v.add_child(close)
	var z: Dictionary = battle["zones"]
	for pile in [["draw", Loc.t("Draw pile (sorted; order hidden)")], ["discard", Loc.t("Discard pile")], ["deployed", Loc.t("Played creatures (out for this battle)")], ["consumed", Loc.t("Consumed")]]:
		var ids: Array = (z[pile[0]] as Array).duplicate()
		v.add_child(UiKit.label("%s: %d" % [pile[1], ids.size()], 18, UiKit.LIFE, true))
		var names: PackedStringArray = []
		for iid: int in ids:
			var inst: Dictionary = battle["deck"][str(iid)]
			names.append(Loc.field(Catalog.card(inst["def_id"]), "name") + ("+" if inst["upgrade_id"] != "" else ""))
		names.sort()
		v.add_child(UiKit.label(", ".join(names) if not names.is_empty() else "—", 16, UiKit.TEXT))
	root.add_child(_piles_panel)
	var vp: Vector2 = root.get_viewport_rect().size
	_piles_panel.size = Vector2(minf(560.0, vp.x - 24), minf(520.0, vp.y - 160))
	_piles_panel.position = Vector2(12, 80)


func focus_floor(_f: int) -> void:
	pass  # Camera stays locked (bible: reduced motion keeps it fixed); floor light highlights instead.


func _show_end_banner() -> void:
	battle_over = true
	_set_locked(true)
	var won: bool = GameSession.phase() != "lost"
	end_banner = UiKit.panel(Color(0.05, 0.07, 0.11, 0.96), UiKit.GOOD if won else UiKit.DANGER)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	end_banner.add_child(v)
	var last: Dictionary = GameSession.run.get("last_battle", {})
	v.add_child(UiKit.label(Loc.t("Victory") if won else Loc.t("The Heart has fallen"), 40, UiKit.GOOD if won else UiKit.DANGER, true))
	v.add_child(UiKit.label(Loc.t("Turns: %d · Heart: %d") % [int(last.get("turns", 0)), int(last.get("heart", 0))], 20))
	var b := UiKit.button(Loc.t("Continue"), UiKit.LIFE, 24)
	b.pressed.connect(AppFlow.goto_phase)
	v.add_child(b)
	root.add_child(end_banner)
	var vp: Vector2 = root.get_viewport_rect().size
	end_banner.size = Vector2(minf(520.0, vp.x - 24), 0)
	end_banner.position = Vector2((vp.x - end_banner.size.x) * 0.5, vp.y * 0.3)
	b.grab_focus()


# ---------------------------------------------------------------- helpers

func _unit_name(u: Dictionary) -> String:
	if u.get("side", "") == "enemy":
		return Loc.field(Catalog.enemy(str(u["def_id"])), "name")
	return Loc.field(Catalog.card(str(u["def_id"])), "name")


func _describe_unit(u: Dictionary) -> String:
	if u.is_empty():
		return ""
	var lines: PackedStringArray = [_unit_name(u) + "  (" + Loc.t(Catalog.floor_name(int(u["floor"]))) + ")"]
	lines.append("%s %d   %s %d/%d" % [UiKit.status_glyph("attack"), BattleReducer.attack_value(battle, u), UiKit.status_glyph("hp"), u["hp"], u["max_hp"]])
	if int(u["armor"]) > 0:
		lines.append(Loc.t("◆ Armor %d: absorbs normal damage first. Poison ignores it.") % u["armor"])
	if int(u["poison"]) > 0:
		lines.append(Loc.t("☠ Poison %d: loses that much HP in its floor's poison phase, then −1.") % u["poison"])
	if int(u["thorns"]) > 0:
		lines.append(Loc.t("✶ Thorns %d: deals that much back to every direct attacker.") % u["thorns"])
	if int(u["growth"]) > 0:
		lines.append(Loc.t("✚ Growth %d: heals that much at the end of its floor.") % u["growth"])
	if u.get("is_boss", false):
		lines.append(Loc.t("Stays while a living ally shares its floor. Leaving the Crown means defeat. +2 attack each turn from turn 10."))
	if u["side"] == "ally":
		var def: Dictionary = Catalog.card(str(u["def_id"]))
		var inst: Dictionary = battle["deck"].get(str(u["card_iid"]), {})
		lines.append(CardStats.format_text(Loc.field(def, "text"), def, str(inst.get("upgrade_id", "")), str(battle["champion_path"]), int(battle["champion_rank"])))
	return "\n".join(lines)


func _anim_speed() -> float:
	var s: Variant = SettingsService.get("anim_speed")
	return float(s) if s != null and float(s) > 0.0 else 1.0


func _reduced_motion() -> bool:
	var r: Variant = SettingsService.get("reduced_motion")
	return bool(r) if r != null else false


func _cycle_speed() -> void:
	var next := {1.0: 2.0, 2.0: 0.5, 0.5: 1.0}
	var cur: float = _anim_speed()
	var n: float = next.get(cur, 1.0)
	SettingsService.set_anim_speed(n)
	presenter.speed = n
	btn_speed.text = "%s×" % str(n).trim_suffix(".0")


var _pause: Node


func _open_menu() -> void:
	if ResourceLoader.exists("res://scenes/ui/pause_menu.tscn"):
		if _pause == null:
			_pause = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
			_pause.set("corner_button", false)  # the HUD has its own Menu button
			_pause.set("esc_opens", false)       # Esc first cancels a selection here
			add_child(_pause)
		_pause.call("open")
	else:
		AppFlow.goto("menu")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _pause != null and bool(_pause.get("is_open")):
			_pause.call("close")
		elif mode != "idle":
			_cancel()
		else:
			_open_menu()
		get_viewport().set_input_as_handled()
