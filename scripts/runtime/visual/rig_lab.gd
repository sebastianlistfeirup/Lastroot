class_name RigLab
extends Node3D
## DEVELOPER TOOL (bible "Rig og events"): inspect one unit/enemy rig before it
## goes into the battle scene.
##   - 1 m grid, 1 m cube, height pole with 0.5 m ticks, a "front = -Z" arrow
##   - plays every state the slot needs (asset_slots.json animation_states) in a loop
##   - reports scale, feet on y=0, facing, AnimationPlayer, clip vs procedural vs MISSING,
##     contact time, and whether finished() really arrived (timing per state)
## Open scenes/tests/rig_lab.tscn (F6). Keys: Left/Right slot, Space next state, R reduced motion.
## CLI: godot --path . res://scenes/tests/rig_lab.tscn -- --slot=unit.B04 --capture=evidence/asset_pipeline/riglab_B04.png
## Dev tool: text not localized.

var slot_index: int = 0
var slots: PackedStringArray = PackedStringArray()

var _visual: Node3D
var _anim: UnitAnimator
var _states: Array = []
var _state_i: int = -1
var _started_ms: int = 0
var _timings: Dictionary = {}
var _report: Label
var _title: Label
var _cam: Camera3D
var _capture: String = ""
var _frames: int = 0


func _ready() -> void:
	slots = VisualSlots.ids_of_kind("unit")
	slots.append_array(VisualSlots.ids_of_kind("enemy"))
	var want := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--slot="):
			want = a.substr(7)
		elif a.begins_with("--capture="):
			_capture = a.substr(10)
	if not want.is_empty() and slots.has(want):
		slot_index = slots.find(want)
	_world()
	_ui()
	_load()


# ---------------------------------------------------------------- audit (headless-safe)

## Measures one slot without a scene tree. Used by RigLab, the unit test and the pipeline.
static func audit(slot_id: String) -> Dictionary:
	var s := VisualSlots.slot(slot_id)
	var v := VisualSlots.make(slot_id)
	var box := VisualSlots.bounds(v)
	var anim := v.get_node_or_null("UnitAnimator") as UnitAnimator
	var issues: Array = []
	var states: Array = s.get("animation_states", []) as Array
	var per_state := {}
	var player: AnimationPlayer = UnitAnimator._find_player(v)
	if anim:
		anim._bind()
	for st: Variant in states:
		var sn := StringName(str(st))
		var how := "procedural"
		if player:
			how = "clip:" + anim._clip_for(sn) if anim and not anim._clip_for(sn).is_empty() else "MISSING (procedural fallback)"
		per_state[str(st)] = how
	var missing: Array = per_state.keys().filter(func(k: Variant) -> bool: return str(per_state[k]).begins_with("MISSING"))
	var declared := float(s.get("height", 0.0))
	if declared > 0.0 and (box.size.y < declared * 0.7 or box.end.y > declared * 1.35):
		issues.append("height %.2f m vs declared %.2f (scale/units? set 'scale' or fix the wrapper)" % [box.end.y, declared])
	if absf(box.position.y) > 0.15:
		issues.append("feet at y=%.2f, expected ~0 (set 'offset')" % box.position.y)
	var facing := facing_of(v)
	if facing == "+Z":
		issues.append("faces +Z: set rotation_y 180 for this slot")
	if anim == null:
		issues.append("no UnitAnimator child")
	if not missing.is_empty():
		issues.append("missing clips: " + ", ".join(missing))
	if str(s.get("rig_family", "")) == "quadruped" and player and v.find_children("GeneralSkeleton", "Skeleton3D", true, false).size() > 0:
		issues.append("quadruped imported with a humanoid bone map: remove the retarget")
	var out := {"slot": slot_id, "proxy": v.get_meta("is_proxy", true), "rig_family": str(s.get("rig_family", "")),
		"height_m": snappedf(box.end.y, 0.01), "declared_m": declared, "feet_y": snappedf(box.position.y, 0.01),
		"footprint_m": [snappedf(box.size.x, 0.01), snappedf(box.size.z, 0.01)], "facing": facing,
		"animation_player": player != null, "clips": Array(player.get_animation_list()) if player else [],
		"states": per_state, "missing_clips": missing, "head_height": VisualSlots.head_height(slot_id),
		"issues": issues, "ok": issues.is_empty()}
	v.free()
	return out


