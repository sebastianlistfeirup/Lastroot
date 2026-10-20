class_name RouteDiorama
extends Node3D
## REF_04 mood behind the 2D route map: floating islands with camp fires, plank
## bridges, a misty violet void and the world tree glowing far away. Mood only —
## the 2D map on top carries every piece of information.
##
## API (call from the route screen):
##   set_progress(battle_index: int, chosen_nodes: Array)
##       battles < battle_index are visited (fires lit), battle_index is the current
##       island (brighter, its own light). chosen_nodes: the picked middle nodes as
##       Vector2i(col, lane) or {"col": int, "lane": int} in route_map coordinates
##       (battle k = col 2k, lane 0; option after battle k = col 2k-1, lane -1/+1).
##       Bridges between lit nodes light up.
##   focus(i: int)          drifts the camera toward battle island i (instant under reduced motion)
##   set_portrait(p: bool)  landscape 1920x1080: path left->right; portrait 430x932: path near->far
##   @export dim            0..1 darkening so text on top stays readable (default 0.35)
## Cheap for web: emissive fires + CPUParticles, 2 lights, no shadows.

@export_range(0.0, 1.0) var dim: float = 0.35:
	set(v):
		dim = v
		if _dim_rect:
			_dim_rect.color = Color(0, 0, 0, dim)

const BATTLES := 6

var portrait: bool = false
var screen_anchor: float = 0.5
var _islands: Dictionary = {}   # Vector2i(col, lane) -> {node, fire, lit, particles}
var _bridges: Array = []        # {a: Vector2i, b: Vector2i, node, lamps}
var _cam: Camera3D
var _cam_base: Transform3D
var _focus_tween: Tween
var _current_light: OmniLight3D
var _dim_rect: ColorRect
var _tree: Node3D
var _battle_index: int = 0
var _chosen: Array[Vector2i] = []


func _ready() -> void:
	_env()
	for c: int in range(0, 11):
		if c % 2 == 0:
			_island(Vector2i(c, 0), true)
		else:
			_island(Vector2i(c, -1), false)
			_island(Vector2i(c, 1), false)
	for c: int in range(0, 10):
		if c % 2 == 0:
			_bridge(Vector2i(c, 0), Vector2i(c + 1, -1))
			_bridge(Vector2i(c, 0), Vector2i(c + 1, 1))
		else:
			_bridge(Vector2i(c, -1), Vector2i(c + 1, 0))
			_bridge(Vector2i(c, 1), Vector2i(c + 1, 0))
	_world_tree()
	_mist()
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_dim_rect = ColorRect.new()
	_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_rect.color = Color(0, 0, 0, dim)
	ui.add_child(_dim_rect)
	for a: String in OS.get_cmdline_user_args():
		if a == "--portrait":
			portrait = true
		elif a.begins_with("--progress="):
			var n := int(a.substr(11))
			var ch: Array = []
			for k: int in range(1, n + 1):
				ch.append(Vector2i(2 * k - 1, -1 if k % 2 == 0 else 1))
			set_progress(n, ch)
	set_portrait(portrait)
	DioramaCapture.attach(self)


func _env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("140f26")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("5a4f8a")
	e.ambient_light_energy = 0.95
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("2a1f48")
	e.fog_density = 0.012
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_color = Color("ffd2a0")
	sun.light_energy = 0.8
	sun.shadow_enabled = false
	add_child(sun)
	_current_light = OmniLight3D.new()
	_current_light.light_color = VisualPalette.color("amber")
	_current_light.light_energy = 1.8
	_current_light.omni_range = 4.5
	add_child(_current_light)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true


func pos_of(k: Vector2i) -> Vector3:
	var c := float(k.x)
	var y := sin(c * 0.9) * 0.6 + (0.3 if k.y != 0 else 0.0)
	if portrait:
		return Vector3(float(k.y) * 2.3, y, 8.0 - c * 2.0)
	return Vector3(-10.0 + c * 2.0, y + c * 0.12, float(k.y) * 1.5)


