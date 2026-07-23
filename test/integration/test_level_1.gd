extends "res://test/fixtures/game_test.gd"
## Tests for the room-specific Level 1 script (levels/level1/level_1.gd).
##
## Built on a synthetic Level1 tree assembled from the stable component scenes --
## never the real level_1.tscn, which changes constantly. The synthetic tree
## mirrors the real Level1 -> Room structure so the script's $Room lookup and
## detector wiring resolve.

const Level1Script := preload("res://levels/level1/level_1.gd")


## A Node2D carrying level_1.gd with a child "Room" (room.gd) holding a Player
## plus the given blocks -- the same shape as the real scene. The player parks in
## a far corner by default so it never blocks a beam. Auto-freed by GUT.
func build_level(blocks: Array, player_cell := Vector2i(20, 0)) -> Node2D:
	var level := Node2D.new()
	level.set_script(Level1Script)
	var room := Room.new()
	room.name = "Room"
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
