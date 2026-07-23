extends AnimatedSprite2D
class_name LaserSegment

@onready var from = Util.DIRECTION.NONE ## The direction the laser is coming from
@onready var to = Util.DIRECTION.NONE ## The direction the laser is going to

var color: Util.LASER_COLOR = Util.LASER_COLOR.WHITE ## The color of the laser

## Tint applied over the white base sprite to produce each laser color.
## The white sprite is a pure grayscale ramp with a (1,1,1) highlight, so
## multiplying it by these values reproduces the old per-color sprites.
const LASER_MODULATE := {
	Util.LASER_COLOR.WHITE:       Color(1.0, 1.0, 1.0),
	Util.LASER_COLOR.CYAN:        Color(0.737, 0.756, 1.0),
	Util.LASER_COLOR.MAGENTA:     Color(0.910, 0.738, 1.0),
	Util.LASER_COLOR.YELLOW:      Color(1.0, 0.930, 0.740),
	Util.LASER_COLOR.DESTRUCTIVE: Color(1.0, 0.35, 0.30),
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
## [br]`beam_rotation` The sprite rotation (radians) aligning the beam to the
## true pixel angle between cell centers -- see Grid.laser_rotation. Using the
## real geometry rather than an idealized 60-degree hex angle keeps angled
## beams collinear with the cells they pass through (no per-segment jag).
func set_laser(pfrom: Util.DIRECTION, pto: Util.DIRECTION, laser_color: Util.LASER_COLOR, beam_rotation: float) -> void:
	color = laser_color
	animation = 'white'
	AnimSync.sync(self)
	self_modulate = LASER_MODULATE.get(color, Color.WHITE)

	from = pfrom
	to = pto

	show()
	var angle_from = Util.get_rotation_from_direction(from)
	var angle_to = Util.get_rotation_from_direction(to)

	if is_equal_approx(abs(angle_from - angle_to), PI):
		rotation = beam_rotation
