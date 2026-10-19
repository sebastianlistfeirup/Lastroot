extends Node
## Screenshots of battle interaction states for evidence/shots (Xvfb):
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1920x1080 res://scenes/tests/battle_capture.tscn

func _ready() -> void:
	var out := "res://evidence/shots/"
	GameSession.run = RunReducer.new_run(4242, "BARK")
	var scr: BattleScreen = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(scr)
	await _frames(20)
	scr.hints_dismissed = true
	scr._on_card_pressed(int(GameSession.battle()["champion_iid"]))
	await _frames(10)
	await _shot(out + "battle_select_champion.png")
	for g in scr.ghost_nodes:
		if g is Button and not (g as Button).disabled:
			(g as Button).pressed.emit()
			break
	await _frames(10)
	await _shot(out + "battle_preview_champion.png")
	scr.btn_confirm.pressed.emit()
	for i in 200:
		if not scr.presenter.playing:
			break
		await get_tree().process_frame
	await _frames(10)
	var hand: Array = GameSession.battle()["zones"]["hand"]
	for iid: int in hand:
		if BattleReducer.card_def(GameSession.battle(), iid)["id"] == "B07":
			scr._on_card_pressed(iid)
			break
	await _frames(10)
	await _shot(out + "battle_select_spell.png")
	var enemies: Array = BattleReducer.all_enemies(GameSession.battle())
	if not enemies.is_empty():
		scr._on_badge_pressed(enemies[0])
	await _frames(10)
	await _shot(out + "battle_preview_spell.png")
	scr._cancel()
	scr.btn_end.pressed.emit()
	await _frames(25)
	await _shot(out + "battle_resolving.png")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(p: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("SHOT ", p)
