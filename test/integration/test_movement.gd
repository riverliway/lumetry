extends "res://test/fixtures/game_test.gd"
## Integration tests for player movement and block-pushing rules, driven through
## Room.Grid._attempt_move on isolated synthetic rooms. Movement animates over
## _process, so the player node is ticked manually to force completion.

func _player_cell(room: Room, player: Node2D) -> Array:
	var c = room.grid.get_nearest_cell(player.position)
	return [c.c, c.r]


# ---------------------------------------------------------- basic movement
func test_moves_into_empty_cell():
	var room := build_room([], Vector2i(5, 5))
	var player := room.get_node("Player")
	room.grid._attempt_move(Util.DIRECTION.UP)
	player._process(1.0)  # complete the move animation
	assert_eq(_player_cell(room, player), [5, 4], "player advanced up")
	assert_eq(room.grid.grid[5][4].block, player, "registered in new cell")
	assert_null(room.grid.grid[5][5].block, "old cell cleared")

func test_move_out_of_bounds_is_ignored():
	var room := build_room([], Vector2i(5, 0))
	var player := room.get_node("Player")
	room.grid._attempt_move(Util.DIRECTION.UP)  # no cell above the top row
	player._process(1.0)
	assert_eq(room.grid.grid[5][0].block, player, "player stayed in place")

func test_cannot_move_into_wall_without_track():
	var wall := make_block(WallScene, 5, 6)  # DOWN neighbor of (5,5)
	var room := build_room([wall], Vector2i(5, 5))
	var player := room.get_node("Player")
	room.grid._attempt_move(Util.DIRECTION.DOWN)
	player._process(1.0)
	assert_eq(room.grid.grid[5][5].block, player, "player blocked, stayed put")
	assert_eq(room.grid.grid[5][6].block, wall, "wall unchanged")

func test_cannot_walk_into_active_laser():
	var emitter := make_block(EmitterScene, 7, 3)  # faces DOWN, beam down column 7
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(6, 5))
	var player := room.get_node("Player")
	# (7,5) is DOWN_RIGHT of (6,5) and lies on the beam -> entry forbidden.
	assert_true(room.grid.grid[7][5].is_laser_active(), "target cell is lit (precondition)")
	room.grid._attempt_move(Util.DIRECTION.DOWN_RIGHT)
	player._process(1.0)
	assert_eq(room.grid.grid[6][5].block, player, "player refused to enter the laser")

# --------------------------------------------------------- block pushing
func test_pushes_block_along_enabled_track():
	var mirror := make_block(MirrorScene, 5, 6)
	var track := make_track(5, 6, [Util.DIRECTION.DOWN])
	var room := build_room([mirror, track], Vector2i(5, 5))
	var player := room.get_node("Player")
	room.grid._attempt_move(Util.DIRECTION.DOWN)
	player._process(1.0)
	assert_eq(room.grid.grid[5][7].block, mirror, "block pushed one cell down")
	assert_null(room.grid.grid[5][6].block, "block left its old cell")
	assert_almost_eq(mirror.position, cell_center(5, 7), Vector2(0.5, 0.5), "block animated to new cell")
	# Intentional (Pokemon Strength-style): pushing shoves the block but the
	# player does NOT follow into the vacated cell.
	assert_eq(room.grid.grid[5][5].block, player, "player stays put after pushing")

func test_cannot_push_block_off_its_track():
	var mirror := make_block(MirrorScene, 5, 6)
	var track := make_track(5, 6, [Util.DIRECTION.UP])  # DOWN not permitted
	var room := build_room([mirror, track], Vector2i(5, 5))
	var player := room.get_node("Player")
	room.grid._attempt_move(Util.DIRECTION.DOWN)
	player._process(1.0)
	assert_eq(room.grid.grid[5][6].block, mirror, "block did not move")

func test_cannot_push_block_into_occupied_cell():
	var mirror := make_block(MirrorScene, 5, 6)
	var track := make_track(5, 6, [Util.DIRECTION.DOWN])
	var blocker := make_block(WallScene, 5, 7)  # occupies the push destination
	var room := build_room([mirror, track, blocker], Vector2i(5, 5))
	var player := room.get_node("Player")
	room.grid._attempt_move(Util.DIRECTION.DOWN)
	player._process(1.0)
	assert_eq(room.grid.grid[5][6].block, mirror, "block stayed, destination blocked")
	assert_eq(room.grid.grid[5][7].block, blocker, "blocker unchanged")
