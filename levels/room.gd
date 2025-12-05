extends Node2D
class_name Room

## Preloaded laser segment for dynamic creation of laser beams
static var laser_segment_scene: PackedScene = preload("res://tileset/laser/laser_segment.tscn")
@onready var grid: Grid = Grid.new(func(): return self)


func _ready() -> void:
	for block in get_children():
		var cell = grid.get_nearest_cell(block.position)
		cell.set_block(block)

	grid.handle_laser_physics()
	grid.connect_player($Player)


func _process(_delta: float) -> void:
	pass

	
## The datastructure to handle the hexagonal grid of cells.
## Has various helper functions for navigating the grid and handling laser physics.
class Grid:
	## Function for communicating with the room instance that this grid belongs to
	var resolve_room: Callable
	## The actual player object to move around
	var player: Player
	
	var WIDTH = 23 ## Number of cells in each row
	var HEIGHT = 12 ## Number of cells in each column
	var grid = []
	
	var SIZE = Vector2(168, 192) ## Number of pixels between columns/rows
	var START = Vector2(79, -17) ## The coordinates of the top left cell
	
	## Initializes the grid with empty cells
	## [br]`room_resolver` is a callable that returns the Room instance this grid belongs to
	func _init(room_resolver: Callable):
		resolve_room = room_resolver
		for c in range(WIDTH):
			var col = []
			for r in range(HEIGHT):
				var px = START.x + SIZE.x * c
				var py = START.y + SIZE.y * r + (SIZE.y / 2 if c % 2 == 1 else 0)
				col.push_back(Cell.new(Vector2(px, py), r, c, resolve_room))
				
			grid.push_back(col)
			
	## Wipes and re-computes the laser physics for the entire grid
	func handle_laser_physics() -> void:
		clear_laser_grid()
		var emitters_index = find(func(cell): return cell.get_block_type() == Util.BLOCK_TYPE.LASER_EMITTER, false)
		
		for i in range(0, len(emitters_index), 2):
			var emitter_cell = grid[emitters_index[i]][emitters_index[i + 1]]
			if emitter_cell.block.activated:
				_propagate_laser(emitter_cell)
				
	## Propogates a laser beam from a given emitter
	## This is an internal helper function for handling the laser physics
	## [br]`emitter` is the cell containing the laser emitter
	func _propagate_laser(emitter: Cell) -> void:
		# Propogate once from the emitter first, and then continue the propogation below
		# because we don't want to continue the propogation if it hits a different emitter
		var cell = _raycast_laser(go(emitter, emitter.block_facing), emitter.block_facing)
		var laser_facing = emitter.block_facing
		
		while true:
			if cell == null:
				# We must be out of bounds
				return
				
			if cell.get_block_type() == Util.BLOCK_TYPE.NONE:
				# We should never hit this case because we should only propagate
				# when it runs into a new block
				assert(false)
				
			elif cell.get_block_type() == Util.BLOCK_TYPE.MIRROR_SHORT:
				var input_dir = Util.rotate_direction_clockwise(laser_facing, 3)
				laser_facing = Util.reflect_direction(input_dir, cell.block_facing, false)
				if laser_facing == input_dir:
					# The mirror reflected back along the input path, so quit out
					return
				cell = _raycast_laser(go(cell, laser_facing), laser_facing)
				continue
				
			elif cell.get_block_type() == Util.BLOCK_TYPE.MIRROR_LONG:
				var input_dir = Util.rotate_direction_clockwise(laser_facing, 3)
				laser_facing = Util.reflect_direction(input_dir, cell.block_facing, true)
				if laser_facing == input_dir:
					# The mirror reflected back along the input path, so quit out
					return
				cell = _raycast_laser(go(cell, laser_facing), laser_facing)
				continue
				
			return
			
	## Shoots the laser in a straight line until it hits a non-air block
	## [br]`cell` is the starting cell
	## [br]`laser_direction` is the direction to shoot the laser in
	## [br]Returns the non-air cell that the laser collided with
	func _raycast_laser(cell: Cell, laser_direction: Util.DIRECTION) -> Cell:
		var current_cell = cell
		
		while current_cell != null and current_cell.get_block_type() == Util.BLOCK_TYPE.NONE:
			current_cell.add_laser(Util.rotate_direction_clockwise(laser_direction, 3), laser_direction)
			current_cell = go(current_cell, laser_direction)
			
		return current_cell
		
	## Cleans lasers off all cells in the grid
	func clear_laser_grid() -> void:
		for c in WIDTH:
			for r in HEIGHT:
				grid[c][r].clear_laser()

	## Connects a player to this grid for movement handling
	func connect_player(pl: Player) -> void:
		player = pl
		player.attempt_move.connect(_attempt_move)
		player.attempt_use.connect(_attempt_use)

	## A hook for the player attempt use signal
	## [br]`player_facing` is the direction the player is facing
	func _attempt_use(player_facing: Util.DIRECTION) -> void:
		var current_cell = get_nearest_cell(player.position)
		var new_cell = go(current_cell, player_facing)

		if new_cell == null:
			return

		var rotation_pad = new_cell.get_rotation_pad()
		if rotation_pad != null:
			rotation_pad.perform_rotation(new_cell.block)
			new_cell.block_facing = Util.rotate_direction_clockwise(new_cell.block_facing)
			player.use()
			handle_laser_physics()
			return

		if new_cell.get_block_type() in [Util.BLOCK_TYPE.LASER_EMITTER]:
			new_cell.block.use()
			player.use()
			handle_laser_physics()

	
	## A hook for the player attempt move signal
	## [br]`direction` is the direction the player is attempting to move in
	func _attempt_move(direction: Util.DIRECTION) -> void:
		var current_cell = get_nearest_cell(player.position)
		var new_cell = go(current_cell, direction)
		if new_cell == null or (new_cell.get_block_type() == Util.BLOCK_TYPE.NONE and new_cell.is_laser_active()):
			# Can't walk into lasers
			return

		if new_cell.get_block_type() != Util.BLOCK_TYPE.NONE:
			var track = new_cell.get_track()
			if track == null:
				# Can't push a block that isn't on a track
				return

			if track.directions.find(direction) == -1:
				# Can't push a block off the track
				return

			var push_cell = go(new_cell, direction)
			if push_cell == null or push_cell.get_block_type() != Util.BLOCK_TYPE.NONE:
				# Can't push into another block or out of bounds
				return

			# Handle block pushing
			push_cell.block = new_cell.block
			push_cell.block_facing = new_cell.block_facing
			new_cell.remove_block()
			player.move(push_cell.block, push_cell.pos, new_cell.pos)
			handle_laser_physics()

			return
		
		# Handle player movement
		new_cell.block = player
		new_cell.block_facing = direction
		current_cell.remove_block()
		player.move(player, new_cell.pos, current_cell.pos)
		handle_laser_physics()
		
	## Checks if this cell is in the top row
	func is_top(cell: Cell) -> bool:
		return cell.r == 0

	## Checks if this cell is in the bottom row
	func is_bottom(cell: Cell) -> bool:
		return cell.r == HEIGHT - 1
		
	## Checks if this cell is in the leftmost column
	func is_left(cell: Cell) -> bool:
		return cell.c == 0
		
	## Checks if this cell is in the rightmost column
	func is_right(cell: Cell) -> bool:
		return cell.c == WIDTH - 1
		
	## Checks if this cell is in a column that is offset down by 1/2 vertically
	func is_off_shifted(cell: Cell) -> bool:
		return cell.c % 2 == 1
		
	## Finds a cell that matches the criteria defined by the callable.
	## [br]`lambda` is a function that takes a cell as a parameter, and returns a boolean
	## [br]If `first` is true, it returns the first index and quits immediately.
	## if false, it returns all indexes that match the lambda
	## [br]Returns the index [col, row] of the first/every cell that the lambda returns true for.
	func find(lambda: Callable, first = true) -> Array[int]:
		var rets: Array[int] = []
		for col in range(WIDTH):
			for row in range(HEIGHT):
				if lambda.call(grid[col][row]):
					if first:
						return [col, row]
					rets.push_back(col)
					rets.push_back(row)
					
		return rets
		
	# # Returns the cell above this one
	func get_top(cell: Cell) -> Cell:
		if is_top(cell):
			return null
		return grid[cell.c][cell.r - 1]
		
	## Returns the cell below this one
	func get_bottom(cell: Cell) -> Cell:
		if is_bottom(cell):
			return null
		return grid[cell.c][cell.r + 1]
		
	## Returns the cell to the upper left of this one
	func get_top_left(cell: Cell) -> Cell:
		if is_left(cell) || (!is_off_shifted(cell) && is_top(cell)):
			return null
		var shift = 0 if is_off_shifted(cell) else 1
		return grid[cell.c - 1][cell.r - shift]
	
	## Returns the cell to the upper right of this one
	func get_top_right(cell: Cell) -> Cell:
		if is_right(cell) || (!is_off_shifted(cell) && is_top(cell)):
			return null
		var shift = 0 if is_off_shifted(cell) else 1
		return grid[cell.c + 1][cell.r - shift]
		
	## Returns the cell to the lower left of this one
	func get_bottom_left(cell: Cell) -> Cell:
		if is_left(cell) || (is_off_shifted(cell) && is_bottom(cell)):
			return null
		var shift = 1 if is_off_shifted(cell) else 0
		return grid[cell.c - 1][cell.r + shift]
	
	## Returns the cell to the lower right of this one
	func get_bottom_right(cell: Cell) -> Cell:
		if is_right(cell) || (is_off_shifted(cell) && is_bottom(cell)):
			return null
		var shift = 1 if is_off_shifted(cell) else 0
		return grid[cell.c + 1][cell.r + shift]
		
	## Returns the new cell after going in the specified direction from the given cell
	func go(cell: Cell, direction: Util.DIRECTION) -> Cell:
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
	
	## Given a position in pixels, returns the nearest cell in the grid measured by euclidean distance
	## [br]`pos` is the position of the center of the object
	func get_nearest_cell(pos: Vector2) -> Cell:
		var pos_x = pos.x + SIZE.x / 2
		var column = floor((pos_x - START.x) / SIZE.x)
		column = max(min(int(column), WIDTH - 1), 0)
		
		var pos_y = pos.y + SIZE.y / 2
		var row = floor((pos_y - START.y - (SIZE.y / 2 if column % 2 == 1 else 0)) / SIZE.y)
		row = max(min(int(row), HEIGHT - 1), 0)

		return grid[column][row]


