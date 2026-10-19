class_name ProxyBuilder
extends RefCounted
## Procedural low-poly proxies for every LASTROOT visual slot (until the owner
## maps a purchased model). Built from faceted primitives (ProxyMesh) and the
## shared VisualPalette. Conventions (same as the wrapper contract):
##   origin = feet / base centre, +Y up, front = -Z (Godot forward), metres.
## Named nodes the UnitAnimator uses: "Staff" (cast raise), "Glow*" (cast/heart pulse),
## "Head" (quadruped dip). Visual only: no collision, no gameplay.

var _at: Node3D
var _rng := RandomNumberGenerator.new()


## Builds the proxy for `spec` ({"builder": name, ...}) under a new "Model" node.
static func build(slot_id: String, spec: Dictionary) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	var b := ProxyBuilder.new()
	b._at = model
	b._rng.seed = hash(slot_id)
	var name := str(spec.get("builder", ""))
	var fn := "_b_" + name
	if name == "parts":
		b._parts(spec.get("parts", []) as Array)
	elif b.has_method(fn):
		b.call(fn, spec)
	else:
		push_warning("ProxyBuilder: unknown builder '%s' for %s" % [name, slot_id])
		b.missing(slot_id)
	return model


# ------------------------------------------------------------------ helpers

func _p(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, nm: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	if not nm.is_empty():
		mi.name = nm
	var std := mat as StandardMaterial3D
	if std and (std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or std.emission_enabled):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Readable names (Glow_Dot2, ...) so animators can find the glow parts.
	_at.add_child(mi, not nm.is_empty())
	return mi


func _grp(nm: String, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.name = nm
	g.position = pos
	g.rotation_degrees = rot
	_at.add_child(g, true)
	_at = g
	return g


func _end(g: Node3D) -> void:
	_at = g.get_parent() as Node3D


func _m(key: String) -> StandardMaterial3D:
	return VisualPalette.mat(key)


func _g(key: String) -> StandardMaterial3D:
	return VisualPalette.glow(key)


func _r(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


## A tube through points (roots, branches), tapering r0 -> r1.
func _tube(pts: Array, r0: float, r1: float, key: String, seg: int = 6) -> void:
	for i: int in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var t0 := float(i) / float(pts.size() - 1)
		var t1 := float(i + 1) / float(pts.size() - 1)
		var ra := lerpf(r0, r1, t0)
		var rb := lerpf(r0, r1, t1)
		var dir := b - a
		var mi := MeshInstance3D.new()
		mi.mesh = ProxyMesh.cyl(rb, ra, dir.length() + minf(ra, rb) * 0.6, seg)
		mi.material_override = _m(key)
		mi.position = (a + b) * 0.5
		if dir.normalized().abs().is_equal_approx(Vector3.UP):
			mi.basis = Basis.IDENTITY if dir.y > 0 else Basis(Vector3.RIGHT, PI)
		else:
			mi.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
		_at.add_child(mi)


## Two glowing eyes looking down -Z.
func _eyes(y: float, z: float, dx: float, key: String, s: Vector3 = Vector3(0.09, 0.06, 0.04)) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.box(s), _g(key), Vector3(dx * sx, y, z), Vector3(0, 0, -10.0 * sx), Vector3.ONE, "Glow_Eye")


func missing(slot_id: String) -> void:
	_p(ProxyMesh.box(Vector3(1, 1, 1)), VisualPalette.glow("missing"), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3.ONE, "Missing")
	var l := Label3D.new()
	l.text = slot_id if not slot_id.is_empty() else "?"
	l.position = Vector3(0, 1.3, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.outline_size = 8
	_at.add_child(l)


## Generic data-driven parts list (owner can author proxies in JSON):
## [{"shape": "box|cyl|sphere|prism|rock", "size": [x,y,z] | "r": .., "h": .., "pos": [..], "rot": [..], "color": key, "glow": bool}]
func _parts(parts: Array) -> void:
	for pv: Variant in parts:
		if not pv is Dictionary:
			continue
		var p: Dictionary = pv
		var sz := _v3(p.get("size", [1, 1, 1]))
		var r := float(p.get("r", 0.5))
		var mesh: Mesh
		match str(p.get("shape", "box")):
			"cyl":
				mesh = ProxyMesh.cyl(float(p.get("top", r)), r, float(p.get("h", 1.0)), int(p.get("seg", 7)))
			"sphere":
				mesh = ProxyMesh.sphere(r)
			"prism":
				mesh = ProxyMesh.prism(sz)
			"rock":
				mesh = ProxyMesh.rock(r, int(p.get("seed", 1)))
			_:
				mesh = ProxyMesh.box(sz)
		var key := str(p.get("color", "stone"))
		_p(mesh, _g(key) if bool(p.get("glow", false)) else _m(key), _v3(p.get("pos", [0, 0, 0])), _v3(p.get("rot", [0, 0, 0])))


static func _v3(v: Variant) -> Vector3:
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


# ------------------------------------------------------------------ Bark (allies)

## B01 The Barkwarden: heavy bark/stone golem, broad chest, amber eyes, plank shield.
func _b_barkwarden(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(0.21, 0.27, 0.72), _m("bark_dark"), Vector3(0.33 * sx, 0.36, 0.02))
		_p(ProxyMesh.rock(0.3, 3 + int(sx)), _m("stone_dark"), Vector3(0.34 * sx, 0.1, -0.06), Vector3(0, 20 * sx, 0), Vector3(1.1, 1, 1.25))
	_p(ProxyMesh.box(Vector3(0.95, 0.36, 0.62)), _m("bark"), Vector3(0, 0.82, 0.02))
	var torso := _grp("Torso", Vector3(0, 1.0, 0.04), Vector3(-8, 0, 0))
	_p(ProxyMesh.cyl(0.78, 0.5, 0.95, 6), _m("bark"), Vector3(0, 0.42, 0), Vector3.ZERO, Vector3(1.0, 1, 0.66))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.box(Vector3(0.56, 0.52, 0.14)), _m("bark_light"), Vector3(0.29 * sx, 0.5, -0.43), Vector3(4, 14 * sx, 6 * sx))
	_p(ProxyMesh.box(Vector3(0.07, 0.46, 0.04)), _g("amber"), Vector3(0, 0.46, -0.5), Vector3(0, 0, 4), Vector3.ONE, "Glow_Core")
	_p(ProxyMesh.box(Vector3(0.05, 0.22, 0.04)), _g("amber_soft"), Vector3(0.1, 0.62, -0.49), Vector3(0, 0, -38))
	_p(ProxyMesh.box(Vector3(0.05, 0.18, 0.04)), _g("amber_soft"), Vector3(-0.09, 0.28, -0.49), Vector3(0, 0, 32))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.rock(0.4, 11 + int(sx)), _m("stone"), Vector3(0.8 * sx, 0.78, 0.0), Vector3(0, 30 * sx, 0), Vector3(1, 1.1, 1))
		_p(ProxyMesh.sphere(0.32, 7, 3, true), _m("moss_light"), Vector3(0.8 * sx, 1.02, 0.0), Vector3.ZERO, Vector3(1.05, 0.45, 1.0))
	_p(ProxyMesh.box(Vector3(1.0, 0.1, 0.5)), _m("moss"), Vector3(0, 0.9, 0.08))
	var head := _grp("Head", Vector3(0, 0.98, -0.2))
	_p(ProxyMesh.box(Vector3(0.52, 0.46, 0.48)), _m("bark"), Vector3(0, 0.0, 0), Vector3(0, 0, 0))
	_p(ProxyMesh.box(Vector3(0.6, 0.13, 0.22)), _m("bark_dark"), Vector3(0, 0.13, -0.2), Vector3(-12, 0, 0))
	_p(ProxyMesh.box(Vector3(0.36, 0.12, 0.12)), _m("bark_dark"), Vector3(0, -0.16, -0.22))
	_eyes(0.03, -0.25, 0.13, "amber", Vector3(0.12, 0.06, 0.04))
	for i: int in 3:
		var a := -30.0 + 30.0 * i
		_p(ProxyMesh.cyl(0.012, 0.035, 0.3, 5), _m("bark_light"), Vector3(-0.15 + 0.15 * i, 0.32, 0.08), Vector3(-10, 0, a))
	_p(ProxyMesh.prism(Vector3(0.12, 0.14, 0.03)), _m("leaf_light"), Vector3(0.27, 0.56, 0.08), Vector3(0, 0, -50))
	_end(head)
	_end(torso)
	for sx: float in [-1.0, 1.0]:
		var arm := _grp("Arm", Vector3(0.88 * sx, 1.72, 0.02), Vector3(-6, 0, 10 * sx))
		_p(ProxyMesh.cyl(0.19, 0.17, 0.62), _m("bark_dark"), Vector3(0, -0.3, 0))
		_p(ProxyMesh.cyl(0.25, 0.2, 0.56), _m("bark"), Vector3(0, -0.82, -0.04))
		_p(ProxyMesh.rock(0.3, 21 + int(sx)), _m("stone_warm"), Vector3(0, -1.18, -0.06), Vector3.ZERO, Vector3(1, 1.15, 1))
		if sx < 0.0:
			var sh := _grp("Shield", Vector3(-0.12, -0.78, -0.42), Vector3(0, 28, -10))
			for k: int in 3:
				_p(ProxyMesh.box(Vector3(0.22, 1.05 - 0.12 * absf(k - 1), 0.1)), _m("wood_plank"), Vector3(-0.23 + 0.23 * k, 0, 0), Vector3(0, 0, _r(-3, 3)))
			for y: float in [-0.28, 0.26]:
				_p(ProxyMesh.box(Vector3(0.74, 0.09, 0.05)), _m("bark_dark"), Vector3(0, y, -0.06))
			_p(ProxyMesh.sphere(0.13, 6, 3, true), _m("moss_light"), Vector3(0.18, 0.47, 0.0), Vector3.ZERO, Vector3(1.2, 0.6, 0.8))
			_end(sh)
		_end(arm)


## B02 Root Sprout: little sapling with root feet and two leaves.
func _b_root_sprout(_s: Dictionary) -> void:
	for i: int in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		_tube([Vector3(0, 0.25, 0), Vector3(cos(a) * 0.16, 0.1, sin(a) * 0.16), Vector3(cos(a) * 0.26, 0.0, sin(a) * 0.26)], 0.06, 0.025, "bark_dark", 5)
	_p(ProxyMesh.cyl(0.14, 0.2, 0.42, 6), _m("bark"), Vector3(0, 0.42, 0))
	var head := _grp("Head", Vector3(0, 0.72, 0))
	_p(ProxyMesh.sphere(0.2, 7, 4), _m("bark_light"), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 0.95))
	_eyes(0.02, -0.17, 0.07, "amber", Vector3(0.06, 0.06, 0.03))
	_p(ProxyMesh.cyl(0.015, 0.03, 0.22, 5), _m("bark"), Vector3(0, 0.26, 0))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.sphere(0.12, 6, 3), _m("leaf_light"), Vector3(0.11 * sx, 0.37, 0), Vector3(0, 0, -40 * sx), Vector3(1.4, 0.35, 0.8))
	_end(head)
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.14 * sx, 0.52, 0), Vector3(0.24 * sx, 0.4, -0.05), Vector3(0.27 * sx, 0.28, -0.08)], 0.04, 0.025, "bark", 5)


