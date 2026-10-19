class_name TargetMarker
extends Node3D
## Flat ground feedback for targeting (slots "fx.ring" and "fx.floor_target").
##   ring  : a unit's feet. set_radius(VisualSlots.footprint_radius(slot_id)).
##   strip : a floor's front, x -5.6..5.6 (floor-targeted spells).
## set_kind(&"none" | &"target" | &"selected" | &"invalid" | &"danger")
##   target   turquoise, gently pulsing   selected  amber, solid
##   invalid  red, dim (static)           danger    red pulse (dies in the forecast)
## The strip supports none/target/selected (others map to the same colours).
## One or two unshaded meshes with an own material, no lights, no physics (never
## blocks clicks). Reduced motion: no pulsing, just the colour. Origin = ground (y=0).

const COLORS := {&"target": "turquoise", &"selected": "amber", &"invalid": "ember_red", &"danger": "ember_red"}
const ALPHA := {&"target": 0.85, &"selected": 0.95, &"invalid": 0.35, &"danger": 0.9}
const STRIP_X := 5.6

var shape: StringName = &"ring"
var kind: StringName = &"none"
var radius: float = 0.6

var _edge: MeshInstance3D
var _band: MeshInstance3D
var _fill: MeshInstance3D
var _edge_mat: StandardMaterial3D
var _fill_mat: StandardMaterial3D
var _tween: Tween


static func create(marker_shape: StringName) -> TargetMarker:
	var m := TargetMarker.new()
	m.shape = marker_shape
	m._build()
	m.set_kind(&"none")
	return m


func _build() -> void:
	_edge_mat = _mat()
	_fill_mat = _mat()
	_edge = MeshInstance3D.new()
	_edge.name = "Edge"
	_fill = MeshInstance3D.new()
	_fill.name = "Fill"
	# The battle camera looks almost side-on (pitch ~7 deg), which flattens any decal,
	# so each marker also has a short glowing vertical band that reads from the side.
	_band = MeshInstance3D.new()
	_band.name = "Band"
	if shape == &"strip":
		_edge.mesh = ProxyMesh.box(Vector3(STRIP_X * 2.0, 0.01, 0.1))
		_edge.position = Vector3(0, 0.035, 1.5)
		_fill.mesh = ProxyMesh.box(Vector3(STRIP_X * 2.0, 0.01, 2.9))
		_fill.position = Vector3(0, 0.03, -0.05)
		_band.mesh = ProxyMesh.box(Vector3(STRIP_X * 2.0, 0.14, 0.02))
		_band.position = Vector3(0, 0.07, 1.56)
	else:
		_edge.mesh = ProxyMesh.ring_flat(0.78, 1.0)
		_edge.position.y = 0.035
		_fill.mesh = ProxyMesh.ring_flat(0.0, 0.78)
		_fill.position.y = 0.03
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.16
		cm.radial_segments = 32
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		_band.mesh = cm
		_band.position.y = 0.08
	for mi: MeshInstance3D in [_fill, _edge, _band]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_edge.material_override = _edge_mat
	_band.material_override = _edge_mat
	_fill.material_override = _fill_mat
	_fill_mat.render_priority = 1
	_edge_mat.render_priority = 2
	set_radius(radius)


func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


## Ring only: outer radius in metres (strip: ignored).
func set_radius(r: float) -> void:
	radius = maxf(r, 0.1)
	if shape == &"ring" and _edge:
		_edge.scale = Vector3(radius, 1, radius)
		_fill.scale = Vector3(radius, 1, radius)
		_band.scale = Vector3(radius, 1, radius)


func set_kind(k: StringName) -> void:
	kind = k if (k in COLORS or k == &"none") else &"none"
	if _tween and _tween.is_valid():
		_tween.kill()
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	set_radius(radius)
	visible = kind != &"none"
	if not visible or _edge_mat == null:
		return
	var c := VisualPalette.color(str(COLORS[kind]))
	var a: float = ALPHA[kind]
	_edge_mat.albedo_color = Color(c, a)
	_fill_mat.albedo_color = Color(c, a * (0.22 if shape == &"ring" else 0.12))
	if kind in [&"target", &"danger"] and not UnitAnimator.motion_reduced() and is_inside_tree():
		_pulse(a, 1.4 if kind == &"target" else 0.55)


func _ready() -> void:
	if kind in [&"target", &"danger"]:
		set_kind(kind)


func _pulse(a: float, period: float) -> void:
	_tween = create_tween().set_loops()
	var lo := Color(_edge_mat.albedo_color, a * 0.45)
	var hi := Color(_edge_mat.albedo_color, a)
	_tween.tween_property(_edge_mat, "albedo_color", lo, period * 0.5).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_edge_mat, "albedo_color", hi, period * 0.5).set_trans(Tween.TRANS_SINE)
	if shape == &"ring":
		var s1 := Vector3(radius * 1.06, 1, radius * 1.06)
		var s0 := Vector3(radius, 1, radius)
		var t2 := create_tween().set_loops()
		t2.tween_property(_edge, "scale", s1, period * 0.5).set_trans(Tween.TRANS_SINE)
		t2.parallel().tween_property(_band, "scale", s1, period * 0.5).set_trans(Tween.TRANS_SINE)
		t2.tween_property(_edge, "scale", s0, period * 0.5).set_trans(Tween.TRANS_SINE)
		t2.parallel().tween_property(_band, "scale", s0, period * 0.5).set_trans(Tween.TRANS_SINE)
		_scale_tween = t2


var _scale_tween: Tween


func _exit_tree() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