## "-Z" (correct), "+Z" (turned around) or "unknown". Proxies: eyes; rigs: toes vs feet.
static func facing_of(v: Node3D) -> String:
	var skels := v.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var sk := skels[0] as Skeleton3D
		var xf := _xf_to(v, sk)
		for pair: Array in [["LeftToes", "LeftFoot"], ["RightToes", "RightFoot"], ["Nose", "Head"]]:
			var a := sk.find_bone(str(pair[0]))
			var b := sk.find_bone(str(pair[1]))
			if a >= 0 and b >= 0:
				var dz := (xf * sk.get_bone_global_rest(a).origin).z - (xf * sk.get_bone_global_rest(b).origin).z
				if absf(dz) > 0.005:
					return "-Z" if dz < 0.0 else "+Z"
	var eyes := v.find_children("Glow_Eye*", "Node3D", true, false)
	if not eyes.is_empty():
		var z := 0.0
		for e: Node in eyes:
			z += (_xf_to(v, e as Node3D) * Vector3.ZERO).z
		return "-Z" if z / float(eyes.size()) < 0.0 else "+Z"
	var marker := v.find_child("Front", true, false) as Node3D
	if marker:
		return "-Z" if (_xf_to(v, marker) * Vector3.ZERO).z < 0.0 else "+Z"
	return "unknown"


