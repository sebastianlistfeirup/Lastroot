class_name StageVariant
extends Node
## Floor-aware look for a piece the battle scene instances once per floor (the
## trunk segment): shows the child group "Variant_roots", "Variant_trunk" or
## "Variant_crown" under Model depending on the world height it ends up at
## (floors at y 0 / 4.5 / 9). Outside a tree, or with `force` set, the given
## variant is used. Visual only; anchors never change.

@export var force: String = ""


func _ready() -> void:
	var root := get_parent() as Node3D
	if root == null:
		return
	var k := force
	if k.is_empty():
		var y := root.global_position.y if root.is_inside_tree() else root.position.y
		k = "roots" if y < 2.0 else ("trunk" if y < 6.5 else "crown")
	apply(root, k)


static func apply(root: Node3D, k: String) -> void:
	for n: Node in root.find_children("Variant_*", "Node3D", true, false):
		(n as Node3D).visible = String(n.name) == "Variant_" + k
	root.set_meta("variant", k)
