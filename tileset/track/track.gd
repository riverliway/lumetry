extends Node2D
class_name Track

var block_type := Util.BLOCK_TYPE.TRACK
var directions: Array[Util.DIRECTION] = []

func _ready() -> void:
	if $Top.is_visible():
		directions.append(Util.DIRECTION.UP)
	if $Bottom.is_visible():
		directions.append(Util.DIRECTION.DOWN)
	if $BottomLeft.is_visible():
		directions.append(Util.DIRECTION.DOWN_LEFT)
	if $BottomRight.is_visible():
		directions.append(Util.DIRECTION.DOWN_RIGHT)
	if $TopLeft.is_visible():
		directions.append(Util.DIRECTION.UP_LEFT)
	if $TopRight.is_visible():
		directions.append(Util.DIRECTION.UP_RIGHT)
