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
			root.add_child(ProxyBuilder.build(slot_id, spec))
	root.name = slot_id.replace(".", "_") if not slot_id.is_empty() else "MissingSlot"
	var kind := str(s.get("kind", "missing"))
	root.set_meta("slot_id", slot_id)
	root.set_meta("is_proxy", is_proxy)
	root.set_meta("kind", kind)
	root.set_meta("height_m", float(s.get("height", 1.0)))
	if kind in ANIMATED_KINDS or slot_id == "stage.heart":
		if root.get_node_or_null("UnitAnimator") == null:
			var an := UnitAnimator.new()
			an.name = "UnitAnimator"
			an.slot_id = slot_id
			an.rig_family = str(s.get("rig_family", "humanoid"))
			root.add_child(an)
	return root


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
		out = xf * (n as VisualInstance3D).get_aabb()
		first = false
	for c: Node in n.get_children():
		var cxf := xf * (c as Node3D).transform if c is Node3D else xf
		var cb := bounds(c, cxf)
		if cb.size == Vector3.ZERO:
			continue
		out = cb if first else out.merge(cb)
		first = false
	return out