func _island(k: Vector2i, battle: bool) -> void:
	var b := ProxyBuilder.new()
	var root := Node3D.new()
	root.name = "Island_%d_%d" % [k.x, k.y]
	b._at = root
	b._rng.seed = hash(k)
	var r := 1.0 if battle else 0.7
	if k.x == 10:
		r = 1.3
	b._p(ProxyMesh.cyl(r, r * 0.15, r * 1.9, 7), VisualPalette.mat("island"), Vector3(0, -r * 0.95, 0))
	var top := b._p(ProxyMesh.cyl(r * 0.98, r, 0.22, 8), VisualPalette.mat("island_top"), Vector3(0, 0.0, 0))
	for i: int in 3:
		b._p(ProxyMesh.rock(r * 0.25, i + k.x * 3, 0.8), VisualPalette.mat("stone_dark"), Vector3(b._r(-r, r) * 0.6, 0.1, b._r(-r, r) * 0.5))
	var fire := Node3D.new()
	fire.name = "Fire"
	root.add_child(fire)
	b._at = fire
	var particles: CPUParticles3D = null
	if k.x == 10:
		var boss := VisualSlots.make("enemy.E06")
		boss.scale = Vector3.ONE * 0.38
		boss.rotation_degrees.y = 200.0 if not portrait else 180.0
		boss.position = Vector3(0, 0.1, -0.2)
		root.add_child(boss)
	if battle or k.x != 10:
		for i: int in 3:
			b._p(ProxyMesh.cyl(0.04, 0.05, 0.5, 5), VisualPalette.mat("bark_dark"), Vector3(0, 0.18, 0), Vector3(0, 60.0 * i, 75))
		b._p(ProxyMesh.cyl(0.0, 0.14, 0.32, 6), VisualPalette.glow("amber"), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3.ONE, "Glow_Fire")
		b._p(ProxyMesh.sphere(0.32, 8, 4), VisualPalette.glow("amber", 0.18, true), Vector3(0, 0.32, 0), Vector3.ZERO, Vector3.ONE, "Glow_Halo")
		particles = CPUParticles3D.new()
		particles.amount = 8
		particles.lifetime = 1.4
		particles.position = Vector3(0, 0.4, 0)
		particles.direction = Vector3.UP
		particles.spread = 15.0
		particles.initial_velocity_min = 0.3
		particles.initial_velocity_max = 0.6
		particles.gravity = Vector3(0, 0.2, 0)
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 0.08
		particles.mesh = ProxyMesh.box(Vector3(0.03, 0.03, 0.03))
		particles.material_override = VisualPalette.glow("ember_hot")
		fire.add_child(particles)
	root.position = pos_of(k)
	add_child(root)
	_islands[k] = {"node": root, "fire": fire, "particles": particles, "top": top, "battle": battle}
	_light_island(k, false)


func _bridge(a: Vector2i, bk: Vector2i) -> void:
	var n := Node3D.new()
	n.name = "Bridge_%d_%d__%d_%d" % [a.x, a.y, bk.x, bk.y]
	add_child(n)
	_bridges.append({"a": a, "b": bk, "node": n})
	_layout_bridge(_bridges.back())


func _layout_bridge(br: Dictionary) -> void:
	var n: Node3D = br["node"]
	for c: Node in n.get_children():
		c.free()
	var pa := pos_of(br["a"]) + Vector3(0, 0.08, 0)
	var pb := pos_of(br["b"]) + Vector3(0, 0.08, 0)
	var steps := 7
	var lamps: Array = []
	for i: int in steps:
		var t := (float(i) + 0.5) / float(steps)
		var p := pa.lerp(pb, t) - Vector3(0, sin(t * PI) * 0.25, 0)
		var plank := MeshInstance3D.new()
		plank.mesh = ProxyMesh.box(Vector3(0.42, 0.04, 0.12))
		plank.material_override = VisualPalette.mat("wood_plank")
		var dir := (pb - pa).normalized()
		plank.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), p)
		n.add_child(plank)
	var mid := pa.lerp(pb, 0.5) - Vector3(0, 0.25, 0) + Vector3(0, 0.22, 0)
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	lamp.mesh = ProxyMesh.sphere(0.09, 6, 3)
	lamp.position = mid
	n.add_child(lamp)
	lamps.append(lamp)
	br["lamps"] = lamps
	_light_bridge(br, bool(br.get("lit", false)))


func _light_island(k: Vector2i, on: bool, current: bool = false) -> void:
	var d: Dictionary = _islands[k]
	d["lit"] = on
	var fire: Node3D = d["fire"]
	for c: Node in fire.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visible = on
	var p := d["particles"] as CPUParticles3D
	if p:
		p.visible = on
		_set_emitting(p, on)
	(d["top"] as MeshInstance3D).material_override = VisualPalette.mat("moss" if on else "stone_cool")
	if current:
		_current_light.position = (d["node"] as Node3D).position + Vector3(0, 1.0, 0.6)


## CPUParticles3D.emitting reads the global transform, which errors outside the
## tree (set_progress can run before the diorama is added, e.g. headless tests).
## Outside the tree the wanted state is kept and applied on tree_entered.
func _set_emitting(p: CPUParticles3D, on: bool) -> void:
	p.set_meta("want_emitting", on)
	if p.is_inside_tree():
		p.emitting = on
	elif not p.tree_entered.is_connected(_apply_emitting.bind(p)):
		p.tree_entered.connect(_apply_emitting.bind(p), CONNECT_ONE_SHOT)


func _apply_emitting(p: CPUParticles3D) -> void:
	p.emitting = bool(p.get_meta("want_emitting", false))


