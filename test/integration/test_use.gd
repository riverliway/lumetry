extends "res://test/fixtures/game_test.gd"
## Integration tests for the `use` verb, driven through Room.Grid._attempt_use on
## isolated synthetic rooms. `use` acts on the cell the player faces: it toggles a
## laser emitter, or spins the block on a rotation pad 60 degrees -- and in both
## cases re-solves the laser physics so the beam updates immediately.
##
## test_laser_emitter.gd / test_rotation_pad.gd cover those blocks in isolation;
## this covers the grid interaction that actually invokes them in-game.

const RotationPadScene: PackedScene = preload("res://tileset/rotation/rotation_pad.tscn")


# ------------------------------------------------------------- emitter toggle
func test_use_toggles_a_faced_emitter_off_then_on():
	# Emitter one cell below the player, facing DOWN so its beam clears the player.
	var emitter := make_block(EmitterScene, 5, 6)
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 5))
	assert_true(emitter.activated, "emitter starts on")
	assert_gt(active_laser_count(room), 0, "beam present to begin with")

	room.grid._attempt_use(Util.DIRECTION.DOWN)
	assert_false(emitter.activated, "using the emitter toggled it off")
	assert_eq(active_laser_count(room), 0, "the physics re-solve cleared the beam")

	room.grid._attempt_use(Util.DIRECTION.DOWN)
	assert_true(emitter.activated, "using again toggled it back on")
	assert_gt(active_laser_count(room), 0, "and the beam came back")


func test_use_cannot_toggle_a_non_interactable_emitter():
	# A fixed emitter (interactable = false) ignores the player's use verb: it
	# stays on and its beam is untouched.
	var emitter := make_block(EmitterScene, 5, 6)
	emitter.laser_range = -1
	emitter.interactable = false
	var room := build_room([emitter], Vector2i(5, 5))
	assert_true(emitter.activated, "emitter starts on")
	var beams_before := active_laser_count(room)

	room.grid._attempt_use(Util.DIRECTION.DOWN)

	assert_true(emitter.activated, "the player could not toggle the fixed emitter off")
	assert_eq(active_laser_count(room), beams_before, "the beam is unchanged")


func test_use_toward_empty_cell_does_nothing():
	# The player faces an empty cell; a distant emitter must be left untouched.
	var emitter := make_block(EmitterScene, 10, 6)
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 5))
	room.grid._attempt_use(Util.DIRECTION.UP)  # (5,4) is empty
	assert_true(emitter.activated, "an unrelated emitter is not toggled")


func test_use_out_of_bounds_is_safe():
	var room := build_room([], Vector2i(5, 0))  # top row: nothing above
	room.grid._attempt_use(Util.DIRECTION.UP)
	pass_test("using toward the grid edge did not crash")


# ------------------------------------------------------------- rotation pad
func test_use_on_a_rotation_pad_spins_the_block_and_reaims_the_beam():
	# An emitter (facing DOWN) sits on a rotation pad one cell below the player.
	var emitter := make_block(EmitterScene, 5, 6)
	emitter.laser_range = -1
	var pad := make_block(RotationPadScene, 5, 6)
	var room := build_room([emitter, pad], Vector2i(5, 5))
	var pad_cell = room.grid.grid[5][6]
	assert_eq(pad_cell.block_facing, Util.DIRECTION.DOWN, "emitter starts facing down")
	assert_true(room.grid.grid[5][7].is_laser_active(), "beam initially travels straight down")

	room.grid._attempt_use(Util.DIRECTION.DOWN)

	assert_eq(pad_cell.block_facing, Util.rotate_direction_clockwise(Util.DIRECTION.DOWN),
		"the block's facing advanced one hex step clockwise")
	var running_pad = pad_cell.get_rotation_pad()
	assert_eq(running_pad._rotating_block, emitter, "the pad is animating the emitter")
	assert_gt(running_pad._rotation_time_left, 0.0, "the rotation animation is in progress")
	assert_false(room.grid.grid[5][7].is_laser_active(),
		"the beam re-aimed off the straight-down path after the spin")
	assert_gt(active_laser_count(room), 0, "a beam still exists in the new direction")
