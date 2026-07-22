extends AnimatedSprite2D
class_name LaserSegment

@onready var from = Util.DIRECTION.NONE ## The direction the laser is coming from
@onready var to = Util.DIRECTION.NONE ## The direction the laser is going to

var color: Util.LASER_COLOR = Util.LASER_COLOR.WHITE ## The color of the laser

## Tint applied over the white base sprite to produce each laser color.
## The white sprite is a pure grayscale ramp with a (1,1,1) highlight, so
## multiplying it by these values reproduces the old per-color sprites.
const LASER_MODULATE := {
	Util.LASER_COLOR.WHITE:   Color(1.0, 1.0, 1.0),
	Util.LASER_COLOR.CYAN:    Color(0.737, 0.756, 1.0),
	Util.LASER_COLOR.MAGENTA: Color(0.910, 0.738, 1.0),
	Util.LASER_COLOR.YELLOW:  Color(1.0, 0.930, 0.740),
}

## Deactivates the laser
func clear_laser() -> void:
	hide()


## Checks if the laser is activated
func is_active() -> bool:
	return visible


## Sets this laser segment to be active
## [br]`from` The direction the laser is coming from
## [br]`to` The direction the laser is going to
func set_laser(pfrom: Util.DIRECTION, pto: Util.DIRECTION, laser_color: Util.LASER_COLOR) -> void:
	color = laser_color
	play('white')
	self_modulate = LASER_MODULATE.get(color, Color.WHITE)

	from = pfrom
	to = pto

	show()
	var angle_from = Util.get_rotation_from_direction(from)
	var angle_to = Util.get_rotation_from_direction(to)
	
	if is_equal_approx(abs(angle_from - angle_to), PI):
		rotation = angle_to
