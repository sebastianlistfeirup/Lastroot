class_name VisualSlots
extends RefCounted
## The one entry point the battle scene uses for visuals (static).
##
##   VisualSlots.make("unit.B01")        -> Node3D (never null)
##   VisualSlots.has_real_asset("unit.B01")
##   VisualSlots.slot_ids()
##   VisualSlots.head_height("enemy.E06") -> metres above the root for the HP/attack badge
##
## A slot shows its purchased-model wrapper when data/art/asset_slots.json has a
## non-empty "scene" (hand mapping) or tools/synty/build.sh wrote one into
## data/art/slot_scenes.json, and the file exists; otherwise a procedural proxy.
## Every root: origin at feet/base centre, facing -Z, metres, meta "slot_id",
## "is_proxy", "kind", "height_m". Units, enemies and the heart carry a child
## "UnitAnimator". Purely visual: no physics bodies, no gameplay.

const SLOTS_PATH := "res://data/art/asset_slots.json"
const BUILT_PATH := "res://data/art/slot_scenes.json"
const ANIMATED_KINDS := ["unit", "enemy"]

static var _slots: Dictionary = {}
static var _built: Dictionary = {}
static var _built_heights: Dictionary = {}
static var _loaded: bool = false


## Points the builder's slot -> wrapper map elsewhere (the selftest uses this).
## Kept in Engine meta, not a static var, so a script reload cannot reset it.
static func set_built_path(path: String) -> void:
	Engine.set_meta("lr_visual_built_path", path)
	reload()


static func built_path() -> String:
	return str(Engine.get_meta("lr_visual_built_path", BUILT_PATH))


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_slots = {}
	_built = {}
	_built_heights = {}
	var v: Variant = _read_json(SLOTS_PATH)
	if v is Dictionary:
		_slots = (v as Dictionary).get("slots", {}) as Dictionary
	else:
		push_warning("VisualSlots: cannot read " + SLOTS_PATH)
	var b: Variant = _read_json(built_path())
	if b is Dictionary:
		_built = (b as Dictionary).get("scenes", {}) as Dictionary
		_built_heights = (b as Dictionary).get("heights", {}) as Dictionary


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Forget cached data (after the import pipeline or the editor dock changed mappings).
static func reload() -> void:
	_loaded = false
	VisualPalette.reload()
	ProxyMerge.clear_cache()
	UnitAnimator._sets = {}


static func slot_ids() -> PackedStringArray:
	_load()
	var ids := PackedStringArray()
	for k: Variant in _slots.keys():
		if not str(k).begins_with("_"):
			ids.append(str(k))
	ids.sort()
	return ids


static func slot(slot_id: String) -> Dictionary:
	_load()
	return _slots.get(slot_id, {}) as Dictionary


static func has_slot(slot_id: String) -> bool:
	_load()
	return _slots.has(slot_id)


## Wrapper scene path ("" = proxy). Hand-set "scene" wins over the builder's mapping.
static func scene_path(slot_id: String) -> String:
	_load()
	var p := str(slot(slot_id).get("scene", ""))
	if p.is_empty():
		var b: Variant = _built.get(slot_id, "")
		p = str((b as Array)[0]) if b is Array and not (b as Array).is_empty() else str(b)
	return p


static func has_real_asset(slot_id: String) -> bool:
	var p := scene_path(slot_id)
	return not p.is_empty() and ResourceLoader.exists(p)


## Height above the root origin where the 2D HP/attack badge should sit.
static func head_height(slot_id: String) -> float:
	_load()
	var s := slot(slot_id)
	if has_real_asset(slot_id) and _built_heights.has(slot_id):
		return float(_built_heights[slot_id]) * float(s.get("scale", 1.0)) + 0.25
	return float(s.get("head_height", float(s.get("height", 1.0)) + 0.25))


