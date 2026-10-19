class_name EpilogDiorama
extends Node3D
## REF_10 ending: the run's actual tree, built from the real stage pieces.
##   set_run(mutations: Array, faction: String, champion_path: String, result: String)
##     result "won":  heart blazing, the run's mutations visible, the champion (BARK ->
##                    Barkwarden, SPORE -> Spore Sage) on the Crown in a victory pose with
##                    a path-coloured aura (BULWARK amber, WRATH ember, VENOM violet,
##                    LIFEWEAVER green), warm dawn light, petals and spores rising.
##     result "lost": heart dimmed and cracked, ash drifting down, embers, ash enemies
##                    (the Ash Crown and two followers) on the Crown, cold light.
##   set_portrait(p: bool)   430x932 (true) or 1920x1080 (false)
##   @export dim             0..1 darkening behind the UI text (default 0.2)
## Slow camera drift (static under reduced motion). Budget: <= 3 lights, no shadows,
## CPUParticles only, no physics. Embed like the other dioramas (SCENE_ASSEMBLY.md).

@export_range(0.0, 1.0) var dim: float = 0.2:
	set(v):
		dim = v
		if _dim_rect:
			_dim_rect.color = Color(0, 0, 0, dim)

const CENTER := Vector3(0, 9.6, -1.0)
const HEART_POS := Vector3(0, 12.4, -0.4)
const PATH_COLORS := {"BULWARK": "amber", "WRATH": "ember_red", "VENOM": "poison_violet", "LIFEWEAVER": "heal"}

var portrait: bool = false
var screen_anchor: float = 0.5
var result: String = "won"

var _env: Environment
var _sun: DirectionalLight3D
var _accent: OmniLight3D
var _cam: Camera3D
var _run: Node3D
var _heart: Node3D
var _dim_rect: ColorRect
var _t: float = 0.0
var _dist: float = 24.0
var _victory_timer: float = 0.0
var _champion: Node3D


func _ready() -> void:
	_build_env()
	add_child(VisualSlots.make("stage.backdrop"))
	var floors := ["stage.floor_roots", "stage.floor_trunk", "stage.floor_crown"]
	for f: int in 3:
		var fl := VisualSlots.make(floors[f])
		fl.position.y = 4.5 * f
		add_child(fl)
		var tr := VisualSlots.make("stage.trunk")
		tr.position.y = 4.5 * f
		add_child(tr)
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_dim_rect = ColorRect.new()
	_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_rect.color = Color(0, 0, 0, dim)
	ui.add_child(_dim_rect)
	var muts: Array = ["M01", "M03"]
	var fac := "BARK"
	var path := "BULWARK"
	var res := "won"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--anchor="):
			screen_anchor = float(a.substr(9))
		elif a == "--portrait":
			portrait = true
		elif a.begins_with("--result="):
			res = a.substr(9)
		elif a.begins_with("--faction="):
			fac = a.substr(10)
		elif a.begins_with("--path="):
			path = a.substr(7)
		elif a.begins_with("--mutations="):
			muts = Array(a.substr(12).split(",", false))
	set_portrait(portrait)
	set_run(muts, fac, path, res)
	DioramaCapture.attach(self)


func _build_env() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_density = 0.006
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = false
	add_child(_sun)
	_accent = OmniLight3D.new()
	_accent.omni_range = 6.0
	add_child(_accent)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true


