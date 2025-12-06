extends AnimatedSprite2D
class_name LaserSegment

@onready var from = Util.DIRECTION.NONE ## The direction the laser is coming from
@onready var to = Util.DIRECTION.NONE ## The direction the laser is going to

var color: Util.LASER_COLOR = Util.LASER_COLOR.WHITE ## The color of the laser

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
	match color:
		Util.LASER_COLOR.WHITE:
			play('white')
		Util.LASER_COLOR.CYAN:
			play('cyan')
		Util.LASER_COLOR.MAGENTA:
			play('magenta')
		Util.LASER_COLOR.YELLOW:
			play('yellow')

	from = pfrom
	to = pto

	show()
	var angle_from = Util.get_rotation_from_direction(from)
	var angle_to = Util.get_rotation_from_direction(to)
	
	if is_equal_approx(abs(angle_from - angle_to), PI):
		rotation = angle_to