static func make(slot_id: String) -> Node3D:
	_load()
	var s := slot(slot_id)
	var root: Node3D = null
	var is_proxy := true
	if s.is_empty():
		push_warning("VisualSlots: unknown slot id '%s' (magenta placeholder)" % slot_id)
		var b := ProxyBuilder.new()
		var m := Node3D.new()
		m.name = "Model"
		b._at = m
		b.missing(slot_id)
		root = Node3D.new()
		root.add_child(m)
	elif has_real_asset(slot_id):
		var ps := load(scene_path(slot_id)) as PackedScene
		var inst: Node = ps.instantiate() if ps else null
		if inst is Node3D:
			root = inst as Node3D
			is_proxy = false
			# Safety net: never let a vendor scene's own camera or lights into the game.
			for extra: Node in root.find_children("*", "Camera3D", true, false) + root.find_children("*", "Light3D", true, false):
				extra.get_parent().remove_child(extra)
				extra.free()
			var model := root.get_node_or_null("Model") as Node3D
			if model:
				# Owner fine-tuning on top of what the builder normalised.
				model.scale *= float(s.get("scale", 1.0))
				var off: Array = s.get("offset", []) as Array
				if off.size() == 3:
					model.position += Vector3(float(off[0]), float(off[1]), float(off[2]))
				model.rotation_degrees.y += float(s.get("rotation_y", 0.0))
		elif inst:
			inst.free()
	if root == null and not s.is_empty():
		root = Node3D.new()
		var kind := str(s.get("kind", ""))
		var spec: Dictionary = s.get("proxy", {}) as Dictionary
		if kind == "fx":
			root.free()
			root = FxBuilder.build(slot_id, spec)
		else:
			var model := ProxyBuilder.build(slot_id, spec)
			root.add_child(model)
			# Bake the static parts into a few surfaces (draw calls); animated parts stay nodes.
			ProxyMerge.merge(model, "%s#%d" % [slot_id, spec.hash()], str(s.get("rig_family", "")) == "quadruped")
	if slot_id == "stage.heart" and root.get_script() == null:
		root.set_script(HeartVisual)
	root.name = slot_id.replace(".", "_") if not slot_id.is_empty() else "MissingSlot"
	var kind := str(s.get("kind", "missing"))
	root.set_meta("slot_id", slot_id)
	root.set_meta("is_proxy", is_proxy)
	root.set_meta("kind", kind)
	root.set_meta("height_m", float(s.get("height", 1.0)))
	if is_proxy and kind in ["stage", "prop", "mutation"] and slot_id != "stage.backdrop":
		var gp := GlowPulse.new()
		gp.name = "GlowPulse"
		root.add_child(gp)
	if is_proxy and str((s.get("proxy", {}) as Dictionary).get("builder", "")) == "trunk":
		var sv := StageVariant.new()
		sv.name = "StageVariant"
		root.add_child(sv)
	if kind in ANIMATED_KINDS or slot_id == "stage.heart":
		if root.get_node_or_null("UnitAnimator") == null:
			var an := UnitAnimator.new()
			an.name = "UnitAnimator"
			an.slot_id = slot_id
			an.rig_family = str(s.get("rig_family", "humanoid"))
			root.add_child(an)
	return root


static var _footprints: Dictionary = {}


## Radius (m) of a ground ring around a unit's feet (fx.ring.set_radius). Measured
## from the visual actually shown (proxy or model) and cached; facing-independent.
static func footprint_radius(slot_id: String) -> float:
	_load()
	if _footprints.has(slot_id):
		return float(_footprints[slot_id])
	var v := make(slot_id)
	var m := v.get_node_or_null("Model")
	var b := bounds(m if m else v)
	v.free()
	# Arms and shields stick out sideways; weight the depth more than the width.
	var r := clampf(0.5 * maxf(b.size.x * 0.75, b.size.z) + 0.12, 0.35, 1.7)
	_footprints[slot_id] = snappedf(r, 0.01)
	return float(_footprints[slot_id])


const SIDE_COLORS := {&"ally": "turquoise", &"enemy": "ember"}
static var _rims: Dictionary = {}


