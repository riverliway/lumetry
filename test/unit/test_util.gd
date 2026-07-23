extends GutTest
## Unit tests for global/util.gd (the `Util` autoload singleton).

const EPS := 0.0001

const ALL_DIRS := [
	Util.DIRECTION.UP, Util.DIRECTION.UP_RIGHT, Util.DIRECTION.DOWN_RIGHT,
	Util.DIRECTION.DOWN, Util.DIRECTION.DOWN_LEFT, Util.DIRECTION.UP_LEFT,
]

# ---------------------------------------------------------------- mod_float
func test_mod_float_basic_positive():
	assert_almost_eq(Util.mod_float(7.0, 3.0), 1.0, EPS)

func test_mod_float_value_below_divisor_is_unchanged():
	assert_almost_eq(Util.mod_float(2.0, 3.0), 2.0, EPS)

func test_mod_float_negative_keeps_sign():
	# The implementation reduces abs(a) then re-applies the sign of a.
	assert_almost_eq(Util.mod_float(-7.0, 3.0), -1.0, EPS)

func test_mod_float_zero():
	assert_almost_eq(Util.mod_float(0.0, 3.0), 0.0, EPS)

func test_mod_float_exact_multiple_returns_divisor():
	# NOTE: the loop condition is strict `> b`, so an exact multiple reduces to
	# `b` rather than 0. Documented here as current behavior.
	assert_almost_eq(Util.mod_float(6.0, 3.0), 3.0, EPS)

func test_mod_float_approx_matches_exact():
	assert_almost_eq(Util.mod_float(7.0, 3.0, true), 1.0, EPS)

# ------------------------------------------------------- find_index / find_elem
func test_find_index_first_match():
	assert_eq(Util.find_index([1, 2, 3, 4], func(x): return x == 3), [2])

func test_find_index_all_matches():
	assert_eq(Util.find_index([1, 2, 2, 3], func(x): return x == 2, false), [1, 2])

func test_find_index_no_match_is_empty():
	assert_eq(Util.find_index([1, 2], func(x): return x == 99), [])

func test_find_elem_returns_elements_not_indexes():
	assert_eq(Util.find_elem([10, 20, 20, 30], func(x): return x == 20, false), [20, 20])

func test_find_elem_first_only():
	assert_eq(Util.find_elem([10, 20, 30], func(x): return x >= 20), [20])

# -------------------------------------------------- direction <-> rotation
func test_rotation_from_direction_down_is_zero():
	assert_almost_eq(Util.get_rotation_from_direction(Util.DIRECTION.DOWN), 0.0, EPS)

func test_rotation_from_direction_up_is_pi():
	assert_almost_eq(Util.get_rotation_from_direction(Util.DIRECTION.UP), PI, EPS)

func test_direction_from_rotation_zero_is_down():
	assert_eq(Util.get_direction_from_rotation(0.0), Util.DIRECTION.DOWN)

func test_direction_from_rotation_pi_is_up():
	assert_eq(Util.get_direction_from_rotation(PI), Util.DIRECTION.UP)

func test_direction_rotation_roundtrips_for_all_six():
	for dir in ALL_DIRS:
		var rot := Util.get_rotation_from_direction(dir)
		assert_eq(Util.get_direction_from_rotation(rot), dir, "roundtrip for dir %d" % dir)

func test_direction_from_rotation_wraps_negative_angle():
	# -2*PI is the same as 0 -> DOWN
	assert_eq(Util.get_direction_from_rotation(-2.0 * PI), Util.DIRECTION.DOWN)

# ------------------------------------------------------- is_half_direction
func test_is_half_direction_false_for_cardinal():
	assert_false(Util.is_half_direction(0.0))

func test_is_half_direction_false_for_60_degrees():
	assert_false(Util.is_half_direction(PI / 3.0))

func test_is_half_direction_true_for_30_degrees():
	assert_true(Util.is_half_direction(PI / 6.0))

# ------------------------------------------------- rotate clockwise / ccw
func test_rotate_cw_once():
	assert_eq(Util.rotate_direction_clockwise(Util.DIRECTION.UP), Util.DIRECTION.UP_RIGHT)

func test_rotate_cw_full_loop_is_identity():
	assert_eq(Util.rotate_direction_clockwise(Util.DIRECTION.UP, 6), Util.DIRECTION.UP)

func test_rotate_cw_wraps_around():
	assert_eq(Util.rotate_direction_clockwise(Util.DIRECTION.UP_LEFT, 1), Util.DIRECTION.UP)

func test_rotate_cw_none_returns_none():
	assert_eq(Util.rotate_direction_clockwise(Util.DIRECTION.NONE), Util.DIRECTION.NONE)

func test_rotate_ccw_once():
	assert_eq(Util.rotate_direction_counterclockwise(Util.DIRECTION.UP), Util.DIRECTION.UP_LEFT)

func test_rotate_ccw_is_inverse_of_cw():
	for dir in ALL_DIRS:
		var moved := Util.rotate_direction_clockwise(dir, 1)
		assert_eq(Util.rotate_direction_counterclockwise(moved, 1), dir, "inverse for dir %d" % dir)

# ---------------------------------------------------------- reflect_direction
func test_reflect_passthrough_when_incoming_equals_facing():
	assert_eq(Util.reflect_direction(Util.DIRECTION.UP, Util.DIRECTION.UP), Util.DIRECTION.UP)

func test_reflect_passthrough_when_incoming_equals_flip():
	# The flip of UP is DOWN; a beam arriving along DOWN passes straight through.
	assert_eq(Util.reflect_direction(Util.DIRECTION.DOWN, Util.DIRECTION.UP), Util.DIRECTION.DOWN)

func test_reflect_long_mirror_known_case():
	assert_eq(
		Util.reflect_direction(Util.DIRECTION.UP, Util.DIRECTION.UP_RIGHT, true),
		Util.DIRECTION.DOWN_RIGHT
	)

func test_reflect_short_mirror_known_case():
	assert_eq(
		Util.reflect_direction(Util.DIRECTION.UP, Util.DIRECTION.UP_RIGHT, false),
		Util.DIRECTION.UP_LEFT
	)

func test_reflect_always_returns_a_valid_direction():
	for incoming in ALL_DIRS:
		for facing in ALL_DIRS:
			var out_long := Util.reflect_direction(incoming, facing, true)
			var out_short := Util.reflect_direction(incoming, facing, false)
			assert_true(out_long in ALL_DIRS, "long reflect valid")
			assert_true(out_short in ALL_DIRS, "short reflect valid")
