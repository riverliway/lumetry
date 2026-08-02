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
## [method mark_hit], then calls [method end_pass], which emits `detected` /
## `cleared` only when the hit state actually changes -- not once per pass.

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

## Whether a beam currently strikes the sensitive face.
var is_hit := false
## Color of the striking beam; meaningful only while [member is_hit] is true.
var hit_color: Util.LASER_COLOR = Util.LASER_COLOR.WHITE

var _was_hit := false  ## is_hit at the start of the current pass


## Begins a physics pass: remembers the prior state and clears the current hit.
func begin_pass() -> void:
	_was_hit = is_hit
	is_hit = false
	_hide_symbol()


## Marks the detector as struck by a beam of `color` during this pass.
func mark_hit(color: Util.LASER_COLOR) -> void:
	is_hit = true
	hit_color = color
	_show_symbol(color)


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


## Ends a physics pass, emitting an edge signal if the hit state changed.
func end_pass() -> void:
	if is_hit and not _was_hit:
		detected.emit(hit_color)
	elif not is_hit and _was_hit:
		cleared.emit()