## Ally/enemy readability at the battle camera without changing silhouettes:
## a faint fresnel rim (turquoise for allies, ember for enemies) as material_overlay
## on every mesh, plus a soft side-coloured disc under the feet. Call once after
## make() for unit/enemy visuals. rim=false keeps only the disc (cheaper: the rim
## draws every mesh twice). Flashes from UnitAnimator restore the rim afterwards.
static func apply_side(visual: Node3D, side: StringName, rim: bool = true) -> void:
	if visual == null or not SIDE_COLORS.has(side):
		return
	var key := str(SIDE_COLORS[side])
	var old := visual.get_node_or_null("SideDisc")
	if old:
		old.free()
	var disc := MeshInstance3D.new()
	disc.name = "SideDisc"
	disc.mesh = ProxyMesh.ring_flat(0.0, 1.0, 32)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	dm.albedo_color = Color(VisualPalette.color(key).darkened(0.35), 0.28)
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r := footprint_radius(str(visual.get_meta("slot_id", "")))
	disc.scale = Vector3(r * 0.85, 1, r * 0.85)
	disc.position.y = 0.02
	visual.add_child(disc)
	visual.set_meta("side", side)
	var mat: Material = rim_material(side) if rim else null
	var model := visual.get_node_or_null("Model")
	if model:
		for n: Node in model.find_children("*", "GeometryInstance3D", true, false):
			if n is Label3D:
				continue
			(n as GeometryInstance3D).material_overlay = mat
	var an := visual.get_node_or_null("UnitAnimator") as UnitAnimator
	if an:
		an.base_overlay = mat


## Shared additive fresnel rim per side (Compatibility-safe spatial shader).
static func rim_material(side: StringName) -> ShaderMaterial:
	if _rims.has(side):
		return _rims[side]
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/runtime/visual/side_rim.gdshader") as Shader
	var c := VisualPalette.color(str(SIDE_COLORS.get(side, "turquoise")))
	m.set_shader_parameter("rim_color", c)
	m.set_shader_parameter("strength", 0.42 if side == &"ally" else 0.65)
	m.set_shader_parameter("power", 3.0 if side == &"ally" else 2.6)
	_rims[side] = m
	return m


## Slots of one kind ("unit", "enemy", "stage", "prop", "mutation", "fx").
static func ids_of_kind(kind: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in slot_ids():
		if str(slot(id).get("kind", "")) == kind:
			out.append(id)
	return out


## Axis-aligned bounds of all visible geometry under n (works outside the tree).
static func bounds(n: Node, xf: Transform3D = Transform3D.IDENTITY) -> AABB:
	var out := AABB()
	var first := true
	if n is VisualInstance3D and not n is Light3D and not n is GPUParticles3D and not n is CPUParticles3D:
		out = _skinned_aabb(n as MeshInstance3D, xf) if n is MeshInstance3D else AABB()
		if out.size == Vector3.ZERO:
			# A ProxyMerge node reports the union of its parts' boxes, as before the merge.
			for pb: AABB in ProxyMerge.part_bounds(n as VisualInstance3D):
				out = xf * pb if first else out.merge(xf * pb)
				first = false
		first = false
	for c: Node in n.get_children():
		var cxf := xf * (c as Node3D).transform if c is Node3D else xf
		var cb := bounds(c, cxf)
		if cb.size == Vector3.ZERO:
			continue
		out = cb if first else out.merge(cb)
		first = false
	return out


## Bounds of a SKINNED mesh as it is drawn (skeleton pose x bind pose x vertex), not the
## raw mesh-space AABB. Real-FBX lesson: after a humanoid bone map the importer's rest
## fixer moves the FBX axis/unit conversion into the bind poses, so the raw vertices of a
## Synty FBX lie flat and ~100x too small; the plain AABB made the builder scale it x600.
## Returns an empty AABB when the mesh is not skinned (caller falls back to get_aabb()).
static func _skinned_aabb(mi: MeshInstance3D, xf: Transform3D) -> AABB:
	if mi.mesh == null or mi.skin == null:
		return AABB()
	var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if sk == null:
		return AABB()
	var skin := mi.skin
	var binds: Array[Transform3D] = []
	for i: int in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0:
			bone = sk.find_bone(String(skin.get_bind_name(i)))
		binds.append((sk.get_bone_global_pose(bone) if bone >= 0 else Transform3D.IDENTITY) * skin.get_bind_pose(i))
	var out := AABB()
	var first := true
	for s: int in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if verts.is_empty() or bones.is_empty() or weights.size() != bones.size():
			return AABB()
		var per: int = floori(float(bones.size()) / float(verts.size()))
		for v: int in verts.size():
			var best := 0
			for j: int in range(1, per):
				if weights[v * per + j] > weights[v * per + best]:
					best = j
			var b := bones[v * per + best]
			var p := xf * ((binds[b] if b < binds.size() else Transform3D.IDENTITY) * verts[v])
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out
