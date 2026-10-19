class_name FactionPortrait
extends Control
## Code-drawn portrait placeholder for a champion (REF_02 silhouettes): the
## Barkwarden as a broad bark golem with amber eyes, the Spore Sage as a
## hooded mushroom mystic with a glowing staff. Replaced by 3D renders later.

var faction: String = "BARK"
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220, 200)


func _process(delta: float) -> void:
	if SettingsService.reduced_motion:
		return
	_t += delta * SettingsService.anim_speed
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var fc: Color = UiKit.faction_color(faction)
	# Frame glow.
	var bg := StyleBoxFlat.new()
	bg.bg_color = UiKit.BG.lerp(fc, 0.08)
	bg.set_corner_radius_all(14)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var c := Vector2(w * 0.5, h * 0.58)
	for i in 6:
		draw_circle(c, h * (0.48 - float(i) * 0.06), Color(fc, 0.04 + 0.01 * float(i)))
	# Ground terrace.
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.12, h * 0.9), Vector2(w * 0.88, h * 0.9), Vector2(w * 0.78, h * 0.97),
		Vector2(w * 0.22, h * 0.97)]), Color("2a2030"))
	draw_rect(Rect2(w * 0.12, h * 0.885, w * 0.76, h * 0.02), Color("3b4a2a") if faction == "BARK" else Color("3a2a52"))
	var s: float = h * 0.8
	var bob: float = sin(_t * 1.6) * s * 0.01
	if faction == "BARK":
		_barkwarden(Vector2(w * 0.5, h * 0.89 + bob), s)
	else:
		_spore_sage(Vector2(w * 0.5, h * 0.89 + bob), s)


func _poly(o: Vector2, s: float, pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(o + p * s)
	draw_colored_polygon(out, col)


func _barkwarden(feet: Vector2, s: float) -> void:
	var bark := Color("6b4a2e")
	var dark := Color("4a321f")
	var moss := Color("5d7a34")
	# Legs.
	_poly(feet, s, [Vector2(-0.2, 0), Vector2(-0.06, 0), Vector2(-0.07, -0.22), Vector2(-0.19, -0.22)], dark)
	_poly(feet, s, [Vector2(0.06, 0), Vector2(0.2, 0), Vector2(0.19, -0.22), Vector2(0.07, -0.22)], dark)
	# Body.
	_poly(feet, s, [Vector2(-0.26, -0.2), Vector2(0.26, -0.2), Vector2(0.3, -0.55), Vector2(0.18, -0.68), Vector2(-0.18, -0.68),
		Vector2(-0.3, -0.55)], bark)
	# Arms.
	_poly(feet, s, [Vector2(-0.3, -0.62), Vector2(-0.42, -0.5), Vector2(-0.4, -0.24), Vector2(-0.3, -0.26), Vector2(-0.28, -0.48)], dark)
	_poly(feet, s, [Vector2(0.3, -0.62), Vector2(0.42, -0.5), Vector2(0.4, -0.24), Vector2(0.3, -0.26), Vector2(0.28, -0.48)], dark)
	# Bark grain.
	for dx: float in [-0.12, 0.0, 0.12]:
		draw_line(feet + Vector2(dx, -0.24) * s, feet + Vector2(dx * 1.1, -0.6) * s, dark, s * 0.012, true)
	# Head with moss crown.
	_poly(feet, s, [Vector2(-0.13, -0.66), Vector2(0.13, -0.66), Vector2(0.12, -0.84), Vector2(-0.12, -0.84)], bark)
	_poly(feet, s, [Vector2(-0.17, -0.82), Vector2(0.17, -0.82), Vector2(0.1, -0.95), Vector2(-0.02, -0.9), Vector2(-0.1, -0.96)], moss)
	var glow: float = 0.75 + 0.25 * sin(_t * 2.0)
	draw_circle(feet + Vector2(-0.05, -0.75) * s, s * 0.022, Color(UiKit.AMBER, glow))
	draw_circle(feet + Vector2(0.05, -0.75) * s, s * 0.022, Color(UiKit.AMBER, glow))
	# Shield of armor plates.
	_poly(feet, s, [Vector2(-0.1, -0.5), Vector2(0.1, -0.5), Vector2(0.1, -0.36), Vector2(0.0, -0.28), Vector2(-0.1, -0.36)], Color(UiKit.ARMOR, 0.55))


func _spore_sage(feet: Vector2, s: float) -> void:
	var robe := Color("4a3570")
	var dark := Color("2e2147")
	var cap := UiKit.SPORE
	# Robe.
	_poly(feet, s, [Vector2(-0.22, 0), Vector2(0.22, 0), Vector2(0.12, -0.5), Vector2(-0.12, -0.5)], robe)
	_poly(feet, s, [Vector2(-0.05, 0), Vector2(0.05, 0), Vector2(0.03, -0.45), Vector2(-0.03, -0.45)], dark)
	# Staff.
	draw_line(feet + Vector2(0.28, 0.0) * s, feet + Vector2(0.24, -0.82) * s, Color("6b4a2e"), s * 0.02, true)
	var glow: float = 0.6 + 0.4 * sin(_t * 2.4)
	for i in 4:
		draw_circle(feet + Vector2(0.24, -0.85) * s, s * (0.07 - 0.015 * float(i)), Color(UiKit.LIFE, 0.15 + 0.2 * float(i) * glow))
	# Face shadow and eyes.
	_poly(feet, s, [Vector2(-0.1, -0.48), Vector2(0.1, -0.48), Vector2(0.08, -0.62), Vector2(-0.08, -0.62)], dark)
	draw_circle(feet + Vector2(-0.04, -0.56) * s, s * 0.016, Color(1, 1, 1, 0.9))
	draw_circle(feet + Vector2(0.04, -0.56) * s, s * 0.016, Color(1, 1, 1, 0.9))
	# Mushroom cap with spots.
	var cap_pts: Array = []
	for i in 17:
		var a: float = PI + PI * float(i) / 16.0
		cap_pts.append(Vector2(cos(a) * 0.3, -0.6 + sin(a) * 0.24))
	_poly(feet, s, cap_pts, cap)
	for sp: Vector2 in [Vector2(-0.14, -0.7), Vector2(0.02, -0.78), Vector2(0.16, -0.68)]:
		draw_circle(feet + sp * s, s * 0.03, Color(1, 1, 1, 0.75))
	# Floating spores.
	for i in 5:
		var a: float = _t * 0.7 + float(i) * 1.3
		draw_circle(feet + Vector2(cos(a) * 0.38, -0.4 + sin(a * 1.3) * 0.25) * s, s * 0.012, Color(UiKit.SPORE, 0.7))
