extends SceneTree
## Build cost of every non-fx proxy: ProxyMerge off, on with a cold cache, on warm.
##   XDG_DATA_HOME=/tmp/xdg_x godot --headless --path . --script res://tools/profile/merge_cost.gd


func _pass() -> float:
	var t0 := Time.get_ticks_usec()
	for id: String in VisualSlots.slot_ids():
		if str(VisualSlots.slot(id).get("kind", "")) == "fx":
			continue
		VisualSlots.make(id).free()
	return (Time.get_ticks_usec() - t0) / 1000.0


func _init() -> void:
	await process_frame
	ProxyMerge.enabled = false
	_pass()
	var off := _pass()
	ProxyMerge.enabled = true
	ProxyMerge.clear_cache()
	var cold := _pass()
	var warm := _pass()
	print("MERGE_COST all proxies: off=%.1f ms  on_cold=%.1f ms  on_warm=%.1f ms" % [off, cold, warm])
	quit()
