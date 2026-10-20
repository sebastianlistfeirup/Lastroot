class_name ProxyMerge
extends RefCounted
## Build-time draw-call reduction for the procedural proxies (presentation only).
## A proxy is built from many small static MeshInstance3D parts; in the
## Compatibility renderer every part (and its side-rim overlay) is its own draw
## call. merge() bakes the static parts into one MeshInstance3D ("Merged") per
## pivot node, with one surface per material:
##   - opaque palette materials that differ only in albedo (lit or unshaded) are
##     collapsed into one shared vertex-colour material (albedo baked into
##     COLOR, sRGB like the albedo uniform), so a whole proxy is ~1-3 surfaces;
##   - emissive, transparent, textured or vertex-coloured materials keep their
##     own surface (same shared material, same look).
## What stays a separate node (the contract animators, HeartVisual, GlowPulse,
## StageVariant and the dioramas rely on): every explicitly named node
## (Glow_*, Gem, Crack, Hat, Shaft, ...), every non-mesh node (lights,
## particles, labels), invisible parts, and pivot groups whose transform or
## visibility is changed at runtime ("Staff", "Head" on quadrupeds, "Glow*",
## "Variant_*", "Crack*", "Gem*"). Static named groups (Torso, Arm, Shield,
## Island_3, ...) stay in the tree as empty transforms; their parts are baked.
## Merged meshes are cached per slot + pivot path, so later builds of the same
## slot reuse them (only the node deletion runs). Real assets are never touched.

const MERGED_NAME := "Merged"
## Meta on a merged node: Array[AABB] of the baked parts, in that node's space.
const PART_BOUNDS_META := "lr_part_bounds"
## Name prefixes of groups that are moved, scaled or hidden at runtime.
const PIVOTS := ["Staff", "Glow", "Variant_", "Crack", "Gem", "Model"]

static var _mesh_cache: Dictionary = {}
static var _vc_cache: Dictionary = {}
static var _soup_cache: Dictionary = {}
## Off switch for A/B measurements (tools/profile) and as an emergency fallback.
static var enabled: bool = true


## Bounding boxes of the visible parts of a geometry node in its own space: the
## baked parts of a merged node, else its AABB (tests check layout per part).
static func part_bounds(n: VisualInstance3D) -> Array[AABB]:
	if n.has_meta(PART_BOUNDS_META):
		return n.get_meta(PART_BOUNDS_META) as Array[AABB]
	var out: Array[AABB] = [n.get_aabb()]
	return out


static func clear_cache() -> void:
	_mesh_cache.clear()
	_vc_cache.clear()
	_soup_cache.clear()


## Merges the static parts under `model` (the proxy's "Model" node).
## `cache_key` should identify the slot ("" = no caching). `head_pivot` keeps a
## "Head" group separate (the quadruped head dip); `extra_pivots` adds name
## prefixes of groups the caller changes at runtime. Returns the number of
## MeshInstance3D nodes removed.
static func merge(model: Node3D, cache_key: String = "", head_pivot: bool = false, extra_pivots: Array = []) -> int:
	if not enabled or model == null:
		return 0
	var pivots: Array = PIVOTS.duplicate()
	if head_pivot:
		pivots.append("Head")
	pivots.append_array(extra_pivots)
	# [pivot, cast_shadow] -> Array of [MeshInstance3D, Transform3D relative to pivot]
	var groups: Dictionary = {}
	var order: Array = []
	_collect(model, model, Transform3D.IDENTITY, pivots, groups, order)
	var removed := 0
	for gk: Array in order:
		var pivot := gk[0] as Node3D
		var shadow: int = gk[1]
		var parts: Array = groups[gk]
		if parts.size() < 2:
			continue
		var key := ""
		if not cache_key.is_empty():
			key = "%s|%s|%d|%d" % [cache_key, model.get_path_to(pivot), shadow, parts.size()]
		var mesh: ArrayMesh = _mesh_cache.get(key) as ArrayMesh if not key.is_empty() else null
		if mesh == null:
			mesh = _bake(parts)
			if mesh == null:
				continue
			if not key.is_empty():
				_mesh_cache[key] = mesh
		var mi := MeshInstance3D.new()
		mi.name = MERGED_NAME
		mi.mesh = mesh
		# Per-part bounds in the merged node's space (layout checks, tests).
		var boxes: Array[AABB] = []
		for p: Array in parts:
			boxes.append((p[1] as Transform3D) * (p[0] as MeshInstance3D).get_aabb())
		mi.set_meta(PART_BOUNDS_META, boxes)
		mi.cast_shadow = shadow as GeometryInstance3D.ShadowCastingSetting
		pivot.add_child(mi, true)
		pivot.move_child(mi, 0)
		for p: Array in parts:
			var n := p[0] as MeshInstance3D
			n.get_parent().remove_child(n)
			n.free()
			removed += 1
	return removed