## The contents of a single cell in the hexagonal grid
class Cell:
	var resolve_room: Callable
	
	var pos = Vector2.ZERO ## The position of this cell in the world (px)
	var r = 0 ## The row index
	var c = 0 ## The col index
	
	var block: Node2D = null ## The block instance in this cell, null if empty
	var block_facing = Util.DIRECTION.NONE ## The direction that the block in this cell is facing

	var terrain: Array[Node2D] = [] ## The terrain instances in this cell
	
	var laser: Array[LaserSegment] = [] ## The laser sprites, cached so we don't have to keep remaking them
	
	## Initializes the cell at the given position and grid indices
	## [br]`ppos` is the position of this cell in the world (px)
	## [br]`pr` is the row index
	## [br]`pc` is the col index
	## [br]`room_resolver` is a callable that returns the Room instance this cell belongs to
	func _init(ppos: Vector2, pr: int, pc: int, room_resolver: Callable):
		pos = ppos
		r = pr
		c = pc
		resolve_room = room_resolver
		
	## Loads a block instance into this cell, snapping it to the grid
	func set_block(block_object: Node2D) -> void:
		if block_object.block_type in [Util.BLOCK_TYPE.TRACK, Util.BLOCK_TYPE.ROTATION_PAD]:
			# Tracks and rotation pads can stack on top of other blocks
			block_object.position = pos
			terrain.push_back(block_object)
			return

		block = block_object
		block.position = pos
		
		var is_mirror = block_object.block_type in [Util.BLOCK_TYPE.MIRROR_SHORT, Util.BLOCK_TYPE.MIRROR_LONG]
		if is_mirror and Util.is_half_direction(block.rotation):
			# Long mirrors are odd because their rotation means they are technically facing halfways
			# between two cardinal directions. So we set their facing to be orthogonal to the rotation
			# i.e. the mirror is horizontal when it is facing down, as opposed to short mirrors which
			# are in line with their facing, and are vertical when facing down.
			block_object.block_type = Util.BLOCK_TYPE.MIRROR_LONG
			block_facing = Util.get_direction_from_rotation(block.rotation + PI / 2)
			block.rotation = Util.get_rotation_from_direction(block_facing) - PI / 2
		else:
			block_facing = Util.get_direction_from_rotation(block.rotation)
			block.rotation = Util.get_rotation_from_direction(block_facing)

	## Removes the block from this cell
	func remove_block() -> void:
		block = null
		block_facing = Util.DIRECTION.NONE
		
	## Returns the type of block in this cell
	func get_block_type() -> Util.BLOCK_TYPE:
		if block == null:
			return Util.BLOCK_TYPE.NONE
		return block.block_type
		
	## Adds a laser segment to this cell
	## [br]`from` is the direction the laser is coming from
	## [br]`to` is the direction the laser is going to
	func add_laser(from: Util.DIRECTION, to: Util.DIRECTION) -> void:
		var available_segment = Util.find_elem(laser, func(ls): return !ls.is_active())
		if len(available_segment) == 0:
			var new_segment = Room.laser_segment_scene.instantiate()
			new_segment.position = pos
			new_segment.set_laser(from, to)
			laser.push_back(new_segment)
			resolve_room.call().add_child(new_segment)
		else:
			available_segment[0].set_laser(from, to)
			
	## Clears out all lasers in this cell
	func clear_laser() -> void:
		for l in laser:
			l.clear_laser()
			
	## Checks if this cell has an active laser in it
	func is_laser_active() -> bool:
		return len(Util.find_index(laser, func(l): return l.is_active())) > 0

	# Gets the track in this cell, returns null if there isn't any
	func get_track() -> Track:
		for t in terrain:
			if t.block_type == Util.BLOCK_TYPE.TRACK:
				return t
		return null

	# Gets the rotation pad in this cell, returns null if there isn't any
	func get_rotation_pad() -> RotationPad:
		for t in terrain:
			if t.block_type == Util.BLOCK_TYPE.ROTATION_PAD:
				return t
		return null