## B03 Barkshield: squat, wide bark guardian behind a tall plank wall-shield.
func _b_barkshield(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(0.16, 0.2, 0.5), _m("bark_dark"), Vector3(0.24 * sx, 0.25, 0.05))
	_p(ProxyMesh.cyl(0.55, 0.42, 0.75, 6), _m("bark"), Vector3(0, 0.85, 0.08), Vector3.ZERO, Vector3(1, 1, 0.75))
	_p(ProxyMesh.rock(0.3, 31), _m("stone"), Vector3(0.5, 1.2, 0.08))
	_p(ProxyMesh.rock(0.28, 32), _m("stone"), Vector3(-0.5, 1.18, 0.08))
	var head := _grp("Head", Vector3(0, 1.32, 0.0))
	_p(ProxyMesh.box(Vector3(0.38, 0.32, 0.36)), _m("bark"), Vector3.ZERO)
	_eyes(0.0, -0.19, 0.09, "amber")
	_p(ProxyMesh.sphere(0.2, 6, 3, true), _m("moss_light"), Vector3(0, 0.15, 0.02), Vector3.ZERO, Vector3(1.2, 0.5, 1.1))
	_end(head)
	var sh := _grp("Shield", Vector3(0, 0.78, -0.55), Vector3(-6, 0, 0))
	for k: int in 4:
		_p(ProxyMesh.box(Vector3(0.27, 1.35 - 0.14 * absf(k - 1.5), 0.12)), _m("wood_plank" if k % 2 == 0 else "bark_light"), Vector3(-0.42 + 0.28 * k, 0, 0), Vector3(0, 0, _r(-2, 2)))
	for y: float in [-0.38, 0.34]:
		_p(ProxyMesh.box(Vector3(1.18, 0.1, 0.06)), _m("bark_dark"), Vector3(0, y, -0.08))
	_p(ProxyMesh.sphere(0.12, 6, 3), _g("amber"), Vector3(0, 0, -0.1), Vector3.ZERO, Vector3(1, 1, 0.4), "Glow_Boss")
	_p(ProxyMesh.sphere(0.2, 6, 3, true), _m("moss"), Vector3(-0.35, 0.62, 0), Vector3.ZERO, Vector3(1.4, 0.5, 0.7))
	_end(sh)


## B04 Thornhart: QUADRUPED stag of bark with thorn antlers. Head toward -Z.
func _b_thornhart(_s: Dictionary) -> void:
	for p: Vector3 in [Vector3(-0.2, 0, -0.42), Vector3(0.2, 0, -0.42), Vector3(-0.2, 0, 0.42), Vector3(0.2, 0, 0.42)]:
		_tube([Vector3(p.x, 0.88, p.z), Vector3(p.x, 0.5, p.z + 0.05), Vector3(p.x, 0.06, p.z - 0.02)], 0.075, 0.04, "bark_dark", 5)
		_p(ProxyMesh.box(Vector3(0.09, 0.08, 0.12)), _m("stone_dark"), Vector3(p.x, 0.04, p.z - 0.03))
	var body := _grp("Body", Vector3(0, 0.98, 0))
	_p(ProxyMesh.cyl(0.3, 0.27, 1.2, 7), _m("bark"), Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, 1, 0.85))
	_p(ProxyMesh.box(Vector3(0.36, 0.1, 0.95)), _m("moss"), Vector3(0, 0.25, 0.02))
	for i: int in 5:
		_p(ProxyMesh.prism(Vector3(0.08, 0.22, 0.08)), _m("thorns"), Vector3(_r(-0.06, 0.06), 0.33, -0.36 + 0.18 * i), Vector3(18, 0, _r(-12, 12)))
	_p(ProxyMesh.prism(Vector3(0.12, 0.25, 0.08)), _m("bark_dark"), Vector3(0, 0.12, 0.63), Vector3(70, 0, 0))
	_end(body)
	var head := _grp("Head", Vector3(0, 1.22, -0.62))
	_tube([Vector3(0, -0.1, 0.12), Vector3(0, 0.15, -0.08), Vector3(0, 0.32, -0.2)], 0.16, 0.11, "bark", 6)
	_p(ProxyMesh.box(Vector3(0.24, 0.24, 0.42)), _m("bark_light"), Vector3(0, 0.38, -0.33), Vector3(18, 0, 0))
	_p(ProxyMesh.box(Vector3(0.16, 0.14, 0.18)), _m("bark_dark"), Vector3(0, 0.3, -0.56), Vector3(18, 0, 0))
	_eyes(0.43, -0.4, 0.125, "amber", Vector3(0.04, 0.05, 0.08))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.prism(Vector3(0.1, 0.18, 0.04)), _m("bark"), Vector3(0.15 * sx, 0.55, -0.25), Vector3(0, 0, -45 * sx))
		var base := Vector3(0.08 * sx, 0.5, -0.3)
		var a1 := base + Vector3(0.2 * sx, 0.2, 0.06)
		var a2 := a1 + Vector3(0.2 * sx, 0.16, 0.14)
		_tube([base, a1, a2], 0.04, 0.018, "bark_dark", 5)
		for t: Array in [[a1, Vector3(0.02 * sx, 0.22, -0.12)], [a2, Vector3(0.12 * sx, 0.15, -0.05)], [a1.lerp(a2, 0.5), Vector3(0.15 * sx, 0.05, 0.12)], [base.lerp(a1, 0.5), Vector3(-0.02 * sx, 0.2, -0.08)]]:
			var tp: Vector3 = t[0]
			var td: Vector3 = t[1]
			_tube([tp, tp + td], 0.02, 0.008, "bark_dark", 4)
			_p(ProxyMesh.prism(Vector3(0.035, 0.07, 0.035)), _m("thorns"), tp + td + td.normalized() * 0.03, Vector3.ZERO, Vector3.ONE).basis = Basis(Quaternion(Vector3.UP, td.normalized()))
	_end(head)


## B05 Sapbearer: round little healer carrying a glowing amber sap orb.
func _b_sapbearer(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(0.07, 0.09, 0.28, 5), _m("bark_dark"), Vector3(0.14 * sx, 0.14, 0))
	_p(ProxyMesh.sphere(0.34, 8, 5), _m("bark_light"), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1, 0.95, 0.9))
	_p(ProxyMesh.sphere(0.2, 7, 3, true), _m("moss_light"), Vector3(0, 0.78, 0.04), Vector3.ZERO, Vector3(1.3, 0.5, 1.2))
	var head := _grp("Head", Vector3(0, 0.6, -0.26))
	_eyes(0.04, -0.03, 0.09, "amber", Vector3(0.07, 0.07, 0.03))
	_end(head)
	_p(ProxyMesh.box(Vector3(0.3, 0.06, 0.4)), _m("bark_dark"), Vector3(0, 0.78, 0.22), Vector3(30, 0, 0))
	_p(ProxyMesh.cyl(0.13, 0.17, 0.32, 7), _m("wood_plank"), Vector3(0, 0.85, 0.3))
	_p(ProxyMesh.sphere(0.15, 7, 4), _g("amber"), Vector3(0, 1.08, 0.3), Vector3.ZERO, Vector3.ONE, "Glow_Sap")
	_p(ProxyMesh.cyl(0.05, 0.05, 0.08, 6), _m("bark_dark"), Vector3(0, 1.25, 0.3))
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.3 * sx, 0.6, -0.05), Vector3(0.38 * sx, 0.42, -0.14)], 0.05, 0.04, "bark", 5)


## B06 Old Oak: 3-space walking oak; wide crown kept low so its number stays visible.
func _b_old_oak(_s: Dictionary) -> void:
	for i: int in 5:
		var a := TAU * float(i) / 5.0 + 0.3
		_tube([Vector3(cos(a) * 0.35, 0.6, sin(a) * 0.3), Vector3(cos(a) * 0.65, 0.25, sin(a) * 0.5), Vector3(cos(a) * 0.9, 0.0, sin(a) * 0.62)], 0.17, 0.06, "bark_dark", 6)
	_p(ProxyMesh.cyl(0.55, 0.7, 1.3, 8), _m("bark"), Vector3(0, 1.05, 0))
	for i: int in 6:
		var a := TAU * float(i) / 6.0
		_p(ProxyMesh.box(Vector3(0.12, 1.2, 0.1)), _m("bark_dark" if i % 2 == 0 else "bark_light"), Vector3(cos(a) * 0.6, 1.05, sin(a) * 0.6), Vector3(0, -rad_to_deg(a), _r(-6, 6)))
	var head := _grp("Head", Vector3(0, 1.25, -0.58))
	_p(ProxyMesh.box(Vector3(0.5, 0.12, 0.12)), _m("bark_dark"), Vector3(0, 0.14, 0), Vector3(0, 0, 4))
	_eyes(0.03, -0.04, 0.15, "amber", Vector3(0.13, 0.07, 0.05))
	_p(ProxyMesh.box(Vector3(0.3, 0.08, 0.06)), _g("amber_soft"), Vector3(0, -0.24, -0.02))
	_end(head)
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.55 * sx, 1.45, 0), Vector3(0.95 * sx, 1.25, -0.15), Vector3(1.1 * sx, 0.8, -0.25)], 0.16, 0.09, "bark", 6)
		_p(ProxyMesh.sphere(0.2, 6, 3), _m("leaf"), Vector3(1.1 * sx, 0.75, -0.25), Vector3.ZERO, Vector3(1.1, 0.8, 1.1))
	for c: Array in [[Vector3(0, 2.05, 0.05), 0.75], [Vector3(-0.6, 1.95, 0.15), 0.55], [Vector3(0.62, 1.98, 0.1), 0.58], [Vector3(0.1, 2.22, 0.3), 0.5], [Vector3(-0.2, 2.0, -0.35), 0.45]]:
		_p(ProxyMesh.rock(float(c[1]), int(c[1] * 100.0), 0.62), _m("leaf" if float(c[1]) > 0.5 else "leaf_light"), c[0] as Vector3)
	_p(ProxyMesh.sphere(0.4, 7, 3, true), _m("moss_light"), Vector3(0.0, 1.66, 0), Vector3.ZERO, Vector3(1.6, 0.4, 1.5))


