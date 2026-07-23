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

func test_mirror_cell_draws_two_bounce_segments():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var mirror := make_block(MirrorScene, 4, 5, PI / 3.0)
	var room := build_room([emitter, mirror])
	var mcell = room.grid.grid[4][5]
	var active = mcell.mirror_laser.filter(func(m): return m.is_active())
	assert_eq(active.size(), 2, "mirror cell draws two half-beam bounce segments")
	# The incoming half-beam is oriented along the entry direction (DOWN): its
	# sprite y-axis (base beam) maps onto the DOWN pixel offset.
	var d_down := room.grid.direction_to_offset(Util.DIRECTION.DOWN).normalized()
	assert_almost_eq(mcell.mirror_laser[0].transform.y.normalized().dot(d_down), 1.0, 0.001,
		"incoming half-beam points along the entry direction")

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

func test_prism_cell_draws_four_split_segments():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var prism := make_block(PrismScene, 4, 5)
	var room := build_room([emitter, prism], Vector2i(20, 0))
	var pcell = room.grid.grid[4][5]
	var active = pcell.prism_laser.filter(func(p): return p.is_active())
	# incoming white + straight/left/right colored outputs
	assert_eq(active.size(), 4, "prism cell draws four half-beam split segments")

# ---------------------------------------------------------- laser detector
func test_detector_facing_the_beam_registers_a_hit():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	# Beam travels DOWN; the detector below faces UP, into the beam's front arc.
	var detector := make_block(DetectorScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	var room := build_room([emitter, detector])
	assert_true(room.grid.grid[4][6].block.is_hit, "detector facing the beam is hit")
	assert_eq(room.grid.grid[4][6].block.hit_color, Util.LASER_COLOR.WHITE, "records the beam color")

func test_detector_facing_away_is_not_hit():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	# Same DOWN beam, but the detector faces DOWN -- the beam meets its back arc.
	var detector := make_block(DetectorScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.DOWN))
	var room := build_room([emitter, detector])
	assert_false(room.grid.grid[4][6].block.is_hit, "a beam hitting the back does not register")

func test_detector_stops_the_beam():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var detector := make_block(DetectorScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	var room := build_room([emitter, detector])
	assert_true(room.grid.grid[4][5].is_laser_active(), "beam reaches the cell before the detector")
	assert_false(room.grid.grid[4][7].is_laser_active(), "beam does not continue past the detector")

func test_detector_emits_detected_signal_on_recompute():
	# Room._ready() already resolved physics, so drive a fresh clear->detect edge
	# by toggling the emitter and watch the signal on the second pass.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var detector := make_block(DetectorScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	var room := build_room([emitter, detector])
	var d = room.grid.grid[4][6].block
	emitter.use()  # off
	room.grid.handle_laser_physics()
	assert_false(d.is_hit, "no beam while the emitter is off")
	watch_signals(d)
	emitter.use()  # on again
	room.grid.handle_laser_physics()
	assert_signal_emitted_with_parameters(d, "detected", [Util.LASER_COLOR.WHITE])
	assert_true(d.is_hit)

func test_detector_emits_cleared_when_beam_stops_reaching_it():
	# The detector starts hit; once the beam no longer reaches it, the falling
	# edge fires `cleared` so level code can react to it turning off.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var detector := make_block(DetectorScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	var room := build_room([emitter, detector])
	var d = room.grid.grid[4][6].block
	assert_true(d.is_hit, "detector starts hit")
	watch_signals(d)
	emitter.use()  # turn the emitter off so the beam no longer reaches the detector
	room.grid.handle_laser_physics()
	assert_false(d.is_hit, "detector no longer hit")
	assert_signal_emitted(d, "cleared")

# -------------------------------------------------------------- toggling
func test_toggling_emitter_off_clears_all_lasers():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var room := build_room([emitter])
	assert_gt(active_laser_count(room), 0, "lasers present while active")
	emitter.use()  # deactivate
	room.grid.handle_laser_physics()
	assert_eq(active_laser_count(room), 0, "no lasers after disabling emitter")
