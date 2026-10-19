class_name MessageDialog
extends MetaModal
## Small confirm / info dialog. `actions` = [[label, accent, callable], ...];
## each action closes the dialog first, then runs its callable.

var message: String = ""
var actions: Array = []


func _init() -> void:
	super()
	max_size = Vector2(680, 420)


func show_message(p_title: String, p_message: String, p_actions: Array = []) -> void:
	title_text = p_title
	message = p_message
	actions = p_actions
	open()


func _build() -> void:
	body.add_child(UiKit.label(message, 20, UiKit.TEXT))
	for a: Array in actions:
		var b := UiKit.button(str(a[0]), a[1])
		var cb: Callable = a[2]
		b.pressed.connect(func() -> void:
			AudioService.play("ui_confirm")
			visible = false
			closed.emit()
			cb.call())
		footer.add_child(b)


func initial_focus() -> Control:
	if footer and footer.get_child_count() > 0:
		return footer.get_child(footer.get_child_count() - 1) as Control
	return close_button


func _layout() -> void:
	max_size.y = 380.0 if not is_portrait() else 520.0
	super()