# ------------------------------------------------------------------ Spore folk (allies)

## Mushroom hat: violet top, pale glowing gills, white spots.
func _hat(y: float, r: float, top_key: String = "cap_violet", squash: float = 0.6, spots: int = 6, rim_key: String = "") -> void:
	_p(ProxyMesh.cyl(r * 0.9, r * 0.98, r * 0.09, 10), _g("cap_gill"), Vector3(0, y, 0))
	_p(ProxyMesh.sphere(r, 10, 4, true), _m(top_key), Vector3(0, y + r * 0.03, 0), Vector3.ZERO, Vector3(1, squash, 1), "Hat")
	if not rim_key.is_empty():
		_p(ProxyMesh.torus(r * 0.9, r * 1.04, 14, 4), _m(rim_key), Vector3(0, y + r * 0.04, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	for i: int in spots:
		var a := TAU * float(i) / float(spots) + 0.4
		var rr := r * (0.45 if i % 2 == 0 else 0.7)
		var hy := sqrt(maxf(r * r - rr * rr, 0.0)) * squash
		_p(ProxyMesh.sphere(r * 0.12, 6, 3, true), _m("cap_violet" if top_key == "cap_pale" else "cap_white"), Vector3(cos(a) * rr, y + hy - r * 0.02, sin(a) * rr), Vector3.ZERO, Vector3(1, 0.5, 1))


## S01 The Spore Sage: small robed figure, huge violet-white hat, staff with turquoise glow.
func _b_spore_sage(_s: Dictionary) -> void:
	_p(ProxyMesh.cyl(0.17, 0.36, 0.72, 8), _m("spore_body"), Vector3(0, 0.36, 0))
	_p(ProxyMesh.cyl(0.36, 0.39, 0.08, 8), _m("cap_violet_dark"), Vector3(0, 0.04, 0))
	_p(ProxyMesh.box(Vector3(0.06, 0.6, 0.04)), _m("cap_white"), Vector3(0, 0.38, -0.27), Vector3(-17, 0, 0))
	var head := _grp("Head", Vector3(0, 0.82, 0))
	_p(ProxyMesh.sphere(0.17, 7, 4), _m("spore_skin"), Vector3.ZERO)
	_p(ProxyMesh.cyl(0.13, 0.015, 0.4, 6), _m("beard"), Vector3(0, -0.2, -0.1), Vector3(-14, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.sphere(0.035, 6, 3), _g("turquoise"), Vector3(0.065 * sx, 0.02, -0.15), Vector3.ZERO, Vector3.ONE, "Glow_Eye")
	_end(head)
	_hat(1.0, 0.66, "cap_pale", 0.72, 7, "cap_violet")
	_p(ProxyMesh.cyl(0.08, 0.1, 0.14, 6), _m("cap_white"), Vector3(0, 0.95, 0))
	_p(ProxyMesh.sphere(0.06, 6, 3), _m("spore_skin"), Vector3(-0.27, 0.55, -0.1))
	_tube([Vector3(0.14, 0.68, -0.02), Vector3(0.32, 0.64, -0.08), Vector3(0.46, 0.6, -0.1)], 0.07, 0.05, "spore_body", 5)
	var staff := _grp("Staff", Vector3(0.5, 0.6, -0.1), Vector3(0, 0, -11))
	_p(ProxyMesh.sphere(0.065, 6, 3), _m("spore_skin"), Vector3(-0.02, 0, 0))
	_tube([Vector3(0.0, -0.6, 0.02), Vector3(0.0, 0.3, 0), Vector3(0.03, 0.75, 0), Vector3(-0.04, 0.9, 0)], 0.03, 0.022, "bark_dark", 5)
	_tube([Vector3(-0.04, 0.9, 0), Vector3(0.06, 1.0, 0), Vector3(0.0, 1.06, 0)], 0.02, 0.012, "bark_dark", 4)
	_p(ProxyMesh.sphere(0.08, 7, 4), _g("turquoise"), Vector3(0.0, 0.97, 0), Vector3.ZERO, Vector3.ONE, "Glow_Staff")
	_p(ProxyMesh.sphere(0.15, 8, 5), VisualPalette.glow("turquoise", 0.22, true), Vector3(0.0, 0.97, 0), Vector3.ZERO, Vector3.ONE, "Glow_Halo")
	_end(staff)


## S02 Sporeling: tiny mushroom creature with glowing antenna spores.
func _b_sporeling(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(0.05, 0.06, 0.16, 5), _m("spore_skin"), Vector3(0.09 * sx, 0.08, 0))
	_p(ProxyMesh.sphere(0.2, 7, 4), _m("spore_body"), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 1.05, 0.95))
	var head := _grp("Head", Vector3(0, 0.4, -0.16))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.sphere(0.035, 6, 3), _g("cap_white"), Vector3(0.07 * sx, 0, 0), Vector3.ZERO, Vector3.ONE, "Glow_Eye")
	_end(head)
	_hat(0.5, 0.34, "cap_violet", 0.55, 5)
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.12 * sx, 0.62, 0.05), Vector3(0.2 * sx, 0.78, 0.08), Vector3(0.24 * sx, 0.86, 0.05)], 0.012, 0.008, "cap_white", 4)
		_p(ProxyMesh.sphere(0.045, 6, 3), _g("turquoise"), Vector3(0.24 * sx, 0.88, 0.05), Vector3.ZERO, Vector3.ONE, "Glow_Spore")
	_tube([Vector3(0.18, 0.3, -0.02), Vector3(0.24, 0.2, -0.1)], 0.035, 0.03, "spore_skin", 5)
	_tube([Vector3(-0.18, 0.3, -0.02), Vector3(-0.24, 0.2, -0.1)], 0.035, 0.03, "spore_skin", 5)


## S03 Fungal Wall: wide stack of shelf fungi on mycelium stalks (static rig).
func _b_fungal_wall(_s: Dictionary) -> void:
	_p(ProxyMesh.rock(0.55, 41, 0.5), _m("spore_skin"), Vector3(0, 0.12, 0.05), Vector3.ZERO, Vector3(1.6, 1, 0.9))
	for st: Array in [[Vector3(-0.45, 0, 0), 0.95], [Vector3(0.0, 0, 0.12), 1.35], [Vector3(0.42, 0, -0.02), 1.1]]:
		var p: Vector3 = st[0]
		var h: float = st[1]
		_p(ProxyMesh.cyl(0.09, 0.15, h, 6), _m("cap_white"), p + Vector3(0, h * 0.5, 0))
	for c: Array in [[Vector3(-0.45, 0.95, 0), 0.42, "cap_violet"], [Vector3(0.0, 1.35, 0.12), 0.5, "cap_violet_dark"], [Vector3(0.42, 1.1, -0.02), 0.44, "cap_violet"],
			[Vector3(-0.2, 0.55, -0.15), 0.34, "cap_violet_dark"], [Vector3(0.28, 0.6, -0.18), 0.36, "cap_violet"], [Vector3(-0.62, 0.42, -0.05), 0.28, "cap_violet"], [Vector3(0.66, 0.4, -0.06), 0.26, "cap_violet_dark"]]:
		var p: Vector3 = c[0]
		var r: float = c[1]
		_p(ProxyMesh.cyl(r * 0.92, r, r * 0.12, 9), _g("cap_gill"), p)
		_p(ProxyMesh.sphere(r, 9, 3, true), _m(str(c[2])), p + Vector3(0, r * 0.03, 0), Vector3.ZERO, Vector3(1, 0.38, 0.85))
	var head := _grp("Head", Vector3(0, 0.82, -0.32))
	_eyes(0.0, 0.0, 0.1, "turquoise", Vector3(0.07, 0.05, 0.03))
	_end(head)
	for i: int in 5:
		_p(ProxyMesh.sphere(0.04, 6, 3), _g("turquoise"), Vector3(_r(-0.6, 0.6), _r(0.2, 1.2), _r(-0.35, -0.2)), Vector3.ZERO, Vector3.ONE, "Glow_Spore")


## S04 Nightcap: dark indigo assassin with a pointed cap and twin thorn daggers.
func _b_nightcap(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(0.05, 0.07, 0.3, 5), _m("spore_skin"), Vector3(0.1 * sx, 0.15, 0.04), Vector3(0, 0, 6 * sx))
	_p(ProxyMesh.cyl(0.13, 0.2, 0.4, 6), _m("cap_violet_dark"), Vector3(0, 0.48, 0), Vector3(-12, 0, 0))
	var head := _grp("Head", Vector3(0, 0.74, -0.06))
	_p(ProxyMesh.sphere(0.14, 6, 3), _m("spore_skin"), Vector3.ZERO)
	_eyes(0.0, -0.13, 0.055, "poison_violet", Vector3(0.06, 0.03, 0.03))
	_end(head)
	_p(ProxyMesh.cyl(0.38, 0.4, 0.05, 9), _g("cap_gill"), Vector3(0, 0.84, -0.05))
	_p(ProxyMesh.cyl(0.0, 0.4, 0.42, 9), _m("spore_body"), Vector3(0, 1.07, -0.05), Vector3(-8, 0, 0), Vector3.ONE, "Hat")
	_p(ProxyMesh.cyl(0.0, 0.06, 0.14, 6), _g("poison_violet"), Vector3(0, 1.3, -0.08), Vector3(-25, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.16 * sx, 0.6, -0.02), Vector3(0.24 * sx, 0.46, -0.16)], 0.035, 0.03, "spore_skin", 5)
		_p(ProxyMesh.prism(Vector3(0.05, 0.32, 0.03)), _m("cap_white"), Vector3(0.25 * sx, 0.5, -0.32), Vector3(-80, 0, 0))


