extends Node
## Entry scene. Parses debug arguments (DebugCapture) or opens the main menu.


func _ready() -> void:
	AppFlow.goto("menu")
