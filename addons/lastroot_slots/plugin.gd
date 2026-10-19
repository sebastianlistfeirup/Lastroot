@tool
extends EditorPlugin
## Adds the Asset-slots dock (right side). Editor-only; the game never loads it.
## Enable in Project > Project Settings > Plugins, or add to project.godot:
##   [editor_plugins]
##   enabled=PackedStringArray("res://addons/lastroot_slots/plugin.cfg")

var dock: Control


func _enter_tree() -> void:
	dock = preload("res://addons/lastroot_slots/slot_dock.gd").new()
	dock.name = "Asset-slots"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