## S05 Mycelium Keeper: tall keeper with a turquoise spore lantern and mycelium threads.
func _b_mycelium_keeper(_s: Dictionary) -> void:
	_p(ProxyMesh.cyl(0.16, 0.34, 0.95, 8), _m("spore_body"), Vector3(0, 0.48, 0))
	for i: int in 6:
		var a := TAU * float(i) / 6.0
		_tube([Vector3(cos(a) * 0.28, 0.25, sin(a) * 0.28), Vector3(cos(a) * 0.42, 0.06, sin(a) * 0.42), Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5)], 0.03, 0.01, "cap_white", 4)
	var head := _grp("Head", Vector3(0, 1.05, 0))
	_p(ProxyMesh.sphere(0.17, 7, 4), _m("spore_skin"), Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.sphere(0.035, 6, 3), _g("turquoise"), Vector3(0.065 * sx, 0.0, -0.15), Vector3.ZERO, Vector3.ONE, "Glow_Eye")
	_end(head)
	_hat(1.2, 0.44, "cap_violet_dark", 0.75, 5)
	var staff := _grp("Staff", Vector3(-0.32, 0.72, -0.12))
	_tube([Vector3(0, -0.72, 0), Vector3(0, 0.55, 0), Vector3(0.12, 0.7, 0)], 0.025, 0.02, "bark_dark", 5)
	_p(ProxyMesh.cyl(0.002, 0.002, 0.15, 3), _m("bark_dark"), Vector3(0.12, 0.62, 0))
	_p(ProxyMesh.box(Vector3(0.12, 0.16, 0.12)), VisualPalette.glow("turquoise", 0.45, true), Vector3(0.12, 0.47, 0), Vector3(0, 45, 0), Vector3.ONE, "Glow_Lantern")
	_p(ProxyMesh.sphere(0.05, 6, 3), _g("turquoise"), Vector3(0.12, 0.47, 0))
	_p(ProxyMesh.prism(Vector3(0.16, 0.08, 0.16)), _m("bark_dark"), Vector3(0.12, 0.58, 0))
	_end(staff)
	_tube([Vector3(0.22, 0.85, -0.02), Vector3(0.3, 0.65, -0.12)], 0.04, 0.035, "spore_skin", 5)


## S06 Spore Colossus: hulking 3-space mushroom giant with glowing spore sacs.
func _b_spore_colossus(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(0.22, 0.3, 0.7, 6), _m("cap_white"), Vector3(0.38 * sx, 0.35, 0.05))
	_p(ProxyMesh.sphere(0.72, 9, 5), _m("spore_body"), Vector3(0, 1.15, 0.05), Vector3.ZERO, Vector3(1.05, 0.85, 0.85))
	for p: Vector3 in [Vector3(0.45, 1.4, -0.35), Vector3(-0.35, 0.95, -0.5), Vector3(0.1, 0.8, -0.6), Vector3(-0.55, 1.45, -0.2)]:
		_p(ProxyMesh.sphere(0.13, 7, 4), _g("turquoise_soft"), p, Vector3.ZERO, Vector3.ONE, "Glow_Sac")
	var head := _grp("Head", Vector3(0, 1.6, -0.35))
	_p(ProxyMesh.sphere(0.28, 7, 4), _m("spore_skin"), Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.9, 1))
	_eyes(0.03, -0.24, 0.11, "turquoise", Vector3(0.09, 0.05, 0.04))
	_end(head)
	_hat(1.9, 0.95, "cap_violet", 0.42, 8)
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.7 * sx, 1.35, 0), Vector3(0.92 * sx, 0.95, -0.12), Vector3(0.95 * sx, 0.5, -0.2)], 0.17, 0.12, "spore_body", 6)
		_p(ProxyMesh.rock(0.2, 51 + int(sx)), _m("spore_skin"), Vector3(0.95 * sx, 0.42, -0.2))


# ------------------------------------------------------------------ Ash enemies

## E01 Ashling: small, hunched, quick ash imp with a long tail.
func _b_ashling(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.1 * sx, 0.36, 0.05), Vector3(0.14 * sx, 0.18, -0.06), Vector3(0.12 * sx, 0.0, 0.0)], 0.05, 0.03, "ash_black", 5)
	_p(ProxyMesh.sphere(0.2, 7, 4), _m("charcoal"), Vector3(0, 0.46, 0.02), Vector3(-25, 0, 0), Vector3(0.9, 1.15, 0.8))
	_p(ProxyMesh.box(Vector3(0.05, 0.16, 0.03)), _g("ember"), Vector3(0.03, 0.47, -0.17), Vector3(0, 0, 18))
	var head := _grp("Head", Vector3(0, 0.66, -0.12))
	_p(ProxyMesh.sphere(0.15, 6, 3), _m("ash_black"), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.1))
	_eyes(0.01, -0.15, 0.06, "ember_hot", Vector3(0.06, 0.03, 0.03))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.prism(Vector3(0.07, 0.22, 0.04)), _m("ash_black"), Vector3(0.1 * sx, 0.17, 0.02), Vector3(-10, 0, -28 * sx))
	_end(head)
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.16 * sx, 0.52, -0.06), Vector3(0.22 * sx, 0.36, -0.18), Vector3(0.2 * sx, 0.24, -0.24)], 0.035, 0.02, "ash_black", 4)
	_tube([Vector3(0, 0.38, 0.18), Vector3(0, 0.3, 0.4), Vector3(0.05, 0.42, 0.58), Vector3(0.0, 0.55, 0.62)], 0.04, 0.012, "charcoal", 4)
	_p(ProxyMesh.prism(Vector3(0.06, 0.08, 0.03)), _g("ember"), Vector3(0.0, 0.6, 0.62))


## E02 Coalshield: compact coal block hiding behind a slab shield with an ember rim.
func _b_coalshield(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.box(Vector3(0.18, 0.3, 0.22)), _m("ash_black"), Vector3(0.18 * sx, 0.15, 0.05))
	_p(ProxyMesh.rock(0.42, 61, 1.0), _m("charcoal"), Vector3(0, 0.62, 0.08), Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
	var head := _grp("Head", Vector3(0, 1.0, 0.0))
	_p(ProxyMesh.box(Vector3(0.32, 0.24, 0.3)), _m("ash_grey"), Vector3.ZERO)
	_p(ProxyMesh.box(Vector3(0.26, 0.04, 0.03)), _g("ember_hot"), Vector3(0, 0.0, -0.16), Vector3.ZERO, Vector3.ONE, "Glow_Eye")
	_end(head)
	var sh := _grp("Shield", Vector3(0.05, 0.6, -0.42), Vector3(-4, -8, 0))
	_p(ProxyMesh.box(Vector3(0.78, 0.95, 0.14)), _m("ash_black"), Vector3.ZERO)
	_p(ProxyMesh.box(Vector3(0.84, 0.06, 0.16)), _g("ember"), Vector3(0, 0.5, 0))
	_p(ProxyMesh.box(Vector3(0.84, 0.06, 0.16)), _g("ember_red"), Vector3(0, -0.5, 0))
	_p(ProxyMesh.rock(0.15, 62), _m("ash_grey"), Vector3(0, 0.05, -0.08), Vector3.ZERO, Vector3(1, 1, 0.5))
	for k: int in 3:
		_p(ProxyMesh.box(Vector3(0.04, 0.3, 0.02)), _g("ember"), Vector3(-0.22 + 0.22 * k, -0.15, -0.075), Vector3(0, 0, _r(-25, 25)))
	_end(sh)


## E03 Emberhunter: lean, spiky, forward-leaning hunter with an ember spear.
func _b_emberhunter(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.12 * sx, 0.72, 0.05), Vector3(0.15 * sx, 0.38, -0.1), Vector3(0.13 * sx, 0.0, 0.02)], 0.06, 0.035, "ash_black", 5)
	var torso := _grp("Torso", Vector3(0, 0.75, 0), Vector3(-18, 0, 0))
	_p(ProxyMesh.cyl(0.24, 0.14, 0.55, 6), _m("charcoal"), Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1, 1, 0.75))
	_p(ProxyMesh.box(Vector3(0.05, 0.3, 0.03)), _g("ember"), Vector3(0, 0.3, -0.17), Vector3(0, 0, 10))
	for i: int in 5:
		_p(ProxyMesh.prism(Vector3(0.09, 0.32, 0.09)), _m("ash_black"), Vector3(-0.2 + 0.1 * i, 0.55 + 0.04 * (2 - absi(i - 2)), 0.12), Vector3(-35, 0, -24 + 12 * i))
	var head := _grp("Head", Vector3(0, 0.66, -0.06))
	_p(ProxyMesh.prism(Vector3(0.2, 0.32, 0.26)), _m("ash_black"), Vector3(0, 0.08, 0), Vector3(-90, 0, 0), Vector3(1, 1.2, 1))
	_eyes(0.05, -0.12, 0.05, "ember_hot", Vector3(0.05, 0.03, 0.03))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.prism(Vector3(0.06, 0.26, 0.05)), _m("ash_grey"), Vector3(0.09 * sx, 0.2, 0.06), Vector3(-30, 0, -20 * sx))
	_end(head)
	_end(torso)
	var spear := _grp("Staff", Vector3(0.24, 0.95, -0.2), Vector3(-62, 0, 0))
	_p(ProxyMesh.cyl(0.02, 0.02, 1.5, 5), _m("bark_dark"), Vector3(0, 0, 0))
	_p(ProxyMesh.prism(Vector3(0.1, 0.28, 0.04)), _g("ember"), Vector3(0, 0.88, 0), Vector3.ZERO, Vector3.ONE, "Glow_Tip")
	_end(spear)
	_tube([Vector3(0.18, 1.12, -0.05), Vector3(0.24, 0.95, -0.2)], 0.04, 0.03, "ash_black", 4)
	_tube([Vector3(-0.18, 1.12, -0.05), Vector3(-0.2, 0.85, -0.12), Vector3(-0.18, 0.7, -0.2)], 0.04, 0.03, "ash_black", 4)


