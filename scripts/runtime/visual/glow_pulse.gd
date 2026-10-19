class_name GlowPulse
extends Node
## Idle life for stage pieces, props and mutations: every small "Glow_*" node
## (mushroom dots, crystals, lanterns, veins, blossoms) under the parent breathes
## slowly with its own phase. Purely visual, a few cheap tweens (web-friendly).
## Reduced motion: no pulsing (static glow).

const NAMES := ["Glow_Dot", "Glow_Crystal", "Glow_Lantern", "Glow_Blossom", "Glow_Vein", "Glow_Band", "Glow_Window", "Glow_Spore", "Glow_Gill", "Glow_RootTip"]
const MAX_NODES := 40

var amount: float = 0.14
var period: float = 2.6


func _ready() -> void:
	if UnitAnimator.motion_reduced():
		return
	var parent := get_parent()
	if parent == null:
		return
	var found: Array[Node3D] = []
	for n: Node in parent.find_children("Glow_*", "Node3D", true, false):
		var base := String(n.name).rstrip("0123456789@").trim_suffix("_")
		for k: String in NAMES:
			if base.begins_with(k):
				found.append(n as Node3D)
				break
		if found.size() >= MAX_NODES:
			break
	var i := 0
	for g: Node3D in found:
		var s0 := g.scale
		var t := create_tween().set_loops()
		var p := period * (0.8 + 0.4 * fposmod(float(i) * 0.618, 1.0))
		t.tween_interval(fposmod(float(i) * 0.37, 1.0) * p * 0.5)
		t.tween_property(g, "scale", s0 * (1.0 + amount), p * 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(g, "scale", s0, p * 0.5).set_trans(Tween.TRANS_SINE)
		i += 1