func set_run(mutations: Array, faction: String, champion_path: String, run_result: String) -> void:
	result = "lost" if run_result.to_lower() == "lost" else "won"
	if _run:
		_run.free()
	_run = Node3D.new()
	_run.name = "Run"
	add_child(_run)
	var won := result == "won"
	# Light and sky: warm dawn vs cold ash night.
	_env.background_color = Color("2a1a2e") if won else Color("080a14")
	_env.ambient_light_color = Color("7a6070") if won else Color("343a58")
	_env.ambient_light_energy = 1.0 if won else 0.7
	_env.fog_light_color = Color("4a2a3a") if won else Color("141828")
	_sun.light_color = Color("ffc48a") if won else Color("8ea4ff")
	_sun.light_energy = 1.35 if won else 0.55
	_sun.rotation_degrees = Vector3(-18, -55, 0) if won else Vector3(-50, 20, 0)
	_heart = VisualSlots.make("stage.heart")
	_heart.position = HEART_POS
	_run.add_child(_heart)
	var hl := _heart.find_child("HeartLight", true, false) as OmniLight3D
	if won:
		for m: Variant in mutations:
			var mid := str(m).to_upper()
			if not mid in ["M01", "M02", "M03", "M04"]:
				continue
			var n := VisualSlots.make("mutation." + mid)
			var f: int = {"M01": 0, "M02": 1, "M03": 2, "M04": -1}[mid]
			n.position = HEART_POS if f < 0 else Vector3(0, 4.5 * f, 0)
			# Keep the light budget: M04's extra light is folded into the heart's own.
			for l: Node in n.find_children("*", "Light3D", true, false):
				l.free()
			_run.add_child(n)
		_heart.scale = Vector3.ONE * 1.18
		if hl:
			hl.light_energy = 3.6
			hl.omni_range = 10.0
		var pulse := VisualSlots.make("fx.heart_pulse")
		pulse.position = HEART_POS
		_run.add_child(pulse)
		_rising(["blossom", "turquoise", "blossom_gold"])
		_place_champion(faction, champion_path)
		_accent.light_color = VisualPalette.color("amber")
		_accent.light_energy = 1.4
		_accent.position = Vector3(-1.6, 11.2, 1.6)
	else:
		_crack_heart(hl)
		_ash()
		var foes := [["enemy.E06", Vector3(1.6, 9.0, 0.2), 210.0], ["enemy.E03", Vector3(3.6, 9.0, 0.4), 220.0], ["enemy.E01", Vector3(-0.6, 9.0, 0.6), 160.0]]
		for e: Array in foes:
			var v := VisualSlots.make(str(e[0]))
			v.position = e[1] as Vector3
			v.rotation_degrees.y = float(e[2])
			_run.add_child(v)
		_accent.light_color = VisualPalette.color("ember_red")
		_accent.light_energy = 1.2
		_accent.position = Vector3(2.2, 11.0, 1.5)
		_champion = null


func _place_champion(faction: String, path: String) -> void:
	var slot := "unit.S01" if faction.to_upper() == "SPORE" else "unit.B01"
	_champion = VisualSlots.make(slot)
	_champion.position = Vector3(-1.9, 9.0, 0.5)
	_champion.rotation_degrees.y = 165.0
	_run.add_child(_champion)
	var key := str(PATH_COLORS.get(path.to_upper(), "amber"))
	var aura := MeshInstance3D.new()
	aura.name = "Aura"
	aura.mesh = ProxyMesh.ring_flat(0.0, 1.0, 32)
	aura.material_override = VisualPalette.glow(key, 0.35, true)
	aura.scale = Vector3.ONE * VisualSlots.footprint_radius(slot) * 1.3
	aura.position = _champion.position + Vector3(0, 0.03, 0)
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_run.add_child(aura)
	var ring := VisualSlots.make("fx.ring") as TargetMarker
	ring.position = _champion.position
	_run.add_child(ring)
	ring.set_radius(VisualSlots.footprint_radius(slot))
	ring.set_kind(&"selected")
	_victory_timer = 0.4


## Lost: the heart's own health visual at near zero (heavy cracks, cold tint,
## flicker), smaller and with a weak light.
func _crack_heart(hl: OmniLight3D) -> void:
	if _heart.has_method("set_health"):
		_heart.call("set_health", 0.08)
		_heart.scale = Vector3.ONE * 0.92
		if hl:
			hl.light_energy = 0.45
		return
	_crack_heart_fallback(hl)