## E04 Sootbearer: round, heavy soot sack with an ember belly and chimney vents.
func _b_sootbearer(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(0.11, 0.14, 0.3, 5), _m("ash_black"), Vector3(0.24 * sx, 0.15, 0.0))
	_p(ProxyMesh.sphere(0.58, 9, 6), _m("charcoal"), Vector3(0, 0.78, 0.03), Vector3.ZERO, Vector3(1, 0.92, 0.95))
	_p(ProxyMesh.sphere(0.3, 8, 4), _g("ember"), Vector3(0, 0.68, -0.38), Vector3.ZERO, Vector3(1, 0.9, 0.5), "Glow_Belly")
	for k: int in 4:
		_p(ProxyMesh.box(Vector3(0.62, 0.05, 0.06)), _m("ash_grey"), Vector3(0, 0.5 + 0.12 * k, -0.47 + 0.02 * absf(k - 1.5)), Vector3(10, 0, 0))
	var head := _grp("Head", Vector3(0, 1.18, -0.3))
	_p(ProxyMesh.sphere(0.2, 7, 4), _m("ash_black"), Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.8, 1))
	_eyes(0.03, -0.17, 0.08, "ember_hot", Vector3(0.07, 0.04, 0.03))
	_end(head)
	for c: Vector3 in [Vector3(-0.28, 1.32, 0.2), Vector3(0.24, 1.36, 0.28)]:
		_p(ProxyMesh.cyl(0.08, 0.1, 0.32, 6), _m("ash_grey"), c)
		_p(ProxyMesh.cyl(0.06, 0.06, 0.02, 6), _g("ember_red"), c + Vector3(0, 0.17, 0))
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.55 * sx, 0.9, -0.05), Vector3(0.66 * sx, 0.6, -0.15), Vector3(0.6 * sx, 0.4, -0.2)], 0.08, 0.06, "ash_black", 5)


## E05 Stonebreaker: wide, armoured brute of basalt plates with huge fists.
func _b_stonebreaker(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(0.18, 0.24, 0.6, 6), _m("ash_black"), Vector3(0.36 * sx, 0.3, 0.05))
	_p(ProxyMesh.box(Vector3(0.8, 0.3, 0.55)), _m("charcoal"), Vector3(0, 0.7, 0.05))
	var torso := _grp("Torso", Vector3(0, 0.85, 0.05), Vector3(-10, 0, 0))
	_p(ProxyMesh.cyl(0.75, 0.48, 0.75, 6), _m("charcoal"), Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(1.05, 1, 0.7))
	for i: int in 3:
		_p(ProxyMesh.box(Vector3(0.36, 0.26, 0.1)), _m("ash_grey"), Vector3(-0.38 + 0.38 * i, 0.42 - 0.05 * absf(i - 1), -0.42), Vector3(6, -18 + 18 * i, 0))
	_p(ProxyMesh.box(Vector3(0.5, 0.05, 0.04)), _g("ember"), Vector3(0, 0.25, -0.48))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.rock(0.42, 71 + int(sx), 0.85), _m("ash_grey"), Vector3(0.78 * sx, 0.72, 0.0))
		_p(ProxyMesh.prism(Vector3(0.16, 0.3, 0.16)), _m("ash_black"), Vector3(0.85 * sx, 1.02, 0.0), Vector3(0, 0, -20 * sx))
	var head := _grp("Head", Vector3(0, 0.82, -0.25))
	_p(ProxyMesh.box(Vector3(0.36, 0.3, 0.32)), _m("ash_black"), Vector3.ZERO)
	_p(ProxyMesh.box(Vector3(0.42, 0.08, 0.2)), _m("ash_grey"), Vector3(0, 0.12, -0.1))
	_eyes(0.0, -0.17, 0.09, "ember_hot", Vector3(0.08, 0.04, 0.03))
	_end(head)
	_end(torso)
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.82 * sx, 1.45, 0.02), Vector3(0.95 * sx, 1.0, -0.08), Vector3(0.92 * sx, 0.55, -0.15)], 0.17, 0.15, "charcoal", 6)
		_p(ProxyMesh.rock(0.32, 73 + int(sx), 1.0), _m("stone_dark"), Vector3(0.92 * sx, 0.42, -0.18))
		_p(ProxyMesh.box(Vector3(0.04, 0.2, 0.04)), _g("ember_red"), Vector3(0.92 * sx, 0.45, -0.48))


## E06 The Ash Crown (boss, ~3 m): charred crown of branches and stone, inner glow, clear face.
func _b_ash_crown(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.38 * sx, 1.05, 0.05), Vector3(0.48 * sx, 0.55, -0.08), Vector3(0.45 * sx, 0.05, 0.0)], 0.2, 0.16, "ash_black", 6)
		_p(ProxyMesh.rock(0.3, 81 + int(sx)), _m("stone_dark"), Vector3(0.46 * sx, 0.1, -0.1), Vector3.ZERO, Vector3(1.1, 0.8, 1.3))
	var torso := _grp("Torso", Vector3(0, 1.05, 0.05), Vector3(-6, 0, 0))
	_p(ProxyMesh.cyl(0.85, 0.55, 1.1, 7), _m("charcoal"), Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1, 1, 0.72))
	_p(ProxyMesh.sphere(0.26, 8, 5), _g("ember_hot"), Vector3(0, 0.62, -0.5), Vector3.ZERO, Vector3(1, 1.1, 0.5), "Glow_Core")
	_p(ProxyMesh.sphere(0.45, 8, 5), VisualPalette.glow("ember", 0.25, true), Vector3(0, 0.62, -0.52), Vector3.ZERO, Vector3(1, 1.1, 0.4), "Glow_CoreHalo")
	for i: int in 6:
		var a := TAU * float(i) / 6.0
		_p(ProxyMesh.box(Vector3(0.05, 0.32, 0.03)), _g("ember"), Vector3(cos(a) * 0.4, 0.62 + sin(a) * 0.36, -0.5), Vector3(0, 0, rad_to_deg(a) + 90))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.rock(0.48, 85 + int(sx), 0.8), _m("ash_grey"), Vector3(0.88 * sx, 1.05, 0.0))
		for k: int in 3:
			_p(ProxyMesh.prism(Vector3(0.14, 0.42 - 0.08 * k, 0.14)), _m("ash_black"), Vector3((0.78 + 0.12 * k) * sx, 1.35 - 0.05 * k, -0.1 + 0.15 * k), Vector3(0, 0, -25 * sx))
	var head := _grp("Head", Vector3(0, 1.35, -0.12))
	_p(ProxyMesh.box(Vector3(0.6, 0.55, 0.5)), _m("ash_black"), Vector3(0, 0.1, 0))
	_p(ProxyMesh.box(Vector3(0.68, 0.12, 0.25)), _m("ash_grey"), Vector3(0, 0.3, -0.18), Vector3(-10, 0, 0))
	_eyes(0.15, -0.26, 0.15, "ember_hot", Vector3(0.15, 0.06, 0.04))
	_p(ProxyMesh.box(Vector3(0.3, 0.05, 0.04)), _g("ember"), Vector3(0, -0.05, -0.26), Vector3(0, 0, 0), Vector3.ONE, "Glow_Mouth")
	for k: int in 4:
		_p(ProxyMesh.prism(Vector3(0.04, 0.08, 0.03)), _m("ash_grey"), Vector3(-0.1 + 0.066 * k, -0.02, -0.27), Vector3(180, 0, 0))
	var crown := _grp("Crown", Vector3(0, 0.42, 0))
	_p(ProxyMesh.torus(0.28, 0.4, 9, 4), _m("charcoal"), Vector3.ZERO)
	for i: int in 9:
		var a := TAU * float(i) / 9.0
		var h := 0.5 if i % 2 == 0 else 0.32
		var tip := Vector3(cos(a) * 0.62, h, sin(a) * 0.62)
		_tube([Vector3(cos(a) * 0.34, 0.0, sin(a) * 0.34), Vector3(cos(a) * 0.42, h * 0.5, sin(a) * 0.42), tip], 0.07, 0.02, "ash_black" if i % 3 else "bark_dark", 5)
		_p(ProxyMesh.sphere(0.05, 5, 3), _g("ember" if i % 2 == 0 else "ember_red"), tip, Vector3.ZERO, Vector3.ONE, "Glow_CrownTip")
		if i % 3 == 0:
			_p(ProxyMesh.rock(0.11, 90 + i), _m("ash_grey"), Vector3(cos(a) * 0.38, 0.06, sin(a) * 0.38))
	_end(crown)
	_end(head)
	_end(torso)
	for sx: float in [-1.0, 1.0]:
		_tube([Vector3(0.9 * sx, 2.0, 0.0), Vector3(1.08 * sx, 1.45, -0.12), Vector3(1.05 * sx, 0.95, -0.25)], 0.2, 0.16, "charcoal", 6)
		for k: int in 3:
			_p(ProxyMesh.prism(Vector3(0.07, 0.3, 0.07)), _m("ash_black"), Vector3((1.0 + 0.05 * (k - 1)) * sx, 0.75, -0.3 - 0.06 * (k - 1)), Vector3(180, 0, 10 * (k - 1)))
		_p(ProxyMesh.box(Vector3(0.05, 0.4, 0.03)), _g("ember_red"), Vector3(1.06 * sx, 1.4, -0.33), Vector3(0, 0, 10 * sx))


# ------------------------------------------------------------------ Stage

