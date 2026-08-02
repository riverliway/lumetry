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

func test_crate_stops_the_beam():
	# Unlike a wall, a crate is opaque: the beam reaches it and stops dead rather
	# than passing through.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var crate := make_block(CrateScene, 4, 6)
	var room := build_room([emitter, crate], Vector2i(20, 0))
	assert_true(room.grid.grid[4][5].is_laser_active(), "beam reaches the cell before the crate")
	assert_false(room.grid.grid[4][6].is_laser_active(), "crate cell has no straight beam segment")
	assert_false(room.grid.grid[4][7].is_laser_active(), "beam does not continue past the crate")

func test_crate_cell_draws_a_half_beam_where_light_strikes_it():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var crate := make_block(CrateScene, 4, 6)
	var room := build_room([emitter, crate], Vector2i(20, 0))
	var ccell = room.grid.grid[4][6]
	var active = ccell.half_laser.filter(func(cs): return cs.is_active())
	assert_eq(active.size(), 1, "crate cell draws one flat-cut half-beam for the incoming light")

func test_crate_also_stops_a_colored_beam():
	# A prism upstream splits white light into colors; a colored beam is opaque to
	# the crate just as the white one is.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var prism := make_block(PrismScene, 4, 5)
	# The prism's straight (magenta) output travels DOWN into the crate below it.
	var crate := make_block(CrateScene, 4, 7)
	var room := build_room([emitter, prism, crate], Vector2i(20, 0))
	assert_true(room.grid.grid[4][6].is_laser_active(), "magenta beam reaches the cell before the crate")
	assert_false(room.grid.grid[4][8].is_laser_active(), "colored beam does not pass through the crate")
	var active = room.grid.grid[4][7].half_laser.filter(func(cs): return cs.is_active())
	assert_eq(active.size(), 1, "crate draws its half-beam for the colored strike too")

func test_emitter_cell_draws_a_half_beam_emerging_from_its_face():
	# The raycast starts one cell out, so the emitter cell has no straight segment;
	# a flat-cut half-beam fills it so the beam looks like it leaves the emitter.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var room := build_room([emitter])
	var active = room.grid.grid[4][3].half_laser.filter(func(hs): return hs.is_active())
	assert_eq(active.size(), 1, "emitter cell draws one flat-cut half-beam emerging from its face")

func test_detector_cell_draws_a_half_beam_where_light_strikes_it():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var detector := make_block(DetectorScene, 4, 6)
	var room := build_room([emitter, detector], Vector2i(20, 0))
	var active = room.grid.grid[4][6].half_laser.filter(func(hs): return hs.is_active())
	assert_eq(active.size(), 1, "detector cell draws one flat-cut half-beam for the incoming light")

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

func test_finite_beam_fades_out_at_its_tip():
	# The last cell of a finite beam draws the dissolving-tail sprite (the "fade"
	# animation); the cells before it stay solid.
	var emitter := make_block(EmitterScene, 4, 2)
	emitter.laser_range = 3  # lights (4,3), (4,4), (4,5)
	var room := build_room([emitter])
	assert_eq(room.grid.grid[4][3].laser[0].animation, &"white", "first cell is solid")
	assert_eq(room.grid.grid[4][4].laser[0].animation, &"white", "middle cell is solid")
	assert_eq(room.grid.grid[4][5].laser[0].animation, &"fade", "the tip cell dissolves")

func test_infinite_beam_never_fades():
	# An infinite beam ends at a block or the grid edge, never by range, so no cell
	# of it is ever the dissolving tail.
	var emitter := make_block(EmitterScene, 4, 2)
	emitter.laser_range = -1
	var room := build_room([emitter])
	assert_eq(room.grid.grid[4][11].laser[0].animation, &"white",
		"the beam reaches the edge solid, not faded")

func test_fade_tip_takes_precedence_over_a_mirror_just_out_of_range():
	# A finite beam that runs out one cell short of a mirror fades at its tip and
	# never bounces -- the range is spent before the beam reaches the mirror.
	var emitter := make_block(EmitterScene, 4, 2)
	emitter.laser_range = 2  # lights (4,3), (4,4); the mirror at (4,5) is out of reach
	var mirror := make_block(MirrorScene, 4, 5, PI / 3.0)
	var room := build_room([emitter, mirror])
	assert_eq(room.grid.grid[4][4].laser[0].animation, &"fade", "the tip fades one cell short of the mirror")
	assert_eq(room.grid.grid[4][5].mirror_laser.filter(func(m): return m.is_active()).size(), 0,
		"the mirror never bounces a beam that did not reach it")

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

