extends Node
## Minimal engine repro (LR-29 leak analysis 21.10): creating and freeing
## Control nodes raises Performance.MEMORY_STATIC by ~50 bytes per Control and
## it never comes back; Node/Node2D/Node3D and raw canvas-item RIDs stay flat.
## Object count stays flat, so nothing in project code holds them.
##   godot --headless --path . res://tools/profile/control_growth.tscn [-- --kind=panel|label|node2d|node]
## Prints CONTROL_GROWTH <kind> <bytes per created node>. Godot 4.5.1-stable and 4.7.1-stable (same 48 B).

var kind := "panel"
const ROUNDS := 120
const PER_ROUND := 40


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kind="):
			kind = a.get_slice("=", 1)
	for i in 10:  # warm-up
		await _round()
	var m0: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var o0: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in ROUNDS:
		await _round()
	var dm: float = Performance.get_monitor(Performance.MEMORY_STATIC) - m0
	var do: int = int(Performance.get_monitor(Performance.OBJECT_COUNT)) - o0
	print("CONTROL_GROWTH %s %.1f bytes/node (static +%.0f B over %d nodes, objects %+d)" % [kind, dm / float(ROUNDS * PER_ROUND), dm, ROUNDS * PER_ROUND, do])
	get_tree().quit()


func _round() -> void:
	var holder: Node = Control.new() if kind in ["panel", "label"] else Node.new()
	add_child(holder)
	for k in PER_ROUND:
		match kind:
			"panel": holder.add_child(Panel.new())
			"label":
				var l := Label.new()
				l.text = "Text"
				holder.add_child(l)
			"node2d": holder.add_child(Node2D.new())
			_: holder.add_child(Node.new())
	for f in 3:
		await get_tree().process_frame
	holder.queue_free()
	for f in 3:
		await get_tree().process_frame
