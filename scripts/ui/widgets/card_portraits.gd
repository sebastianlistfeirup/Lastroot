class_name CardPortraits
extends Node
## Lazy, cached portrait renders for cards (LR-24). The first request for a
## slot id ("unit.B02", "enemy.E06") queues one off-screen render: a small
## SubViewport with its own world, camera and light, rendered ONCE
## (UPDATE_ONCE), copied into an ImageTexture and freed. Every later request
## is a cache hit, so cards never keep viewports alive or render per frame.
## The model comes from VisualSlots.make(), so real Synty wrappers replace the
## proxies here automatically. Headless runs (tests) skip rendering and the
## card shows its drawn emblem instead.

signal portrait_ready(slot_id: String, tex: Texture2D)

const SIZE := Vector2i(224, 144)

static var _cache: Dictionary = {}     # slot_id -> Texture2D (or null = failed)
static var _instance: CardPortraits = null
static var _waiters: Dictionary = {}   # slot_id -> [Callable] (method callables; freed targets are skipped)

var _queue: PackedStringArray = []
var _busy: bool = false


## Cached texture, or null while it is still being rendered (connect to
## portrait_ready via request()).
static func cached(slot_id: String) -> Texture2D:
	return _cache.get(slot_id, null)


static func is_cached(slot_id: String) -> bool:
	return _cache.has(slot_id)


static func enabled() -> bool:
	return DisplayServer.get_name() != "headless" and VisualSlots.has_slot("unit.B01")


## Asks for a render; `cb(tex)` runs when it is ready (at once on a cache hit).
static func request(slot_id: String, cb: Callable) -> void:
	if _cache.has(slot_id):
		if _cache[slot_id] != null:
			cb.call(_cache[slot_id])
		return
	if not enabled() or not VisualSlots.has_slot(slot_id):
		_cache[slot_id] = null
		return
	var inst: CardPortraits = _get_instance()
	if inst == null:
		return
	if not _waiters.has(slot_id):
		_waiters[slot_id] = []
	(_waiters[slot_id] as Array).append(cb)
	if not inst._queue.has(slot_id):
		inst._queue.append(slot_id)
	inst._pump.call_deferred()


static func _get_instance() -> CardPortraits:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_instance = CardPortraits.new()
	_instance.name = "CardPortraits"
	_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_instance)
	return _instance


func _pump() -> void:
	if _busy or _queue.is_empty() or not is_inside_tree():
		if not is_inside_tree() and not _queue.is_empty():
			_pump.call_deferred()
		return
	_busy = true
	var slot_id: String = _queue[0]
	_queue.remove_at(0)
	var tex: Texture2D = await _render(slot_id)
	_cache[slot_id] = tex
	var waiting: Array = _waiters.get(slot_id, [])
	_waiters.erase(slot_id)
	if tex != null:
		for cb: Callable in waiting:
			if cb.is_valid():
				cb.call(tex)
		portrait_ready.emit(slot_id, tex)
	_busy = false
	if not _queue.is_empty():
		_pump.call_deferred()


func _render(slot_id: String) -> Texture2D:
	var sv := SubViewport.new()
	sv.size = SIZE
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_2X
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var world := Node3D.new()
	sv.add_child(world)
	var model: Node3D = VisualSlots.make(slot_id)
	# A still pose: no animator ticking in the off-screen render.
	var an: Node = model.get_node_or_null("UnitAnimator")
	if an:
		an.process_mode = Node.PROCESS_MODE_DISABLED
	model.rotation_degrees.y = 200.0 if slot_id.begins_with("unit.") else 160.0
	world.add_child(model)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.7)
	e.ambient_light_energy = 0.9
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 1.3
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.6, 1.0, 0.95) if slot_id.begins_with("unit.") else Color(1.0, 0.55, 0.3)
	world.add_child(rim)
	var cam := Camera3D.new()
	world.add_child(cam)
	add_child(sv)
	# Frame the model: bust-ish shot, upper 70 % of its height.
	var ab: AABB = VisualSlots.bounds(model, model.transform)
	if ab.size == Vector3.ZERO:
		ab = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, float(model.get_meta("height_m", 1.5)), 1))
	var h: float = maxf(ab.size.y, 0.3)
	var target := Vector3(ab.get_center().x, ab.position.y + h * 0.58, ab.get_center().z)
	cam.fov = 30.0
	var dist: float = (h * 0.62) / tan(deg_to_rad(cam.fov * 0.5))
	dist = maxf(dist, maxf(ab.size.x, ab.size.z) * 1.2)
	cam.position = target + Vector3(0, h * 0.08, dist)
	cam.look_at(target)
	# One frame for the new world/shaders to settle; the very first portrait
	# of a session otherwise came back empty.
	await get_tree().process_frame
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = sv.get_texture().get_image()
	sv.queue_free()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


## Drops the cache (after asset imports).
static func clear() -> void:
	_cache.clear()
