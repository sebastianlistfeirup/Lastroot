extends Node
## Deterministic-ish battle screenshots for visual A/B checks (draw-call work):
##   XDG_DATA_HOME=/tmp/xdg_x xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --fixed-fps 60 \
##     --rendering-method gl_compatibility --resolution 1920x1080 res://tools/profile/parity_capture.tscn \
##     -- --state=midbattle|boss|full_tree --out=/abs/path.png [--frames=90] [--no-merge]
## --fixed-fps makes every tween advance by the same delta per frame, so two runs
## differ only by particles. --no-merge turns ProxyMerge off (the old path).

var state := "midbattle"
var out := ""
var frames := 90


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--state="):
			state = a.trim_prefix("--state=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--frames="):
			frames = int(a.trim_prefix("--frames="))
		elif a == "--no-merge":
			if ResourceLoader.exists("res://scripts/runtime/visual/proxy_merge.gd"):
				(load("res://scripts/runtime/visual/proxy_merge.gd") as GDScript).set("enabled", false)
	seed(12345)
	_main.call_deferred()


func _main() -> void:
	var run: Dictionary
	if state == "full_tree":
		var sp: Node = (load("res://tools/profile/stress_profile.gd") as GDScript).new()
		run = sp.call("_full_tree")
		sp.free()
	else:
		run = DebugFixtures.make(state, "BARK", 2)
	GameSession.run = run
	GameSession.presentation_pending = false
	var scr: Node = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(scr)
	for i in frames:
		await RenderingServer.frame_post_draw
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var img := get_viewport().get_texture().get_image()
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		img.save_png(out)
	print("PARITY %s draw_calls=%d -> %s" % [state, dc, out])
	get_tree().quit(0)