func _light_bridge(br: Dictionary, on: bool) -> void:
	br["lit"] = on
	for l: Variant in br.get("lamps", []):
		(l as MeshInstance3D).material_override = VisualPalette.glow("amber" if on else "stone_dark")


func set_progress(battle_index: int, chosen_nodes: Array) -> void:
	_battle_index = clampi(battle_index, 0, BATTLES - 1)
	var src := chosen_nodes.duplicate()
	_chosen.clear()
	for c: Variant in src:
		if c is Vector2i:
			_chosen.append(c)
		elif c is Dictionary:
			_chosen.append(Vector2i(int((c as Dictionary).get("col", 0)), int((c as Dictionary).get("lane", 0))))
	if _islands.is_empty():
		return
	for k: Vector2i in _islands.keys():
		var lit := (k.y == 0 and k.x / 2 <= _battle_index) or _chosen.has(k)
		_light_island(k, lit, k.y == 0 and k.x / 2 == _battle_index)
	for br: Dictionary in _bridges:
		var a: Vector2i = br["a"]
		var b: Vector2i = br["b"]
		_light_bridge(br, bool(_islands[a]["lit"]) and bool(_islands[b]["lit"]))


## API parity with the other dioramas. The route spans the whole width, so the
## anchor is stored but does not move the camera.
func set_screen_anchor(x: float) -> void:
	screen_anchor = clampf(x, 0.0, 1.0)


func focus(i: int) -> void:
	var k := Vector2i(clampi(i, 0, BATTLES - 1) * 2, 0)
	var target := _cam_base
	var shift := pos_of(k) * Vector3(0.35, 0.2, 0.35)
	target.origin += Vector3(shift.x, shift.y, shift.z if portrait else 0.0)
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	if UnitAnimator.motion_reduced() or not is_inside_tree():
		_cam.transform = target
		return
	_focus_tween = create_tween()
	_focus_tween.tween_property(_cam, "transform", target, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_portrait(p: bool) -> void:
	portrait = p
	for k: Vector2i in _islands.keys():
		(_islands[k]["node"] as Node3D).position = pos_of(k)
	for br: Dictionary in _bridges:
		_layout_bridge(br)
	if _tree:
		_tree.position = Vector3(-2.0, -1.5, -22.0) if portrait else Vector3(-17.0, 2.5, -20.0)
	set_progress(_battle_index, _chosen)
	if portrait:
		_cam.keep_aspect = Camera3D.KEEP_WIDTH
		_cam.fov = 30.0
		_aim(Vector3(0.0, 15.0, 15.0), Vector3(0, -0.8, -2.5))
	else:
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.fov = 46.0
		_aim(Vector3(-1.0, 8.0, 17.0), Vector3(-1.0, 1.4, -2.0))
	_cam_base = _cam.transform


func _aim(pos: Vector3, at: Vector3) -> void:
	_cam.transform = Transform3D(Basis.looking_at(at - pos, Vector3.UP), pos)


## The world tree far away: crown trunk segment + heart on a big island, glowing.
func _world_tree() -> void:
	_tree = Node3D.new()
	_tree.name = "WorldTree"
	add_child(_tree)
	var base := ProxyBuilder.new()
	base._at = _tree
	base._p(ProxyMesh.cyl(3.2, 0.5, 5.0, 8), VisualPalette.mat("island"), Vector3(0, -2.4, -3.0))
	base._p(ProxyMesh.cyl(3.1, 3.2, 0.3, 8), VisualPalette.mat("island_top"), Vector3(0, 0.0, -3.0))
	var trunk := VisualSlots.make("stage.trunk")
	var sv := trunk.get_node_or_null("StageVariant")
	if sv:
		sv.set("force", "crown")
	_tree.add_child(trunk)
	var heart := VisualSlots.make("stage.heart")
	heart.position = Vector3(0, 3.4, -0.4)
	_tree.add_child(heart)
	var h := heart.find_child("HeartLight", true, false) as OmniLight3D
	if h:
		h.omni_range = 9.0
		h.light_energy = 2.5
	_tree.scale = Vector3.ONE * 1.3


func _mist() -> void:
	for i: int in 4:
		var m := MeshInstance3D.new()
		m.mesh = ProxyMesh.sphere(10.0, 12, 6)
		m.material_override = VisualPalette.glow("haze", 0.045)
		m.position = Vector3(-14.0 + 10.0 * i, -6.0, -4.0 - 2.0 * float(i % 2))
		m.scale = Vector3(1.6, 0.35, 1.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	var motes := CPUParticles3D.new()
	motes.amount = 30
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(16, 4, 6)
	motes.gravity = Vector3(0.05, 0.08, 0)
	motes.initial_velocity_max = 0.05
	motes.mesh = ProxyMesh.box(Vector3(0.04, 0.04, 0.04))
	motes.material_override = VisualPalette.glow("cap_gill", 0.6)
	motes.position = Vector3(0, -1.0, -2.0)
	add_child(motes)
