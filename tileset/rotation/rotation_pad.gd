extends Sprite2D
class_name RotationPad

var block_type := Util.BLOCK_TYPE.ROTATION_PAD

var _ROTATION_DURATION := 0.75 ## The duration of a rotation in 
var _ROTATION_AMOUNT := deg_to_rad(60.0) ## The amount to rotate in radians
var _rotating_block: Node2D = null ## The block currently being rotated
var _rotation_time_left := 0.0 ## The time left for the current rotation
var _rotation_self_start_amount := 0.0 ## The rotation amount for the pad at the start of the rotation
var _rotation_block_start_amount := 0.0 ## The rotation amount for the block at the start of the rotation

func _process(delta: float) -> void:
	if _rotation_time_left > 0.0:
		var rotation_step = (_ROTATION_AMOUNT / _ROTATION_DURATION) * delta
		
		rotation = Util.mod_float(rotation + rotation_step, 2 * PI)
		if _rotating_block != null:
			_rotating_block.rotation = Util.mod_float(_rotating_block.rotation + rotation_step, 2 * PI)

		_rotation_time_left -= delta
		if _rotation_time_left <= 0.0:
			# Ensure final rotation amounts are exact
			rotation = Util.mod_float(_rotation_self_start_amount + _ROTATION_AMOUNT, 2 * PI)
			if _rotating_block != null:
				_rotating_block.rotation = Util.mod_float(_rotation_block_start_amount + _ROTATION_AMOUNT, 2 * PI)
			_rotating_block = null


## Starts rotating both itself and the given block
func perform_rotation(block: Node2D) -> void:
	_rotating_block = block
	_rotation_time_left = _ROTATION_DURATION
	_rotation_self_start_amount = rotation
	if _rotating_block != null:
		_rotation_block_start_amount = _rotating_block.rotation
