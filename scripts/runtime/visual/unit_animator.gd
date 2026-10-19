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
const LOOPING: Array[StringName] = [&"idle"]
const LIB := "lr"
## Procedural durations at speed 1.0 (seconds).
const DURATION := {&"idle": 2.4, &"summon": 0.62, &"attack": 0.62, &"cast": 0.8, &"hit": 0.38, &"death": 0.7,
	&"defend": 0.5, &"victory": 1.1, &"move": 0.45}
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
## Overlay restored after flashes (the ally/enemy rim from VisualSlots.apply_side).
var base_overlay: Material = null
## Speed factor for the idle loop (HeartVisual slows the heart's pulse when hurt).
var idle_rate: float = 1.0

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
var _sub_rest: Dictionary = {}
var _hit_scale: float = 1.0
var _appeared: bool = false


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


## True when motion should be calm: the static flag, or the game's SettingsService
## autoload (if present) has reduced_motion on. No integration call needed.
static func motion_reduced() -> bool:
	if reduced_motion:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var svc := tree.root.get_node_or_null("SettingsService")
	return svc != null and bool(svc.get("reduced_motion"))


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
		_restore_subs()
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
		_after(ct / speed, _emit_contact.bind(token, state))
	if not is_inside_tree():
		_finish.call_deferred(token, state)
		return
	var wait := (DURATION.get(state, 0.5) as float) if state in LOOPING else dur
	# Normal end and the safety net share one path; the token makes it fire once.
	_after(wait / speed, _finish.bind(token, state))
	_after(wait / speed + TIMEOUT_MARGIN, _finish.bind(token, state))


## Hit reaction scaled by the damage actually dealt: bigger hit, bigger recoil
## and a brighter flash (capped at amount ~8). Same finished/timeout rules as play().
func play_hit(amount: int, speed: float = 1.0) -> void:
	_hit_scale = clampf(0.6 + float(maxi(amount, 0)) / 6.0, 0.6, 2.0)
	play(&"hit", speed)


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


## Delayed call owned by this node: a Tween dies with the node, so nothing fires
## (and nothing captures) after the unit view is freed. Callbacks are bound methods.
func _after(t: float, cb: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(t, 0.0))
	tw.tween_callback(cb)


func _emit_contact(token: int, state: StringName) -> void:
	if token == _token:
		contact.emit(state)


func _fx_if(token: int, id: String, local: Vector3, on_model: bool) -> void:
	if token == _token:
		_spawn_fx(id, local, on_model)


func _cast_flare(token: int, k: float) -> void:
	if token == _token:
		_glow_pulse(1.0 + 0.9 * k, 0.08, 0.3)
		_flash(Color(0.25, 1.0, 0.85, 0.4), 0.35)


func _finish(token: int, state: StringName) -> void:
	if token != _token or _pending != state:
		return
	_pending = &""
	finished.emit(state)
	if state in [&"summon", &"attack", &"cast", &"hit", &"victory", &"move", &"defend"]:
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


## "bark" | "spore" | "ash" | "heart" — picks the personality of each state.
func _family() -> StringName:
	if slot_id == "stage.heart":
		return &"heart"
	if slot_id.begins_with("enemy."):
		return &"ash"
	if slot_id.begins_with("unit.S"):
		return &"spore"
	return &"bark"


func _is_champion() -> bool:
	return slot_id == "unit.B01" or slot_id == "unit.S01"


## Remembers a sub-node's rest transform (Staff, Head, ...) so an interrupted
## tween can never leave it bent: play() restores all of them first.
func _sub(n: Node3D) -> Node3D:
	if n != null and not _sub_rest.has(n):
		_sub_rest[n] = n.transform
	return n


func _restore_subs() -> void:
	for n: Variant in _sub_rest.keys():
		if is_instance_valid(n):
			(n as Node3D).transform = _sub_rest[n]
		else:
			_sub_rest.erase(n)


## One-shot fx at a point in the visual root's space. Parented to the topmost 3D
## ancestor (same World3D), so it survives the unit view being removed.
func _spawn_fx(id: String, local: Vector3 = Vector3.ZERO, on_model: bool = false) -> void:
	if not is_inside_tree() or not VisualSlots.has_slot(id):
		return
	var fx := VisualSlots.make(id)
	if on_model and _model:
		_model.add_child(fx)
		fx.position = local
		return
	var root := get_parent() as Node3D
	var top: Node = root
	while top.get_parent() is Node3D:
		top = top.get_parent()
	top.add_child(fx)
	fx.global_position = root.global_transform * local
	fx.global_rotation = Vector3.ZERO