static func _xf_to(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


# ---------------------------------------------------------------- scene

func _world() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#161320")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8a86a8")
	e.ambient_light_energy = 0.6
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	_box(Vector3(12, 0.04, 12), Vector3(0, -0.02, 0), "stone_dark")
	for i: int in range(-6, 7):
		var key := "stone_warm" if i % 5 == 0 else "stone"
		_box(Vector3(12, 0.005, 0.02), Vector3(0, 0.003, i), key)
		_box(Vector3(0.02, 0.005, 12), Vector3(i, 0.003, 0), key)
	_box(Vector3.ONE, Vector3(2.4, 0.5, 0.6), "stone", "1 m")
	_box(Vector3(0.05, 3.0, 0.05), Vector3(-1.8, 1.5, -0.7), "amber")
	for k: int in range(1, 7):
		var y := 0.5 * k
		_box(Vector3(0.22, 0.012, 0.012), Vector3(-1.9, y, -0.7), "amber")
		_label("%.1f m" % y, Vector3(-2.25, y, -0.7), 0.004)
	# Front arrow: Godot forward is -Z; every unit must look along it.
	_box(Vector3(0.06, 0.02, 1.6), Vector3(0, 0.02, -1.3), "turquoise")
	var tip := MeshInstance3D.new()
	tip.mesh = ProxyMesh.prism(Vector3(0.3, 0.3, 0.04))
	tip.material_override = VisualPalette.glow("turquoise")
	tip.position = Vector3(0, 0.03, -2.2)
	tip.rotation_degrees = Vector3(-90, 0, 0)
	add_child(tip)
	_label("front = -Z", Vector3(0.0, 0.1, -2.6), 0.004)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_cam.current = true


func _box(size: Vector3, pos: Vector3, key: String, text: String = "") -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ProxyMesh.box(size)
	mi.material_override = VisualPalette.glow(key) if key in ["amber", "turquoise"] else VisualPalette.mat(key)
	mi.position = pos
	add_child(mi)
	if not text.is_empty():
		_label(text, pos + Vector3(0, size.y * 0.5 + 0.15, 0), 0.004)


func _label(text: String, pos: Vector3, px: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.font_size = 40
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)


func _ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_title = Label.new()
	_title.position = Vector2(16, 10)
	_title.add_theme_font_size_override("font_size", 24)
	ui.add_child(_title)
	_report = Label.new()
	_report.position = Vector2(16, 48)
	_report.add_theme_font_size_override("font_size", 17)
	_report.add_theme_color_override("font_outline_color", Color.BLACK)
	_report.add_theme_constant_override("outline_size", 4)
	ui.add_child(_report)


func _load() -> void:
	if _visual:
		_visual.queue_free()
	var id := slots[slot_index]
	_visual = VisualSlots.make(id)
	# 3/4 view: rotate the unit, not the camera, so "front = -Z" stays readable on the grid.
	add_child(_visual)
	_anim = _visual.get_node_or_null("UnitAnimator") as UnitAnimator
	if _anim and not _anim.finished.is_connected(_on_finished):
		_anim.finished.connect(_on_finished)
	_states = VisualSlots.slot(id).get("animation_states", ["idle"]) as Array
	_state_i = -1
	_timings.clear()
	var h := maxf(float(VisualSlots.slot(id).get("height", 1.6)), 1.2)
	_cam.position = Vector3(h * 1.7, h * 0.95, -h * 1.9)
	_cam.look_at(Vector3(0, h * 0.45, -0.3))
	_next_state()


func _next_state() -> void:
	if _anim == null or _states.is_empty():
		_refresh()
		return
	_state_i = (_state_i + 1) % _states.size()
	_started_ms = Time.get_ticks_msec()
	_anim.play(StringName(str(_states[_state_i])))
	_refresh()


func _on_finished(state: StringName) -> void:
	_timings[String(state)] = "%.2fs" % (float(Time.get_ticks_msec() - _started_ms) / 1000.0)
	_refresh()
	if _state_i >= 0 and String(state) == str(_states[_state_i]):
		get_tree().create_timer(0.35).timeout.connect(_next_state)


func _refresh() -> void:
	var id := slots[slot_index]
	var a := audit(id)
	_title.text = "RigLab · %s (%s) · %s · ←/→ slot  Space state  R reduced motion" % [id, str(VisualSlots.slot(id).get("name", "")), "PROXY" if a["proxy"] else "MODEL"]
	var lines: Array = []
	lines.append("height %.2f m (declared %.2f) · feet y %.2f · facing %s · rig %s · badge at %.2f m" % [a["height_m"], a["declared_m"], a["feet_y"], a["facing"], a["rig_family"], a["head_height"]])
	lines.append("AnimationPlayer: %s · reduced motion: %s" % ["yes (%d clips)" % (a["clips"] as Array).size() if a["animation_player"] else "no (procedural)", UnitAnimator.reduced_motion])
	for st: String in (a["states"] as Dictionary).keys():
		var cur := ">" if _state_i >= 0 and st == str(_states[_state_i]) else " "
		var ct := _anim.contact_time(StringName(st)) if _anim else 0.0
		lines.append("%s %-8s %-30s %s%s" % [cur, st, a["states"][st], ("contact %.2fs  " % ct) if ct > 0.0 else "", "finished after " + str(_timings[st]) if _timings.has(st) else ""])
	lines.append("issues: " + ("none" if (a["issues"] as Array).is_empty() else "; ".join(a["issues"])))
	_report.text = "\n".join(lines)


func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_RIGHT:
			slot_index = (slot_index + 1) % slots.size()
			_load()
		KEY_LEFT:
			slot_index = (slot_index - 1 + slots.size()) % slots.size()
			_load()
		KEY_SPACE:
			_next_state()
		KEY_R:
			UnitAnimator.reduced_motion = not UnitAnimator.reduced_motion
			_refresh()


func _process(_dt: float) -> void:
	if _capture.is_empty():
		return
	_frames += 1
	if _frames == 75:
		var path := ProjectSettings.globalize_path(_capture if _capture.begins_with("res://") else "res://" + _capture)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		get_viewport().get_texture().get_image().save_png(path)
		print("captured ", _capture)
		get_tree().quit()
