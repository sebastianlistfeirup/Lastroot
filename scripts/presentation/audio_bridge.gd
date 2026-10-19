class_name AudioBridge
extends RefCounted
## Fire-and-forget sound cues for presentation code. Silently does nothing
## when the AudioService has no such method yet (cue list: docs/AUDIO_LEDGER.csv).


static func play(cue: String) -> void:
	var loop := Engine.get_main_loop()
	if loop == null:
		return
	var svc: Node = (loop as SceneTree).root.get_node_or_null("AudioService")
	if svc != null and svc.has_method("play"):
		svc.call("play", cue)
