extends SceneTree
## LR-29 bisect: static memory over N full bot runs in the pure domain (no
## scenes, no autoload UI). godot --headless --path . --script res://tools/profile/mem_domain.gd -- --runs=60


func _init() -> void:
	var n := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			n = int(a.get_slice("=", 1))
	var line := PackedStringArray()
	for i in n:
		var res: Dictionary = AutoPlayer.play_run(RunReducer.new_run(7000 + i, "BARK" if i % 2 == 0 else "SPORE"))
		res.clear()
		if i % 5 == 0 or i == n - 1:
			line.append("%d:%.1fMB/%d" % [i, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	print("MEM_DOMAIN ", " ".join(line))
	quit()
