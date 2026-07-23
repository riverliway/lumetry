extends "res://test/fixtures/game_test.gd"
## Integration tests for laser propagation, range limiting, mirror reflection,
## prism splitting, and emitter toggling — all on isolated synthetic rooms.
## Emitters instantiate facing DOWN (rotation 0 -> DIRECTION.DOWN).

## True if any lit laser cell exists outside the given column (proof a beam bent).
func _has_lit_cell_off_column(room: Room, excluded_col: int) -> bool:
	for c in range(GRID_WIDTH):
		if c == excluded_col:
			continue
		for r in range(GRID_HEIGHT):
			if room.grid.grid[c][r].is_laser_active():
				return true
	return false


# ---------------------------------------------------- straight propagation
func test_beam_travels_straight_to_the_edge():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1  # infinite
	var room := build_room([emitter])
	assert_false(room.grid.grid[4][3].is_laser_active(), "emitter cell itself is not lit")
	assert_true(room.grid.grid[4][4].is_laser_active(), "cell just past emitter lit")
	assert_true(room.grid.grid[4][11].is_laser_active(), "beam reached the bottom edge")
	assert_false(room.grid.grid[0][0].is_laser_active(), "unrelated cell dark")

func test_beam_passes_through_walls():
	# Intentional: walls are laser-transparent so the beam can be animated
	# intersecting them. The beam lights the wall cell and continues past it.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var wall := make_block(WallScene, 4, 5)
	var room := build_room([emitter, wall])
	assert_true(room.grid.grid[4][4].is_laser_active(), "cell before the wall lit")
	assert_true(room.grid.grid[4][5].is_laser_active(), "the wall cell itself is lit")
	assert_true(room.grid.grid[4][6].is_laser_active(), "beam continues past the wall")

func test_no_beam_when_emitter_starts_disabled():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	emitter.activated = false
	var room := build_room([emitter])
	assert_eq(active_laser_count(room), 0)

# --------------------------------------------------------- range limiting
func test_range_limited_beam_stops_after_n_cells():
	var emitter := make_block(EmitterScene, 4, 2)
	emitter.laser_range = 3
	var room := build_room([emitter])
	assert_true(room.grid.grid[4][3].is_laser_active(), "cell 1 lit")
	assert_true(room.grid.grid[4][4].is_laser_active(), "cell 2 lit")
	assert_true(room.grid.grid[4][5].is_laser_active(), "cell 3 lit")
	assert_false(room.grid.grid[4][6].is_laser_active(), "cell 4 beyond range is dark")
	assert_eq(active_laser_count(room), 3, "exactly range-many segments lit")

# ------------------------------------------------------- mirror reflection
func test_mirror_reflects_beam_off_its_column():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var mirror := make_block(MirrorScene, 4, 5, PI / 3.0)  # angled short mirror
	var room := build_room([emitter, mirror])
	assert_true(room.grid.grid[4][4].is_laser_active(), "beam reaches the mirror")
	assert_false(room.grid.grid[4][6].is_laser_active(), "beam does not pass straight through")
	assert_gt(active_laser_count(room), 1, "beam continued after reflecting")
	assert_true(_has_lit_cell_off_column(room, 4), "reflected beam left the emitter column")

# ---------------------------------------------------------- prism splitting
func test_prism_splits_white_beam_into_three_colors():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var prism := make_block(PrismScene, 4, 5)
	# Park the player in a far corner: the prism's DOWN_RIGHT (yellow) beam would
	# otherwise be blocked by the player at the default cell (5,5).
	var room := build_room([emitter, prism], Vector2i(20, 0))
	var colors := active_laser_colors(room)
	assert_true(colors.has(Util.LASER_COLOR.CYAN), "cyan beam present")
	assert_true(colors.has(Util.LASER_COLOR.MAGENTA), "magenta beam present")
	assert_true(colors.has(Util.LASER_COLOR.YELLOW), "yellow beam present")

# -------------------------------------------------------------- toggling
func test_toggling_emitter_off_clears_all_lasers():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var room := build_room([emitter])
	assert_gt(active_laser_count(room), 0, "lasers present while active")
	emitter.use()  # deactivate
	room.grid.handle_laser_physics()
	assert_eq(active_laser_count(room), 0, "no lasers after disabling emitter")