## Floor terrace: top at y=0, usable x -5.5..+5.5, depth ~3.2 (z -1.6..1.6).
## The front edge (+Z) carries no props; dressing only on the back edge.
## Each floor has its own mood (REF_05): Roots dark/cool with violet glowing
## fungi, Trunk warm amber-lit, Crown lighter and greener with blossoms.
func _b_floor(s: Dictionary) -> void:
	var kind := str(s.get("variant", "roots"))
	var w := float(s.get("width", 11.0))
	var d := float(s.get("depth", 3.2))
	var tiles: Array = {"roots": ["stone_cool", "stone_dark", "stone_cool", "stone"], "trunk": ["stone_warm", "stone", "stone_warm", "stone_dark"],
		"crown": ["stone_light", "stone_warm", "stone_light", "stone"]}.get(kind, ["stone"])
	var rim: String = {"roots": "bark_dark", "trunk": "bark", "crown": "bark_light"}.get(kind, "bark")
	var moss: String = {"roots": "moss", "trunk": "moss", "crown": "moss_light"}.get(kind, "moss")
	var moss_chance: float = {"roots": 0.25, "trunk": 0.4, "crown": 0.75}.get(kind, 0.4)
	# Paving: rows of slightly irregular flagstones.
	var cols := 12
	var rows := 3
	for r: int in rows:
		for c: int in cols:
			var tw := w / float(cols)
			var td := d / float(rows)
			var x := -w * 0.5 + tw * (float(c) + 0.5) + _r(-0.04, 0.04)
			var z := -d * 0.5 + td * (float(r) + 0.5)
			var tk: String = tiles[(r * 7 + c * 3) % tiles.size()]
			_p(ProxyMesh.box(Vector3(tw - 0.07, 0.14, td - 0.07)), _m(tk), Vector3(x, -0.07 + _r(-0.012, 0.004), z), Vector3(0, _r(-2.5, 2.5), 0))
			if r < 2 and _rng.randf() < moss_chance * (1.0 if r == 0 else 0.5):
				_p(ProxyMesh.box(Vector3(_r(0.3, 0.7), 0.03, _r(0.2, 0.5))), _m(moss), Vector3(x + _r(-0.2, 0.2), 0.005, z - td * 0.3), Vector3(0, _r(0, 90), 0))
	_p(ProxyMesh.box(Vector3(w + 0.3, 0.12, d + 0.3)), _m("stone_dark"), Vector3(0, -0.1, 0))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(d * 0.55, d * 0.5, 0.18, 9), _m(str(tiles[1])), Vector3((w * 0.5 + 0.1) * sx, -0.1, 0), Vector3.ZERO, Vector3(0.75, 1, 1))
	# Bark rim, wrapping the slab; front edge stays clean (low moss only).
	_p(ProxyMesh.box(Vector3(w + 0.8, 0.55, d + 0.5)), _m(rim), Vector3(0, -0.42, -0.05))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(d * 0.62, d * 0.55, 0.55, 9), _m(rim), Vector3((w * 0.5 + 0.3) * sx, -0.42, -0.05), Vector3.ZERO, Vector3(0.75, 1, 1))
	for i: int in 16:
		var x := -w * 0.5 - 0.2 + (w + 0.4) * float(i) / 15.0
		_p(ProxyMesh.box(Vector3(_r(0.5, 0.9), _r(0.45, 0.7), 0.16)), _m("bark_dark" if i % 3 else rim), Vector3(x, -0.45, d * 0.5 + 0.22), Vector3(0, _r(-8, 8), _r(-10, 10)))
	for i: int in 26:
		var x := -w * 0.5 - 0.3 + (w + 0.6) * float(i) / 25.0 + _r(-0.15, 0.15)
		var mh := _r(0.06, 0.12)
		_p(ProxyMesh.box(Vector3(_r(0.35, 0.8), mh, _r(0.22, 0.36))), _m(moss if i % 4 else "moss_light"), Vector3(x, -mh * 0.5 + 0.012, d * 0.5 + 0.16), Vector3(0, _r(-10, 10), 0))
	for i: int in 18:
		var x := _r(-w * 0.5, w * 0.5)
		var dl := _r(0.3, 1.1) if kind == "roots" else _r(0.2, 0.45)
		_p(ProxyMesh.box(Vector3(_r(0.08, 0.18), dl, 0.05)), _m("moss"), Vector3(x, -0.5 - dl * 0.5 + 0.1, d * 0.5 + 0.3), Vector3(0, 0, _r(-6, 6)))
	# Underside: tapered root mass, kept behind the units of the floor below (z < -1.2)
	# except on the lowest floor, where nothing stands underneath.
	if kind == "roots":
		_p(ProxyMesh.cyl(2.6, 1.0, 1.4, 8), _m("bark_dark"), Vector3(0, -1.35, -0.6), Vector3.ZERO, Vector3(1.9, 1, 0.8))
	else:
		_p(ProxyMesh.cyl(2.2, 1.2, 1.2, 8), _m("bark_dark"), Vector3(0, -1.2, -2.6), Vector3.ZERO, Vector3(1.6, 1, 0.55))
	match kind:
		"roots":
			for i: int in 7:
				var x := -5.0 + float(i) * 1.66
				var dz := _r(-0.6, 0.8)
				_tube([Vector3(x * 0.5, -0.6, dz - 0.4), Vector3(x * 0.8, -1.6, dz + 0.2), Vector3(x * 1.05, -2.6, dz + 0.4), Vector3(x * 1.1, -3.6, dz)], 0.42, 0.1, "bark_dark" if i % 2 else "bark", 6)
			# Violet glowing fungi on the rim's ends (not on the walkable surface).
			for sx: float in [-1.0, 1.0]:
				for k: int in 3:
					var p := Vector3((w * 0.5 + 0.9 + 0.25 * k) * sx, -0.3 - 0.22 * k, 0.6 - 0.5 * k)
					_p(ProxyMesh.cyl(0.2 - 0.04 * k, 0.24 - 0.04 * k, 0.06, 8), _g("poison_violet"), p, Vector3(0, 0, 18 * sx), Vector3.ONE, "Glow_Gill")
			_dress_back(w, d, ["mushroom_cluster", "rock", "root_arch", "mushroom_cluster", "rock", "mushroom_cluster"])
		"trunk":
			for sx: float in [-1.0, 1.0]:
				_tube([Vector3(1.4 * sx, -0.7, -2.4), Vector3(3.2 * sx, -1.2, -1.8), Vector3(4.6 * sx, -2.0, -2.0)], 0.32, 0.08, "bark", 6)
			_dress_back(w, d, ["lantern", "mushroom_cluster", "lantern", "lantern", "rock", "lantern"])
		"crown":
			for sx: float in [-1.0, 1.0]:
				_tube([Vector3(1.2 * sx, -0.6, -2.4), Vector3(3.0 * sx, -1.0, -1.8), Vector3(4.6 * sx, -1.7, -1.9)], 0.3, 0.07, "bark_light", 6)
				# Leafy bushes behind the back corners: the crown reads greener and lighter.
				for k: int in 3:
					_p(ProxyMesh.rock(_r(0.45, 0.7), 300 + k + int(sx * 10.0), 0.7), _m("leaf_bright" if k % 2 else "leaf_light"),
						Vector3((w * 0.5 - 0.2 + 0.5 * k) * sx, 0.25 + 0.2 * k, -d * 0.5 - 0.35 - 0.2 * k))
			_dress_back(w, d, ["crystal", "blossom", "crystal", "blossom", "lantern", "crystal"])


## Props along the back edge (z ~ -1.45), leaving the centre (trunk) and front free.
func _dress_back(w: float, d: float, kinds: Array) -> void:
	var xs := [-5.2, -4.0, -2.4, 2.4, 4.0, 5.2]
	for i: int in mini(kinds.size(), xs.size()):
		var g := _grp("Dress_%d" % i, Vector3(float(xs[i]) * w / 11.0, 0, -d * 0.5 + 0.12), Vector3(0, _r(-30, 30), 0))
		g.scale = Vector3.ONE * 0.75
		var k := str(kinds[i])
		if k == "blossom":
			_blossoms(1)
		else:
			call("_b_" + k, {})
		_end(g)


func _blossoms(n: int) -> void:
	for i: int in n:
		var base := Vector3(_r(-0.2, 0.2), 0, _r(-0.15, 0.15))
		_tube([base, base + Vector3(0, 0.45, 0)], 0.04, 0.03, "bark", 4)
		for k: int in 5:
			var a := TAU * float(k) / 5.0
			_p(ProxyMesh.prism(Vector3(0.16, 0.34, 0.05)), _m("blossom_gold"), base + Vector3(cos(a) * 0.07, 0.62, sin(a) * 0.07), Vector3(0, -rad_to_deg(a) + 90, 22))
		_p(ProxyMesh.sphere(0.07, 6, 3), _g("blossom_gold"), base + Vector3(0, 0.6, 0), Vector3.ZERO, Vector3.ONE, "Glow_Blossom")


