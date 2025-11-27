extends Node2D

@onready var grid: Grid = Grid.new()


func _ready() -> void:
	for block in get_children():
		var cell = grid.get_nearest_cell(block.position)
		cell.set_block(block)


func _process(delta: float) -> void:
	pass


class Grid:
	var WIDTH = 23 # Number of cells in each row
	var HEIGHT = 12 # Number of cells in each column
	var grid = []
	
	var SIZE = Vector2(168, 192) # Number of pixels between columns/rows
	var START = Vector2(79, -17) # The coordinates of the top left cell
	
	func _init():
		for c in range(WIDTH):
			var col = []
			for r in range(HEIGHT):
				var px = START.x + SIZE.x * c
				var py = START.y + SIZE.y * r + (SIZE.y / 2 if c % 2 == 1 else 0)
				col.push_back(Cell.new(Vector2(px, py), r, c))
				
			grid.push_back(col)
			
	func is_top(cell: Cell) -> bool:
		return cell.r == 0
		
	func is_bottom(cell: Cell) -> bool:
		return cell.r == HEIGHT - 1
		
	func is_left(cell: Cell) -> bool:
		return cell.c == 0
		
	func is_right(cell: Cell) -> bool:
		return cell.c == WIDTH - 1
		
	func is_off_shifted(cell: Cell) -> bool:
		"""
		:returns: true if this cell is in a column that is offset down by 1/2 vertically
		"""
		return cell.c % 2 == 1
		
	func get_top(cell: Cell) -> Cell:
		"""
		:returns: the cell above this one
		"""
		if is_top(cell):
			return null
		return grid[cell.c][cell.r - 1]
		
	func get_bottom(cell: Cell) -> Cell:
		"""
		:returns: the cell below this one
		"""
		if is_bottom(cell):
			return null
		return grid[cell.c][cell.r + 1]
		
	func get_top_left(cell: Cell) -> Cell:
		"""
		:returns: the cell to the upper left of this one
		"""
		if is_left(cell) || (!is_off_shifted(cell) && is_top(cell)):
			return null
		var shift = 0 if is_off_shifted(cell) else 1
		return grid[cell.c - 1][cell.r - shift]
	
	func get_top_right(cell: Cell) -> Cell:
		"""
		:returns: the cell to the upper right of this one
		"""
		if is_right(cell) || (!is_off_shifted(cell) && is_top(cell)):
			return null
		var shift = 0 if is_off_shifted(cell) else 1
		return grid[cell.c + 1][cell.r - shift]
		
	func get_bottom_left(cell: Cell) -> Cell:
		"""
		:returns: the cell to the lower left of this one
		"""
		if is_left(cell) || (is_off_shifted(cell) && is_bottom(cell)):
			return null
		var shift = 1 if is_off_shifted(cell) else 0
		return grid[cell.c - 1][cell.r + shift]
	
	func get_bottom_right(cell: Cell) -> Cell:
		"""
		:returns: the cell to the lower right of this one
		"""
		if is_right(cell) || (is_off_shifted(cell) && is_top(cell)):
			return null
		var shift = 1 if is_off_shifted(cell) else 0
		return grid[cell.c + 1][cell.r + shift]
		
	func go(cell: Cell, direction: DIRECTION) -> Cell:
		"""
		:returns: the new cell after going in the specified direction from the given cell
		"""
		match direction:
			DIRECTION.UP:
				return get_top(cell)
			DIRECTION.DOWN:
				return get_bottom(cell)
			DIRECTION.UP_LEFT:
				return get_top_left(cell)
			DIRECTION.UP_RIGHT:
				return get_top_right(cell)
			DIRECTION.DOWN_LEFT:
				return get_bottom_left(cell)
			DIRECTION.DOWN_RIGHT:
				return get_bottom_right(cell)
			_:
				return cell
				
	func get_nearest_cell(pos: Vector2) -> Cell:
		"""
		:returns: the cell which is closest to the position, measured by eculidean distance
		"""
		var column = floor((pos.x - START.x) / SIZE.x)
		column = max(min(int(column), WIDTH - 1), 0)
		
		var row = floor((pos.y - START.y + (SIZE.y / 2 if column % 2 == 1 else 0)) / SIZE.y)
		row = max(min(int(row), HEIGHT - 1), 0)

		return grid[column][row]
		
	static func get_direction_from_rotation(rotation: float) -> DIRECTION:
		"""
		:returns: the hexdirection from the given angle in radians
		"""
		var rot = (int(rad_to_deg(rotation) + 30 + 360 * 100) % 360) / 60
		var directions = [
			DIRECTION.DOWN,
			DIRECTION.DOWN_LEFT,
			DIRECTION.UP_LEFT,
			DIRECTION.UP,
			DIRECTION.UP_RIGHT,
			DIRECTION.DOWN_RIGHT
		]
		return directions[rot]
		
	static func get_rotation_from_direction(direction: DIRECTION) -> float:
		"""
		:returns: the angle in radians from a given hexdirection
		"""
		var directions = [
			DIRECTION.DOWN,
			DIRECTION.DOWN_LEFT,
			DIRECTION.UP_LEFT,
			DIRECTION.UP,
			DIRECTION.UP_RIGHT,
			DIRECTION.DOWN_RIGHT
		]
		return max(directions.find(direction), 0) * 2 * PI / 6
		
	static func rotate_direction_clockwise(direction: DIRECTION) -> DIRECTION:
		"""
		:returns: the hexdirection resulting from rotating the given direction clockwise
		"""
		var directions = [
			DIRECTION.UP,
			DIRECTION.UP_RIGHT,
			DIRECTION.DOWN_RIGHT,
			DIRECTION.DOWN,
			DIRECTION.DOWN_LEFT,
			DIRECTION.UP_LEFT
		]
		var index = directions.find(direction)
		if index < 0 || index >= len(directions):
			return DIRECTION.NONE
		if index == len(directions) - 1:
			return directions[0]
		return directions[index + 1]
		
	static func rotate_direction_counterclockwise(direction: DIRECTION) -> DIRECTION:
		"""
		:returns: the hexdirection resulting from rotating the given direction counter-clockwise
		"""
		var directions = [
			DIRECTION.UP,
			DIRECTION.UP_RIGHT,
			DIRECTION.DOWN_RIGHT,
			DIRECTION.DOWN,
			DIRECTION.DOWN_LEFT,
			DIRECTION.UP_LEFT
		]
		var index = directions.find(direction)
		if index < 0 || index >= len(directions):
			return DIRECTION.NONE
		return directions[index - 1]

class Cell:
	var pos = Vector2.ZERO # The position of this cell in the world (px)
	var r = 0 # The row index
	var c = 0 # The col index
	
	var block = null
	var block_facing = DIRECTION.NONE
	
	var laser = null
	var laser_facing = DIRECTION.NONE
	
	func _init(ppos, pr, pc):
		pos = ppos
		r = pr
		c = pc
		
	func set_block(block_object) -> void:
		block = block_object
		block.position = pos
		
		block_facing = Grid.get_direction_from_rotation(block.rotation)
		block.rotation = Grid.get_rotation_from_direction(block_facing)

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
	EMITTER
}
