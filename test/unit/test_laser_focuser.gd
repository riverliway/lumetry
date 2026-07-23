extends "res://test/fixtures/game_test.gd"
## Unit tests for the laser focuser block (three-in / one-out) and its back-port
## geometry -- the mirror image of the detector's front arc.

var _grid


func before_each():
	_grid = Room.Grid.new(func(): return null)


# ---------------------------------------------------------------- block API
func test_block_type_is_focuser():
	var f = FocuserScene.instantiate()
	assert_eq(f.block_type, Util.BLOCK_TYPE.LASER_FOCUSER)
	f.free()

func test_not_ready_until_three_ports_fed():
	var f = FocuserScene.instantiate()
	f.reset_ports()
	assert_false(f.is_ready(), "no ports fed")
	f.feed_port(Util.DIRECTION.UP, Util.LASER_COLOR.CYAN)
	f.feed_port(Util.DIRECTION.UP_LEFT, Util.LASER_COLOR.MAGENTA)
	assert_false(f.is_ready(), "two ports fed")
	f.feed_port(Util.DIRECTION.UP_RIGHT, Util.LASER_COLOR.YELLOW)
	assert_true(f.is_ready(), "all three ports fed")
	f.free()

func test_feeding_the_same_port_twice_counts_once():
	var f = FocuserScene.instantiate()
	f.reset_ports()
	f.feed_port(Util.DIRECTION.UP, Util.LASER_COLOR.CYAN)
	f.feed_port(Util.DIRECTION.UP, Util.LASER_COLOR.MAGENTA)
	assert_false(f.is_ready(), "only one distinct port is fed")
	f.free()

func test_reset_ports_clears_inputs_and_emitted_flag():
	var f = FocuserScene.instantiate()
	f.feed_port(Util.DIRECTION.UP, Util.LASER_COLOR.WHITE)
	f.has_emitted = true
	f.reset_ports()
	assert_false(f.is_ready(), "inputs cleared")
	assert_false(f.has_emitted, "emitted flag cleared")
	f.free()

func test_destructive_has_a_distinct_beam_tint():
	assert_true(LaserSegment.LASER_MODULATE.has(Util.LASER_COLOR.DESTRUCTIVE),
		"the destructive beam has its own tint")


# ---------------------------------------------------------- back-port geometry
func test_back_ports_are_opposite_facing_plus_neighbors():
	# Facing DOWN -> output goes down, so inputs arrive from the UP side.
	var ports = _grid.focuser_back_ports(Util.DIRECTION.DOWN)
	assert_eq(ports.size(), 3)
	assert_true(ports.has(Util.DIRECTION.UP), "direct back port")
	assert_true(ports.has(Util.DIRECTION.UP_LEFT), "back-left port")
	assert_true(ports.has(Util.DIRECTION.UP_RIGHT), "back-right port")

func test_back_ports_exclude_the_front_output_arc():
	# The three back ports never overlap the front arc (facing + its neighbors),
	# so a beam can't both feed a port and hit the output side.
	for facing in [Util.DIRECTION.UP, Util.DIRECTION.DOWN, Util.DIRECTION.UP_LEFT,
			Util.DIRECTION.UP_RIGHT, Util.DIRECTION.DOWN_LEFT, Util.DIRECTION.DOWN_RIGHT]:
		var ports = _grid.focuser_back_ports(facing)
		assert_false(ports.has(facing), "facing %d not a port" % facing)
		assert_false(ports.has(Util.rotate_direction_clockwise(facing)), "front-cw of %d not a port" % facing)
		assert_false(ports.has(Util.rotate_direction_counterclockwise(facing)), "front-ccw of %d not a port" % facing)