func test_mirror_struck_by_two_beams_draws_both_bounces():
	# GEN-573: one mirror hit by two separate beams in the same resolve must render
	# BOTH bounces, not just the last. The short mirror at (4,5) faces DOWN_LEFT; a
	# beam arriving DOWN (from the emitter above) reflects to UP_LEFT, and a beam
	# arriving UP (from the emitter below) reflects to DOWN_RIGHT -- each drawing its
	# own pair of half-beam segments, for four in the cell.
	var top := make_block(EmitterScene, 4, 3)  # faces DOWN
	top.laser_range = -1
	var bottom := make_block(EmitterScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	bottom.laser_range = -1
	var mirror := make_block(MirrorScene, 4, 5, PI / 3.0)
	# Park the player clear of the DOWN_RIGHT reflected beam (it would pass (5,5)).
	var room := build_room([top, bottom, mirror], Vector2i(20, 0))
	var mcell = room.grid.grid[4][5]
	var active = mcell.mirror_laser.filter(func(m): return m.is_active())
	assert_eq(active.size(), 4, "two beams bouncing off one mirror draw two segments each")

func test_mirror_hit_edge_on_terminates_the_beam_with_a_half_segment():
	# A beam travelling straight into a short mirror whose surface runs along the same
	# axis can't reflect. Rather than vanishing a cell short, the beam terminates
	# inside the mirror with a flat-cut half-beam, exactly like a crate or detector.
	var emitter := make_block(EmitterScene, 4, 3)  # faces DOWN
	emitter.laser_range = -1
	var mirror := make_block(MirrorScene, 4, 5)  # rotation 0 -> short mirror facing DOWN (vertical)
	var room := build_room([emitter, mirror], Vector2i(20, 0))
	var mcell = room.grid.grid[4][5]
	assert_eq(mcell.mirror_laser.filter(func(m): return m.is_active()).size(), 0,
		"an un-reflectable hit draws no bounce segments")
	assert_eq(mcell.half_laser.filter(func(h): return h.is_active()).size(), 1,
		"the beam ends inside the mirror with one flat-cut half-beam, like a crate")
	assert_true(room.grid.grid[4][4].is_laser_active(), "beam reaches the cell before the mirror")
	assert_false(room.grid.grid[4][6].is_laser_active(), "and does not continue past it")

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
	# The hit settles logically at once, but `detected` waits until the traveling
	# beam has visually reached the detector -- step the reveal clock to get there.
	assert_true(d.is_hit, "logically hit the same tick the beam is drawn")
	room._process(10.0)
	assert_signal_emitted_with_parameters(d, "detected", [Util.LASER_COLOR.WHITE])

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

# ------------------------------------------------- laser focuser / destructive
# A focuser at (4,6) facing DOWN takes inputs through its three back ports (UP,
# UP_LEFT, UP_RIGHT) and emits a destructive beam downward. Each requested port
# is fed by a white emitter one cell away, aimed into the focuser.
func _focuser_with_feeders(ports_to_feed: Array) -> Array:
	var blocks := [make_block(FocuserScene, 4, 6, Util.get_rotation_from_direction(Util.DIRECTION.DOWN))]
	var feeders := {
		Util.DIRECTION.UP:       [Vector2i(4, 5), Util.DIRECTION.DOWN],
		Util.DIRECTION.UP_LEFT:  [Vector2i(3, 5), Util.DIRECTION.DOWN_RIGHT],
		Util.DIRECTION.UP_RIGHT: [Vector2i(5, 5), Util.DIRECTION.DOWN_LEFT],
	}
	for port in ports_to_feed:
		var spec = feeders[port]
		var e := make_block(EmitterScene, spec[0].x, spec[0].y, Util.get_rotation_from_direction(spec[1]))
		e.laser_range = -1
		blocks.push_back(e)
	return blocks

func test_focuser_with_three_inputs_emits_a_destructive_beam():
	var blocks := _focuser_with_feeders([Util.DIRECTION.UP, Util.DIRECTION.UP_LEFT, Util.DIRECTION.UP_RIGHT])
	var room := build_room(blocks, Vector2i(20, 0))
	assert_true(room.grid.grid[4][6].block.is_ready(), "all three back ports fed")
	assert_true(room.grid.grid[4][7].is_laser_active(), "destructive beam leaves the front")
	assert_true(active_laser_colors(room).has(Util.LASER_COLOR.DESTRUCTIVE), "output beam is destructive")

func test_focuser_missing_an_input_stays_inert():
	var blocks := _focuser_with_feeders([Util.DIRECTION.UP, Util.DIRECTION.UP_LEFT])  # only two
	var room := build_room(blocks, Vector2i(20, 0))
	assert_false(room.grid.grid[4][6].block.is_ready(), "only two ports fed")
	assert_false(active_laser_colors(room).has(Util.LASER_COLOR.DESTRUCTIVE), "no destructive output")

func test_destructive_beam_melts_a_block_then_light_repropagates():
	var blocks := _focuser_with_feeders([Util.DIRECTION.UP, Util.DIRECTION.UP_LEFT, Util.DIRECTION.UP_RIGHT])
	blocks.push_back(make_block(MeltableScene, 4, 8))  # two cells down, in the beam path
	var room := build_room(blocks, Vector2i(20, 0))
	assert_eq(room.grid.grid[4][8].get_block_type(), Util.BLOCK_TYPE.NONE, "the meltable block was melted away")
	assert_true(room.grid.grid[4][9].is_laser_active(), "beam continues past the freshly cleared cell")

func test_ordinary_beam_does_not_melt_a_meltable_block():
	var emitter := make_block(EmitterScene, 4, 3)  # faces DOWN
	emitter.laser_range = -1
	var meltable := make_block(MeltableScene, 4, 6)
	var room := build_room([emitter, meltable], Vector2i(20, 0))
	assert_eq(room.grid.grid[4][6].get_block_type(), Util.BLOCK_TYPE.MELTABLE, "white light leaves it intact")
	assert_false(room.grid.grid[4][7].is_laser_active(), "and the meltable blocks ordinary light")

# -------------------------------------------------------------- toggling
func test_toggling_emitter_off_clears_all_lasers():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var room := build_room([emitter])
	assert_gt(active_laser_count(room), 0, "lasers present while active")
	emitter.use()  # deactivate
	room.grid.handle_laser_physics()
	assert_eq(active_laser_count(room), 0, "no lasers after disabling emitter")
