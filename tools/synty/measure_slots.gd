extends SceneTree
## Prints the real bounds of every slot visual (proxy or mapped model) next to
## its declared height/head_height, and writes evidence/asset_pipeline/slot_bounds.json.
##   godot --headless --path . --script res://tools/synty/measure_slots.gd


func _init() -> void:
	var rows: Array = []
	for id: String in VisualSlots.slot_ids():
		var s := VisualSlots.slot(id)
		var v := VisualSlots.make(id)
		var b := VisualSlots.bounds(v)
		var row := {"slot": id, "proxy": v.get_meta("is_proxy", true), "declared_height": float(s.get("height", 0.0)),
			"head_height": VisualSlots.head_height(id), "min": [snappedf(b.position.x, 0.01), snappedf(b.position.y, 0.01), snappedf(b.position.z, 0.01)],
			"size": [snappedf(b.size.x, 0.01), snappedf(b.size.y, 0.01), snappedf(b.size.z, 0.01)], "top": snappedf(b.end.y, 0.01)}
		rows.append(row)
		print("%-22s top %5.2f  head %5.2f  size %5.2f x %5.2f x %5.2f  min y %5.2f" % [id, b.end.y, row["head_height"], b.size.x, b.size.y, b.size.z, b.position.y])
		v.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/asset_pipeline"))
	var f := FileAccess.open("res://evidence/asset_pipeline/slot_bounds.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, " "))
	f.close()
	quit()
