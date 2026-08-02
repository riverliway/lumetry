extends "res://test/fixtures/game_test.gd"
## Integration tests for the traveling-beam reveal (GEN-562). Physics resolve
## instantly -- a segment is visible (is_active) the same tick it is lit, so
## detectors and movement are unaffected -- but a newly-lit segment is held
## transparent (modulate.a == 0) and faded in over time, staggered by how far
## past the divergence point it sits. An unchanged stretch of beam is not
## re-animated. Reveal timing is driven by Room._process(delta), which the tests
## step manually rather than waiting on real frames.


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
