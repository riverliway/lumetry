extends AnimatedSprite2D
class_name PrismSegment
## A half-beam drawn inside a prism cell: the laser cut flat (perpendicular to
## the beam) through the center. Four of these render a split -- the incoming
## white beam plus the straight / left / right colored outputs. The flat cut is
## baked into the sprite by tools/image_compiler.py; this node tints it and
## places it via a rotation Transform2D from Grid._draw_prism_split.

## The colorblind glyph overlay, if present.
@onready var _symbol: ColorSymbol = get_node_or_null("ColorSymbol")

## Deactivates the segment
func clear_laser() -> void:
	hide()
	if _symbol:
		_symbol.set_active(false)


## Whether this segment is currently shown
func is_active() -> bool:
	return visible


## Shows one half-beam of the split.
## [br]`color` tints the white beam via the shared LaserSegment.beam_modulate
## [br]`xf` rotates/places the sprite so its flat cut sits at the prism center
## [br]`finite` dims the beam when it belongs to a finite-range emitter
func set_prism(color: Util.LASER_COLOR, xf: Transform2D, finite := false) -> void:
	AnimSync.sync(self)
	self_modulate = LaserSegment.beam_modulate(color, finite)
	if _symbol:
		_symbol.set_symbol(color)
		_symbol.set_active(true)
	transform = xf
	show()
