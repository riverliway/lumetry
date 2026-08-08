extends Sprite2D
class_name RotationPad

const _ENABLED_TEXTURE := preload("res://tileset/rotation/rotation.png")
const _DISABLED_TEXTURE := preload("res://tileset/rotation/rotation_pad_disabled.png")

var block_type := Util.BLOCK_TYPE.ROTATION_PAD

## Whether the player can rotate this pad with the use verb. When false the pad
## is locked -- using it does nothing (the grid skips it in _attempt_use) -- but
## level code can still spin it (and the block on top) via Room.rotate_pad().
## Setting it swaps the sprite (active when unlocked, greyed-out when locked), so
## a level can flip it at runtime -- e.g. level 5's middle detector unlocks the
## pad while its beam is present -- and the lock state stays visible. Mirrors the
## laser emitter's `interactable`.
@export var interactable := true:
	set(value):
		interactable = value
		texture = _ENABLED_TEXTURE if value else _DISABLED_TEXTURE

var _ROTATION_DURATION := 0.75 ## The duration of a rotation in 
var _ROTATION_AMOUNT := deg_to_rad(60.0) ## The amount to rotate in radians
var _rotating_block: Node2D = null ## The block currently being rotated
var _rotation_time_left := 0.0 ## The time left for the current rotation
var _rotation_self_start_amount := 0.0 ## The rotation amount for the pad at the start of the rotation
var _rotation_block_start_amount := 0.0 ## The rotation amount for the block at the start of the rotation

func _process(delta: float) -> void:
	if _rotation_time_left <= 0.0:
		return

	_rotation_time_left -= delta
	if _rotation_time_left <= 0.0:
		# Ensure final rotation amounts are exact
		rotation = Util.mod_float(_rotation_self_start_amount + _ROTATION_AMOUNT, 2 * PI)
		if _rotating_block != null:
			_rotating_block.rotation = Util.mod_float(_rotation_block_start_amount + _ROTATION_AMOUNT, 2 * PI)
		_rotating_block = null
		return

	# Ease the spin in and out (an S-curve) so it accelerates off the start and
	# settles gently into +60 deg, rather than snapping to a constant speed.
	# Interpolate absolutely from the recorded start angle so the eased fraction
	# maps straight onto the turn.
	var t := smoothstep(0.0, 1.0, 1.0 - (_rotation_time_left / _ROTATION_DURATION))
	var turned := _ROTATION_AMOUNT * t
	rotation = Util.mod_float(_rotation_self_start_amount + turned, 2 * PI)
	if _rotating_block != null:
		_rotating_block.rotation = Util.mod_float(_rotation_block_start_amount + turned, 2 * PI)


## Starts rotating both itself and the given block. Returns the animation's
## duration so a caller can time other effects to it (e.g. the room holds a
## re-aimed beam back until the spin finishes).
func perform_rotation(block: Node2D) -> float:
	_rotating_block = block
	_rotation_time_left = _ROTATION_DURATION
	_rotation_self_start_amount = rotation
	if _rotating_block != null:
		_rotation_block_start_amount = _rotating_block.rotation
	return _ROTATION_DURATION
