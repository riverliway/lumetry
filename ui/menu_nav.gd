extends Node
## Reusable menu navigation. Add as a child of the node whose focusable descendants
## make up a menu (or point `buttons_root` at that node). The *focused* control is
## the on-screen cursor: WASD (the move_* actions) moves it to the nearest control
## in that direction, moving the mouse over one moves the cursor there, and the
## built-in ui_accept (Space/Enter) or a mouse click presses it.
##
## Buttons and sliders (Range) are both cursor targets. When the cursor is on a
## slider, left/right adjust its value by one step instead of jumping away; up/down
## still move to the neighbouring row. So an options screen mixing sliders and
## buttons navigates with the same WASD as any other menu.
##
## Navigation is scoped to this node's own controls, so several menus can coexist
## (e.g. a confirm dialog opened over a menu) -- each MenuNav only reacts when the
## cursor is on one of its own targets. "Back" (ESC) is left to the owning menu.

## Node whose descendant controls form the menu. Defaults to this node's parent.
@export var buttons_root: Node

var _targets: Array[Control] = []


func _ready() -> void:
	# Deferred so it runs after sibling scripts finish their own _ready -- the
	# level select disables locked buttons in its _ready, and we must see the
	# final disabled state before deciding what the cursor can land on.
	_setup.call_deferred()


func _setup() -> void:
	var root: Node = buttons_root if buttons_root else get_parent()
	_targets.clear()
	for control in _focusables(root):
		if control is BaseButton and control.disabled:
			control.focus_mode = Control.FOCUS_NONE  # locked: never a cursor target
			continue
		control.focus_mode = Control.FOCUS_ALL
		if not control.mouse_entered.is_connected(control.grab_focus):
			control.mouse_entered.connect(control.grab_focus)  # hover moves the cursor
		_targets.append(control)
	# Auto-place the cursor only if the menu is actually on screen; a menu that
	# starts hidden (a dialog) grabs focus itself when it opens.
	if root is CanvasItem and root.is_visible_in_tree():
		focus_first()


## Puts the cursor on the first enabled target, if any.
func focus_first() -> void:
	if not _targets.is_empty():
		_targets[0].grab_focus()


## Every focusable target (BaseButton or slider) under `root`, depth-first.
func _focusables(root: Node) -> Array:
	var result: Array = []
	for child in root.get_children():
		if child is BaseButton or child is Range:
			result.append(child)
		result.append_array(_focusables(child))
	return result


func _unhandled_input(event: InputEvent) -> void:
	var side := _direction_side(event)
	if side < 0:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not _targets.has(focused):
		return  # not our cursor -- let whoever owns it navigate
	# On a slider, left/right change the value rather than leaving the control.
	if focused is Range and (side == SIDE_LEFT or side == SIDE_RIGHT):
		var step: float = focused.step if focused.step > 0.0 else 1.0
		focused.value += step if side == SIDE_RIGHT else -step
		get_viewport().set_input_as_handled()
		return
	var neighbor := _nearest(focused, side)
	if neighbor:
		neighbor.grab_focus()
		get_viewport().set_input_as_handled()


## The nearest enabled target to `from` in the given direction, among our own.
func _nearest(from: Control, side: int) -> Control:
	var origin := from.get_global_rect().get_center()
	var best: Control = null
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
