extends AnimatedSprite2D
class_name PrismSegment
## A half-beam drawn inside a prism cell: the laser cut flat (perpendicular to
## the beam) through the center. Four of these render a split -- the incoming
## white beam plus the straight / left / right colored outputs. The flat cut is
## baked into the sprite by tools/image_compiler.py; this node tints it and
## places it via a rotation Transform2D from Grid._draw_prism_split.

## Deactivates the segment
func clear_laser() -> void:
	hide()


## Whether this segment is currently shown
func is_active() -> bool:
	return visible


## Shows one half-beam of the split.
## [br]`color` tints the white beam via the shared LaserSegment.LASER_MODULATE table
## [br]`xf` rotates/places the sprite so its flat cut sits at the prism center
func set_prism(color: Util.LASER_COLOR, xf: Transform2D) -> void:
	AnimSync.sync(self)
	self_modulate = LaserSegment.LASER_MODULATE.get(color, Color.WHITE)
	transform = xf
	show()
