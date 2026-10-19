class_name TestVisualSlots
extends RefCounted
## Unit tests for the visual asset layer (VisualSlots, proxies, UnitAnimator contract,
## stage layout rules, vendor hints). Runner contract: every method named test_*
## takes no arguments and returns an Array of failure strings (empty = pass).
##   var t := TestVisualSlots.new()
##   for m in t.get_method_list(): if m.name.begins_with("test_"): var fails: Array = t.call(m.name)
## Standalone: godot --headless --path . --script res://tools/synty/run_visual_tests.gd
## Headless-safe: nothing here needs a running scene tree (timing of finished() is
## covered by tools/synty/selftest.sh in a live tree).

const UNITS := ["unit.B01", "unit.B02", "unit.B03", "unit.B04", "unit.B05", "unit.B06",
	"unit.S01", "unit.S02", "unit.S03", "unit.S04", "unit.S05", "unit.S06"]
const ENEMIES := ["enemy.E01", "enemy.E02", "enemy.E03", "enemy.E04", "enemy.E05", "enemy.E06"]
const STAGE := ["stage.floor_roots", "stage.floor_trunk", "stage.floor_crown", "stage.trunk", "stage.heart", "stage.backdrop"]
const PROPS := ["prop.lantern", "prop.mushroom_cluster", "prop.crystal", "prop.root_arch", "prop.rock"]
const MUTATIONS := ["mutation.M01", "mutation.M02", "mutation.M03", "mutation.M04"]
const FX := ["fx.poison", "fx.heal", "fx.armor", "fx.thorns", "fx.growth", "fx.spore_bolt", "fx.bark_hit", "fx.ash_death", "fx.heart_pulse", "fx.heart_damage", "fx.ring", "fx.floor_target"]
const STATES := ["idle", "summon", "attack", "cast", "hit", "death", "defend", "victory", "move"]


static func all_required() -> Array:
	return UNITS + ENEMIES + STAGE + PROPS + MUTATIONS + FX


func test_every_required_slot_exists() -> Array:
	var f: Array = []
	var ids := VisualSlots.slot_ids()
	for id: String in all_required():
		if not ids.has(id):
			f.append("missing slot " + id)
	return f


func test_make_never_null_and_sets_meta() -> Array:
	var f: Array = []
	for id: String in all_required():
		var v := VisualSlots.make(id)
		if v == null:
			f.append(id + ": make returned null")
			continue
		if str(v.get_meta("slot_id", "")) != id:
			f.append(id + ": meta slot_id wrong")
		if not v.has_meta("is_proxy"):
			f.append(id + ": meta is_proxy missing")
		if not VisualSlots.has_real_asset(id) and not bool(v.get_meta("is_proxy")):
			f.append(id + ": no asset mapped but is_proxy false")
		v.free()
	return f


func test_unknown_id_is_labelled_placeholder() -> Array:
	var v := VisualSlots.make("unit.NOPE")
	if v == null:
		return ["unknown id returned null"]
	var f: Array = []
	if v.find_children("*", "Label3D", true, false).is_empty():
		f.append("unknown id placeholder has no label")
	if not bool(v.get_meta("is_proxy", false)):
		f.append("unknown id placeholder must be a proxy")
	v.free()
	return f


func test_units_and_enemies_carry_unit_animator() -> Array:
	var f: Array = []
	for id: String in UNITS + ENEMIES + ["stage.heart"]:
		var v := VisualSlots.make(id)
		var an := v.get_node_or_null("UnitAnimator")
		if not an is UnitAnimator:
			f.append(id + ": no child UnitAnimator")
		elif v.get_meta("is_proxy", true):
			(an as UnitAnimator)._bind()
			for st: String in STATES:
				if not (an as UnitAnimator).has_clip(StringName(st)):
					f.append("%s: proxy has no procedural %s" % [id, st])
		v.free()
	return f


