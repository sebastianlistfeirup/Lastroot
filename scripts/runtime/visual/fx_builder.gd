class_name FxBuilder
extends RefCounted
## Procedural effects (CPUParticles3D: works in Compatibility/web). Origin is the
## affected unit's feet; effects are sized for a ~1.6 m unit (scale the root by
## VisualSlots.head_height(unit) / 1.8 for very small or large units).
## One-shot effects (meta "one_shot" = true) free themselves after "lifetime_s".
## Looping status effects (poison, armor, thorns, growth, heart_pulse) stay until
## the caller frees them. Visual only.

const ONE_SHOT := ["fx.heal", "fx.spore_bolt", "fx.bark_hit", "fx.ash_death", "fx.heart_damage"]


static func build(slot_id: String, spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Fx"
	var kind := str(spec.get("builder", slot_id.trim_prefix("fx.")))
	var life := 0.0
	match kind:
		"poison":
			_emit(root, {"color": "poison", "ramp2": "poison_violet", "amount": 18, "life": 1.6, "shape": "ring", "radius": 0.45, "y": 0.2,
				"vel": Vector3(0, 0.55, 0), "spread": 15.0, "size": 0.12, "grow": 1.6, "gravity": Vector3(0, 0.1, 0), "mesh": "sphere"})
			_emit(root, {"color": "poison_violet", "amount": 8, "life": 1.2, "shape": "sphere", "radius": 0.35, "y": 0.9, "vel": Vector3(0, 0.2, 0),
				"size": 0.06, "gravity": Vector3.ZERO})
		"heal":
			life = 1.4
			_emit(root, {"color": "heal", "ramp2": "turquoise", "amount": 28, "life": 1.1, "shape": "ring", "radius": 0.5, "y": 0.05,
				"vel": Vector3(0, 1.6, 0), "spread": 8.0, "size": 0.09, "one_shot": true, "explosiveness": 0.6, "gravity": Vector3(0, -0.4, 0), "mesh": "plus"})
			_ring(root, "heal", 0.6, 0.05)
		"armor":
			var shell := MeshInstance3D.new()
			shell.name = "Glow_Armor"
			shell.mesh = ProxyMesh.sphere(0.8, 6, 4)
			shell.material_override = VisualPalette.glow("armor", 0.12, true)
			shell.position = Vector3(0, 0.85, 0)
			shell.scale = Vector3(1, 1.15, 1)
			shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(shell)
			_emit(root, {"color": "armor", "amount": 10, "life": 1.4, "shape": "sphere", "radius": 0.8, "y": 0.85, "vel": Vector3(0, 0.15, 0),
				"size": 0.07, "gravity": Vector3.ZERO, "mesh": "diamond"})
		"thorns":
			for i: int in 8:
				var a := TAU * float(i) / 8.0
				var t := MeshInstance3D.new()
				t.mesh = ProxyMesh.prism(Vector3(0.08, 0.32, 0.08))
				t.material_override = VisualPalette.mat("thorns")
				t.position = Vector3(cos(a) * 0.55, 0.12, sin(a) * 0.55)
				t.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
				root.add_child(t)
			_emit(root, {"color": "thorns", "amount": 6, "life": 0.9, "shape": "ring", "radius": 0.55, "y": 0.2, "vel": Vector3(0, 0.4, 0), "size": 0.05})
		"growth":
			_emit(root, {"color": "leaf_light", "ramp2": "heal", "amount": 12, "life": 1.8, "shape": "ring", "radius": 0.4, "y": 0.1,
				"vel": Vector3(0, 0.6, 0), "spread": 25.0, "size": 0.1, "mesh": "leaf", "additive": false, "spin": 180.0, "gravity": Vector3.ZERO})
		"spore_bolt":
			life = 1.2
			var core := MeshInstance3D.new()
			core.name = "Glow_Bolt"
			core.mesh = ProxyMesh.sphere(0.12, 7, 4)
			core.material_override = VisualPalette.glow("turquoise")
			root.add_child(core)
			var halo := MeshInstance3D.new()
			halo.mesh = ProxyMesh.sphere(0.24, 7, 4)
			halo.material_override = VisualPalette.glow("turquoise", 0.25, true)
			root.add_child(halo)
			var trail := _emit(root, {"color": "turquoise", "ramp2": "poison_violet", "amount": 40, "life": 0.45, "shape": "sphere", "radius": 0.08, "y": 0.0,
				"vel": Vector3.ZERO, "size": 0.08, "gravity": Vector3.ZERO})
			trail.local_coords = false
		"bark_hit":
			life = 0.9
			_emit(root, {"color": "bark_light", "amount": 16, "life": 0.6, "shape": "sphere", "radius": 0.15, "y": 0.9, "vel": Vector3(0, 2.2, 0),
				"spread": 75.0, "size": 0.09, "one_shot": true, "explosiveness": 0.95, "gravity": Vector3(0, -7, 0), "mesh": "chip", "additive": false, "spin": 540.0})
			_emit(root, {"color": "amber", "amount": 10, "life": 0.35, "shape": "sphere", "radius": 0.1, "y": 0.9, "vel": Vector3(0, 1.5, 0),
				"spread": 90.0, "size": 0.06, "one_shot": true, "explosiveness": 1.0, "gravity": Vector3.ZERO})
		"ash_death":
			life = 1.8
			_emit(root, {"color": "ash_grey", "ramp2": "ash_black", "amount": 30, "life": 1.4, "shape": "sphere", "radius": 0.45, "y": 0.6,
				"vel": Vector3(0, 0.7, 0), "spread": 60.0, "size": 0.22, "grow": 2.2, "one_shot": true, "explosiveness": 0.8, "additive": false, "gravity": Vector3(0, 0.25, 0)})
			_emit(root, {"color": "ember_hot", "ramp2": "ember_red", "amount": 22, "life": 1.1, "shape": "sphere", "radius": 0.35, "y": 0.6,
				"vel": Vector3(0, 1.4, 0), "spread": 70.0, "size": 0.05, "one_shot": true, "explosiveness": 0.9, "gravity": Vector3(0, 0.6, 0)})
		"heart_pulse":
			_emit(root, {"color": "turquoise", "amount": 26, "life": 1.6, "shape": "ring", "radius": 0.9, "inner": 0.85, "y": 1.0, "axis": Vector3(0, 0, 1),
				"vel": Vector3.ZERO, "radial": 0.6, "size": 0.07, "gravity": Vector3(0, 0.15, 0)})
			_emit(root, {"color": "turquoise_soft", "amount": 10, "life": 2.2, "shape": "sphere", "radius": 1.0, "y": 1.0, "vel": Vector3(0, 0.25, 0),
				"size": 0.05, "gravity": Vector3.ZERO, "mesh": "diamond"})
		"heart_damage":
			life = 1.3
			_emit(root, {"color": "ember_red", "ramp2": "turquoise", "amount": 26, "life": 0.9, "shape": "sphere", "radius": 0.5, "y": 1.0,
				"vel": Vector3(0, 0.5, 0), "radial": 3.0, "spread": 180.0, "size": 0.09, "one_shot": true, "explosiveness": 1.0, "gravity": Vector3(0, -3, 0), "mesh": "diamond", "spin": 360.0})
			_ring(root, "ember_red", 1.0, 1.0, Vector3(90, 0, 0))
		_:
			push_warning("FxBuilder: unknown fx %s" % slot_id)
	root.set_meta("one_shot", life > 0.0)
	root.set_meta("lifetime_s", life)
	if life > 0.0:
		var r := root
		root.ready.connect(func() -> void:
			if r.is_inside_tree():
				r.get_tree().create_timer(life).timeout.connect(r.queue_free), CONNECT_ONE_SHOT)
	return root


static func _emit(root: Node3D, o: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Particles%d" % root.get_child_count()
	p.amount = int(o.get("amount", 16))
	p.lifetime = float(o.get("life", 1.0))
	p.one_shot = bool(o.get("one_shot", false))
	p.explosiveness = float(o.get("explosiveness", 0.0))
	p.position = Vector3(0, float(o.get("y", 0.0)), 0)
	p.emitting = true
	match str(o.get("shape", "sphere")):
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_radius = float(o.get("radius", 0.5))
			p.emission_ring_inner_radius = float(o.get("inner", 0.0))
			p.emission_ring_height = 0.05
			p.emission_ring_axis = o.get("axis", Vector3.UP) as Vector3
		_:
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = float(o.get("radius", 0.3))
	var vel: Vector3 = o.get("vel", Vector3.UP) as Vector3
	p.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	p.initial_velocity_min = vel.length() * 0.7
	p.initial_velocity_max = vel.length() * 1.2
	p.spread = float(o.get("spread", 20.0))
	p.gravity = o.get("gravity", Vector3(0, -1, 0)) as Vector3
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0)) * 1.3
	var spin := float(o.get("spin", 0.0))
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	var size := float(o.get("size", 0.1))
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	var grow := float(o.get("grow", 0.0))
	curve.add_point(Vector2(0, 0.3 if grow == 0.0 else 0.5))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1, 0.0 if grow == 0.0 else grow))
	curve.max_value = maxf(grow, 1.0)
	p.scale_amount_curve = curve
	var c1 := VisualPalette.color(str(o.get("color", "turquoise")))
	var c2 := VisualPalette.color(str(o.get("ramp2", o.get("color", "turquoise"))))
	var g := Gradient.new()
	g.set_color(0, Color(c1, 1.0))
	g.set_color(1, Color(c2, 0.0))
	g.add_point(0.6, Color(c1.lerp(c2, 0.5), 0.85))
	p.color_ramp = g
	var additive := bool(o.get("additive", true))
	var mesh: Mesh
	match str(o.get("mesh", "quad")):
		"sphere":
			mesh = ProxyMesh.sphere(size, 6, 3)
		"diamond":
			mesh = ProxyMesh.sphere(size, 4, 2)
		"leaf", "chip":
			mesh = ProxyMesh.box(Vector3(size, size * 0.25, size * 1.6))
		"plus":
			var q := QuadMesh.new()
			q.size = Vector2(size, size * 2.0)
			mesh = q
		_:
			var q := QuadMesh.new()
			q.size = Vector2(size, size)
			mesh = q
	var m := VisualPalette.particle(str(o.get("color", "turquoise")), additive)
	if mesh is QuadMesh:
		(mesh as QuadMesh).material = m
	else:
		var mm := m.duplicate() as StandardMaterial3D
		mm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		p.material_override = mm
	p.mesh = mesh
	root.add_child(p)
	return p


