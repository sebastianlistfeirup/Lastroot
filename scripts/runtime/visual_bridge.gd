class_name VisualBridge
extends RefCounted
## Thin bridge to the visual slot layer (scripts/runtime/visual/, owned by the
## asset pipeline). The battle code only asks for "a node for this slot id";
## whether that is a Synty/PolyPerfect wrapper or a greybox proxy is decided
## there. If the layer is not present, simple registered proxies are built here.

const VS_PATH := "res://scripts/runtime/visual/visual_slots.gd"

static var _vs: GDScript = null
static var _checked := false


static func _layer() -> GDScript:
	if not _checked:
		_checked = true
		if ResourceLoader.exists(VS_PATH):
			_vs = load(VS_PATH)
	return _vs


static func make(slot_id: String) -> Node3D:
	var vs := _layer()
	if vs != null:
		var n: Variant = vs.call("make", slot_id)
		if n is Node3D:
			return n
	return _fallback(slot_id)


static func head_height(slot_id: String) -> float:
	var vs := _layer()
	if vs != null and vs.has_method("head_height"):
		return float(vs.call("head_height", slot_id))
	return _fallback_height(slot_id)


static func _fallback_height(slot_id: String) -> float:
	if slot_id.begins_with("enemy.E06"):
		return 3.0
	if slot_id in ["unit.B01", "unit.B06", "unit.S06"]:
		return 2.3
	if slot_id.begins_with("enemy."):
		return 1.3
	return 1.4


static func _fallback(slot_id: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("slot_id", slot_id)
	root.set_meta("is_proxy", true)
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	var h: float = _fallback_height(slot_id)
	if slot_id.begins_with("unit.B"):
		mat.albedo_color = UiKit.BARK
	elif slot_id.begins_with("unit.S"):
		mat.albedo_color = UiKit.SPORE
	elif slot_id.begins_with("enemy."):
		mat.albedo_color = Color("2b2b30")
		mat.emission_enabled = true
		mat.emission = Color("ff6a2a") * 0.25
	else:
		mat.albedo_color = Color("3a4256")
	if slot_id.begins_with("stage.floor"):
		var cyl := CylinderMesh.new()
		cyl.top_radius = 5.9
		cyl.bottom_radius = 5.4
		cyl.height = 0.6
		mi.mesh = cyl
		mi.position.y = -0.3
		mi.scale = Vector3(1.0, 1.0, 0.36)
		mat.albedo_color = Color("4a3a2a")
	elif slot_id == "stage.heart":
		var sph := SphereMesh.new()
		sph.radius = 0.8
		sph.height = 1.6
		mi.mesh = sph
		mat.albedo_color = UiKit.LIFE
		mat.emission_enabled = true
		mat.emission = UiKit.LIFE
		mat.emission_energy_multiplier = 2.0
	elif slot_id == "stage.trunk":
		var c := CylinderMesh.new()
		c.top_radius = 0.9
		c.bottom_radius = 1.2
		c.height = 4.5
		mi.mesh = c
		mi.position = Vector3(0, 2.25, -1.6)
		mat.albedo_color = Color("5a4030")
	else:
		var cap := CapsuleMesh.new()
		cap.radius = 0.32 if h < 2.0 else 0.55
		cap.height = h
		mi.mesh = cap
		mi.position.y = h * 0.5
	mi.material_override = mat
	root.add_child(mi)
	return root
