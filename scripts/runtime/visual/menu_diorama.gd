class_name MenuDiorama
extends Node3D
## Title / champion-select backdrop: the world tree built from the real TreeStage
## pieces (VisualSlots floors, trunk per floor, heart, backdrop), the heart pulsing,
## the Barkwarden and the Spore Sage on the Roots, embers rising, and a slow
## swaying orbit of the camera (static under reduced motion).
##
## API:
##   set_champion(faction: String)  "BARK" | "SPORE" | "" — highlights that champion
##                                  (amber ring, side rim, a warm light, victory pose)
##   set_portrait(p: bool)          reframes for 430x932 (true) or 1920x1080 (false)
##   @export dim                    0..1 darkening behind UI text (default 0.2)
## Cheap for web: 3 lights (sun, heart, champion), no shadows, CPUParticles.

@export_range(0.0, 1.0) var dim: float = 0.2:
	set(v):
		dim = v
		if _dim_rect:
			_dim_rect.color = Color(0, 0, 0, dim)

const CENTER := Vector3(0, 6.2, -1.0)
const ORBIT_DEG := 22.0
const ORBIT_PERIOD := 26.0

var portrait: bool = false
var screen_anchor: float = 0.5
var faction: String = ""

var _cam: Camera3D
var _champs: Dictionary = {}   # "BARK"/"SPORE" -> {node, ring}
var _champ_light: OmniLight3D
var _dim_rect: ColorRect
var _t: float = 0.0
var _dist: float = 30.0
var _height: float = 6.5


func _ready() -> void:
	_env()
	add_child(VisualSlots.make("stage.backdrop"))
	var floors := ["stage.floor_roots", "stage.floor_trunk", "stage.floor_crown"]
	for f: int in 3:
		var fl := VisualSlots.make(floors[f])
		fl.position.y = 4.5 * f
		add_child(fl)
		var tr := VisualSlots.make("stage.trunk")
		tr.position.y = 4.5 * f
		add_child(tr)
	var heart := VisualSlots.make("stage.heart")
	heart.position = Vector3(0, 12.4, -0.4)
	add_child(heart)
	var pulse := VisualSlots.make("fx.heart_pulse")
	pulse.position = heart.position
	add_child(pulse)
	_champion("BARK", "unit.B01", Vector3(-2.9, 0, 0.3), 155.0)
	_champion("SPORE", "unit.S01", Vector3(2.4, 0, 0.4), 205.0)
	_embers()
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_dim_rect = ColorRect.new()
	_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_rect.color = Color(0, 0, 0, dim)
	ui.add_child(_dim_rect)
	var want := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--anchor="):
			screen_anchor = float(a.substr(9))
		elif a == "--portrait":
			portrait = true
		elif a.begins_with("--champion="):
			want = a.substr(11)
	set_portrait(portrait)
	set_champion(want)
	DioramaCapture.attach(self)


func _env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0b0e1a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("4a4f7a")
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("1d1830")
	e.fog_density = 0.005
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_color = Color("ffd9a8")
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)
	_champ_light = OmniLight3D.new()
	_champ_light.light_color = VisualPalette.color("amber")
	_champ_light.light_energy = 0.0
	_champ_light.omni_range = 4.5
	add_child(_champ_light)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true


func _champion(key: String, slot_id: String, pos: Vector3, yaw: float) -> void:
	var v := VisualSlots.make(slot_id)
	v.position = pos
	v.rotation_degrees.y = yaw
	add_child(v)
	var ring := VisualSlots.make("fx.ring") as TargetMarker
	ring.position = pos
	add_child(ring)
	ring.set_radius(VisualSlots.footprint_radius(slot_id))
	_champs[key] = {"node": v, "ring": ring, "slot": slot_id}


func set_champion(f: String) -> void:
	faction = f.to_upper()
	for key: String in _champs.keys():
		var c: Dictionary = _champs[key]
		var v: Node3D = c["node"]
		var on := key == faction
		(c["ring"] as TargetMarker).set_kind(&"selected" if on else &"none")
		var disc := v.get_node_or_null("SideDisc")
		if disc:
			disc.free()
		var model := v.get_node_or_null("Model")
		if model:
			for n: Node in model.find_children("*", "GeometryInstance3D", true, false):
				(n as GeometryInstance3D).material_overlay = null
		var an := v.get_node_or_null("UnitAnimator") as UnitAnimator
		if an:
			an.base_overlay = null
		if on:
			VisualSlots.apply_side(v, &"ally", not OS.has_feature("web"))
			_champ_light.position = v.position + Vector3(0, 2.2, 1.4)
			_champ_light.light_energy = 1.6
			if an and v.is_inside_tree():
				an.play(&"victory")
	if not _champs.has(faction):
		_champ_light.light_energy = 0.0


func set_portrait(p: bool) -> void:
	portrait = p
	if portrait:
		_cam.keep_aspect = Camera3D.KEEP_WIDTH
		_cam.fov = 29.0
		_dist = 31.0
		_height = 6.8
	else:
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.fov = 38.0
		_dist = 30.0
		_height = 7.2
	_place_camera()


func _place_camera() -> void:
	var a := 0.0
	if not UnitAnimator.motion_reduced():
		a = deg_to_rad(ORBIT_DEG) * sin(TAU * _t / ORBIT_PERIOD)
	var pos := CENTER + Vector3(sin(a) * _dist, _height - CENTER.y + 1.5, cos(a) * _dist)
	_cam.transform = Transform3D(Basis.looking_at(CENTER + Vector3(0, 0.3, 0) - pos, Vector3.UP), pos)
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


func _embers() -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = Vector3(0, -1.5, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9, 0.5, 3)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0.08, 0.15, 0)
	p.mesh = ProxyMesh.box(Vector3(0.05, 0.05, 0.05))
	p.material_override = VisualPalette.glow("ember_hot")
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	add_child(p)