func test_required_animation_states_declared() -> Array:
	var f: Array = []
	for id: String in UNITS + ENEMIES:
		var st: Array = VisualSlots.slot(id).get("animation_states", []) as Array
		for need: String in ["idle", "attack", "hit", "death"]:
			if id == "unit.S03" and need == "attack":
				continue
			if not need in st:
				f.append("%s: animation_states lacks %s" % [id, need])
		if str(VisualSlots.slot(id).get("rig_family", "")).is_empty():
			f.append(id + ": no rig_family")
	if str(VisualSlots.slot("unit.B04").get("rig_family", "")) != "quadruped":
		f.append("Thornhart must be a quadruped rig family")
	return f


func test_contact_times_default() -> Array:
	var an := UnitAnimator.new()
	var f: Array = []
	if absf(an.contact_time(&"attack") - 0.3) > 0.05:
		f.append("attack contact not ~0.3 s")
	if an.contact_time(&"cast") <= 0.2 or an.contact_time(&"cast") > 0.5:
		f.append("cast contact not ~0.3-0.4 s")
	if an.contact_time(&"idle") != 0.0:
		f.append("idle must have no contact")
	an.free()
	return f


func test_feet_origin_and_facing() -> Array:
	var f: Array = []
	for id: String in UNITS + ENEMIES:
		var v := VisualSlots.make(id)
		var b := VisualSlots.bounds(v)
		if absf(b.position.y) > 0.15:
			f.append("%s: feet at y=%.2f" % [id, b.position.y])
		var c := b.get_center()
		if absf(c.x) > 0.45 or absf(c.z) > 0.6:
			f.append("%s: not centred on the origin (%.2f, %.2f)" % [id, c.x, c.z])
		var facing := RigLab.facing_of(v)
		if facing != "-Z":
			f.append("%s: facing %s, expected -Z" % [id, facing])
		v.free()
	return f


func test_head_height_clears_model() -> Array:
	var f: Array = []
	for id: String in UNITS + ENEMIES:
		var v := VisualSlots.make(id)
		var top := VisualSlots.bounds(v).end.y
		var hh := VisualSlots.head_height(id)
		if hh < top - 0.05:
			f.append("%s: badge %.2f below model top %.2f" % [id, hh, top])
		if hh > top + 0.6:
			f.append("%s: badge %.2f floats far above top %.2f" % [id, hh, top])
		v.free()
	return f


func test_size_language() -> Array:
	var f: Array = []
	var h := {}
	for id: String in UNITS + ENEMIES:
		var v := VisualSlots.make(id)
		h[id] = VisualSlots.bounds(v).end.y
		v.free()
	for id: String in UNITS:
		var sp := int(VisualSlots.slot(id).get("space", 1))
		if sp == 1 and float(h[id]) > 1.45:
			f.append("%s: 1-space unit too tall (%.2f)" % [id, h[id]])
		if sp == 3 and float(h[id]) < 2.2:
			f.append("%s: 3-space unit too small (%.2f)" % [id, h[id]])
	if float(h["unit.S01"]) >= float(h["unit.B01"]):
		f.append("Spore Sage must be smaller than the Barkwarden")
	if float(h["enemy.E06"]) < 3.0:
		f.append("boss under 3 m")
	for id: String in ENEMIES:
		if id != "enemy.E01" and float(h[id]) <= float(h["enemy.E01"]):
			f.append("Ashling must be the smallest enemy (vs %s)" % id)
	return f


## Floors: play area (x -5.5..5.5, front part of the depth) is flat at y<=0.02;
## props only on the back edge.
func test_floor_play_area_free() -> Array:
	var f: Array = []
	for id: String in ["stage.floor_roots", "stage.floor_trunk", "stage.floor_crown"]:
		var v := VisualSlots.make(id)
		var play := AABB(Vector3(-5.5, 0.02, -0.9), Vector3(11.0, 6.0, 2.5))
		for n: Node in v.find_children("*", "VisualInstance3D", true, false):
			var b := RigLab._xf_to(v, n as Node3D) * (n as VisualInstance3D).get_aabb()
			if b.intersects(play):
				f.append("%s: %s rises into the play area (top %.2f at z %.2f)" % [id, n.name, b.end.y, b.get_center().z])
				break
		v.free()
	return f


