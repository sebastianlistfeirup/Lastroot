extends Node
## Entry scene. Opens the main menu, or (dev/QA) a named fixture:
##   godot --path . -- --setup=midbattle --faction=SPORE --seed=3
##   ... --capture=evidence/shots/x.png [--frames=90] [--size=1920x1080]


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	if args.has("size"):
		var wh: PackedStringArray = str(args["size"]).split("x")
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if args.has("setup"):
		GameSession.run = DebugFixtures.make(args["setup"], args.get("faction", "BARK"), int(args.get("seed", "1")))
		GameSession.presentation_pending = false
		AppFlow.goto_phase()
	else:
		AppFlow.goto("menu")
	if args.has("autoplay"):
		get_tree().root.call_deferred("add_child", AutoDriver.new())
	if args.has("capture"):
		var cap := DebugCapture.new()
		cap.path = args["capture"]
		cap.frames = int(args.get("frames", "90"))
		get_tree().root.call_deferred("add_child", cap)