func _procedural(state: StringName, speed: float) -> void:
	var k := 0.35 if motion_reduced() else 1.0
	var p0 := _rest.origin
	var s0 := _rest.basis.get_scale()
	var fwd := -_rest.basis.z.normalized()
	var big := clampf(_height() / 1.6, 0.6, 1.8)
	var fam := _family()
	var rx := _rest.basis.get_euler().x
	var rz := _rest.basis.get_euler().z
	if not state in LOOPING:
		_tween = create_tween()
		_tween.set_speed_scale(speed)
	match state:
		&"idle" when fam == &"heart":
			# The heart breathes: slow pulse of the gem and its halo (top visual priority).
			_idle_tween = create_tween().set_loops()
			_idle_tween.set_speed_scale(speed * idle_rate)
			var amp := 0.02 if motion_reduced() else 0.07
			var nodes := _model.find_children("Glow_Heart*", "Node3D", true, false) + _model.find_children("Glow_Halo*", "Node3D", true, false)
			if nodes.is_empty():
				nodes = [_model]
			var bases: Array[Vector3] = []
			for n: Node in nodes:
				if not n.has_meta("lr_base_scale"):
					n.set_meta("lr_base_scale", (n as Node3D).scale)
				bases.append(n.get_meta("lr_base_scale") as Vector3)
			var setter := func(v: float) -> void:
				for i: int in nodes.size():
					if is_instance_valid(nodes[i]):
						(nodes[i] as Node3D).scale = bases[i] * v
			_idle_tween.tween_method(setter, 1.0, 1.0 + amp, 1.3).set_trans(Tween.TRANS_SINE)
			_idle_tween.tween_method(setter, 1.0 + amp, 1.0, 1.5).set_trans(Tween.TRANS_SINE)
		&"idle":
			_idle_tween = create_tween().set_loops()
			_idle_tween.set_speed_scale(speed)
			if slot_id == "unit.B01":
				# Champion variant: slow, heavy sway of a stone giant.
				_idle_tween.tween_property(_model, "rotation:z", rz + deg_to_rad(2.2 * k), 1.6).set_trans(Tween.TRANS_SINE)
				_idle_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.0 + 0.02 * k, 1.0 - 0.012 * k, 1.0), 1.6).set_trans(Tween.TRANS_SINE)
				_idle_tween.tween_property(_model, "rotation:z", rz - deg_to_rad(2.2 * k), 1.6).set_trans(Tween.TRANS_SINE)
				_idle_tween.parallel().tween_property(_model, "scale", s0, 1.6).set_trans(Tween.TRANS_SINE)
			elif slot_id == "unit.S01":
				# Champion variant: floaty bob with a breathing staff glow.
				_idle_tween.tween_property(_model, "position", p0 + Vector3(0, 0.05 * k, 0), 1.4).set_trans(Tween.TRANS_SINE)
				_idle_tween.tween_property(_model, "position", p0, 1.4).set_trans(Tween.TRANS_SINE)
				_glow_pulse(1.0 + 0.25 * k, 1.4, 1.4)
			else:
				var amp := 0.025 * k * big
				var period := 0.9 if fam == &"ash" else 1.2
				_idle_tween.tween_property(_model, "position", p0 + Vector3(0, amp, 0), period).set_trans(Tween.TRANS_SINE)
				_idle_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.0 + 0.015 * k, 1.0 + 0.03 * k, 1.0 + 0.015 * k), period).set_trans(Tween.TRANS_SINE)
				_idle_tween.tween_property(_model, "position", p0, period).set_trans(Tween.TRANS_SINE)
				_idle_tween.parallel().tween_property(_model, "scale", s0, period).set_trans(Tween.TRANS_SINE)
		&"summon" when fam == &"ash":
			_appear_from_ash(speed, k, big)
		&"summon":
			# Grows up out of the bark/roots: rises from below the floor, stretches, settles.
			_model.scale = s0 * Vector3(0.45, 0.05, 0.45)
			_model.position = p0 - Vector3(0, 0.35 * big * k, 0)
			_tween.tween_property(_model, "position", p0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "scale", s0 * Vector3(0.9, 1.14, 0.9), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(_model, "scale", s0 * Vector3(1.06, 0.95, 1.06), 0.12).set_trans(Tween.TRANS_SINE)
			_tween.tween_property(_model, "scale", s0, 0.16).set_trans(Tween.TRANS_SINE)
			_spawn_fx("fx.summon_spore" if fam == &"spore" else "fx.summon_bark")
			_flash(Color(0.5, 1.0, 0.75, 0.45) if fam == &"bark" else Color(0.6, 0.45, 1.0, 0.45), 0.5)
		&"attack" when fam == &"ash":
			# Lunge with an ember trail; contact at 0.30 s.
			var back := p0 - fwd * 0.22 * k * big
			var hit := p0 + fwd * 0.95 * k * big
			_tween.tween_property(_model, "position", back + Vector3(0, 0.05 * big, 0), 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", rx + deg_to_rad(10.0 * k), 0.17)
			_tween.tween_property(_model, "position", hit, 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_model, "rotation:x", rx - deg_to_rad(18.0 * k), 0.13)
			_tween.tween_property(_model, "position", p0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", rx, 0.32)
			_after(0.15 / speed, _fx_if.bind(_token, "fx.ember_trail", Vector3(0, _height() * 0.5, 0), true))
			_head_dip(0.3, k)
		&"attack", &"cast" when fam == &"spore":
			_spore_cast(speed, k, big, state)
		&"attack":
			# Bark: heavy, short wind-up and slam; contact (impact) at 0.30 s.
			var lift := p0 - fwd * 0.12 * k * big + Vector3(0, 0.12 * k * big, 0)
			var slam := p0 + fwd * 0.45 * k * big
			_tween.tween_property(_model, "position", lift, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", rx + deg_to_rad(16.0 * k), 0.18).set_trans(Tween.TRANS_SINE)
			_tween.parallel().tween_property(_model, "scale", s0 * Vector3(0.97, 1.06, 0.97), 0.18)
			_tween.tween_property(_model, "position", slam, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_model, "rotation:x", rx - deg_to_rad(20.0 * k), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.08, 0.88, 1.08), 0.12)
			_tween.tween_interval(0.06)
			_tween.tween_property(_model, "position", p0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", rx, 0.26)
			_tween.parallel().tween_property(_model, "scale", s0, 0.26)
			_after(0.3 / speed, _fx_if.bind(_token, "fx.summon_bark", fwd * 0.55 * big, false))
			_head_dip(0.3, k)
		&"cast":
			_spore_cast(speed, k, big, state)
		&"hit":
			# Recoil and flash scale with the damage (play_hit); capped.
			var a := _hit_scale
			_hit_scale = 1.0
			var kb := p0 - fwd * 0.2 * k * big * a
			_tween.tween_property(_model, "position", kb + Vector3(0, 0.03 * a * k, 0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", rx + deg_to_rad(9.0 * k * a), 0.07)
			_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.0 + 0.05 * a, 1.0 - 0.06 * a, 1.0 + 0.05 * a), 0.07)
			_tween.tween_property(_model, "position", p0, 0.27).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "rotation:x", rx, 0.27)
			_tween.parallel().tween_property(_model, "scale", s0, 0.2)
			_flash(Color(1.0, 0.12, 0.08, clampf(0.45 + 0.15 * a, 0.45, 0.85)), 0.32)
		&"death" when fam == &"ash":
			# Crumbles: a shudder, then collapses into itself (presenter spawns fx.ash_death).
			_tween.tween_property(_model, "position", p0 + _rest.basis.x.normalized() * 0.05 * k, 0.04)
			_tween.tween_property(_model, "position", p0 - _rest.basis.x.normalized() * 0.05 * k, 0.04)
			_tween.tween_property(_model, "position", p0, 0.04)
			_tween.tween_property(_model, "scale", s0 * Vector3(1.12, 0.25, 1.12), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_model, "position", p0 - Vector3(0, 0.08 * big, 0), 0.42)
			_tween.parallel().tween_method(_set_transparency, 0.0, 1.0, 0.42)
			_tween.tween_callback(func() -> void: _model.visible = false)
			_flash(Color(1.0, 0.45, 0.1, 0.7), 0.35)
		&"death":
			# Wilts and sinks into the floor, shedding leaves/spores.
			_tween.tween_property(_model, "rotation:z", rz + deg_to_rad(14.0 * k), 0.2).set_trans(Tween.TRANS_SINE)
			_tween.parallel().tween_property(_model, "rotation:x", rx - deg_to_rad(10.0 * k), 0.2)
			_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.0, 0.9, 1.0), 0.2)
			_tween.tween_property(_model, "position", p0 - Vector3(0, 0.6 * big, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.1, 0.4, 1.1), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_method(_set_transparency, 0.0, 1.0, 0.45)
			_tween.tween_callback(func() -> void: _model.visible = false)
			_spawn_fx("fx.wilt_spore" if fam == &"spore" else "fx.wilt", Vector3(0, _height() * 0.6, 0))
			_flash(Color(0.15, 0.1, 0.05, 0.6), 0.6)
		&"defend":
			var staff := _sub(_model.find_child("Staff", true, false) as Node3D)
			if slot_id == "unit.B01":
				# Champion: braces behind the plank shield, amber core flares.
				_tween.tween_property(_model, "scale", s0 * Vector3(1.08, 0.86, 1.08), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_tween.parallel().tween_property(_model, "rotation:x", rx + deg_to_rad(6.0 * k), 0.14)
				_tween.tween_property(_model, "scale", s0 * Vector3(1.04, 0.93, 1.04), 0.36)
				_tween.parallel().tween_property(_model, "rotation:x", rx, 0.36)
				_glow_pulse(1.0 + 0.6 * k, 0.15, 0.35)
				_flash(Color(1.0, 0.7, 0.25, 0.4), 0.45)
			elif staff:
				# Spore casters raise the staff across the body; the orb flares as a ward.
				_tween.tween_property(staff, "rotation", staff.rotation + Vector3(deg_to_rad(-30.0 * k), 0, deg_to_rad(28.0 * k)), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.04, 0.94, 1.04), 0.16)
				_tween.tween_property(staff, "rotation", staff.rotation, 0.34)
				_tween.parallel().tween_property(_model, "scale", s0, 0.34)
				_glow_pulse(1.0 + 0.7 * k, 0.15, 0.35)
				_flash(Color(0.3, 1.0, 0.85, 0.35), 0.45)
			else:
				_tween.tween_property(_model, "scale", s0 * Vector3(1.06, 0.9, 1.06), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_tween.parallel().tween_property(_model, "position", p0 - fwd * 0.06 * k, 0.15)
				_tween.tween_property(_model, "scale", s0 * Vector3(1.03, 0.95, 1.03), 0.35)
				_flash(Color(0.8, 0.88, 0.95, 0.45), 0.45)
		&"victory":
			if slot_id == "unit.B01":
				# Champion: two ground-shaking stomps.
				for i: int in 2:
					_tween.tween_property(_model, "position", p0 + Vector3(0, 0.22 * k * big, 0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					_tween.parallel().tween_property(_model, "scale", s0 * Vector3(0.96, 1.06, 0.96), 0.2)
					_tween.tween_property(_model, "position", p0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					_tween.parallel().tween_property(_model, "scale", s0 * Vector3(1.1, 0.88, 1.1), 0.12)
					_tween.tween_property(_model, "scale", s0, 0.18)
				_glow_pulse(1.0 + 0.5 * k, 0.3, 0.6)
			elif slot_id == "unit.S01":
				# Champion: staff to the sky, slow turn, spores rise.
				var staff := _sub(_model.find_child("Staff", true, false) as Node3D)
				if staff:
					_tween.tween_property(staff, "rotation", staff.rotation + Vector3(deg_to_rad(-40.0 * k), 0, deg_to_rad(-8.0 * k)), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_tween.parallel().tween_property(_model, "position", p0 + Vector3(0, 0.15 * k * big, 0), 0.25)
				_tween.tween_property(_model, "rotation:y", _rest.basis.get_euler().y + deg_to_rad(360.0 * k), 0.6).set_trans(Tween.TRANS_SINE)
				_tween.tween_property(_model, "position", p0, 0.2)
				if staff:
					_tween.parallel().tween_property(staff, "rotation", staff.rotation, 0.2)
				_tween.tween_callback(func() -> void: _model.transform = _rest)
				_glow_pulse(1.0 + 0.8 * k, 0.4, 0.6)
				_spawn_fx("fx.summon_spore", Vector3(0, 0.2, 0))
			else:
				_tween.tween_property(_model, "position", p0 + Vector3(0, 0.35 * k * big, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_tween.parallel().tween_property(_model, "rotation:y", _rest.basis.get_euler().y + deg_to_rad(180.0 * k), 0.5)
				_tween.tween_property(_model, "position", p0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				_tween.tween_property(_model, "rotation:y", _rest.basis.get_euler().y + deg_to_rad(360.0 * k), 0.35)
				_tween.tween_callback(func() -> void: _model.transform = _rest)
				_glow_pulse(1.0 + 0.5 * k, 0.4, 0.6)
		&"move":
			# One hop (0.45 s) matching a 0.45 s root tween between anchors (spawn, climb, lift).
			if fam == &"ash" and not _appeared:
				_spawn_fx("fx.ash_puff")
				_appeared = true
			var hop := (0.32 if fam == &"ash" else 0.18) * k * big
			_tween.tween_property(_model, "scale", s0 * Vector3(1.06, 0.9, 1.06), 0.06)
			_tween.tween_property(_model, "position", p0 + Vector3(0, hop, 0), 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_model, "scale", s0 * Vector3(0.95, 1.08, 0.95), 0.17)
			_tween.parallel().tween_property(_model, "rotation:x", rx - deg_to_rad(8.0 * k), 0.17)
			_tween.tween_property(_model, "position", p0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_model, "rotation:x", rx, 0.16)
			_tween.parallel().tween_property(_model, "scale", s0, 0.16)
			_tween.tween_property(_model, "scale", s0 * Vector3(1.05, 0.94, 1.05), 0.03)
			_tween.tween_property(_model, "scale", s0, 0.03)


## Enemy first appearance: a smoky ash puff, the figure condenses out of it.
func _appear_from_ash(_speed: float, k: float, big: float) -> void:
	var s0 := _rest.basis.get_scale()
	var p0 := _rest.origin
	_appeared = true
	_spawn_fx("fx.ash_puff")
	_model.scale = s0 * Vector3(1.25, 0.2, 1.25)
	_model.position = p0 + Vector3(0, 0.1 * big * k, 0)
	_set_transparency(0.7)
	_tween.tween_interval(0.08)
	_tween.tween_property(_model, "scale", s0 * Vector3(0.94, 1.08, 0.94), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_model, "position", p0, 0.3)
	_tween.parallel().tween_method(_set_transparency, 0.7, 0.0, 0.3)
	_tween.tween_property(_model, "scale", s0, 0.14)
	_flash(Color(1.0, 0.45, 0.1, 0.5), 0.4)


## Spore folk: rear back, staff thrust forward and up, orb flares at contact (0.38 s);
## the presenter launches fx.spore_bolt from here.
func _spore_cast(speed: float, k: float, big: float, state: StringName) -> void:
	var p0 := _rest.origin
	var fwd := -_rest.basis.z.normalized()
	var rx := _rest.basis.get_euler().x
	var staff := _sub(_model.find_child("Staff", true, false) as Node3D)
	var ct := contact_time(state)
	_tween.tween_property(_model, "position", p0 - fwd * 0.1 * k * big + Vector3(0, 0.06 * k * big, 0), ct * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_model, "rotation:x", rx + deg_to_rad(8.0 * k), ct * 0.55)
	if staff:
		_tween.parallel().tween_property(staff, "rotation", staff.rotation + Vector3(deg_to_rad(25.0 * k), 0, 0), ct * 0.55).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_model, "position", p0 + fwd * 0.18 * k * big + Vector3(0, 0.1 * k * big, 0), ct * 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_model, "rotation:x", rx - deg_to_rad(10.0 * k), ct * 0.45)
	if staff:
		_tween.parallel().tween_property(staff, "rotation", staff.rotation + Vector3(deg_to_rad(-55.0 * k), 0, deg_to_rad(8.0 * k)), ct * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.1)
	_tween.tween_property(_model, "position", p0, 0.3).set_trans(Tween.TRANS_QUAD)
	_tween.parallel().tween_property(_model, "rotation:x", rx, 0.3)
	if staff:
		_tween.parallel().tween_property(staff, "rotation", staff.rotation, 0.3)
	_after(ct / speed, _cast_flare.bind(_token, k))


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
	# After a flash the side rim (VisualSlots.apply_side) comes back, not "no overlay".
	var rest: Material = base_overlay
	for n: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		if n.name == "SideDisc":
			continue
		(n as GeometryInstance3D).material_overlay = _overlay if on else rest
	if _model is GeometryInstance3D:
		(_model as GeometryInstance3D).material_overlay = _overlay if on else rest


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