func test_trunk_and_backdrop_stay_behind() -> Array:
	var f: Array = []
	var t := VisualSlots.make("stage.trunk")
	# Everything at unit height (local y < 3.2) stays behind the units (z < -1.2);
	# only the crown variant's branches above head height may reach further forward.
	for n: Node in t.find_children("*", "VisualInstance3D", true, false):
		var b := RigLab._xf_to(t, n as Node3D) * (n as VisualInstance3D).get_aabb()
		if b.get_center().y < 3.0 and b.end.z > -1.2:
			f.append("trunk part %s at unit height reaches z=%.2f (must be < -1.2)" % [n.name, b.end.z])
			break
	for k: String in ["roots", "trunk", "crown"]:
		StageVariant.apply(t, k)
		var vis := 0
		for g: Node in t.find_children("Variant_*", "Node3D", true, false):
			vis += 1 if (g as Node3D).visible else 0
		if vis != 1 or str(t.get_meta("variant", "")) != k:
			f.append("trunk variant %s not exclusive" % k)
	if t.get_node_or_null("StageVariant") == null:
		f.append("trunk proxy lacks the StageVariant node")
	StageVariant.apply(t, "trunk")
	var tb := VisualSlots.bounds(t.get_node("Model").get_node("Variant_trunk"))
	if absf(tb.get_center().x) > 0.3:
		f.append("trunk not centred on x=0")
	if absf(tb.size.y - 4.5) > 0.6:
		f.append("trunk segment height %.2f, expected ~4.5 (tiles per floor)" % tb.size.y)
	t.free()
	var b := VisualSlots.make("stage.backdrop")
	var bb := VisualSlots.bounds(b)
	if bb.end.z > -15.0:
		f.append("backdrop reaches z=%.2f (must stay < -15)" % bb.end.z)
	b.free()
	var h := VisualSlots.make("stage.heart")
	var hb := VisualSlots.bounds(h)
	if hb.size.y < 1.4 or hb.size.y > 2.6:
		f.append("heart height %.2f, expected ~1.6-2.2" % hb.size.y)
	h.free()
	return f


func test_visual_only_no_physics() -> Array:
	var f: Array = []
	for id: String in all_required():
		var v := VisualSlots.make(id)
		if not v.find_children("*", "CollisionObject3D", true, false).is_empty():
			f.append(id + ": contains physics bodies")
		v.free()
	return f


func test_fx_metadata() -> Array:
	var f: Array = []
	for id: String in FX:
		var v := VisualSlots.make(id)
		var one := bool(v.get_meta("one_shot", false))
		if one != bool(VisualSlots.slot(id).get("one_shot", false)):
			f.append(id + ": one_shot meta disagrees with asset_slots.json")
		if one and float(v.get_meta("lifetime_s", 0.0)) <= 0.0:
			f.append(id + ": one-shot without lifetime")
		if v.find_children("*", "GPUParticles3D", true, false).size() > 0:
			f.append(id + ": uses GPUParticles3D (CPUParticles3D preferred for web/compat)")
		v.free()
	return f