static func _is_pivot(n: Node, pivots: Array) -> bool:
	var nm := String(n.name)
	for p: String in pivots:
		if nm.begins_with(p):
			return true
	return false


static func _collect(n: Node, pivot: Node3D, xf: Transform3D, pivots: Array, groups: Dictionary, order: Array) -> void:
	for c: Node in n.get_children():
		if not c is Node3D:
			continue
		var c3 := c as Node3D
		if c is MeshInstance3D and _mergeable(c as MeshInstance3D):
			var gk: Array = [pivot, int((c as MeshInstance3D).cast_shadow)]
			if not groups.has(gk):
				groups[gk] = []
				order.append(gk)
			(groups[gk] as Array).append([c, xf * c3.transform])
			continue
		# Scripted nodes and nested visuals (VisualSlots roots: already merged, animated) stay as they are.
		if c.get_script() != null or c.has_meta("slot_id"):
			continue
		var named := not String(c.name).begins_with("@")
		var own := c is GeometryInstance3D or _is_pivot(c, pivots) or (named and c.get_class() != "Node3D")
		# A hidden pivot (StageVariant's Variant_*, HeartVisual's cracks) merges inside
		# itself and keeps its visibility; a hidden plain group stays as it is.
		if not c3.visible and not own:
			continue
		if own:
			# Its own node; its unnamed descendants merge relative to it.
			_collect(c, c3, Transform3D.IDENTITY, pivots, groups, order)
		else:
			_collect(c, pivot, xf * c3.transform, pivots, groups, order)


## An unnamed, visible, childless, static part with plain geometry and one material.
static func _mergeable(mi: MeshInstance3D) -> bool:
	if not String(mi.name).begins_with("@") or not mi.visible or mi.get_child_count() > 0:
		return false
	if mi.mesh == null or mi.material_overlay != null or mi.transparency > 0.0 or mi.get_script() != null:
		return false
	if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return false
	var mat := mi.material_override as BaseMaterial3D
	if mat == null:
		return false
	if mi.mesh is ArrayMesh:
		for si: int in mi.mesh.get_surface_count():
			if (mi.mesh as ArrayMesh).surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
				return false
	elif not mi.mesh is PrimitiveMesh:
		return false
	return true


## Material + whether its albedo is baked into vertex colours.
static func _target(mat: BaseMaterial3D, mesh_has_color: bool) -> Array:
	var collapsible: bool = not mesh_has_color and mat is StandardMaterial3D \
		and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not mat.emission_enabled \
		and mat.albedo_texture == null and not mat.vertex_color_use_as_albedo and is_equal_approx(mat.albedo_color.a, 1.0) \
		and mat.blend_mode == BaseMaterial3D.BLEND_MODE_MIX and mat.next_pass == null \
		and mat.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED and not mat.use_point_size
	if not collapsible:
		return [mat, false]
	var sig := "%d|%d|%.3f|%.3f|%.3f|%s|%d|%d|%d|%s" % [mat.shading_mode, mat.specular_mode, mat.roughness, mat.metallic,
		mat.metallic_specular, mat.disable_fog, mat.cull_mode, mat.diffuse_mode, mat.depth_draw_mode, mat.no_depth_test]
	if not _vc_cache.has(sig):
		var vc := mat.duplicate() as StandardMaterial3D
		vc.albedo_color = Color.WHITE
		vc.vertex_color_use_as_albedo = true
		vc.vertex_color_is_srgb = true
		vc.resource_name = "lr_vertex_colour"
		_vc_cache[sig] = vc
	return [_vc_cache[sig], true]


