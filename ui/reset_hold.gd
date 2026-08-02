extends Control
class_name ResetHold
## Hold-to-reset meter, present in every room (Room._ready adds one). Holding the
## `reset` action (R) for HOLD_DURATION reloads the room to its start; a radial
## meter in the bottom-right fills while the key is held and vanishes the instant
## it is released. Lives inside a CanvasLayer (reset_hold.tscn) so it draws in
## screen space regardless of the room's fit-to-screen scale (GEN-571).
##
## This is additive: the pause menu keeps its own Reset Room button.

## Emitted the moment a full hold completes, right before the room reloads. A
## test can watch this (and disconnect _reload_room) to verify the timing without
## actually reloading the scene.
signal reset_fired

const HOLD_DURATION := 3.0  ## Seconds the reset key must be held to fire.
const RING_WIDTH := 18.0    ## Thickness of the radial ring.

## A soft dark backdrop disc so the meter reads against a bright board, a dim full
## track, and the bright arc that fills over it as the hold progresses.
const COLOR_BACKDROP := Color(0.0, 0.0, 0.0, 0.35)
const COLOR_TRACK := Color(1.0, 1.0, 1.0, 0.22)
const COLOR_FILL := Color(1.0, 1.0, 1.0, 0.92)

var _held := 0.0        ## Seconds the reset action has been held this press (0 = released).
var _resetting := false ## Latched once the reset fires, so it fires only once.


func _ready() -> void:
	reset_fired.connect(_reload_room)


func _process(delta: float) -> void:
	if _resetting:
		return
	var before := _held
	if Input.is_action_pressed("reset"):
		_held = minf(_held + delta, HOLD_DURATION)
		if _held >= HOLD_DURATION:
			_resetting = true
			reset_fired.emit()
	else:
		_held = 0.0  # released before completing -> the meter disappears
	if _held != before:
		queue_redraw()


## Draws the radial meter, filling clockwise from the top. Nothing is drawn while
## the key is released, so the meter is only ever on screen mid-hold.
func _draw() -> void:
	if _held <= 0.0:
		return
	var radius := minf(size.x, size.y) * 0.5 - RING_WIDTH
	if radius <= 0.0:
		return
	var center := size / 2.0
	draw_circle(center, radius + RING_WIDTH * 0.5, COLOR_BACKDROP)
	draw_arc(center, radius, 0.0, TAU, 64, COLOR_TRACK, RING_WIDTH, true)
	var start := -PI / 2.0  # top of the circle
	var progress := _held / HOLD_DURATION
	draw_arc(center, radius, start, start + progress * TAU, 64, COLOR_FILL, RING_WIDTH, true)


## Reloads the current room to its starting state, fading through black -- the
## same reset the pause menu's Reset Room button and a death use. A full hold is
## the player signalling they were stuck, so it also records a softlock for the
## level-select badge before reloading.
func _reload_room() -> void:
	Level.record_softlock(get_tree().current_scene)
	Transition.transition(func(): get_tree().reload_current_scene())
