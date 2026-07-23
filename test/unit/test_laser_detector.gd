extends "res://test/fixtures/game_test.gd"
## Unit tests for the laser detector block: its edge-triggered hit signals and
## the front-arc geometry that decides which incoming beams count as a hit.

var _grid


func before_each():
	_grid = Room.Grid.new(func(): return null)


# ---------------------------------------------------------------- block API
func test_block_type_is_detector():
	var d = DetectorScene.instantiate()
	assert_eq(d.block_type, Util.BLOCK_TYPE.LASER_DETECTOR)
	d.free()

func test_starts_not_hit():
	var d = DetectorScene.instantiate()
	assert_false(d.is_hit)
	d.free()

func test_detected_fires_with_color_on_rising_edge():
	var d = DetectorScene.instantiate()
	watch_signals(d)
	d.begin_pass()
	d.mark_hit(Util.LASER_COLOR.CYAN)
	d.end_pass()
	assert_true(d.is_hit, "hit state set")
	assert_eq(d.hit_color, Util.LASER_COLOR.CYAN, "records the striking color")
	assert_signal_emitted_with_parameters(d, "detected", [Util.LASER_COLOR.CYAN])
	d.free()

func test_detected_not_reemitted_while_still_hit():
	var d = DetectorScene.instantiate()
	d.begin_pass(); d.mark_hit(Util.LASER_COLOR.WHITE); d.end_pass()
	watch_signals(d)
	d.begin_pass(); d.mark_hit(Util.LASER_COLOR.WHITE); d.end_pass()
	assert_signal_not_emitted(d, "detected")
	assert_true(d.is_hit)
	d.free()

func test_cleared_fires_when_beam_leaves():
	var d = DetectorScene.instantiate()
	d.begin_pass(); d.mark_hit(Util.LASER_COLOR.WHITE); d.end_pass()
	watch_signals(d)
	d.begin_pass()  # no mark_hit this pass
	d.end_pass()
	assert_false(d.is_hit)
	assert_signal_emitted(d, "cleared")
	d.free()

func test_no_signals_when_never_hit():
	var d = DetectorScene.instantiate()
	watch_signals(d)
	d.begin_pass()
	d.end_pass()
	assert_signal_not_emitted(d, "detected")
	assert_signal_not_emitted(d, "cleared")
	d.free()


# ---------------------------------------------------------- front-arc geometry
func test_front_arc_is_facing_plus_two_neighbors():
	# A detector facing UP is sensitive to beams arriving from UP and its two
	# neighbors (UP_LEFT / UP_RIGHT) -- the front half of the hex.
	var dirs = _grid.detector_hit_directions(Util.DIRECTION.UP)
	assert_eq(dirs.size(), 3)
	assert_true(dirs.has(Util.DIRECTION.UP), "faces UP")
	assert_true(dirs.has(Util.DIRECTION.UP_LEFT), "left neighbor")
	assert_true(dirs.has(Util.DIRECTION.UP_RIGHT), "right neighbor")

func test_back_arc_never_triggers():
	# The opposite three directions (the back half) are excluded for every facing.
	for facing in [Util.DIRECTION.UP, Util.DIRECTION.DOWN, Util.DIRECTION.UP_LEFT,
			Util.DIRECTION.UP_RIGHT, Util.DIRECTION.DOWN_LEFT, Util.DIRECTION.DOWN_RIGHT]:
		var front = _grid.detector_hit_directions(facing)
		assert_false(front.has(Util.rotate_direction_clockwise(facing, 2)), "back-left of %d excluded" % facing)
		assert_false(front.has(Util.rotate_direction_clockwise(facing, 3)), "back of %d excluded" % facing)
		assert_false(front.has(Util.rotate_direction_clockwise(facing, 4)), "back-right of %d excluded" % facing)
