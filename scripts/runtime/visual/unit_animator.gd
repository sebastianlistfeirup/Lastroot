class_name UnitAnimator
extends Node
## Presentation-only animation driver, a child named "UnitAnimator" of every
## unit/enemy visual root made by VisualSlots.make(). It dramatises results the
## rules engine already decided (bible: "Animation: dramatisér et allerede
## afgjort resultat"); nothing here may change game state.
##
##   play(state, speed)   idle, summon, attack, cast, hit, death, defend, victory, move
##   finished(state)      ALWAYS emitted once per play() (timeout fallback, also when
##                        interrupted by another play()), so a missing clip never locks a run.
##   contact(state)       emitted at the hit frame of attack/cast (feedback sync only).
##   contact_time(state)  seconds from play() to the hit frame at speed 1.0 (divide by speed).
##
## Real rig: plays clips from the wrapper's AnimationPlayer (library "lr" named after
## states, or names mapped in data/art/animation_sets.json), in place. A state with
## no clip falls back to the procedural tween, so it still reads and finishes.
## Proxy: procedural tweens on the "Model" child (never on the root, which the
## battle scene owns and moves between anchors).

signal finished(state: StringName)
signal contact(state: StringName)

const STATES: Array[StringName] = [&"idle", &"summon", &"attack", &"cast", &"hit", &"death", &"defend", &"victory", &"move"]
const LOOPING: Array[StringName] = [&"idle", &"move"]
const LIB := "lr"
## Procedural durations at speed 1.0 (seconds).
const DURATION := {&"idle": 2.4, &"summon": 0.55, &"attack": 0.62, &"cast": 0.8, &"hit": 0.38, &"death": 0.95,
	&"defend": 0.5, &"victory": 1.1, &"move": 0.5}
const CONTACT := {&"attack": 0.3, &"cast": 0.38}
## Extra seconds before the safety timeout fires finished().
const TIMEOUT_MARGIN := 0.6
const SETS_PATH := "res://data/art/animation_sets.json"

## Smaller, calmer motion everywhere (settings: reduced motion).
static var reduced_motion: bool = false
static var _sets: Dictionary = {}

## Rig family from asset_slots.json ("humanoid", "quadruped", "static", ...).
var rig_family: String = "humanoid"
var slot_id: String = ""
var current: StringName = &""

var _model: Node3D
var _player: AnimationPlayer
var _rest: Transform3D = Transform3D.IDENTITY
var _token: int = 0
var _pending: StringName = &""
var _tween: Tween
var _idle_tween: Tween
var _overlay: StandardMaterial3D
var _clip_map: Dictionary = {}
var _contact_map: Dictionary = {}


func _ready() -> void:
	_bind()
	if current == &"":
		play(&"idle")


## Finds the Model node and (if any) an AnimationPlayer. Safe to call again
## after the visual has been rebuilt.
func _bind() -> void:
	var root := get_parent()
	if root == null:
		return
	_model = root.get_node_or_null("Model") as Node3D
	if _model == null and root is Node3D:
		_model = root as Node3D
	_rest = _model.transform if _model else Transform3D.IDENTITY
	_player = root.get_node_or_null("LRAnimations") as AnimationPlayer
	if _player == null:
		_player = _find_player(root)
	if slot_id.is_empty():
		slot_id = str(root.get_meta("slot_id", ""))
	var cfg := _slot_set(slot_id)
	_clip_map = cfg.get("clips", {}) as Dictionary
	_contact_map = cfg.get("contact", {}) as Dictionary


static func _find_player(n: Node) -> AnimationPlayer:
	for c: Node in n.get_children():
		if c is AnimationPlayer:
			return c as AnimationPlayer
		var deep := _find_player(c)
		if deep:
			return deep
	return null


