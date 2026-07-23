extends Node2D
class_name Room

## Preloaded laser segment for dynamic creation of laser beams
static var laser_segment_scene: PackedScene = preload("res://tileset/laser/laser_segment.tscn")
## Preloaded half-beam segment for drawing a bounce inside a mirror cell
static var mirror_segment_scene: PackedScene = preload("res://tileset/laser/mirror_segment.tscn")
## Preloaded half-beam segment for drawing a split inside a prism cell
static var prism_segment_scene: PackedScene = preload("res://tileset/laser/prism_segment.tscn")
## Grid dimensions for this room, in cells. Set per level scene; the whole board
## is scaled to fit the screen (see levels/level.gd), so a bigger room just
## renders smaller rather than running off the edge.
@export var grid_width := 23
@export var grid_height := 12
@onready var grid: Grid = Grid.new(func(): return self, grid_width, grid_height)


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
	## [br]`width`/`height` are the grid dimensions in cells (cell size is constant)
	func _init(room_resolver: Callable, width := 23, height := 12):
		resolve_room = room_resolver
		WIDTH = width
		HEIGHT = height
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

		# Detectors are edge-triggered across the pass: clear their hit state now,
		# let propagation mark the struck ones, then fire signals for any changes.
		var detectors = find_detectors()
		for detector in detectors:
			detector.begin_pass()

		var emitters_index = find(func(cell): return cell.get_block_type() == Util.BLOCK_TYPE.LASER_EMITTER, false)

		for i in range(0, len(emitters_index), 2):
			var emitter_cell = grid[emitters_index[i]][emitters_index[i + 1]]
			if emitter_cell.block.activated:
				_propagate_laser(emitter_cell, emitter_cell.block.laser_range, emitter_cell.block_facing, Util.LASER_COLOR.WHITE)

		for detector in detectors:
			detector.end_pass()
				
	## Propogates a laser beam from a given emitter
	## This is an internal helper function for handling the laser physics
	## [br]`emitter` is the cell containing the laser emitter
	func _propagate_laser(emitter: Cell, strength: int, laser_direction: Util.DIRECTION, color: Util.LASER_COLOR) -> void:
		var laser_strength: Array[int] = [strength]
	
		# Propogate once from the emitter first, and then continue the propogation below
		# because we don't want to continue the propogation if it hits a different emitter
		var cell = _raycast_laser(go(emitter, laser_direction), laser_strength, laser_direction, color)
		var laser_facing = laser_direction
		
		while laser_strength[0] != 0:
			if cell == null:
				# We must be out of bounds
				return
				
			if cell.get_block_type() == Util.BLOCK_TYPE.MIRROR_SHORT:
				var input_dir = Util.rotate_direction_clockwise(laser_facing, 3)
				var incoming_dir = laser_facing
				laser_facing = Util.reflect_direction(input_dir, cell.block_facing, false)
				if laser_facing == input_dir:
					# The mirror reflected back along the input path, so quit out
					return

				_draw_mirror_bounce(cell, incoming_dir, laser_facing, false, color)
				laser_strength[0] -= 1
				cell = _raycast_laser(go(cell, laser_facing), laser_strength, laser_facing, color)
				continue

			if cell.get_block_type() == Util.BLOCK_TYPE.MIRROR_LONG:
				var input_dir = Util.rotate_direction_clockwise(laser_facing, 3)
				var incoming_dir = laser_facing
				laser_facing = Util.reflect_direction(input_dir, cell.block_facing, true)
				if laser_facing == input_dir:
					# The mirror reflected back along the input path, so quit out
					return

				_draw_mirror_bounce(cell, incoming_dir, laser_facing, true, color)
				laser_strength[0] -= 1
				cell = _raycast_laser(go(cell, laser_facing), laser_strength, laser_facing, color)
				continue

			if cell.get_block_type() == Util.BLOCK_TYPE.LASER_DETECTOR:
				# The beam stops here; the detector registers a hit only if the
				# beam arrived through its sensitive front arc (see detector_hit_directions).
				var from_dir = Util.rotate_direction_clockwise(laser_facing, 3)
				if detector_hit_directions(cell.block_facing).has(from_dir):
					cell.block.mark_hit(color)
				return

			if cell.get_block_type() == Util.BLOCK_TYPE.PRISIM:
				if color != Util.LASER_COLOR.WHITE:
					# Colored lasers are absorbed by the prism
					return

				_draw_prism_split(cell, laser_facing)
				# Split the laser into three colored lasers
				_propagate_laser(cell, laser_strength[0] - 1, Util.rotate_direction_clockwise(laser_facing), Util.LASER_COLOR.CYAN)
				_propagate_laser(cell, laser_strength[0] - 1, laser_facing, Util.LASER_COLOR.MAGENTA)
				_propagate_laser(cell, laser_strength[0] - 1, Util.rotate_direction_counterclockwise(laser_facing), Util.LASER_COLOR.YELLOW)
				
			return
			
	## Shoots the laser in a straight line until it hits a non-air block
	## [br]`cell` is the starting cell
	## [br]`laser_direction` is the direction to shoot the laser in
	## [br]Returns the non-air cell that the laser collided with
	func _raycast_laser(cell: Cell, strength: Array[int], laser_direction: Util.DIRECTION, color: Util.LASER_COLOR) -> Cell:
		var current_cell = cell

		var _should_continue = func (c: Cell, s: int) -> bool:
			if c == null:
				return false
			if s == 0:
				return false
			return c.get_block_type() in [Util.BLOCK_TYPE.NONE, Util.BLOCK_TYPE.WALL]
		
		while _should_continue.call(current_cell, strength[0]):
			current_cell.add_laser(Util.rotate_direction_clockwise(laser_direction, 3), laser_direction, color, laser_rotation(laser_direction))
			current_cell = go(current_cell, laser_direction)
			strength[0] -= 1 
			
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
	
	## Every laser-detector block instance currently placed in the grid.
	func find_detectors() -> Array:
		var detectors: Array = []
		var index = find(func(cell): return cell.get_block_type() == Util.BLOCK_TYPE.LASER_DETECTOR, false)
		for i in range(0, len(index), 2):
			detectors.push_back(grid[index[i]][index[i + 1]].block)
		return detectors

	## The three directions a detector facing `facing` can be struck from: the way
	## it faces plus its two neighbors -- its ~180-degree sensitive front arc. A
	## beam arriving FROM one of these directions triggers the detector; a beam
	## from the back three is ignored.
	func detector_hit_directions(facing: Util.DIRECTION) -> Array:
		return [
			facing,
			Util.rotate_direction_clockwise(facing),
			Util.rotate_direction_counterclockwise(facing),
		]

	## The world-space pixel offset from a cell to its neighbor in `direction`.
	func direction_to_offset(direction: Util.DIRECTION) -> Vector2:
		match direction:
			Util.DIRECTION.UP:         return Vector2(0, -SIZE.y)
			Util.DIRECTION.DOWN:       return Vector2(0, SIZE.y)
			Util.DIRECTION.UP_LEFT:    return Vector2(-SIZE.x, -SIZE.y / 2.0)
			Util.DIRECTION.UP_RIGHT:   return Vector2(SIZE.x, -SIZE.y / 2.0)
			Util.DIRECTION.DOWN_LEFT:  return Vector2(-SIZE.x, SIZE.y / 2.0)
			Util.DIRECTION.DOWN_RIGHT: return Vector2(SIZE.x, SIZE.y / 2.0)
			_:                         return Vector2.ZERO

	## The sprite rotation (radians) that points a laser segment along `direction`.
	## [br]Uses the grid's true pixel geometry -- a diagonal step is (SIZE.x, SIZE.y/2),
	## which is ~60.26 degrees from vertical, not the idealized 60. Rotating segments
	## to the real angle keeps them collinear with the cells they pass through, so
	## angled beams don't jag at each segment boundary.
	func laser_rotation(direction: Util.DIRECTION) -> float:
		# The sprite points DOWN (+y) at rotation 0, so subtract that reference angle.
		return direction_to_offset(direction).angle() - PI / 2.0

	## World transforms for the two half-beam sprites that draw a bounce inside a
	## mirror cell: the incoming beam (stopping at the surface) and the reflected
	## beam (leaving it). Matches the angled cut baked in by the image compiler --
	## the beam meets the surface at 60 deg (short) / 30 deg (long).
	## [br]Returns [incoming_transform, reflected_transform].
	func mirror_bounce_transforms(cell: Cell, incoming_dir: Util.DIRECTION, outgoing_dir: Util.DIRECTION, is_long: bool) -> Array:
		var d_in := direction_to_offset(incoming_dir).normalized()
		var d_out := direction_to_offset(outgoing_dir).normalized()
		var phi := deg_to_rad(30.0) if is_long else deg_to_rad(60.0)
		var n_base := Vector2(cos(phi), -sin(phi))      # base sprite's cut normal
		var n_target := (d_out - d_in).normalized()     # mirror normal, reflective side
		return [
			_mirror_solve(d_in, n_base, n_target, cell.pos),
			_mirror_solve(-d_out, n_base, n_target, cell.pos),
		]

	## Isometry (as a Transform2D at `origin`) mapping the base cut sprite -- beam
	## axis (0,1) and cut normal `n_base` -- onto `target_beam` and `n_target`.
	func _mirror_solve(target_beam: Vector2, n_base: Vector2, n_target: Vector2, origin: Vector2) -> Transform2D:
		var base := Transform2D(Vector2(0, 1), n_base, Vector2.ZERO)
		var target := Transform2D(target_beam, n_target, Vector2.ZERO)
		var a := target * base.affine_inverse()
		return Transform2D(a.x, a.y, origin)

	## Renders a bounce in a mirror cell as two half-beam sprites (incoming +
	## reflected). The mirror cell holds no straight segment; this is its beam.
	func _draw_mirror_bounce(cell: Cell, incoming_dir: Util.DIRECTION, outgoing_dir: Util.DIRECTION, is_long: bool, color: Util.LASER_COLOR) -> void:
		var xfs = mirror_bounce_transforms(cell, incoming_dir, outgoing_dir, is_long)
		cell.add_mirror_laser(is_long, color, xfs[0], xfs[1])

	## Renders the split in a prism cell as four flat-cut half-beams: the incoming
	## white beam and the straight (magenta), clockwise (cyan) and counter-clockwise
	## (yellow) outputs -- matching the beams _propagate_laser spawns. Each cut is
	## flat, so a plain rotation orients it; the incoming beam points along the entry
	## direction while each output points its full end outward (rotate 3 = reverse).
	func _draw_prism_split(cell: Cell, incoming_dir: Util.DIRECTION) -> void:
		var cyan_dir := Util.rotate_direction_clockwise(incoming_dir)
		var yellow_dir := Util.rotate_direction_counterclockwise(incoming_dir)
		var colors := [Util.LASER_COLOR.WHITE, Util.LASER_COLOR.MAGENTA, Util.LASER_COLOR.CYAN, Util.LASER_COLOR.YELLOW]
		var transforms := [
			Transform2D(laser_rotation(incoming_dir), cell.pos),
			Transform2D(laser_rotation(Util.rotate_direction_clockwise(incoming_dir, 3)), cell.pos),
			Transform2D(laser_rotation(Util.rotate_direction_clockwise(cyan_dir, 3)), cell.pos),
			Transform2D(laser_rotation(Util.rotate_direction_clockwise(yellow_dir, 3)), cell.pos),
		]
		cell.add_prism_laser(colors, transforms)

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

	## Every cell's world-space center, column-major. Used to lay out the floor.
	func cell_centers() -> Array:
		var centers: Array = []
		for c in range(WIDTH):
			for r in range(HEIGHT):
				centers.push_back(grid[c][r].pos)
		return centers

	## The board's pixel bounds in board space: the bounding box of every cell,
	## each treated as a SIZE-big footprint. Used to scale the room to the screen
	## so the whole board stays visible regardless of how many cells it has.
	func board_bounds() -> Rect2:
		var min_center := Vector2(START.x, START.y)
		var max_center := Vector2(START.x + SIZE.x * (WIDTH - 1), START.y + SIZE.y * (HEIGHT - 1))
		if WIDTH >= 2:
			# Odd columns sit half a cell lower, extending the bottom edge.
			max_center.y += SIZE.y / 2.0
		return Rect2(min_center - SIZE / 2.0, (max_center - min_center) + SIZE)


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
	var mirror_laser: Array[MirrorSegment] = [] ## The two half-beam bounce sprites when a mirror sits here
	var prism_laser: Array[PrismSegment] = [] ## The four half-beam split sprites when a prism sits here
	
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
		block_object.z_index = Util.z_index_for(block_object.block_type)
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
	## [br]`beam_rotation` is the sprite rotation from Grid.laser_rotation
	func add_laser(from: Util.DIRECTION, to: Util.DIRECTION, color: Util.LASER_COLOR, beam_rotation: float) -> void:
		var available_segment = Util.find_elem(laser, func(ls): return !ls.is_active())
		if len(available_segment) == 0:
			var new_segment = Room.laser_segment_scene.instantiate()
			new_segment.position = pos
			new_segment.z_index = Util.Z_LASER
			laser.push_back(new_segment)
			resolve_room.call().add_child(new_segment)
			new_segment.set_laser(from, to, color, beam_rotation)
		else:
			available_segment[0].set_laser(from, to, color, beam_rotation)

	## Draws a mirror bounce here as two half-beam sprites (incoming + reflected),
	## pooled like the straight segments. Transforms come from Grid.mirror_bounce_transforms.
	func add_mirror_laser(is_long: bool, color: Util.LASER_COLOR, incoming_xf: Transform2D, reflected_xf: Transform2D) -> void:
		_set_mirror_segment(0, is_long, color, incoming_xf)
		_set_mirror_segment(1, is_long, color, reflected_xf)

	func _set_mirror_segment(index: int, is_long: bool, color: Util.LASER_COLOR, xf: Transform2D) -> void:
		while mirror_laser.size() <= index:
			var seg = Room.mirror_segment_scene.instantiate()
			seg.z_index = Util.Z_LASER
			mirror_laser.push_back(seg)
			resolve_room.call().add_child(seg)
		mirror_laser[index].set_mirror(is_long, color, xf)

	## Draws a prism split here as four flat-cut half-beam sprites, pooled like the
	## straight segments. `colors[i]` and `transforms[i]` come from Grid._draw_prism_split.
	func add_prism_laser(colors: Array, transforms: Array) -> void:
		for i in range(colors.size()):
			_set_prism_segment(i, colors[i], transforms[i])

	func _set_prism_segment(index: int, color: Util.LASER_COLOR, xf: Transform2D) -> void:
		while prism_laser.size() <= index:
			var seg = Room.prism_segment_scene.instantiate()
			seg.z_index = Util.Z_LASER
			prism_laser.push_back(seg)
			resolve_room.call().add_child(seg)
		prism_laser[index].set_prism(color, xf)

	## Clears out all lasers in this cell
	func clear_laser() -> void:
		for l in laser:
			l.clear_laser()
		for m in mirror_laser:
			m.clear_laser()
		for p in prism_laser:
			p.clear_laser()
			
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