## Triangle soup (de-indexed vertices, normals, colours) of one mesh surface.
## The proxy meshes are shared (ProxyMesh cache), so this is mostly a cache hit.
static func _soup(mesh: Mesh, si: int) -> Array:
	var k := "%d|%d" % [mesh.get_instance_id(), si]
	if _soup_cache.has(k):
		return _soup_cache[k]
	var arr: Array = mesh.surface_get_arrays(si)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if norms.size() != verts.size():
		norms = PackedVector3Array()
		norms.resize(verts.size())
		norms.fill(Vector3.UP)
	if cols.size() != verts.size():
		cols = PackedColorArray()
	if not idx.is_empty():
		var v2 := PackedVector3Array()
		var n2 := PackedVector3Array()
		var c2 := PackedColorArray()
		v2.resize(idx.size())
		n2.resize(idx.size())
		if not cols.is_empty():
			c2.resize(idx.size())
		for i: int in idx.size():
			v2[i] = verts[idx[i]]
			n2[i] = norms[idx[i]]
			if not cols.is_empty():
				c2[i] = cols[idx[i]]
		verts = v2
		norms = n2
		cols = c2
	var tri := verts.size() - verts.size() % 3
	verts.resize(tri)
	norms.resize(tri)
	if not cols.is_empty():
		cols.resize(tri)
	var out := [verts, norms, cols]
	_soup_cache[k] = out
	return out


static func _bake(parts: Array) -> ArrayMesh:
	# bucket key -> {m, v, n, c, vc, src_col}
	var buckets: Dictionary = {}
	var mats: Array = []
	for p: Array in parts:
		var mi := p[0] as MeshInstance3D
		var xf := p[1] as Transform3D
		var nb := xf.basis.inverse().transposed()
		var sc := xf.basis.get_scale()
		var uniform := is_equal_approx(sc.x, sc.y) and is_equal_approx(sc.y, sc.z) \
			and xf.basis.orthonormalized().is_equal_approx(Basis(xf.basis.x / sc.x, xf.basis.y / sc.y, xf.basis.z / sc.z))
		var flip := xf.basis.determinant() < 0.0
		var src_mat := mi.material_override as BaseMaterial3D
		var col := Color(src_mat.albedo_color.r, src_mat.albedo_color.g, src_mat.albedo_color.b, 1.0)
		for si: int in mi.mesh.get_surface_count():
			var soup := _soup(mi.mesh, si)
			var has_col := not (soup[2] as PackedColorArray).is_empty()
			var tgt := _target(src_mat, has_col)
			var m: Material = tgt[0]
			var bk := "%d|%s" % [m.get_instance_id(), has_col]
			if not buckets.has(bk):
				buckets[bk] = {"m": m, "v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "vc": tgt[1], "src_col": has_col}
				mats.append(bk)
			var b: Dictionary = buckets[bk]
			var tv: PackedVector3Array = xf * (soup[0] as PackedVector3Array)
			var tn: PackedVector3Array
			if uniform:
				# Rotation (+ uniform scale): normals stay unit length under the rotation.
				tn = Transform3D(xf.basis.orthonormalized(), Vector3.ZERO) * (soup[1] as PackedVector3Array)
			else:
				tn = Transform3D(nb, Vector3.ZERO) * (soup[1] as PackedVector3Array)
				for i: int in tn.size():
					tn[i] = tn[i].normalized()
			var tc: PackedColorArray = (soup[2] as PackedColorArray).duplicate()
			if b["vc"]:
				tc.resize(tv.size())
				tc.fill(col)
			if flip:
				# A mirrored part: keep the front faces facing out.
				for t: int in range(0, tv.size(), 3):
					var v1 := tv[t + 1]
					tv[t + 1] = tv[t + 2]
					tv[t + 2] = v1
					var n1 := tn[t + 1]
					tn[t + 1] = tn[t + 2]
					tn[t + 2] = n1
					if not tc.is_empty():
						var c1 := tc[t + 1]
						tc[t + 1] = tc[t + 2]
						tc[t + 2] = c1
			# Packed arrays are values: append to a local and store it back.
			var bv: PackedVector3Array = b["v"]
			var bn: PackedVector3Array = b["n"]
			var bc: PackedColorArray = b["c"]
			bv.append_array(tv)
			bn.append_array(tn)
			bc.append_array(tc)
			b["v"] = bv
			b["n"] = bn
			b["c"] = bc
	var out := ArrayMesh.new()
	for bk: String in mats:
		var b: Dictionary = buckets[bk]
		var m: Material = b["m"]
		if (b["v"] as PackedVector3Array).is_empty():
			continue
		var a: Array = []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = b["v"]
		a[Mesh.ARRAY_NORMAL] = b["n"]
		if b["vc"] or b["src_col"]:
			a[Mesh.ARRAY_COLOR] = b["c"]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		out.surface_set_material(out.get_surface_count() - 1, m)
	return out if out.get_surface_count() > 0 else null
