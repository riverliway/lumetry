extends Node
## Reusable menu navigation. Add as a child of the node whose button descendants
## make up a menu (or point `buttons_root` at that node). The *focused* button is
## the on-screen cursor: WASD (the move_* actions) moves it to the nearest button
## in that direction, moving the mouse over a button moves the cursor there, and
## the built-in ui_accept (Space/Enter) or a mouse click presses it.
##
## Navigation is scoped to this node's own buttons, so several menus can coexist
## (e.g. a confirm dialog opened over a menu) -- each MenuNav only reacts when the
## cursor is on one of its own buttons. "Back" (ESC) is left to the owning menu.

## Node whose descendant buttons form the menu. Defaults to this node's parent.
@export var buttons_root: Node

var _targets: Array[BaseButton] = []


func _ready() -> void:
	# Deferred so it runs after sibling scripts finish their own _ready -- the
	# level select disables locked buttons in its _ready, and we must see the
	# final disabled state before deciding what the cursor can land on.
	_setup.call_deferred()


func _setup() -> void:
	var root: Node = buttons_root if buttons_root else get_parent()
	_targets.clear()
	for button in _buttons(root):
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE  # locked: never a cursor target
			continue
		button.focus_mode = Control.FOCUS_ALL
		if not button.mouse_entered.is_connected(button.grab_focus):
			button.mouse_entered.connect(button.grab_focus)  # hover moves the cursor
		_targets.append(button)
	# Auto-place the cursor only if the menu is actually on screen; a menu that
	# starts hidden (a dialog) grabs focus itself when it opens.
	if root is CanvasItem and root.is_visible_in_tree():
		focus_first()


## Puts the cursor on the first enabled button, if any.
func focus_first() -> void:
	if not _targets.is_empty():
		_targets[0].grab_focus()


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
	if focused == null or not _targets.has(focused):
		return  # not our cursor -- let whoever owns it navigate
	var neighbor := _nearest(focused, side)
	if neighbor:
		neighbor.grab_focus()
		get_viewport().set_input_as_handled()


## The nearest enabled button to `from` in the given direction, among our own.
func _nearest(from: Control, side: int) -> BaseButton:
	var origin := from.get_global_rect().get_center()
	var best: BaseButton = null
	var best_score := INF
	for button in _targets:
		if button == from:
			continue
		var delta := button.get_global_rect().get_center() - origin
		var along := 0.0
		var off := 0.0
		match side:
			SIDE_TOP:
				along = -delta.y
				off = absf(delta.x)
			SIDE_BOTTOM:
				along = delta.y
				off = absf(delta.x)
			SIDE_LEFT:
				along = -delta.x
				off = absf(delta.y)
			SIDE_RIGHT:
				along = delta.x
				off = absf(delta.y)
		if along <= 0.0:
			continue  # not in this direction
		var score := along + off * 2.0  # prefer aligned, then closest
		if score < best_score:
			best_score = score
			best = button
	return best


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
