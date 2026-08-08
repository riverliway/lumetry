extends "res://test/fixtures/game_test.gd"
## Integration tests for the traveling-beam reveal (GEN-562). Physics resolve
## instantly -- a segment is visible (is_active) the same tick it is lit, so
## detectors and movement are unaffected -- but a newly-lit segment is held
## transparent (modulate.a == 0) and faded in over time, staggered by how far
## past the divergence point it sits. An unchanged stretch of beam is not
## re-animated. Reveal timing is driven by Room._process(delta), which the tests
## step manually rather than waiting on real frames.


const RotationPadScene: PackedScene = preload("res://tileset/rotation/rotation_pad.tscn")


## Every currently-lit laser segment in the room (straight, mirror, prism, stub).
func _lit_segments(room: Room) -> Array:
	var segs := []
	for child in room.get_children():
		if (child is LaserSegment or child is MirrorSegment or child is PrismSegment) and child.visible:
			segs.push_back(child)
	return segs


## How many lit segments are still transparent (mid-reveal).
func _transparent_count(room: Room) -> int:
	var n := 0
	for seg in _lit_segments(room):
		if seg.modulate.a < 1.0:
			n += 1
	return n


# ------------------------------------------------------------- load is instant
func test_load_resolve_shows_every_beam_opaque_at_once():
	# Room._ready resolves before the player is connected, so the level opens with
	# its beams already drawn -- nothing should be mid-reveal.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var room := build_room([emitter])
	assert_gt(_lit_segments(room).size(), 0, "the beam is drawn on load")
	assert_eq(_transparent_count(room), 0, "no segment is left transparent on load")
	assert_true(room._laser_reveals.is_empty(), "nothing queued to reveal on load")


# ------------------------------------------------- a fresh beam travels forward
func test_turning_a_beam_on_staggers_the_new_cells():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var room := build_room([emitter])
	emitter.use()  # off
	room.grid.handle_laser_physics()
	assert_eq(active_laser_count(room), 0, "beam cleared while off")

	emitter.use()  # on again -- now player-driven, so it animates
	room.grid.handle_laser_physics()
	# Physics is instant: the cells are logically lit right away...
	assert_true(room.grid.grid[4][11].is_laser_active(), "far cell is logically lit at once")
	# ...but the freshly lit cells past the first are still fading in.
	assert_gt(_transparent_count(room), 0, "newly lit cells start transparent")
	assert_false(room._laser_reveals.is_empty(), "reveals are queued")


func test_reveal_finishes_after_enough_time_passes():
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var room := build_room([emitter])
	emitter.use(); room.grid.handle_laser_physics()   # off
	emitter.use(); room.grid.handle_laser_physics()    # on (animating)
	assert_gt(_transparent_count(room), 0, "starts mid-reveal")

	room._process(10.0)  # fast-forward well past every scheduled delay
	assert_eq(_transparent_count(room), 0, "every segment is opaque once the clock runs out")
	assert_true(room._laser_reveals.is_empty(), "reveal queue drains")


# --------------------------------------------- the diff: unchanged stays put
func test_an_unchanged_beam_is_not_reanimated():
	# Re-resolving without changing anything must leave the beam fully opaque and
	# queue no reveals -- only genuinely new cells animate.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var room := build_room([emitter])
	room.grid.handle_laser_physics()  # player-driven, but identical to the load state
	assert_eq(_transparent_count(room), 0, "an unchanged beam does not fade back in")
	assert_true(room._laser_reveals.is_empty(), "nothing queued for an unchanged beam")


# ------------------------------------------------- the intro replays from dark
func test_intro_reveals_the_whole_beam_from_dark():
	# The level intro (Room.play_intro -> Grid.begin_intro) forces the next resolve to
	# animate the entire board in from dark, even though the load resolve already drew
	# it opaque and nothing about the beam changed -- the opposite of the unchanged
	# beam above. This is what makes the beams travel in when a level opens.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var room := build_room([emitter])
	assert_eq(_transparent_count(room), 0, "the load resolve left the beam opaque")

	room.grid.begin_intro()
	room.grid.handle_laser_physics()
	assert_gt(_transparent_count(room), 0, "the intro re-hides the beam and staggers it in")
	assert_false(room._laser_reveals.is_empty(), "the intro queues staggered reveals")

	room._process(10.0)  # fast-forward past every scheduled delay
	assert_eq(_transparent_count(room), 0, "the intro reveal finishes: every segment opaque")
	assert_true(room._laser_reveals.is_empty(), "the intro reveal queue drains")


func test_only_the_newly_extended_cells_reanimate():
	# Extending a beam's range must leave the already-lit stretch opaque and only
	# fade in the cells past where it used to stop -- the divergence point.
	var emitter := make_block(EmitterScene, 4, 3)  # faces DOWN
	emitter.laser_range = 3  # lights (4,4), (4,5), (4,6)
	var room := build_room([emitter])
	room._process(10.0)  # settle the load reveal
	assert_true(room.grid.grid[4][6].is_laser_active(), "beam stops at range 3")
	assert_false(room.grid.grid[4][7].is_laser_active(), "cell past the old range is dark")

	emitter.laser_range = 6  # now reaches (4,9)
	room.grid.handle_laser_physics()

	# The original stretch is unchanged, so it never blinks off.
	assert_eq(room.grid.grid[4][5].laser[0].modulate.a, 1.0, "unchanged cell within the old range stays opaque")
	# The extension is genuinely new, so it travels in.
	assert_true(room.grid.grid[4][9].is_laser_active(), "beam now reaches the extended range")
	assert_gt(_transparent_count(room), 0, "the newly reached cells fade in")


