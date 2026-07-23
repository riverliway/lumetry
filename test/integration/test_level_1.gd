extends "res://test/fixtures/game_test.gd"
## Tests for the room-specific Level 1 script (levels/level1/level_1.gd).
##
## Built on a synthetic Level1 tree assembled from the stable component scenes --
## never the real level_1.tscn, which changes constantly. The synthetic tree
## mirrors the real Level1 -> Room structure so the script's $Room lookup and
## detector wiring resolve.

const Level1Script := preload("res://levels/level1/level_1.gd")


## A Node2D carrying level_1.gd with a "Floor" container and a "Room" child
## (room.gd) holding a Player plus the given blocks -- the same shape the base
## Level expects. The player parks in a far corner by default so it never blocks
## a beam. `width`/`height` size the grid. When `with_floor` is true the Floor is
## populated with plain tiles, mirroring what tools/generate_floor.py bakes into
## a real scene, so runtime wall-dimming can be exercised. Auto-freed by GUT.
func build_level(blocks: Array, player_cell := Vector2i(20, 0), width := 23, height := 12, with_floor := false) -> Node2D:
	var level := Node2D.new()
	level.set_script(Level1Script)
	var floor_node := Node2D.new()
	floor_node.name = "Floor"
	level.add_child(floor_node)
	if with_floor:
		for c in range(width):
			for r in range(height):
				var tile := Sprite2D.new()
				tile.position = cell_center(c, r)
				floor_node.add_child(tile)
	var room := Room.new()
	room.name = "Room"
	room.grid_width = width
	room.grid_height = height
	var player := PlayerScene.instantiate()
	player.name = "Player"
	player.position = cell_center(player_cell.x, player_cell.y)
	room.add_child(player)
	for block in blocks:
		room.add_child(block)
	level.add_child(room)
	add_child_autofree(level)
	return level


func test_solved_when_the_only_detector_is_lit():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var detector := make_block(DetectorScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	var level := build_level([emitter, detector])
	assert_true(level._solved, "room is solved while the detector is lit")

func test_not_solved_when_detector_faces_away():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var detector := make_block(DetectorScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.DOWN))
	var level := build_level([emitter, detector])
	assert_false(level._solved, "a beam on the detector's back does not solve the room")

func test_not_solved_without_any_detector():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var level := build_level([emitter])
	assert_false(level._solved, "a room with no detector is never solved")

func test_unsolved_signal_fires_when_beam_is_broken():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var detector := make_block(DetectorScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	var level := build_level([emitter, detector])
	assert_true(level._solved, "starts solved")
	watch_signals(level)
	emitter.use()  # break the beam
	level.room.grid.handle_laser_physics()
	assert_false(level._solved, "no longer solved once the beam is broken")
	assert_signal_emitted(level, "unsolved")

func test_solved_signal_fires_on_the_solving_edge():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	emitter.activated = false  # start dark so we can observe the solving edge
	var detector := make_block(DetectorScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	var level := build_level([emitter, detector])
	assert_false(level._solved, "starts unsolved while the emitter is off")
	watch_signals(level)
	emitter.use()  # turn on -> beam reaches the detector
	level.room.grid.handle_laser_physics()
	assert_true(level._solved)
	assert_signal_emitted(level, "solved")


# ------------------------------------ board presentation (base Level: fit + dim)
func test_wall_floor_is_dimmed_at_runtime():
	var wall := make_block(WallScene, 3, 4)
	var level := build_level([wall], Vector2i(0, 0), 23, 12, true)
	var wall_center := cell_center(3, 4)
	var dimmed := 0
	var wall_tile_dimmed := false
	for tile in level.get_node("Floor").get_children():
		if tile.modulate.a < 1.0:
			dimmed += 1
			if tile.position.is_equal_approx(wall_center):
				wall_tile_dimmed = true
	assert_true(wall_tile_dimmed, "the floor cell under the wall is dimmed")
	assert_eq(dimmed, 1, "only the wall cell is dimmed; open cells stay bright")

func test_default_room_scales_to_fit_the_screen():
	# The 23x12 board (~3864x2400) fits a 3840x2160 design viewport limited by
	# height -> a uniform 0.9 scale, so the whole room stays visible.
	var level := build_level([], Vector2i(0, 0))
	assert_almost_eq(level.scale.x, 0.9, 0.001, "uniform fit scale x")
	assert_almost_eq(level.scale.y, 0.9, 0.001, "uniform fit scale y")

func test_smaller_room_scales_up_more_than_a_bigger_room():
	var small := build_level([], Vector2i(0, 0), 5, 7)
	var big := build_level([], Vector2i(0, 0), 23, 12)
	assert_gt(small.scale.x, big.scale.x, "fewer cells -> sprites shrink less (scale up)")