static func _slot_set(id: String) -> Dictionary:
	if _sets.is_empty():
		_sets = {"_": {}}
		if FileAccess.file_exists(SETS_PATH):
			var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETS_PATH))
			if v is Dictionary:
				_sets = v
	var slots: Dictionary = _sets.get("slots", {}) as Dictionary
	var sets: Dictionary = _sets.get("sets", {}) as Dictionary
	var s: Dictionary = slots.get(id, {}) as Dictionary
	var out: Dictionary = (sets.get(str(s.get("set", "")), {}) as Dictionary).duplicate(true)
	for k: String in ["clips", "contact"]:
		var own: Dictionary = s.get(k, {}) as Dictionary
		if not own.is_empty():
			var merged: Dictionary = out.get(k, {}) as Dictionary
			merged.merge(own, true)
			out[k] = merged
	return out


# ------------------------------------------------------------------ public API

func has_clip(state: StringName) -> bool:
	if _player == null:
		_bind()
	if _player != null:
		return not _clip_for(state).is_empty()
	return state in STATES and _model != null


## True when this visual is animated by procedural tweens (proxy or missing clip).
func is_procedural(state: StringName = &"idle") -> bool:
	return _player == null or _clip_for(state).is_empty()


func contact_time(state: StringName) -> float:
	if _contact_map.has(String(state)):
		return float(_contact_map[String(state)])
	return float(CONTACT.get(state, 0.0))


func play(state: StringName, speed: float = 1.0) -> void:
	if _model == null:
		_bind()
	speed = maxf(speed, 0.05)
	# An interrupted one-shot still reports finished, so nobody waits forever.
	if _pending != &"":
		var was := _pending
		_pending = &""
		finished.emit(was)
	_token += 1
	var token := _token
	current = state
	_kill_tweens()
	if _model:
		_model.transform = _rest
		_model.visible = true
		_set_transparency(0.0)
	_set_overlay(Color(0, 0, 0, 0))
	if not state in STATES:
		push_warning("UnitAnimator: unknown state %s" % state)
		finished.emit.call_deferred(state)
		return
	_pending = state
	var dur := float(DURATION.get(state, 0.5))
	var clip := _clip_for(state) if _player else ""
	if not clip.is_empty():
		var anim := _player.get_animation(clip)
		dur = anim.length if anim and anim.length > 0.0 else dur
		_player.play(clip, 0.12, speed)
		if state == &"hit":
			_flash(Color(1, 0.15, 0.1, 0.55), 0.3 / speed)
	elif is_inside_tree() and _model:
		_procedural(state, speed)
	else:
		dur = 0.0
	var ct := contact_time(state)
	if ct > 0.0 and is_inside_tree():
		get_tree().create_timer(ct / speed).timeout.connect(func() -> void:
			if token == _token:
				contact.emit(state))
	if not is_inside_tree():
		_finish.call_deferred(token, state)
		return
	var wait := (DURATION.get(state, 0.5) as float) if state in LOOPING else dur
	# Normal end and the safety net share one path; the token makes it fire once.
	get_tree().create_timer(wait / speed).timeout.connect(_finish.bind(token, state))
	get_tree().create_timer(wait / speed + TIMEOUT_MARGIN).timeout.connect(_finish.bind(token, state))


## Puts the visual straight into its end pose (skip / load).
func snap(state: StringName) -> void:
	_token += 1
	_pending = &""
	_kill_tweens()
	current = state
	if _model:
		_model.transform = _rest
		_model.visible = state != &"death"
	_set_overlay(Color(0, 0, 0, 0))
	if state != &"death":
		play(&"idle")


func _finish(token: int, state: StringName) -> void:
	if token != _token or _pending != state:
		return
	_pending = &""
	finished.emit(state)
	if state in [&"summon", &"attack", &"cast", &"hit", &"victory"]:
		play(&"idle")