func test_vendor_suggestions_cover_every_slot() -> Array:
	var f: Array = []
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/vendor_suggestions.json"))
	if not v is Dictionary:
		return ["vendor_suggestions.json unreadable"]
	var slots: Dictionary = (v as Dictionary).get("slots", {})
	for id: String in all_required():
		var e: Dictionary = slots.get(id, {})
		if e.is_empty():
			f.append(id + ": no vendor suggestion")
			continue
		if bool(e.get("verified", true)) or not "unverified" in str(e.get("status", "")):
			f.append(id + ": must be marked unverified")
		if (e.get("packs", []) as Array).is_empty():
			f.append(id + ": no pack named")
		var fam := str(VisualSlots.slot(id).get("rig_family", ""))
		if fam == "humanoid":
			var mix: Dictionary = e.get("mixamo", {})
			for st: Variant in VisualSlots.slot(id).get("animation_states", []) as Array:
				if (mix.get(str(st), []) as Array).is_empty():
					f.append("%s: no Mixamo hint for %s" % [id, st])
		elif fam == "quadruped" and (e.get("clips", {}) as Dictionary).is_empty():
			f.append(id + ": quadruped without own-clip hints")
	return f


## Mutations are visual only and never enter the unit play area of their floor.
func test_mutations_keep_play_area_free() -> Array:
	var f: Array = []
	var play := AABB(Vector3(-5.5, 0.02, -0.9), Vector3(11.0, 2.8, 2.5))
	for id: String in ["mutation.M01", "mutation.M02", "mutation.M03"]:
		var v := VisualSlots.make(id)
		if VisualSlots.bounds(v).size == Vector3.ZERO:
			f.append(id + ": nothing visible")
		for n: Node in v.find_children("*", "VisualInstance3D", true, false):
			if n is CPUParticles3D:
				continue
			var b := RigLab._xf_to(v, n as Node3D) * (n as VisualInstance3D).get_aabb()
			if b.intersects(play):
				f.append("%s: %s enters the play area (y %.2f..%.2f, z %.2f..%.2f)" % [id, n.name, b.position.y, b.end.y, b.position.z, b.end.z])
				break
		if v.get_node_or_null("GlowPulse") == null:
			f.append(id + ": no GlowPulse idle life")
		v.free()
	return f


func test_target_markers_switch_kinds() -> Array:
	var f: Array = []
	for id: String in ["fx.ring", "fx.floor_target"]:
		var m := VisualSlots.make(id) as TargetMarker
		if m == null:
			f.append(id + ": not a TargetMarker")
			continue
		if m.visible:
			f.append(id + ": must start hidden (kind none)")
		var kinds: Array = [&"target", &"selected"] + ([&"invalid", &"danger"] if id == "fx.ring" else [])
		for k: StringName in kinds:
			m.set_kind(k)
			if not m.visible or m.kind != k:
				f.append("%s: set_kind(%s) did not show it" % [id, k])
		m.set_kind(&"bogus")
		if m.visible or m.kind != &"none":
			f.append(id + ": unknown kind must hide the marker")
		m.set_kind(&"none")
		if m.visible:
			f.append(id + ": kind none must hide")
		if not m.find_children("*", "CollisionObject3D", true, false).is_empty() or not m.find_children("*", "Light3D", true, false).is_empty():
			f.append(id + ": must not have physics bodies or lights")
		m.free()
	var r := VisualSlots.make("fx.ring") as TargetMarker
	r.set_radius(1.2)
	r.set_kind(&"selected")
	var b := VisualSlots.bounds(r)
	if absf(b.size.x - 2.4) > 0.05:
		f.append("ring radius 1.2 gives width %.2f, expected 2.4" % b.size.x)
	if b.end.y > 0.25 or b.position.y < -0.01:
		f.append("ring must lie on the ground (y %.2f..%.2f)" % [b.position.y, b.end.y])
	r.free()
	var s := VisualSlots.make("fx.floor_target") as TargetMarker
	s.set_kind(&"target")
	var sb := VisualSlots.bounds(s)
	if absf(sb.position.x + 5.6) > 0.05 or absf(sb.end.x - 5.6) > 0.05:
		f.append("floor strip must span x -5.6..5.6 (got %.2f..%.2f)" % [sb.position.x, sb.end.x])
	s.free()
	return f


