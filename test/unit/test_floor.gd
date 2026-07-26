extends GutTest
## Unit tests for tileset/floor/floor.gd -- a decorative floor tile that dims itself
## on _ready() when its `is_background` flag is set, marking the non-playable border
## cells. (The base Level also dims wall-cell floor tiles at runtime; that path is
## covered in test/integration/test_level_1.gd.)

const FloorScript := preload("res://tileset/floor/floor.gd")

## The dim tint floor.gd applies when is_background is true.
const BACKGROUND_TINT := Color("ffffff26")


func _make_tile(is_background: bool) -> Sprite2D:
	var tile := Sprite2D.new()
	tile.set_script(FloorScript)
	tile.is_background = is_background
	add_child_autofree(tile)  # _ready runs on entering the tree
	return tile


func test_background_tile_is_dimmed():
	var tile := _make_tile(true)
	assert_eq(tile.modulate, BACKGROUND_TINT, "background tile is dimmed on ready")
	assert_lt(tile.modulate.a, 1.0, "and is translucent")


func test_foreground_tile_is_untouched():
	var tile := _make_tile(false)
	assert_eq(tile.modulate, Color.WHITE, "a normal floor tile keeps full brightness")
