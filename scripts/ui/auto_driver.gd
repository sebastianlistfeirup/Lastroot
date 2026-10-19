class_name AutoDriver
extends Node
## QA only (--autoplay): plays the battle through GameSession with the bot at
## a human-like pace so Movie Maker can record real gameplay. Quits when the
## battle ends (after the end banner has been visible for a moment).

var delay: float = 0.9
var _t: float = 0.0
var _done_t: float = -1.0


func _process(dt: float) -> void:
	var scr: Node = get_tree().current_scene
	if not (scr is BattleScreen):
		return
	var b: BattleScreen = scr
	if GameSession.phase() != "battle":
		if _done_t < 0.0:
			_done_t = 0.0
		_done_t += dt
		if _done_t > 2.5:
			get_tree().quit()
		return
	if b.locked or b.presenter.playing:
		_t = 0.0
		return
	_t += dt
	if _t < delay:
		return
	_t = 0.0
	GameSession.battle_cmd(AutoPlayer.choose(GameSession.battle()))