static func _ring(root: Node3D, key: String, r: float, y: float, rot: Vector3 = Vector3.ZERO) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Glow_Ring"
	ring.mesh = ProxyMesh.torus(r * 0.9, r, 20, 3)
	ring.material_override = VisualPalette.glow(key, 0.6, true)
	ring.position = Vector3(0, y, 0)
	ring.rotation_degrees = rot
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	ring.ready.connect(func() -> void:
		var t := ring.create_tween()
		t.tween_property(ring, "scale", Vector3.ONE * 1.6, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(ring, "transparency", 1.0, 0.6), CONNECT_ONE_SHOT)


## Flies a spore bolt (or any fx slot) from `from` to `to` (global positions) under
## `parent`, then plays `impact_slot` at the target. Returns the bolt.
static func launch(parent: Node3D, from: Vector3, to: Vector3, duration: float = 0.35, slot_id: String = "fx.spore_bolt", impact_slot: String = "fx.heal") -> Node3D:
	var bolt := VisualSlots.make(slot_id)
	parent.add_child(bolt)
	bolt.global_position = from
	var t := bolt.create_tween()
	var mid := from.lerp(to, 0.5) + Vector3(0, from.distance_to(to) * 0.18, 0)
	t.tween_method(func(v: float) -> void:
		var a := from.lerp(mid, v)
		var b := mid.lerp(to, v)
		bolt.global_position = a.lerp(b, v), 0.0, 1.0, duration)
	t.tween_callback(func() -> void:
		if not impact_slot.is_empty():
			var fx := VisualSlots.make(impact_slot)
			parent.add_child(fx)
			fx.global_position = to - Vector3(0, 0.9, 0)
		bolt.queue_free())
	return bolt
