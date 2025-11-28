# This script is loaded as a global in the project settings
extends Node


func mod_float(a: float, b: float, use_approx=false) -> float:
	"""
	Implements the modulus operator for floats (a % b)
	
	:param a: The number to modulus to, can be positive or negative
	:param b: The number to clamp it to, must be positive
	:param use_approx: if true, it uses a performant approximation
	"""
	
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


func find_index(list: Array[Variant], lambda: Callable, first = true) -> Array[int]:
	"""
	Iterates over the list and gets an array of indexes where the lambda returns true
	
	:param list: The list of items to iterate over
	:param lambda: A callable function that takes an element of the list and returns a boolean
	:param first: A flag that when true, early-exits and only returns the first index
	
	:returns: A list of indexes where the lambda returns true on those indexes
	"""
	var to_ret: Array[int] = []
	for i in range(len(list)):
		if lambda.call(list[i]):
			if first:
				return [i]
			to_ret.push_back(i)
	
	return to_ret


func find_elem(list: Array[Variant], lambda: Callable, first = true) -> Array[Variant]:
	"""
	Iterates over the list and gets an array of elements where the lambda returns true
	
	:param list: The list of items to iterate over
	:param lambda: A callable function that takes an element of the list and returns a boolean
	:param first: A flag that when true, early-exits and only returns the first element
	
	:returns: A list of elements where the lambda returns true on those elements
	"""
	var indexes = find_index(list, lambda, first)
	return indexes.map(func(i): return list[i])


func get_direction_from_rotation(rotation: float) -> Util.DIRECTION:
	"""
	:returns: the hexdirection from the given angle in radians
	"""
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


func get_rotation_from_direction(direction: Util.DIRECTION) -> float:
	"""
	:returns: the angle in radians from a given hexdirection
	"""
	var directions = [
		Util.DIRECTION.DOWN,
		Util.DIRECTION.DOWN_LEFT,
		Util.DIRECTION.UP_LEFT,
		Util.DIRECTION.UP,
		Util.DIRECTION.UP_RIGHT,
		Util.DIRECTION.DOWN_RIGHT
	]
	return max(directions.find(direction), 0) * 2 * PI / 6


func rotate_direction_clockwise(direction: Util.DIRECTION, times=1) -> Util.DIRECTION:
	"""
	:returns: the hexdirection resulting from rotating the given direction clockwise
	"""
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


func rotate_direction_counterclockwise(direction: Util.DIRECTION, times=1) -> Util.DIRECTION:
	"""
	:returns: the hexdirection resulting from rotating the given direction counter-clockwise
	"""
	return rotate_direction_clockwise(direction, -times)


func reflect_direction(incoming_beam: Util.DIRECTION, mirror_facing: Util.DIRECTION, long_mirror=true) -> Util.DIRECTION:
	"""
	Handles the reflect operation for mirrors
	
	:param incoming_beam: The direction of the beam that is coming into the current cell
	:param mirror_facing: The direction that the mirror is facing
	:param long_mirror: Flag determining if the mirror is a long mirror (vertex-to-vertex) or a short mirror (edge-to-edge)
	When the mirror is facing down, the long mirror is completely horizontal, and the short mirror is completely vertical
	
	:returns: the outgoing beam from the cell after reflecting off the mirror
	"""
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
	WALL,
	LASER_EMITTER
}
