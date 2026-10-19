class_name ProxyMesh
extends RefCounted
## Cached, flat-shaded ("faceted", Synty-like low poly) primitive meshes for
## the procedural proxies. Every function returns a shared Mesh: never edit it.

static var _cache: Dictionary = {}


static func box(s: Vector3) -> Mesh:
	var k := "box|%s" % s
	if not _cache.has(k):
		var m := BoxMesh.new()
		m.size = s
		_cache[k] = m
	return _cache[k]


## Faceted cylinder/cone. top or bottom radius 0 gives a cone.
static func cyl(top: float, bottom: float, h: float, seg: int = 7) -> Mesh:
	var k := "cyl|%.3f|%.3f|%.3f|%d" % [top, bottom, h, seg]
	if not _cache.has(k):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		_cache[k] = faceted(m)
	return _cache[k]


static func sphere(r: float, seg: int = 8, rings: int = 5, hemi: bool = false) -> Mesh:
	var k := "sph|%.3f|%d|%d|%s" % [r, seg, rings, hemi]
	if not _cache.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * (1.0 if hemi else 2.0)
		m.radial_segments = seg
		m.rings = rings
		m.is_hemisphere = hemi
		_cache[k] = faceted(m)
	return _cache[k]


## Triangular prism (spikes, thorns, roof shapes). Apex points +Y.
static func prism(s: Vector3) -> Mesh:
	var k := "prism|%s" % s
	if not _cache.has(k):
		var m := PrismMesh.new()
		m.size = s
		_cache[k] = faceted(m)
	return _cache[k]


static func torus(inner: float, outer: float, rings: int = 12, ring_seg: int = 5) -> Mesh:
	var k := "torus|%.3f|%.3f|%d|%d" % [inner, outer, rings, ring_seg]
	if not _cache.has(k):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = rings
		m.ring_segments = ring_seg
		_cache[k] = faceted(m)
	return _cache[k]


## Irregular low-poly rock: a jittered sphere, deterministic per seed.
static func rock(r: float, seed: int, squash: float = 0.75) -> Mesh:
	var k := "rock|%.3f|%d|%.2f" % [r, seed, squash]
	if not _cache.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 7
		m.rings = 4
		var arr: Array = m.get_mesh_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i: int in verts.size():
			var v: Vector3 = verts[i]
			# Same position -> same jitter, so seams stay closed.
			var h := hash(Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)) + Vector3i(seed, seed * 7, seed * 13))
			var f := 0.78 + float(h % 1000) / 1000.0 * 0.42
			verts[i] = Vector3(v.x * f, v.y * f * squash, v.z * f)
		arr[Mesh.ARRAY_VERTEX] = verts
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_cache[k] = faceted(am)
	return _cache[k]


## Faceted gem heart (the tree's heart crystal), width w, depth d. Vertex
## colours shade the facets so it reads as cut crystal even when unshaded.
static func heart_gem(w: float, d: float) -> Mesh:
	var k := "heart|%.3f|%.3f" % [w, d]
	if _cache.has(k):
		return _cache[k]
	var n := 22
	var s := w / 32.0
	var outline: Array[Vector3] = []
	for i: int in n:
		var t := TAU * float(i) / float(n)
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		outline.append(Vector3(x * s, (y + 2.5) * s, 0.0))
	var center := Vector3(0, 0.0, 0)
	var light := Vector3(-0.4, 0.7, 0.6).normalized()
	var base := VisualPalette.color("turquoise")
	var deep := VisualPalette.color("turquoise_soft").darkened(0.35)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [1.0, -1.0]:
		var apex := center + Vector3(0, 0, d * side)
		var ring: Array[Vector3] = []
		for p: Vector3 in outline:
			ring.append(p * 0.55 + Vector3(0, 0, d * 0.62 * side))
		for i: int in n:
			var j := (i + 1) % n
			_tri(st, outline[i], outline[j], ring[j], center, light, base, deep)
			_tri(st, outline[i], ring[j], ring[i], center, light, base, deep)
			_tri(st, ring[i], ring[j], apex, center, light, base, deep)
	var mesh := st.commit()
	_cache[k] = mesh
	return mesh


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3, light: Vector3, base: Color, deep: Color) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	var mid := (a + b + c) / 3.0
	if nrm.dot(mid - center) < 0.0:
		var tmp := b
		b = c
		c = tmp
		nrm = -nrm
	var f := clampf(0.5 + 0.5 * nrm.dot(light), 0.0, 1.0)
	var col := deep.lerp(base, f).lerp(Color.WHITE, pow(f, 6.0) * 0.6)
	st.set_color(col)
	st.set_normal(nrm)
	# Godot's front faces are clockwise when seen from outside.
	for v: Vector3 in [a, c, b]:
		st.add_vertex(v)


## Converts any mesh to flat-shaded triangles (one normal per face).
static func faceted(src: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si: int in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for i: int in verts.size():
				idx.append(i)
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		for t: int in range(0, idx.size() - 2, 3):
			var a: Vector3 = verts[idx[t]]
			var b: Vector3 = verts[idx[t + 1]]
			var c: Vector3 = verts[idx[t + 2]]
			var fn := (b - a).cross(c - a)
			if fn.length_squared() < 1e-12:
				continue
			fn = fn.normalized()
			if not norms.is_empty():
				var avg: Vector3 = norms[idx[t]] + norms[idx[t + 1]] + norms[idx[t + 2]]
				if fn.dot(avg) < 0.0:
					fn = -fn
			nv.append_array([a, b, c])
			nn.append_array([fn, fn, fn])
		var na: Array = []
		na.resize(Mesh.ARRAY_MAX)
		na[Mesh.ARRAY_VERTEX] = nv
		na[Mesh.ARRAY_NORMAL] = nn
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
	return out
