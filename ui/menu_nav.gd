extends Node
## Reusable menu navigation. Add as a child of the node whose focusable descendants
## make up a menu (or point `buttons_root` at that node). The *focused* control is
## the on-screen cursor: WASD (the move_* actions) or a controller (the D-pad, via
## the same move_* actions, and the left stick) moves it to the nearest control in
## that direction, moving the mouse over one moves the cursor there, and the
## built-in ui_accept (Space / Enter / controller A) or a mouse click presses it.
##
## Digital inputs (keyboard, D-pad) navigate on their press event; the analog left
## stick is polled with edge detection, so one push moves the cursor once -- like a
## WASD tap -- rather than scrolling while it is held.
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

## Left-stick push past this fraction counts as a menu direction. Fixed (not the
## gameplay joystick_deadzone) -- menu nav wants a firm, deliberate flick.
const _STICK_DEADZONE := 0.5

var _targets: Array[Control] = []

## The side the left stick currently rests toward (a Side, or -1 when centred).
## Navigation fires only when this changes, so a held stick moves the cursor once.
var _stick_side := -1


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
	if side >= 0 and _navigate(side):
		get_viewport().set_input_as_handled()


## Polls the analog left stick, navigating once each time it enters a new
## direction. Digital inputs (keyboard, D-pad) go through _unhandled_input.
func _process(_delta: float) -> void:
	var side := _stick_side_now()
	if side == _stick_side:
		return  # still resting the same way (or still centred) -- no new push
	_stick_side = side
	if side >= 0:
		_navigate(side)


## Moves the cursor one step toward `side` (or nudges a focused slider), if this
## MenuNav owns the focused control. Returns whether it acted. Shared by the
## keyboard/D-pad event path and the left-stick polling.
func _navigate(side: int) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not _targets.has(focused):
		return false  # not our cursor -- let whoever owns it navigate
	# On a slider, left/right change the value rather than leaving the control.
	if focused is Range and (side == SIDE_LEFT or side == SIDE_RIGHT):
		var step: float = focused.step if focused.step > 0.0 else 1.0
		focused.value += step if side == SIDE_RIGHT else -step
		return true
	var neighbor := _nearest(focused, side)
	if neighbor:
		neighbor.grab_focus()
		return true
	return false


## The side the left stick points toward, or -1 while it rests within the menu
## deadzone. Analog, so it is quantised to the single dominant side.
func _stick_side_now() -> int:
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down", _STICK_DEADZONE)
	if v == Vector2.ZERO:
		return -1
	if absf(v.x) >= absf(v.y):
		return SIDE_RIGHT if v.x > 0.0 else SIDE_LEFT
	return SIDE_BOTTOM if v.y > 0.0 else SIDE_TOP


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


## Maps a pressed move_* action (WASD or the D-pad, which shares them) to the Side
## to seek a neighbour on, else -1. The analog stick is handled in _process.
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
