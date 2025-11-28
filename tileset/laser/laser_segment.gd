extends AnimatedSprite2D
class_name LaserSegment

@onready var from = Util.DIRECTION.NONE
@onready var to = Util.DIRECTION.NONE


func clear_laser() -> void:
	"""
	Clear out the laser
	"""
	hide()


func is_active() -> bool:
	return visible


func set_laser(pfrom: Util.DIRECTION, pto: Util.DIRECTION) -> void:
	"""
	Sets this laser segment to be active
	
	:param from: the rotation in radians for where the laser is coming from
	:param to: the rotation in radians for where the laser is going to
	"""
	from = pfrom
	to = pto

	show()
	var angle_from = Util.get_rotation_from_direction(from)
	var angle_to = Util.get_rotation_from_direction(to)
	
	if is_equal_approx(abs(angle_from - angle_to), PI):
		play("straight")
		rotation = angle_to
