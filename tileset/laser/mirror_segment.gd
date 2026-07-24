extends AnimatedSprite2D
class_name MirrorSegment
## A half-beam drawn inside a mirror cell: the laser sliced along the mirror
## surface. Two of these (incoming + reflected) render a bounce. The angled cut
## is baked into the sprite by tools/image_compiler.py; this node just picks the
## short/long set, tints it, and places it with a Transform2D from
## Grid.mirror_bounce_transforms (a rotation, possibly reflected).

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


## Shows the bounce half-beam.
## [br]`is_long` selects the long (60 deg bounce) vs short (120 deg) cut
## [br]`color` tints the white beam via the shared LaserSegment.LASER_MODULATE table
## [br]`xf` places/orients the sprite so its cut lands on the mirror surface
func set_mirror(is_long: bool, color: Util.LASER_COLOR, xf: Transform2D) -> void:
	animation = 'long' if is_long else 'short'
	AnimSync.sync(self)
	self_modulate = LaserSegment.LASER_MODULATE.get(color, Color.WHITE)
	if _symbol:
		_symbol.set_symbol(color)
		_symbol.set_active(true)
	transform = xf
	show()