func _crack_heart_fallback(hl: OmniLight3D) -> void:
	for n: Node in _heart.find_children("Gem*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_color = Color(0.32, 0.38, 0.42)
		mi.material_override = m
	for n: Node in _heart.find_children("Glow_Halo*", "Node3D", true, false) + _heart.find_children("Glow_Shard*", "Node3D", true, false):
		(n as Node3D).visible = false
	var b := ProxyBuilder.new()
	var cracks := Node3D.new()
	cracks.name = "Cracks"
	cracks.position = Vector3(0, 1.0, 0.45)
	_heart.get_node("Model").add_child(cracks)
	b._at = cracks
	for c: Array in [[Vector3(-0.1, 0.25, 0), 28.0, 0.7], [Vector3(0.15, -0.05, 0), -35.0, 0.55], [Vector3(-0.05, -0.3, 0), 70.0, 0.4], [Vector3(0.28, 0.3, 0), 10.0, 0.35]]:
		b._p(ProxyMesh.box(Vector3(0.035, float(c[2]), 0.02)), VisualPalette.glow("ash_black"), c[0] as Vector3, Vector3(0, 0, float(c[1])))
	_heart.scale = Vector3.ONE * 0.92
	if hl:
		hl.light_energy = 0.45
		hl.light_color = Color("5a8a90")


func _rising(keys: Array) -> void:
	for i: int in keys.size():
		var p := CPUParticles3D.new()
		p.amount = 18
		p.lifetime = 6.0
		p.preprocess = 6.0
		p.position = Vector3(0, 8.6, -0.5)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(5.5, 0.3, 1.4)
		p.direction = Vector3.UP
		p.spread = 20.0
		p.initial_velocity_min = 0.25
		p.initial_velocity_max = 0.6
		p.gravity = Vector3(0.05, 0.12, 0)
		p.angular_velocity_min = -90.0
		p.angular_velocity_max = 90.0
		p.mesh = ProxyMesh.box(Vector3(0.07, 0.02, 0.05)) if str(keys[i]) == "blossom" else ProxyMesh.sphere(0.04, 5, 3)
		p.material_override = VisualPalette.glow(str(keys[i]))
		_run.add_child(p)


func _ash() -> void:
	var ash := CPUParticles3D.new()
	ash.amount = 60
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.position = Vector3(0, 17.0, 0)
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(10, 0.5, 4)
	ash.gravity = Vector3(0.15, -0.35, 0)
	ash.initial_velocity_max = 0.1
	ash.angular_velocity_min = -60.0
	ash.angular_velocity_max = 60.0
	ash.mesh = ProxyMesh.box(Vector3(0.07, 0.02, 0.06))
	ash.material_override = VisualPalette.glow("ash_light", 0.8)
	_run.add_child(ash)
	var embers := CPUParticles3D.new()
	embers.amount = 24
	embers.lifetime = 5.0
	embers.preprocess = 5.0
	embers.position = Vector3(1.5, 8.8, 0)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(4, 0.3, 1.2)
	embers.direction = Vector3.UP
	embers.initial_velocity_min = 0.4
	embers.initial_velocity_max = 0.9
	embers.gravity = Vector3(0, 0.2, 0)
	embers.mesh = ProxyMesh.box(Vector3(0.04, 0.04, 0.04))
	embers.material_override = VisualPalette.glow("ember_hot")
	_run.add_child(embers)


func set_portrait(p: bool) -> void:
	portrait = p
	_cam.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	_cam.fov = 34.0 if portrait else 36.0
	_dist = 25.0 if portrait else 24.0
	_place_camera()


func _place_camera() -> void:
	var a := 0.0
	var lift := 0.0
	if not UnitAnimator.motion_reduced():
		a = deg_to_rad(9.0) * sin(TAU * _t / 30.0)
		lift = 0.4 * sin(TAU * _t / 22.0)
	var center := CENTER + (Vector3(0, -1.5, 0) if portrait else Vector3.ZERO)
	var pos := center + Vector3(sin(a) * _dist, 2.2 + lift, cos(a) * _dist)
	_cam.transform = Transform3D(Basis.looking_at(center - pos, Vector3.UP), pos)
	_apply_anchor(_dist)



## Where the tree's centre should appear horizontally (0..1 of the view width), e.g.
## 0.24 when UI panels cover the right side, 0.5 centred. Implemented as a sideways
## camera shift (h_offset) of exactly the right size for the current aspect and fov.
func set_screen_anchor(x: float) -> void:
	screen_anchor = clampf(x, 0.0, 1.0)
	_place_camera()


func _apply_anchor(dist: float) -> void:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size if vp else Vector2(16, 9)
	var aspect := size.x / maxf(size.y, 1.0)
	var half_w := 0.0
	if _cam.keep_aspect == Camera3D.KEEP_WIDTH:
		half_w = dist * tan(deg_to_rad(_cam.fov) * 0.5)
	else:
		half_w = dist * tan(deg_to_rad(_cam.fov) * 0.5) * aspect
	_cam.h_offset = (1.0 - 2.0 * screen_anchor) * half_w


func _process(dt: float) -> void:
	_t += dt
	_place_camera()
	# The champion repeats a victory pose now and then (once under reduced motion).
	if _champion and is_instance_valid(_champion) and _victory_timer > 0.0:
		_victory_timer -= dt
		if _victory_timer <= 0.0:
			var an := _champion.get_node_or_null("UnitAnimator") as UnitAnimator
			if an:
				an.play(&"victory")
			_victory_timer = -1.0 if UnitAnimator.motion_reduced() else 4.5
