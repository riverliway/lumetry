extends Node2D
class_name Room

static var laser_segment_scene: PackedScene = preload("res://tileset/laser/laser_segment.tscn")
@onready var grid: Grid = Grid.new(func(): return self)


func _ready() -> void:
	for block in get_children():
		var cell = grid.get_nearest_cell(block.position)
		cell.set_block(block)

	grid.handle_laser_physics()

func _process(delta: float) -> void:
	pass


class Grid:
	var resolve_room: Callable
	
	var WIDTH = 23 # Number of cells in each row
	var HEIGHT = 12 # Number of cells in each column
	var grid = []
	
	var SIZE = Vector2(168, 192) # Number of pixels between columns/rows
	var START = Vector2(79, -17) # The coordinates of the top left cell
	
	func _init(room_resolver: Callable):
		resolve_room = room_resolver
		for c in range(WIDTH):
			var col = []
			for r in range(HEIGHT):
				var px = START.x + SIZE.x * c
				var py = START.y + SIZE.y * r + (SIZE.y / 2 if c % 2 == 1 else 0)
				col.push_back(Cell.new(Vector2(px, py), r, c, resolve_room))
				
			grid.push_back(col)
			
	func handle_laser_physics() -> void:
		"""
		Creates new laser segments originating from the emitter
		"""
		var emitters_index = find(func(cell): return cell.get_block_type() == Util.BLOCK_TYPE.LASER_EMITTER, false)
		
		for i in range(0, len(emitters_index), 2):
			var emitter_cell = grid[emitters_index[i]][emitters_index[i + 1]]
			var laser_facing = emitter_cell.block_facing
			var next_cell = go(emitter_cell, laser_facing)
			
			while next_cell != null && next_cell.get_block_type() == Util.BLOCK_TYPE.NONE:
				next_cell.add_laser(Util.rotate_direction_clockwise(laser_facing, 3), laser_facing)
				next_cell = go(next_cell, laser_facing)
		
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
		
	func find(lambda: Callable, first = true) -> Array[int]:
		"""
		Finds a cell that matches the criteria defined by the callable.
		
		:param lambda: a function that takes a cell as a parameter, and returns a boolean
		:param first: if true, it returns the first index and quits immediately.
			If false, it returns all indexes that match the lambda
		
		:returns: the index [col, row] of the first/every cell that the lambda returns true for.
		If the lambda returns false for all cells in the grid, an empty array is returned.
		"""
		var rets: Array[int] = []
		for col in range(WIDTH):
			for row in range(HEIGHT):
				if lambda.call(grid[col][row]):
					if first:
						return [col, row]
					rets.push_back(col)
					rets.push_back(row)
					
		return rets
		
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
		
	func go(cell: Cell, direction: Util.DIRECTION) -> Cell:
		"""
		:returns: the new cell after going in the specified direction from the given cell
		"""
		match direction:
			Util.DIRECTION.UP:
				return get_top(cell)
			Util.DIRECTION.DOWN:
				return get_bottom(cell)
			Util.DIRECTION.UP_LEFT:
				return get_top_left(cell)
			Util.DIRECTION.UP_RIGHT:
				return get_top_right(cell)
			Util.DIRECTION.DOWN_LEFT:
				return get_bottom_left(cell)
			Util.DIRECTION.DOWN_RIGHT:
				return get_bottom_right(cell)
			_:
				return cell
				
	func get_nearest_cell(pos: Vector2) -> Cell:
		"""
		:returns: the cell which is closest to the position, measured by eculidean distance
		"""
		var pos_x = pos.x + SIZE.x / 2
		var column = floor((pos_x - START.x) / SIZE.x)
		column = max(min(int(column), WIDTH - 1), 0)
		
		var pos_y = pos.y + SIZE.y / 2
		var row = floor((pos_y - START.y - (SIZE.y / 2 if column % 2 == 1 else 0)) / SIZE.y)
		row = max(min(int(row), HEIGHT - 1), 0)

		return grid[column][row]


class Cell:
	var resolve_room: Callable
	
	var pos = Vector2.ZERO # The position of this cell in the world (px)
	var r = 0 # The row index
	var c = 0 # The col index
	
	var block = null
	var block_facing = Util.DIRECTION.NONE
	
	var laser: Array[LaserSegment] = [] # The laser sprites, cached so we don't have to keep remaking them
	
	func _init(ppos: Vector2, pr: int, pc: int, room_resolver: Callable):
		pos = ppos
		r = pr
		c = pc
		resolve_room = room_resolver
		
	func set_block(block_object) -> void:
		"""
		Loads the block instance into the cell
		"""
		block = block_object
		block.position = pos
		
		block_facing = Util.get_direction_from_rotation(block.rotation)
		block.rotation = Util.get_rotation_from_direction(block_facing)
		
	func get_block_type() -> Util.BLOCK_TYPE:
		if block == null:
			return Util.BLOCK_TYPE.NONE
		return block.block_type
		
	func add_laser(from: Util.DIRECTION, to: Util.DIRECTION) -> void:
		"""
		Adds a new laser to this cell going from the direction to the other direction
		"""
		var available_segment = Util.find_elem(laser, func(ls): return !ls.is_active())
		if len(available_segment) == 0:
			var new_segment = Room.laser_segment_scene.instantiate()
			new_segment.position = pos
			new_segment.set_laser(from, to)
			laser.push_back(new_segment)
			resolve_room.call().add_child(new_segment)
		else:
			available_segment[0].set_laser(from, to)
			
	func clear_laser() -> void:
		"""
		Clears out all lasers existing in this cell
		"""
		for l in laser:
			l.clear_laser()
			
	func is_laser_active() -> bool:
		"""
		Checks if this cell has a laser in it
		"""
		return len(Util.find_index(laser, func(l): return l.is_active())) > 0
