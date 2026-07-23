extends GutTest
## Unit tests for the Room.Grid inner class: hex-grid navigation, boundary
## handling, nearest-cell lookup, and find(). Navigation never touches the Room
## instance, so a null-returning resolver is sufficient.

const WIDTH := 23
const HEIGHT := 12

var _grid

## Minimal stand-in for a placeable block (Cell.set_block reads block_type,
## position and rotation). Not a real Track/RotationPad, so it lands as the
## cell's primary block, which is all find() needs.
class FakeBlock extends Node2D:
	var block_type
	func _init(type_value):
		block_type = type_value


func before_each():
	_grid = Room.Grid.new(func(): return null)


func cell(col: int, row: int):
	return _grid.grid[col][row]


func coords(c) -> Array:
	return [c.c, c.r] if c != null else []


# ----------------------------------------------------------- construction
func test_grid_dimensions():
	assert_eq(_grid.grid.size(), WIDTH)
	assert_eq(_grid.grid[0].size(), HEIGHT)

func test_cell_knows_its_own_indices():
	var c = cell(7, 3)
	assert_eq([c.c, c.r], [7, 3])

# --------------------------------------------------------- shift predicate
func test_odd_columns_are_shifted():
	assert_true(_grid.is_off_shifted(cell(1, 0)))
	assert_false(_grid.is_off_shifted(cell(2, 0)))

func test_edge_predicates():
	assert_true(_grid.is_top(cell(4, 0)), "top")
	assert_true(_grid.is_bottom(cell(4, HEIGHT - 1)), "bottom")
	assert_true(_grid.is_left(cell(0, 3)), "left")
	assert_true(_grid.is_right(cell(WIDTH - 1, 3)), "right")

# ---------------------------------------------------- neighbor navigation
func test_neighbors_from_even_column_interior():
	var c = cell(4, 5)
	assert_eq(coords(_grid.go(c, Util.DIRECTION.UP)), [4, 4], "up")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.DOWN)), [4, 6], "down")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.UP_LEFT)), [3, 4], "up_left")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.UP_RIGHT)), [5, 4], "up_right")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.DOWN_LEFT)), [3, 5], "down_left")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.DOWN_RIGHT)), [5, 5], "down_right")

func test_neighbors_from_odd_column_interior():
	var c = cell(5, 5)
	assert_eq(coords(_grid.go(c, Util.DIRECTION.UP)), [5, 4], "up")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.DOWN)), [5, 6], "down")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.UP_LEFT)), [4, 5], "up_left")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.UP_RIGHT)), [6, 5], "up_right")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.DOWN_LEFT)), [4, 6], "down_left")
	assert_eq(coords(_grid.go(c, Util.DIRECTION.DOWN_RIGHT)), [6, 6], "down_right")

func test_go_none_returns_same_cell():
	var c = cell(4, 5)
	assert_eq(_grid.go(c, Util.DIRECTION.NONE), c)

# --------------------------------------------------------- boundary nulls
func test_top_row_has_no_up():
	assert_null(_grid.go(cell(4, 0), Util.DIRECTION.UP))

func test_bottom_row_has_no_down():
	assert_null(_grid.go(cell(4, HEIGHT - 1), Util.DIRECTION.DOWN))

func test_left_column_has_no_up_left():
	assert_null(_grid.go(cell(0, 5), Util.DIRECTION.UP_LEFT))

func test_left_column_has_no_down_left():
	assert_null(_grid.go(cell(0, 5), Util.DIRECTION.DOWN_LEFT))

func test_right_column_has_no_up_right():
	assert_null(_grid.go(cell(WIDTH - 1, 5), Util.DIRECTION.UP_RIGHT))

func test_even_top_cell_has_no_upper_diagonals():
	assert_null(_grid.go(cell(2, 0), Util.DIRECTION.UP_LEFT), "up_left")
	assert_null(_grid.go(cell(2, 0), Util.DIRECTION.UP_RIGHT), "up_right")

func test_odd_bottom_cell_has_no_lower_diagonals():
	assert_null(_grid.go(cell(5, HEIGHT - 1), Util.DIRECTION.DOWN_LEFT), "down_left")
	assert_null(_grid.go(cell(5, HEIGHT - 1), Util.DIRECTION.DOWN_RIGHT), "down_right")

# ------------------------------------------------------ get_nearest_cell
func test_nearest_cell_at_even_center():
	assert_eq(coords(_grid.get_nearest_cell(cell(10, 4).pos)), [10, 4])

func test_nearest_cell_at_odd_center():
	assert_eq(coords(_grid.get_nearest_cell(cell(5, 5).pos)), [5, 5])

func test_nearest_cell_clamps_far_negative_to_origin():
	assert_eq(coords(_grid.get_nearest_cell(Vector2(-100000, -100000))), [0, 0])

func test_nearest_cell_clamps_far_positive_to_last_cell():
	assert_eq(coords(_grid.get_nearest_cell(Vector2(100000, 100000))), [WIDTH - 1, HEIGHT - 1])

# ------------------------------------------------------------------- find
func test_find_on_empty_grid_returns_empty():
	assert_eq(_grid.find(func(c): return c.get_block_type() == Util.BLOCK_TYPE.WALL), [])

func test_find_first_returns_col_row_pair():
	var block := FakeBlock.new(Util.BLOCK_TYPE.WALL)
	autofree(block)
	cell(3, 7).set_block(block)
	assert_eq(_grid.find(func(c): return c.get_block_type() == Util.BLOCK_TYPE.WALL), [3, 7])

func test_find_all_returns_flat_column_major_pairs():
	var b1 := FakeBlock.new(Util.BLOCK_TYPE.WALL)
	var b2 := FakeBlock.new(Util.BLOCK_TYPE.WALL)
	autofree(b1)
	autofree(b2)
	cell(0, 0).set_block(b1)
	cell(1, 0).set_block(b2)
	assert_eq(
		_grid.find(func(c): return c.get_block_type() == Util.BLOCK_TYPE.WALL, false),
		[0, 0, 1, 0]
	)