func test_footprint_radius_and_side() -> Array:
	var f: Array = []
	for id: String in UNITS + ENEMIES:
		var r := VisualSlots.footprint_radius(id)
		if r < 0.35 or r > 1.7:
			f.append("%s: footprint radius %.2f out of range" % [id, r])
	if VisualSlots.footprint_radius("enemy.E06") <= VisualSlots.footprint_radius("enemy.E01"):
		f.append("boss ring must be larger than Ashling's")
	for pair: Array in [["unit.B01", &"ally"], ["enemy.E03", &"enemy"]]:
		var v := VisualSlots.make(str(pair[0]))
		VisualSlots.apply_side(v, pair[1])
		if v.get_node_or_null("SideDisc") == null:
			f.append("%s: no SideDisc" % pair[0])
		var mesh := v.get_node("Model").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		if mesh.material_overlay == null:
			f.append("%s: no rim overlay" % pair[0])
		var an := v.get_node("UnitAnimator") as UnitAnimator
		if an.base_overlay != mesh.material_overlay:
			f.append("%s: animator would not restore the rim after a flash" % pair[0])
		if not v.find_children("*", "CollisionObject3D", true, false).is_empty():
			f.append("%s: side decoration added physics" % pair[0])
		v.free()
	return f


## Meta-screen dioramas: build headless, expose their API, stay web-cheap.
func test_dioramas_api_and_budget() -> Array:
	var f: Array = []
	for path: String in ["res://scenes/art/route_diorama.tscn", "res://scenes/art/menu_diorama.tscn", "res://scenes/art/epilog_diorama.tscn"]:
		var ps := load(path) as PackedScene
		if ps == null:
			f.append(path + ": missing")
			continue
		var d := ps.instantiate()
		d.call("_ready")
		var api: Array = ["set_portrait"] + (["set_progress", "focus"] if "route" in path else (["set_run"] if "epilog" in path else ["set_champion"]))
		for m: String in api:
			if not d.has_method(m):
				f.append("%s: no %s()" % [path, m])
		if "route" in path:
			d.call("set_progress", 3, [Vector2i(1, 1), {"col": 3, "lane": -1}])
			d.call("focus", 2)
		elif "epilog" in path:
			# Worst case for the light budget: all mutations (M04 brings its own light).
			d.call("set_run", ["M01", "M02", "M03", "M04"], "SPORE", "LIFEWEAVER", "won")
			if d.find_children("Aura", "MeshInstance3D", true, false).is_empty():
				f.append("epilog won: no champion aura")
			if d.find_children("*", "", true, false).filter(func(n: Node) -> bool: return str(n.get_meta("slot_id", "")) == "unit.S01").is_empty():
				f.append("epilog won SPORE: Spore Sage missing on the Crown")
			_check_lights(d, path + " (won)", f)
			d.call("set_run", [], "BARK", "BULWARK", "lost")
			if d.find_children("Cracks", "Node3D", true, false).is_empty():
				f.append("epilog lost: heart not cracked")
			if d.find_children("*", "", true, false).filter(func(n: Node) -> bool: return str(n.get_meta("slot_id", "")) == "enemy.E06").is_empty():
				f.append("epilog lost: no Ash Crown on the Crown")
		else:
			d.call("set_champion", "SPORE")
			d.call("set_champion", "")
		d.call("set_portrait", true)
		d.call("set_portrait", false)
		_check_lights(d, path, f)
		if not d.find_children("*", "GPUParticles3D", true, false).is_empty():
			f.append(path + ": uses GPUParticles3D")
		if not d.find_children("*", "CollisionObject3D", true, false).is_empty():
			f.append(path + ": has physics bodies")
		d.free()
	return f


func _check_lights(d: Node, label: String, f: Array) -> void:
	var lights := d.find_children("*", "Light3D", true, false)
	if lights.size() > 3:
		f.append("%s: %d lights (max 3)" % [label, lights.size()])
	for l: Node in lights:
		if (l as Light3D).shadow_enabled:
			f.append("%s: %s casts shadows" % [label, l.name])