## Trunk segment: base y=0, top y=4.5, behind the play area (front z ~ -1.4). The battle
## scene instances one per floor; StageVariant shows the matching look by height:
## roots (dark, violet fungi), trunk (amber windows high up, turquoise veins),
## crown (tapers and splits into branches cradling the heart, green leafy canopy).
## No bright parts near x=0 at unit height: that gap between the sides stays calm.
func _b_trunk(s: Dictionary) -> void:
	var h := float(s.get("height", 4.5))
	var z := -3.2
	for k: String in ["roots", "trunk", "crown"]:
		var g := _grp("Variant_" + k)
		g.visible = k == "trunk"
		var top := 2.6 if k == "crown" else h
		var rb := 1.75 if k == "roots" else 1.6
		var rt := 1.0 if k == "crown" else 1.38
		_p(ProxyMesh.cyl(rt, rb, top, 9), _m("bark_dark" if k == "roots" else "bark"), Vector3(0, top * 0.5, z))
		for i: int in 8:
			var a := TAU * float(i) / 8.0 + 0.2
			var pts: Array = []
			for j: int in 5:
				var t := float(j) / 4.0
				var aa := a + t * 0.9
				var rr := lerpf(rb - 0.3, rt - 0.2, t)
				pts.append(Vector3(cos(aa) * rr, top * t - 0.1, z + sin(aa) * rr))
			_tube(pts, 0.32, 0.22, "bark_dark" if i % 2 else ("bark" if k == "roots" else "bark_light"), 6)
		match k:
			"roots":
				for i: int in 6:
					var a := PI + PI * float(i) / 5.0
					_tube([Vector3(cos(a) * 1.4, 0.6, z + sin(a) * 1.0), Vector3(cos(a) * 2.2, 0.1, z + sin(a) * 1.3 - 0.2), Vector3(cos(a) * 2.8, -0.05, z + sin(a) * 1.5 - 0.4)], 0.3, 0.1, "bark_dark", 6)
				for p: Vector3 in [Vector3(-1.1, 1.3, z + 1.25), Vector3(1.15, 2.1, z + 1.2), Vector3(-0.9, 3.1, z + 1.3), Vector3(1.0, 3.7, z + 1.25)]:
					_p(ProxyMesh.cyl(0.24, 0.28, 0.06, 8), _g("poison_violet"), p, Vector3(10, 0, 0), Vector3.ONE, "Glow_Gill")
					_p(ProxyMesh.cyl(0.28, 0.3, 0.05, 8), _m("cap_violet_dark"), p + Vector3(0, 0.05, 0))
				_window(Vector3(0.0, 3.8, z + 1.42), "amber_soft")
			"trunk":
				for p: Vector3 in [Vector3(-0.75, 2.9, z + 1.3), Vector3(0.8, 3.6, z + 1.26), Vector3(0.05, 4.1, z + 1.36)]:
					_window(p, "amber")
				for i: int in 4:
					var x := -0.95 + 0.62 * float(i) + _r(-0.1, 0.1)
					var fz := z + sqrt(maxf(1.5 * 1.5 - x * x, 0.0)) + 0.02
					_tube([Vector3(x, 0.2, fz), Vector3(x + _r(-0.15, 0.15), 1.6, fz - 0.03), Vector3(x + _r(-0.2, 0.2), 3.0, fz - 0.06), Vector3(x, 4.4, fz - 0.1)], 0.022, 0.014, "turquoise_soft", 4)
					_p(ProxyMesh.sphere(0.06, 5, 3), _g("turquoise"), Vector3(x, 1.6 + 0.5 * float(i % 2), fz), Vector3.ZERO, Vector3.ONE, "Glow_Vein")
			"crown":
				# Branches cradle the heart (heart at trunk-local (0, 3.4, -0.4); stay behind it).
				var ends := [Vector3(-1.6, 4.3, -1.0), Vector3(1.6, 4.4, -1.0), Vector3(-1.0, 4.9, -1.9), Vector3(1.1, 4.9, -1.9), Vector3(0.0, 5.0, -2.6)]
				for i: int in ends.size():
					var e: Vector3 = ends[i]
					var b := Vector3(e.x * 0.35, 2.3, z + 0.5)
					_tube([b, b.lerp(e, 0.5) + Vector3(0, -0.3, 0), e], 0.3, 0.07, "bark_light" if i % 2 else "bark", 6)
				# Leafy canopy to the sides of the heart, low enough to stay clear of the HUD;
				# directly behind the heart only dark branches, so the turquoise pops.
				for c: Array in [[Vector3(-2.8, 3.8, -2.9), 0.85], [Vector3(2.9, 3.7, -2.9), 0.85], [Vector3(-2.0, 4.4, -3.3), 0.7], [Vector3(2.1, 4.4, -3.3), 0.7],
						[Vector3(-3.7, 3.2, -3.4), 0.65], [Vector3(3.8, 3.1, -3.4), 0.65]]:
					var r: float = c[1]
					_p(ProxyMesh.rock(r, 400 + int(r * 10.0) + int(absf((c[0] as Vector3).x) * 7.0), 0.65), _m("leaf_light" if r > 0.75 else "leaf_bright"), c[0] as Vector3)
				for p: Vector3 in [Vector3(-2.4, 4.2, -2.3), Vector3(2.4, 4.1, -2.3), Vector3(-1.8, 4.8, -2.8), Vector3(1.9, 4.8, -2.8), Vector3(-3.3, 3.6, -2.7), Vector3(3.4, 3.5, -2.7)]:
					_p(ProxyMesh.rock(0.28, int(p.x * 13.0) + 77, 0.8), _m("blossom"), p)
					_p(ProxyMesh.sphere(0.08, 5, 3), _g("blossom_gold"), p + Vector3(0, 0.2, 0.2), Vector3.ZERO, Vector3.ONE, "Glow_Blossom")
		_end(g)


func _window(p: Vector3, key: String) -> void:
	_p(ProxyMesh.box(Vector3(0.32, 0.5, 0.05)), _m("bark_dark"), p + Vector3(0, 0, -0.02))
	_p(ProxyMesh.box(Vector3(0.18, 0.34, 0.05)), _g(key), p, Vector3.ZERO, Vector3.ONE, "Glow_Window")


## Heart crystal ~1.6 m on a cradle of branches, glowing turquoise.
func _b_heart(_s: Dictionary) -> void:
	for i: int in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		_tube([Vector3(cos(a) * 0.9, 0.0, sin(a) * 0.6), Vector3(cos(a) * 0.55, 0.45, sin(a) * 0.4), Vector3(cos(a) * 0.75, 1.3, sin(a) * 0.45), Vector3(cos(a) * 0.5, 1.95, sin(a) * 0.3)], 0.14, 0.03, "bark" if i % 2 else "bark_dark", 5)
	_p(ProxyMesh.rock(0.55, 99, 0.45), _m("bark_dark"), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1.4, 1, 1))
	var gem := _grp("Glow_Heart", Vector3(0, 1.0, 0))
	var mi := _p(ProxyMesh.heart_gem(1.5, 0.42), _heart_mat(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, "Gem")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p(ProxyMesh.sphere(0.95, 10, 6), VisualPalette.glow("turquoise", 0.12, true), Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.1, 1, 0.6), "Glow_Halo")
	_end(gem)
	for i: int in 7:
		var a := TAU * float(i) / 7.0
		_p(ProxyMesh.cyl(0.0, 0.06, 0.22, 4), _g("turquoise"), Vector3(cos(a) * 1.15, 1.0 + sin(a * 2.0) * 0.5 + 0.2, sin(a) * 0.35), Vector3(_r(-30, 30), 0, _r(-40, 40)), Vector3.ONE, "Glow_Shard")
	var light := OmniLight3D.new()
	light.name = "HeartLight"
	light.light_color = VisualPalette.color("turquoise")
	light.light_energy = 2.2
	light.omni_range = 6.0
	light.position = Vector3(0, 1.0, 0.6)
	_at.add_child(light)


func _heart_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Dark floating islands, rock spires and violet haze far behind (z < -15).
## Kept small and away from the tree's silhouette so the stage reads first.
func _b_backdrop(_s: Dictionary) -> void:
	for i: int in 14:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * _r(12, 44)
		var z := _r(-50, -20)
		var y := _r(-8, 20)
		var r := _r(0.6, 1.8)
		var g := _grp("Island_%d" % i, Vector3(x, y, z), Vector3(0, _r(0, 360), 0))
		_p(ProxyMesh.cyl(r, r * 0.12, r * 1.8, 7), _m("island"), Vector3(0, -r * 0.9, 0))
		_p(ProxyMesh.cyl(r * 0.98, r, 0.25, 7), _m("island_top"), Vector3(0, 0.08, 0))
		if i % 3 == 0:
			_p(ProxyMesh.cyl(0.0, r * 0.25, r * 1.4, 5), _m("island"), Vector3(_r(-r * 0.4, r * 0.4), r * 0.7, 0))
		if i % 4 == 1:
			_p(ProxyMesh.box(Vector3(0.12, 0.2, 0.05)), _g("amber_soft"), Vector3(0, 0.3, r * 0.6), Vector3.ZERO, Vector3.ONE, "Glow_Window")
		_end(g)
	for i: int in 12:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (16.0 + 3.0 * float(i))
		var h := _r(10, 26)
		_p(ProxyMesh.cyl(_r(0.2, 0.6), _r(1.0, 2.2), h, 6), _g("haze_dark"), Vector3(x, -14 + h * 0.5, _r(-52, -34)))
	_p(ProxyMesh.sphere(14.0, 12, 6), VisualPalette.glow("haze", 0.05, false), Vector3(0, -18.0, -30.0), Vector3.ZERO, Vector3(3.0, 0.5, 0.4), "Haze")
	_p(ProxyMesh.sphere(3.0, 16, 8), VisualPalette.glow("cap_white", 0.8), Vector3(30, 24, -60), Vector3.ZERO, Vector3.ONE, "Moon")


# ------------------------------------------------------------------ Props

func _b_lantern(_s: Dictionary) -> void:
	_tube([Vector3(0, 0, 0), Vector3(0.02, 0.9, 0), Vector3(0.1, 1.15, 0), Vector3(0.3, 1.2, 0)], 0.05, 0.03, "bark_dark", 5)
	_p(ProxyMesh.cyl(0.004, 0.004, 0.12, 3), _m("bark_dark"), Vector3(0.3, 1.12, 0))
	_p(ProxyMesh.cyl(0.07, 0.09, 0.2, 6), VisualPalette.glow("amber", 0.85), Vector3(0.3, 0.96, 0), Vector3.ZERO, Vector3.ONE, "Glow_Lantern")
	_p(ProxyMesh.cyl(0.0, 0.12, 0.1, 6), _m("bark_dark"), Vector3(0.3, 1.1, 0))
	_p(ProxyMesh.sphere(0.2, 8, 4), VisualPalette.glow("amber", 0.18, true), Vector3(0.3, 0.96, 0))
	_p(ProxyMesh.rock(0.14, 7), _m("stone_dark"), Vector3(0, 0.03, 0))


