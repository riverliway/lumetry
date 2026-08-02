extends Sprite2D
class_name LaserDetector
## A laser detector block. A beam striking its sensitive front face fires an
## event; the level-specific script listens for it (open a door, advance rooms,
## etc.). The front face spans three hex directions -- the way the detector
## faces plus its two neighbors -- so it only registers beams arriving from the
## front. Beams from the back three directions are ignored. It will eventually
## be a semi-circle; for now the sprite is a placeholder copy of the prism.
##
## Detection is edge-triggered across a laser physics pass. Grid.handle_laser_physics
## calls [method begin_pass] on every detector, marks the struck ones via
## [method mark_hit], then calls [method end_pass], which fires `detected` /
## `cleared` only when the hit state actually changes -- not once per pass.
##
## Logical hit state ([member is_hit]) settles instantly, the same tick the beam
## is drawn, so physics and the win condition stay correct. But the *reported*
## state -- the glyph, and the `detected` / `cleared` signals that a level uses to
## light a wire or power a linked emitter -- lags a rising edge until the traveling
## beam has visually reached the detector, so a mechanism doesn't react before the
## player sees the beam arrive. The grid injects [member defer_report] to schedule
## that on the beam's reveal clock; a clear is reported at once (beams vanish
## instantly, with no retract animation), and the default fires everything
## immediately (the load resolve, non-animating passes, and unit tests).

## Emitted when a beam begins striking the sensitive face.
signal detected(color: Util.LASER_COLOR)
## Emitted when a beam stops striking the sensitive face.
signal cleared()

## Placeholder programmer art for telling the two detector roles apart: an
## end-level "goal" detector (the room's win target) keeps the red dome, while a
## middle-level "mechanism" detector -- one that drives an in-room device (a
## gated emitter, a rotation pad, ...) rather than winning the room -- shows blue.
## The dome is a solid colour, so we swap the whole texture rather than modulate
## it (multiplying solid red by blue would darken to near-black, not read as blue).
const _GOAL_TEXTURE := preload("res://tileset/detector/detector.png")
const _MECHANISM_TEXTURE := preload("res://tileset/detector/detector_blue.png")

var block_type := Util.BLOCK_TYPE.LASER_DETECTOR

## Whether this is a middle-level mechanism detector (blue) rather than an
## end-level goal detector (red). Set per-instance in the level scene; assigning
## it swaps the sprite so the two roles read differently at a glance. Only the
## look changes -- the hit/signal behaviour is identical for both roles.
@export var is_mechanism := false:
	set(value):
		is_mechanism = value
		texture = _MECHANISM_TEXTURE if is_mechanism else _GOAL_TEXTURE

## Whether a beam currently strikes the sensitive face. Settles instantly during a
## pass; the visible/reported state ([member _reported]) may still be catching up.
var is_hit := false
## Color of the striking beam; meaningful only while [member is_hit] is true.
var hit_color: Util.LASER_COLOR = Util.LASER_COLOR.WHITE

## What the glyph and the detected/cleared signals currently reflect. Lags is_hit
## on a rising edge until the striking beam reveals (see the class comment).
var _reported := false
## Seconds into the reveal at which the striking beam reaches this detector, set by
## [method mark_hit] from Grid._reveal_step; 0 for an unchanged or non-animating hit.
var _reveal_delay := 0.0

## How a reported-state change is timed: called with (delay, apply_callable). The
## default runs it immediately; Grid.handle_laser_physics swaps in one that waits
## `delay` seconds on the beam's reveal clock before a rising edge is reported.
var defer_report: Callable = func(_delay: float, apply: Callable) -> void: apply.call()


## Begins a physics pass: clears the current hit (the propagation re-marks it).
func begin_pass() -> void:
	is_hit = false
	_reveal_delay = 0.0


## Marks the detector as struck by a beam of `color` during this pass. `reveal_delay`
## is when that beam becomes visible at this cell, so a rising edge can wait for it.
func mark_hit(color: Util.LASER_COLOR, reveal_delay := 0.0) -> void:
	is_hit = true
	hit_color = color
	_reveal_delay = reveal_delay


## Shows the colorblind glyph for the striking beam's color, if the overlay
## exists (it is absent in the stripped-down detector unit tests).
func _show_symbol(color: Util.LASER_COLOR) -> void:
	var symbol := get_node_or_null("ColorSymbol")
	if symbol:
		symbol.set_symbol(color)
		symbol.set_active(true)


func _hide_symbol() -> void:
	var symbol := get_node_or_null("ColorSymbol")
	if symbol:
		symbol.set_active(false)


## Ends a physics pass: reconciles the reported state toward the settled is_hit. A
## change is staged through `defer_report` -- a rising edge waits for the beam to
## reveal, a clear reports at once -- which flips the glyph and fires the edge
## signal via [method _apply_report]. Unchanged state does nothing (so it never
## re-fires while a beam sits on the detector, and a beam that breaks before it
## ever revealed simply reports nothing).
func end_pass() -> void:
	var target := is_hit
	if target == _reported:
		return
	var color := hit_color
	var delay := _reveal_delay if target else 0.0
	defer_report.call(delay, func() -> void: _apply_report(target, color))


## Commits a reported-state change: updates the glyph and fires the edge signal.
## Called immediately or, for a rising edge, once the beam has reached the detector.
func _apply_report(state: bool, color: Util.LASER_COLOR) -> void:
	_reported = state
	if state:
		_show_symbol(color)
		detected.emit(color)
	else:
		_hide_symbol()
		cleared.emit()