# ----------------------------------- a detector reports in step with the beam
func test_a_detector_reports_its_hit_only_once_the_beam_reveals():
	# A detector's `detected` -- which a level uses to light a wire or power a linked
	# emitter -- must wait until the traveling beam visually reaches it, not fire the
	# instant physics resolves (so a mechanism doesn't react ahead of the beam).
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var detector := make_block(DetectorScene, 4, 8, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	var room := build_room([emitter, detector], Vector2i(20, 0))
	var d = room.grid.grid[4][8].block
	emitter.use(); room.grid.handle_laser_physics(); room._process(10.0)  # settle the beam OFF
	watch_signals(d)

	emitter.use(); room.grid.handle_laser_physics()  # ON -- the beam travels toward it
	assert_true(d.is_hit, "the hit settles logically the same tick the beam is drawn")
	assert_signal_not_emitted(d, "detected", "but it is not reported before the beam arrives")

	room._process(10.0)  # let the beam finish travelling to the detector
	assert_signal_emitted(d, "detected", "reported once the beam has reached it")


func test_a_hit_that_breaks_before_it_reveals_is_never_reported():
	# If the beam stops reaching the detector before its reveal completes (the player
	# re-resolved in between), the pending report is dropped -- the wire/device it
	# would drive must not blip on for a beam the player never actually saw connect.
	var emitter := make_block(EmitterScene, 4, 3)
	emitter.laser_range = -1
	var detector := make_block(DetectorScene, 4, 8, Util.get_rotation_from_direction(Util.DIRECTION.UP))
	var room := build_room([emitter, detector], Vector2i(20, 0))
	var d = room.grid.grid[4][8].block
	emitter.use(); room.grid.handle_laser_physics(); room._process(10.0)  # settle OFF
	watch_signals(d)

	emitter.use(); room.grid.handle_laser_physics()  # ON -- report pending mid-reveal
	emitter.use(); room.grid.handle_laser_physics()  # OFF again before the beam arrived
	room._process(10.0)

	assert_signal_not_emitted(d, "detected", "a hit that never revealed is never reported")
	assert_false(d.is_hit, "and it ends logically un-hit")


# ---------------------- a moving block keeps its old beam through the first half
func test_rotating_a_pad_keeps_the_old_beam_until_the_spin_is_half_done():
	# An emitter on a rotation pad fires straight down. Rotating it re-aims the beam,
	# but the old straight-down beam must stay on screen while the block turns -- the
	# re-light is deferred, not run the instant the pad is used.
	var emitter := make_block(EmitterScene, 5, 6)
	emitter.laser_range = -1
	var pad := make_block(RotationPadScene, 5, 6)
	var room := build_room([emitter, pad], Vector2i(5, 5))
	room._process(10.0)  # settle the initial straight-down beam
	assert_true(room.grid.grid[5][7].is_laser_active(), "beam starts travelling straight down")

	room.rotate_pad(pad)

	# The re-light has not run: the old straight-down beam still shows, fully opaque,
	# and a deferred resolve is queued for the spin's midpoint.
	assert_true(room.grid.grid[5][7].is_laser_active(), "the old straight-down beam holds at first")
	assert_eq(_transparent_count(room), 0, "the held beam is fully shown, nothing mid-reveal")
	assert_false(room._reveal_callbacks.is_empty(), "the re-light is deferred, not run yet")

	# Still holding just before the midpoint...
	room._process(pad._ROTATION_DURATION / 2.0 - 0.05)
	assert_true(room.grid.grid[5][7].is_laser_active(), "old beam still shown before the midpoint")


func test_the_reaimed_beam_relights_and_travels_in_after_the_midpoint():
	var emitter := make_block(EmitterScene, 5, 6)
	emitter.laser_range = -1
	var pad := make_block(RotationPadScene, 5, 6)
	var room := build_room([emitter, pad], Vector2i(5, 5))
	room._process(10.0)  # settle the initial beam

	room.rotate_pad(pad)
	room._process(pad._ROTATION_DURATION / 2.0 + 0.05)  # cross the midpoint -> re-light runs

	# The old straight path is gone and the re-aimed beam is now lit and travelling in.
	assert_false(room.grid.grid[5][7].is_laser_active(), "the old straight path cleared once the re-light ran")
	assert_gt(active_laser_count(room), 0, "the re-aimed beam is lit in its new direction")
	assert_gt(_transparent_count(room), 0, "and it fades in from the divergence point")

	room._process(10.0)  # let it finish travelling
	assert_eq(_transparent_count(room), 0, "the re-aimed beam fully shows")
	assert_true(room._laser_reveals.is_empty(), "the reveal queue drains")
