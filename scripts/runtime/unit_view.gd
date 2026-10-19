class_name UnitView
extends Node3D
## Presentation of one UnitInstance (bible p.16: "Hver UnitView læser et
## unit_id og en præsentationstilstand"). Mesh, skeleton and particles live
## under VisualRoot. Nothing here can change the battle.

var unit_id: int = -1
var side: String = "ally"
var def_id: String = ""
var slot_id: String = ""
var head_height: float = 1.4
var visual: Node3D
var animator: Node = null
var _move_tween: Tween


func setup(u: Dictionary) -> UnitView:
	unit_id = int(u["unit_id"])
	side = str(u["side"])
	def_id = str(u["def_id"])
	slot_id = ("unit." if side == "ally" else "enemy.") + def_id
	name = "Unit_%d" % unit_id
	var root := Node3D.new()
	root.name = "VisualRoot"
	add_child(root)
	visual = VisualBridge.make(slot_id)
	root.add_child(visual)
	# Models face -Z; allies look right (+X) toward the enemies, enemies look left.
	root.rotation_degrees.y = -90.0 if side == "ally" else 90.0
	head_height = VisualBridge.head_height(slot_id)
	animator = visual.find_child("UnitAnimator", true, false)
	play("idle")
	return self


## Plays a presentation state; returns seconds until the contact frame (for
## attack/cast) or the clip's nominal length. Never blocks the flow.
func play(state: StringName, speed: float = 1.0) -> float:
	if animator != null and animator.has_method("play"):
		animator.call("play", state, speed)
		if animator.has_method("contact_time") and (state == &"attack" or state == &"cast"):
			return float(animator.call("contact_time", state)) / maxf(speed, 0.1)
		return 0.35 / maxf(speed, 0.1)
	return _fallback_anim(state, speed)


func _fallback_anim(state: StringName, speed: float) -> float:
	var s: float = maxf(speed, 0.1)
	var vr: Node3D = get_node("VisualRoot")
	var t := create_tween()
	match state:
		&"attack", &"cast":
			var dir: float = 0.45 if side == "ally" else -0.45
			t.tween_property(vr, "position:x", dir, 0.14 / s)
			t.tween_property(vr, "position:x", 0.0, 0.2 / s)
			return 0.14 / s
		&"hit":
			t.tween_property(vr, "position:x", -0.15 if side == "ally" else 0.15, 0.06 / s)
			t.tween_property(vr, "position:x", 0.0, 0.12 / s)
		&"death":
			t.tween_property(vr, "scale", Vector3(0.05, 0.05, 0.05), 0.4 / s)
			return 0.4 / s
		&"summon":
			vr.scale = Vector3(0.1, 0.1, 0.1)
			t.tween_property(vr, "scale", Vector3.ONE, 0.25 / s).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:
			t.kill()
	return 0.25 / s


func move_to(pos: Vector3, duration: float) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if duration <= 0.0:
		position = pos
		return
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func head_world() -> Vector3:
	return global_position + Vector3(0, head_height + 0.15, 0)
