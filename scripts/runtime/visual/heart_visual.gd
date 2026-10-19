class_name HeartVisual
extends Node3D
## Script on the stage.heart root (set by VisualSlots.make): shows the tree heart's
## health. Visual only — the HUD carries the number.
##   set_health(ratio)      >= 0.66 bright, full halo, normal pulse
##                          0.33..0.66 a few cracks, slightly dimmer, slower pulse
##                          < 0.33 heavy cracks, cold tint, flicker, slow pulse
##   hurt(amount_ratio)     one-shot: cracks flash red, shard burst (fx.heart_damage),
##                          a short shake (none under reduced motion)
## Works on the proxy (Gem/Glow_Halo/Glow_Shard/Crack nodes) and degrades to a light
## change on a purchased model without those nodes.

var health: float = 1.0

var _gem_mat: StandardMaterial3D
var _cracks: Array[Node3D] = []
var _halos: Array[Node3D] = []
var _shards: Array[Node3D] = []
var _light: OmniLight3D
var _light_base: float = 2.2
var _flicker: float = 0.0
var _tint: Color = Color.WHITE
var _crack_flash: StandardMaterial3D
var _bound: bool = false


func _bind() -> void:
	if _bound:
		return
	_bound = true
	for n: Node in find_children("Gem*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			_gem_mat = (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			mi.material_override = _gem_mat
		break
	for n: Node in find_children("Crack*", "Node3D", true, false):
		_cracks.append(n as Node3D)
	for n: Node in find_children("Glow_Halo*", "Node3D", true, false):
		_halos.append(n as Node3D)
	for n: Node in find_children("Glow_Shard*", "Node3D", true, false):
		_shards.append(n as Node3D)
	_light = find_child("HeartLight", true, false) as OmniLight3D
	if _light:
		_light_base = _light.light_energy


func _ready() -> void:
	_bind()
	set_health(health)


func set_health(ratio: float) -> void:
	_bind()
	health = clampf(ratio, 0.0, 1.0)
	var band := 2 if health >= 0.66 else (1 if health >= 0.33 else 0)
	var show_cracks: int = 0 if band == 2 else (3 if band == 1 else 99)
	for i: int in _cracks.size():
		_cracks[i].visible = i < show_cracks
	for h: Node3D in _halos:
		h.visible = band > 0
		if not h.has_meta("lr_base_scale"):
			h.set_meta("lr_base_scale", h.scale)
		h.scale = (h.get_meta("lr_base_scale") as Vector3) * (1.0 if band == 2 else 0.8)
	for i: int in _shards.size():
		_shards[i].visible = band == 2 or (band == 1 and i % 2 == 0)
	_tint = [Color(0.5, 0.62, 0.85), Color(0.8, 0.86, 0.9), Color.WHITE][band] as Color
	if _gem_mat:
		_gem_mat.albedo_color = _tint
	if _light:
		_light.light_energy = _light_base * [0.4, 0.7, 1.0][band]
		_light.light_color = VisualPalette.color("turquoise").lerp(Color("6f8cff"), [0.5, 0.15, 0.0][band])
	_flicker = 1.0 if band == 0 else 0.0
	var an := get_node_or_null("UnitAnimator") as UnitAnimator
	if an:
		an.idle_rate = [0.55, 0.75, 1.0][band]
		if an.current == &"idle" and is_inside_tree():
			an.play(&"idle")


func hurt(amount_ratio: float = 0.2) -> void:
	_bind()
	var a := clampf(amount_ratio, 0.05, 1.0)
	if not is_inside_tree():
		return
	var fx := VisualSlots.make("fx.heart_damage")
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.scale = Vector3.ONE * (0.7 + 0.8 * a)
	# Cracks flash red (all of them briefly, then back to the health state).
	if _crack_flash == null:
		_crack_flash = VisualPalette.glow("ember_red").duplicate() as StandardMaterial3D
	for c: Node3D in _cracks:
		c.visible = true
		for g: Node in c.find_children("*", "GeometryInstance3D", true, false) + ([c] if c is GeometryInstance3D else []):
			(g as GeometryInstance3D).material_overlay = _crack_flash
	if _gem_mat:
		_gem_mat.albedo_color = Color(1.0, 0.55, 0.5)
	var t := create_tween()
	if not UnitAnimator.motion_reduced():
		var model := get_node_or_null("Model") as Node3D
		if model:
			var p0 := model.position
			var amp := 0.06 + 0.12 * a
			t.tween_property(model, "position", p0 + Vector3(amp, 0, 0), 0.04)
			t.tween_property(model, "position", p0 - Vector3(amp, 0, 0), 0.06)
			t.tween_property(model, "position", p0, 0.06)
	t.tween_interval(0.2)
	t.tween_callback(func() -> void:
		for c: Node3D in _cracks:
			for g: Node in c.find_children("*", "GeometryInstance3D", true, false) + ([c] if c is GeometryInstance3D else []):
				(g as GeometryInstance3D).material_overlay = null
		set_health(health))


func _process(_dt: float) -> void:
	if _flicker <= 0.0 or UnitAnimator.motion_reduced():
		return
	if randf() < 0.18:
		var f := randf_range(0.55, 1.0)
		if _gem_mat:
			_gem_mat.albedo_color = _tint * f
		if _light:
			_light.light_energy = _light_base * 0.4 * f
