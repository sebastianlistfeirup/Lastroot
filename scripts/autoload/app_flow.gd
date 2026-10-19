extends Node
## Scene flow (bible p.27): boot -> menu -> run (route/battle/reward) -> result -> menu.
## Screens never change game state themselves; they call GameSession.

const SCENES := {
	"menu": "res://scenes/menu/main_menu.tscn",
	"battle": "res://scenes/battle/battle.tscn",
	"run": "res://scenes/flow/run_screen.tscn",
	"result": "res://scenes/flow/result_screen.tscn",
}

var current: String = ""


func goto(scene_id: String) -> void:
	if not SCENES.has(scene_id):
		push_error("AppFlow: unknown scene %s" % scene_id)
		return
	current = scene_id
	get_tree().call_deferred("change_scene_to_file", SCENES[scene_id])