func _b_mushroom_cluster(_s: Dictionary) -> void:
	for m: Array in [[Vector3(0, 0, 0), 0.32, 0.55], [Vector3(0.32, 0, 0.12), 0.2, 0.36], [Vector3(-0.28, 0, 0.08), 0.18, 0.28], [Vector3(0.12, 0, -0.25), 0.14, 0.22]]:
		var p: Vector3 = m[0]
		var r: float = m[1]
		var h: float = m[2]
		_p(ProxyMesh.cyl(r * 0.22, r * 0.3, h, 6), _m("cap_white"), p + Vector3(0, h * 0.5, 0), Vector3(0, 0, _r(-8, 8)))
		_p(ProxyMesh.cyl(r * 0.9, r, r * 0.12, 8), _g("cap_gill"), p + Vector3(0, h, 0))
		_p(ProxyMesh.sphere(r, 8, 3, true), _m("cap_violet"), p + Vector3(0, h + 0.01, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
		_p(ProxyMesh.sphere(r * 0.18, 5, 3), _g("turquoise"), p + Vector3(r * 0.4, h + r * 0.4, 0), Vector3.ZERO, Vector3.ONE, "Glow_Dot")


func _b_crystal(_s: Dictionary) -> void:
	for c: Array in [[Vector3(0, 0, 0), 0.16, 0.95, 0.0], [Vector3(0.2, 0, 0.08), 0.11, 0.6, -22.0], [Vector3(-0.18, 0, 0.06), 0.1, 0.5, 25.0], [Vector3(0.05, 0, -0.16), 0.08, 0.4, 12.0]]:
		var p: Vector3 = c[0]
		var r: float = c[1]
		var h: float = c[2]
		var g := _grp("Glow_Crystal", p, Vector3(float(c[3]) * 0.4, 0, float(c[3])))
		_p(ProxyMesh.cyl(r, r * 0.8, h * 0.75, 6), VisualPalette.glow("turquoise_soft", 0.92), Vector3(0, h * 0.375, 0))
		_p(ProxyMesh.cyl(0.0, r, h * 0.25, 6), _g("turquoise"), Vector3(0, h * 0.875, 0))
		_end(g)
	_p(ProxyMesh.rock(0.25, 17, 0.4), _m("stone_dark"), Vector3(0, 0.02, 0))


func _b_root_arch(_s: Dictionary) -> void:
	var pts: Array = []
	for k: int in 9:
		var a := PI * float(k) / 8.0
		pts.append(Vector3(cos(a) * 0.85, sin(a) * 1.5, 0.0))
	_tube(pts, 0.2, 0.14, "bark", 6)
	_tube([Vector3(0.85, 0.0, 0), Vector3(1.05, -0.05, 0.15)], 0.2, 0.08, "bark_dark", 5)
	_tube([Vector3(-0.85, 0.0, 0), Vector3(-1.1, -0.05, -0.1)], 0.2, 0.08, "bark_dark", 5)
	for i: int in 3:
		_p(ProxyMesh.box(Vector3(0.07, _r(0.25, 0.5), 0.04)), _m("moss_light"), Vector3(_r(-0.4, 0.4), 1.3, 0.1))


func _b_rock(_s: Dictionary) -> void:
	_p(ProxyMesh.rock(0.45, 5, 0.7), _m("stone"), Vector3(0, 0.22, 0))
	_p(ProxyMesh.rock(0.25, 6, 0.8), _m("stone_dark"), Vector3(0.42, 0.1, 0.1))
	_p(ProxyMesh.sphere(0.3, 6, 3, true), _m("moss"), Vector3(-0.05, 0.42, 0), Vector3.ZERO, Vector3(1.1, 0.3, 1))


# ------------------------------------------------------------------ Mutations (in the frame of what they decorate)

## M01 Deep Roots (Roots-floor frame): a wider bark ledge under the platform edge
## (below the walkable surface, never in the play area) and thick new roots with
## amber tips growing over the back edge and down the outer corners.
func _b_m01_roots(_s: Dictionary) -> void:
	_p(ProxyMesh.box(Vector3(13.6, 0.32, 4.4)), _m("bark_light"), Vector3(0, -0.62, -0.1))
	for sx: float in [-1.0, 1.0]:
		_p(ProxyMesh.cyl(2.3, 2.1, 0.32, 9), _m("bark_light"), Vector3(6.8 * sx, -0.62, -0.1), Vector3.ZERO, Vector3(0.8, 1, 1))
		_p(ProxyMesh.sphere(0.35, 7, 3, true), _m("moss_light"), Vector3(7.6 * sx, -0.45, 0.6), Vector3.ZERO, Vector3(1.4, 0.4, 1.0))
	var tips: Array[Vector3] = []
	for x: float in [-4.8, -3.4, -1.9, 1.9, 3.3, 4.7]:
		var e := Vector3(x * 1.12, -3.4, -0.9)
		_tube([Vector3(x * 0.4, 1.4, -2.8), Vector3(x * 0.85, 0.55, -2.0), Vector3(x, 0.05, -1.75), Vector3(x * 1.06, -1.6, -1.65), e], 0.36, 0.08, "bark_light", 6)
		tips.append(e)
	for sx: float in [-1.0, 1.0]:
		for k: int in 2:
			var e := Vector3((6.6 + 0.6 * k) * sx, -2.9 - 0.6 * k, 1.2 - 0.6 * k)
			_tube([Vector3((5.9 + 0.4 * k) * sx, -0.4, 1.0 - 0.5 * k), Vector3((6.5 + 0.5 * k) * sx, -1.4, 1.5 - 0.5 * k), e], 0.3, 0.07, "bark", 6)
			tips.append(e)
	for t: Vector3 in tips:
		_p(ProxyMesh.sphere(0.1, 5, 3), _g("amber"), t, Vector3.ZERO, Vector3.ONE, "Glow_RootTip")


## M02 Strong Trunk (trunk-segment frame on the Trunk floor): a thick glowing band
## high on the trunk (above unit heads) and turquoise veins down to the floor.
func _b_m02_band(_s: Dictionary) -> void:
	var z := -3.2
	var y := 3.35
	_p(ProxyMesh.torus(1.55, 2.05, 18, 6), _m("bark_light"), Vector3(0, y, z), Vector3.ZERO, Vector3(1, 1.7, 1))
	_p(ProxyMesh.torus(1.9, 2.12, 18, 4), _g("turquoise"), Vector3(0, y, z), Vector3.ZERO, Vector3(1.0, 0.7, 1.0), "Glow_Band")
	_p(ProxyMesh.torus(1.9, 2.1, 18, 4), _g("turquoise"), Vector3(0, y - 0.38, z), Vector3.ZERO, Vector3(1.0, 0.5, 1.0), "Glow_Band")
	for i: int in 5:
		var x := -1.2 + 0.6 * float(i)
		var fz := z + sqrt(maxf(1.62 * 1.62 - x * x, 0.0)) + 0.03
		_tube([Vector3(x, 0.15, fz), Vector3(x + _r(-0.15, 0.15), 1.2, fz), Vector3(x + _r(-0.2, 0.2), 2.3, fz - 0.05), Vector3(x, y - 0.4, fz - 0.1)], 0.04, 0.028, "turquoise_soft", 4)
		_p(ProxyMesh.sphere(0.08, 5, 3), _g("turquoise"), Vector3(x, 0.8 + 0.6 * float(i % 3), fz + 0.02), Vector3.ZERO, Vector3.ONE, "Glow_Vein")


## M03 Gentle Crown (Crown-floor frame): blossom trees at the back corners, golden
## flowers along the back edge and a few drifting petals.
func _b_m03_blossoms(_s: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		for k: int in 2:
			var bx := (4.3 + 1.3 * k) * sx
			_tube([Vector3(bx, 0, -1.9), Vector3(bx - 0.2 * sx, 0.8, -2.0), Vector3(bx + 0.1 * sx, 1.5, -2.1)], 0.13, 0.06, "bark_light", 5)
			for j: int in 4:
				_p(ProxyMesh.rock(_r(0.4, 0.6), 500 + j + k * 7 + int(sx * 3.0), 0.75), _m("blossom"), Vector3(bx + _r(-0.5, 0.5), _r(1.5, 2.1), -2.1 + _r(-0.3, 0.2)))
			_p(ProxyMesh.sphere(0.12, 6, 3), _g("blossom_gold"), Vector3(bx, 1.75, -1.75), Vector3.ZERO, Vector3.ONE, "Glow_Blossom")
	for x: float in [-3.2, -1.7, 1.7, 3.2]:
		var g := _grp("Blossom", Vector3(x, 0, -1.5))
		_blossoms(1)
		_end(g)
	var petals := CPUParticles3D.new()
	petals.name = "Petals"
	petals.amount = 14
	petals.lifetime = 5.0
	petals.position = Vector3(0, 2.6, -1.6)
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(5.5, 0.4, 0.4)
	petals.gravity = Vector3(0.1, -0.35, 0)
	petals.initial_velocity_min = 0.0
	petals.initial_velocity_max = 0.1
	petals.angular_velocity_min = -90.0
	petals.angular_velocity_max = 90.0
	petals.mesh = ProxyMesh.box(Vector3(0.08, 0.02, 0.06))
	petals.material_override = VisualPalette.glow("blossom")
	_at.add_child(petals)


## M04 Great Heart (heart frame): a larger double halo, a glowing ring, more shards
## and one extra light.
func _b_m04_glow(_s: Dictionary) -> void:
	_p(ProxyMesh.sphere(1.5, 12, 8), VisualPalette.glow("turquoise", 0.08, true), Vector3(0, 1.0, 0), Vector3.ZERO, Vector3(1.2, 1.1, 0.55), "Glow_Halo")
	_p(ProxyMesh.sphere(2.1, 12, 8), VisualPalette.glow("turquoise_soft", 0.05, true), Vector3(0, 1.0, -0.2), Vector3.ZERO, Vector3(1.2, 1.05, 0.4), "Glow_Halo")
	_p(ProxyMesh.torus(1.45, 1.6, 24, 3), VisualPalette.glow("turquoise", 0.75, true), Vector3(0, 1.0, -0.15), Vector3(90, 0, 0), Vector3.ONE, "Glow_Band")
	for i: int in 12:
		var a := TAU * float(i) / 12.0
		_p(ProxyMesh.cyl(0.0, 0.08, 0.3, 4), _g("turquoise"), Vector3(cos(a) * 1.85, 1.0 + sin(a) * 1.5, -0.1), Vector3(0, 0, rad_to_deg(a) - 90.0), Vector3.ONE, "Glow_Crystal")
	var light := OmniLight3D.new()
	light.name = "GreatHeartLight"
	light.light_color = VisualPalette.color("turquoise")
	light.light_energy = 1.8
	light.omni_range = 10.0
	light.position = Vector3(0, 1.0, 1.0)
	_at.add_child(light)
