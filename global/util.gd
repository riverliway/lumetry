# This script is loaded as a global in the project settings
extends Node


## Implements the modulus operator for floats (a % b)
## [br]`a` The number to modulus to, can be positive or negative
## [br]`b` The number to clamp it to, must be positive
## [br]`use_approx` if true, it uses a performant approximation
func mod_float(a: float, b: float, use_approx=false) -> float:
	if use_approx:
		const BUFFER = 100000.0
		var approx_a = int(a * BUFFER)
		var approx_b = int(b * BUFFER)
		return (approx_a % approx_b) / BUFFER
		
	var remainder = abs(a)
	var s = sign(a)
	while abs(remainder) > b:
		remainder -= b
		
	return remainder * s


## Iterates over the list and gets an array of indexes where the lambda returns true
## [br]`list` The list of items to iterate over
## [br]`lambda` A callable function that takes an element of the list and returns a boolean
## [br]`first` A flag that when true, early-exits and only returns the first index
## [br]Returns: A list of indexes where the lambda returns true on those indexes
func find_index(list: Array[Variant], lambda: Callable, first = true) -> Array[int]:
	var to_ret: Array[int] = []
	for i in range(len(list)):
		if lambda.call(list[i]):
			if first:
				return [i]
			to_ret.push_back(i)
	
	return to_ret


## Iterates over the list and gets an array of elements where the lambda returns true
## [br]`list` The list of items to iterate over
## [br]`lambda` A callable function that takes an element of the list and returns a boolean
## [br]`first` A flag that when true, early-exits and only returns the first element
## [br]Returns: A list of elements where the lambda returns true on those elements
func find_elem(list: Array[Variant], lambda: Callable, first = true) -> Array[Variant]:
	var indexes = find_index(list, lambda, first)
	return indexes.map(func(i): return list[i])


## Gets the hexdirection from a given angle in radians
func get_direction_from_rotation(rotation: float) -> Util.DIRECTION:
	var rot = (int(rad_to_deg(rotation) + 30 + 360 * 100) % 360) / 60.0
	var directions = [
		Util.DIRECTION.DOWN,
		Util.DIRECTION.DOWN_LEFT,
		Util.DIRECTION.UP_LEFT,
		Util.DIRECTION.UP,
		Util.DIRECTION.UP_RIGHT,
		Util.DIRECTION.DOWN_RIGHT
	]
	return directions[rot]


## Gets the angle in radians from a given hexdirection
func get_rotation_from_direction(direction: Util.DIRECTION) -> float:
	var directions = [
		Util.DIRECTION.DOWN,
		Util.DIRECTION.DOWN_LEFT,
		Util.DIRECTION.UP_LEFT,
		Util.DIRECTION.UP,
		Util.DIRECTION.UP_RIGHT,
		Util.DIRECTION.DOWN_RIGHT
	]
	return max(directions.find(direction), 0) * 2 * PI / 6


## Determines if a given rotation is a half-direction (i.e. between two directions)
func is_half_direction(rotation: float) -> bool:
	var rot = int((int(rad_to_deg(rotation) + 15 + 360 * 100) % 360) / 30.0)
	return rot % 2 == 1


## Rotates a hexdirection clockwise by a given number of times
func rotate_direction_clockwise(direction: Util.DIRECTION, times=1) -> Util.DIRECTION:
	var directions = [
		Util.DIRECTION.UP,
		Util.DIRECTION.UP_RIGHT,
		Util.DIRECTION.DOWN_RIGHT,
		Util.DIRECTION.DOWN,
		Util.DIRECTION.DOWN_LEFT,
		Util.DIRECTION.UP_LEFT
	]
	var index = directions.find(direction)
	if index < 0 || index >= len(directions):
		return Util.DIRECTION.NONE
	return directions[(index + times) % len(directions)]


## Rotates a hexdirection counter-clockwise by a given number of times
func rotate_direction_counterclockwise(direction: Util.DIRECTION, times=1) -> Util.DIRECTION:
	return rotate_direction_clockwise(direction, -times)


## Handles the reflect operation for mirrors
## [br]`incoming_beam` The direction of the beam that is coming into the current cell
## [br]`mirror_facing` The direction that the mirror is facing
## [br]`long_mirror` A flag determining if the mirror is a long mirror (vertex-to-vertex) or a short mirror (edge-to-edge)
## When the mirror is facing down, the long mirror is completely horizontal, and the short mirror is completely vertical
## [br]Returns: the outgoing beam from the cell after reflecting off the mirror
func reflect_direction(incoming_beam: Util.DIRECTION, mirror_facing: Util.DIRECTION, long_mirror=true) -> Util.DIRECTION:
	var mirror_flipped = rotate_direction_clockwise(mirror_facing, 3)
	
	if incoming_beam == mirror_facing || incoming_beam == mirror_flipped:
		return incoming_beam
		
	var in_beam = rotate_direction_clockwise(incoming_beam)
	if in_beam == mirror_facing || in_beam == mirror_flipped:
		return rotate_direction_clockwise(incoming_beam, 2 if long_mirror else -1)
		
	return rotate_direction_clockwise(incoming_beam, -2 if long_mirror else 1)

enum DIRECTION {
	NONE,
	UP,
	DOWN,
	UP_LEFT,
	UP_RIGHT,
	DOWN_LEFT,
	DOWN_RIGHT
}

enum BLOCK_TYPE {
	NONE,
	PLAYER,
	WALL,
	LASER_EMITTER,
	MIRROR_SHORT,
	MIRROR_LONG,
	PRISIM,
	TRACK,
	ROTATION_PAD
}

enum PLAYER_STATE {
	IDLE,
	LOOKING,
	MOVING,
	USING
}

enum LASER_COLOR {
	WHITE,
	CYAN,
	MAGENTA,
	YELLOW,
	DESTRUCTIVE
}
