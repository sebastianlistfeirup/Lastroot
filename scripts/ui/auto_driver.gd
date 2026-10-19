class_name AutoDriver
extends Node
## QA only (--autoplay[=N]): plays through GameSession with the bot at a
## human-like pace so Movie Maker can record real gameplay: battles, reward,
## route and node screens. Quits after N battles have finished (default 1)
## or when the run ends.

var delay: float = 0.9
var battles: int = 1
var _t: float = 0.0
var _end_t: float = -1.0
var _finished_battles: int = 0
var _was_battle: bool = false


func _process(dt: float) -> void:
	var scr: Node = get_tree().current_scene
	var phase: String = GameSession.phase()
	if phase == "battle":
		_was_battle = true
	elif _was_battle:
		_was_battle = false
		_finished_battles += 1
	if _finished_battles >= battles or phase in ["won", "lost"]:
		_end_t = maxf(_end_t, 0.0) + dt
		if _end_t > 3.0:
			get_tree().quit()
		return
	_t += dt
	if scr is BattleScreen:
		var b: BattleScreen = scr
		if phase != "battle":
			if _t > 2.0:
				_t = 0.0
				AppFlow.goto_phase()
			return
		if b.locked or b.presenter.playing:
			_t = 0.0
			return
		if _t < delay:
			return
		_t = 0.0
		GameSession.battle_cmd(AutoPlayer.choose(GameSession.battle()))
	elif phase in ["reward", "route", "node"]:
		if _t < delay * 1.6:
			return
		_t = 0.0
		GameSession.cmd(AutoPlayer.choose_run(GameSession.run))