func _clip_for(state: StringName) -> String:
	if _player == null:
		return ""
	var s := String(state)
	if _player.has_animation(LIB + "/" + s):
		return LIB + "/" + s
	var mapped := str(_clip_map.get(s, ""))
	if not mapped.is_empty() and _player.has_animation(mapped):
		return mapped
	return ""


# ------------------------------------------------------------------ procedural

func _kill_tweens() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()


func _procedural(state: StringName, speed: float) -> void:
	var k := 0.35 if reduced_motion else 1.0
	var p0 := _rest.origin
	var s0 := _rest.basis.get_scale()
	var fwd := -_rest.basis.z.normalized()
	var big := clampf(_height() / 1.6, 0.6, 1.8)
	if not state in LOOPING:
		_tween = create_tween()
		_tween.set_speed_scale(speed)
	match state:
		&"idle":
			_idle_tween = create_tween().set_loops()
			_idle_tween.set_speed_scale(speed)
			var amp := 0.025 * k * big
			_idle_tween.tween_property(_model, "position", p0 + Vector3(0, amp, 0), 1.2).set_trans(Tween.TRANS_SINE)
			_idle_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.0 + 0.015 * k, 1.0 + 0.03 * k, 1.0 + 0.015 * k), 1.2).set_trans(Tween.TRANS_SINE)
			_idle_tween.tween_property(_model, "position", p0, 1.2).set_trans(Tween.TRANS_SINE)
			_idle_tween.parallel().tween_property(_model, "scale", s0, 1.2).set_trans(Tween.TRANS_SINE)
		&"summon":
			_model.scale = s0 * 0.05
			_model.position = p0 - Vector3(0, 0.3 * k, 0)
			_tween.tween_property(_model, "scale", s0 * Vector3(1.12, 0.9, 1.12), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "position", p0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(_model, "scale", s0, 0.25).set_trans(Tween.TRANS_SINE)
			_flash(Color(0.5, 1.0, 0.85, 0.5), 0.5)
		&"attack":
			var back := p0 - fwd * 0.18 * k * big
			var hit := p0 + fwd * 0.75 * k * big
			_tween.tween_property(_model, "position", back, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", _rest.basis.get_euler().x + deg_to_rad(8.0 * k), 0.16)
			_tween.tween_property(_model, "position", hit, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_model, "rotation:x", _rest.basis.get_euler().x - deg_to_rad(14.0 * k), 0.14)
			_head_dip(0.3, k)
			_tween.tween_property(_model, "position", p0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", _rest.basis.get_euler().x, 0.32)
		&"cast":
			var staff := _model.find_child("Staff", true, false) as Node3D
			_tween.tween_property(_model, "position", p0 + Vector3(0, 0.12 * k * big, 0), 0.3).set_trans(Tween.TRANS_SINE)
			if staff:
				var r0 := staff.rotation
				_tween.parallel().tween_property(staff, "rotation", r0 + Vector3(deg_to_rad(-35.0 * k), 0, deg_to_rad(10.0 * k)), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_tween.tween_property(staff, "rotation", r0, 0.4).set_delay(0.1)
				_tween.parallel().tween_property(_model, "position", p0, 0.4).set_delay(0.1)
			else:
				_tween.tween_property(_model, "position", p0, 0.4).set_delay(0.1)
			_glow_pulse(1.0 + 0.8 * k, 0.38, 0.42)
			_flash(Color(0.25, 1.0, 0.85, 0.35), 0.7)
		&"hit":
			var kb := p0 - fwd * 0.22 * k * big
			_tween.tween_property(_model, "position", kb, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", _rest.basis.get_euler().x + deg_to_rad(10.0 * k), 0.08)
			_tween.tween_property(_model, "position", p0, 0.26).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", _rest.basis.get_euler().x, 0.26)
			_flash(Color(1.0, 0.12, 0.08, 0.7), 0.34)
		&"death":
			_tween.tween_property(_model, "rotation:z", _rest.basis.get_euler().z + deg_to_rad(12.0 * k), 0.2)
			_tween.tween_property(_model, "position", p0 - Vector3(0, 0.5 * big, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.15, 0.35, 1.15), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_method(_set_transparency, 0.0, 1.0, 0.6)
			_tween.tween_callback(func() -> void: _model.visible = false)
			_flash(Color(0.1, 0.08, 0.08, 0.6), 0.8)
		&"defend":
			_tween.tween_property(_model, "scale", s0 * Vector3(1.06, 0.9, 1.06), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "position", p0 - fwd * 0.06 * k, 0.15)
			_tween.tween_property(_model, "scale", s0 * Vector3(1.03, 0.95, 1.03), 0.35)
			_flash(Color(0.8, 0.88, 0.95, 0.45), 0.45)
		&"victory":
			_tween.tween_property(_model, "position", p0 + Vector3(0, 0.35 * k * big, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:y", _rest.basis.get_euler().y + deg_to_rad(180.0 * k), 0.5)
			_tween.tween_property(_model, "position", p0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.tween_property(_model, "rotation:y", _rest.basis.get_euler().y + deg_to_rad(360.0 * k), 0.35)
			_tween.tween_callback(func() -> void: _model.transform = _rest)
			_glow_pulse(1.0 + 0.5 * k, 0.4, 0.6)
		&"move":
			_idle_tween = create_tween().set_loops()
			_idle_tween.set_speed_scale(speed)
			var hop := 0.12 * k * big
			_idle_tween.tween_property(_model, "position", p0 + Vector3(0, hop, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_idle_tween.parallel().tween_property(_model, "rotation:x", _rest.basis.get_euler().x - deg_to_rad(6.0 * k), 0.25)
			_idle_tween.tween_property(_model, "position", p0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_idle_tween.parallel().tween_property(_model, "rotation:x", _rest.basis.get_euler().x, 0.25)


## Quadrupeds and creatures with a "Head" node dip it on the strike.
func _head_dip(at: float, k: float) -> void:
	if rig_family != "quadruped":
		return
	var head := _model.find_child("Head", true, false) as Node3D
	if head == null:
		return
	var r0 := head.rotation
	var t := create_tween()
	t.tween_interval(at - 0.12)
	t.tween_property(head, "rotation:x", r0.x - deg_to_rad(30.0 * k), 0.12)
	t.tween_property(head, "rotation:x", r0.x, 0.25)


## Scales every "Glow*" node up and back (staff orb, eyes, heart, cores).
func _glow_pulse(amount: float, rise: float, fall: float) -> void:
	var nodes := _model.find_children("Glow*", "Node3D", true, false)
	if nodes.is_empty():
		return
	var t := create_tween().set_parallel(true)
	for n: Node in nodes:
		var g := n as Node3D
		var s0 := g.scale
		t.tween_property(g, "scale", s0 * amount, rise).set_trans(Tween.TRANS_SINE)
		t.chain().tween_property(g, "scale", s0, fall).set_trans(Tween.TRANS_SINE)


## Per-unit colour flash through material_overlay (shared palette materials stay untouched).
func _flash(c: Color, dur: float) -> void:
	if _model == null or not is_inside_tree():
		return
	var t := create_tween()
	t.tween_method(_set_overlay, c, Color(c.r, c.g, c.b, 0.0), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_overlay(c: Color) -> void:
	if _model == null:
		return
	if _overlay == null:
		_overlay = StandardMaterial3D.new()
		_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_overlay.albedo_color = c
	var on := c.a > 0.005
	for n: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).material_overlay = _overlay if on else null
	if _model is GeometryInstance3D:
		(_model as GeometryInstance3D).material_overlay = _overlay if on else null


func _set_transparency(v: float) -> void:
	if _model == null:
		return
	for n: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).transparency = v


func _height() -> float:
	var root := get_parent()
	if root and root.has_meta("height_m"):
		return float(root.get_meta("height_m"))
	return 1.6
