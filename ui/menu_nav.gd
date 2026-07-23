extends Node
## Reusable menu navigation. Add as a child of the node whose button descendants
## make up a menu (or point `buttons_root` at that node). The *focused* button is
## the on-screen cursor: WASD (the move_* actions) moves it to the nearest button
## in that direction, moving the mouse over a button moves the cursor there, and
## the built-in ui_accept (Space/Enter) or a mouse click presses it. "Back" (ESC)
## is left to the owning menu, which is the only thing that knows where back goes.

## Node whose descendant buttons form the menu. Defaults to this node's parent.
@export var buttons_root: Node


func _ready() -> void:
	# Deferred so it runs after sibling scripts finish their own _ready -- the
	# level select disables locked buttons in its _ready, and we must see the
	# final disabled state before deciding what the cursor can land on.
	_setup.call_deferred()


func _setup() -> void:
	var first: BaseButton = null
	for button in _buttons(buttons_root if buttons_root else get_parent()):
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE  # locked: never a cursor target
			continue
		button.focus_mode = Control.FOCUS_ALL
		if not button.mouse_entered.is_connected(button.grab_focus):
			button.mouse_entered.connect(button.grab_focus)  # hover moves the cursor
		if first == null:
			first = button
	if first:
		first.grab_focus()


## Every BaseButton under `root`, depth-first in tree order.
func _buttons(root: Node) -> Array:
	var result: Array = []
	for child in root.get_children():
		if child is BaseButton:
			result.append(child)
		result.append_array(_buttons(child))
	return result


func _unhandled_input(event: InputEvent) -> void:
	var side := _direction_side(event)
	if side < 0:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	var neighbor := focused.find_valid_focus_neighbor(side)
	if neighbor:
		neighbor.grab_focus()
		get_viewport().set_input_as_handled()


## Maps a pressed WASD move_* action to the Side to seek a neighbour on, else -1.
func _direction_side(event: InputEvent) -> int:
	if event.is_action_pressed("move_up"):
		return SIDE_TOP
	if event.is_action_pressed("move_down"):
		return SIDE_BOTTOM
	if event.is_action_pressed("move_left"):
		return SIDE_LEFT
	if event.is_action_pressed("move_right"):
		return SIDE_RIGHT
	return -1
