extends GutTest
## Unit tests for the Room.Cell inner class: block placement/removal, terrain
## stacking (tracks & rotation pads), and short->long mirror promotion.

const TrackScene: PackedScene = preload("res://tileset/track/track.tscn")
const RotationPadScene: PackedScene = preload("res://tileset/rotation/rotation_pad.tscn")

## Stand-in for simple blocks. get_track()/get_rotation_pad() have typed returns
## (Track/RotationPad) so those cases use the real scenes instead of this fake.
class FakeBlock extends Node2D:
	var block_type
	func _init(type_value):
		block_type = type_value


func make_cell():
	return Room.Cell.new(Vector2(100, 200), 3, 4, func(): return null)


# ------------------------------------------------------------- empty state
func test_empty_cell_reports_none():
	assert_eq(make_cell().get_block_type(), Util.BLOCK_TYPE.NONE)

# ---------------------------------------------------- primary block set/remove
func test_set_block_records_type_and_snaps_position():
	var c = make_cell()
	var block := FakeBlock.new(Util.BLOCK_TYPE.WALL)
	autofree(block)
	c.set_block(block)
	assert_eq(c.get_block_type(), Util.BLOCK_TYPE.WALL, "type")
	assert_eq(block.position, Vector2(100, 200), "snapped to cell center")

func test_remove_block_resets_to_none():
	var c = make_cell()
	var block := FakeBlock.new(Util.BLOCK_TYPE.WALL)
	autofree(block)
	c.set_block(block)
	c.remove_block()
	assert_eq(c.get_block_type(), Util.BLOCK_TYPE.NONE)

# ------------------------------------------------------ terrain stacking
func test_track_stacks_as_terrain_not_primary_block():
	var c = make_cell()
	var track := TrackScene.instantiate()
	autofree(track)
	c.set_block(track)
	assert_eq(c.get_block_type(), Util.BLOCK_TYPE.NONE, "cell's primary block stays empty")
	assert_eq(c.get_track(), track, "track retrievable as terrain")

func test_rotation_pad_stacks_as_terrain():
	var c = make_cell()
	var pad := RotationPadScene.instantiate()
	autofree(pad)
	c.set_block(pad)
	assert_eq(c.get_rotation_pad(), pad)

func test_get_track_null_when_absent():
	assert_null(make_cell().get_track())

func test_get_rotation_pad_null_when_absent():
	assert_null(make_cell().get_rotation_pad())

# ------------------------------------------------- mirror short/long promotion
func test_axis_aligned_mirror_stays_short():
	var c = make_cell()
	var mirror := FakeBlock.new(Util.BLOCK_TYPE.MIRROR_SHORT)
	autofree(mirror)
	mirror.rotation = 0.0  # cardinal -> not a half direction
	c.set_block(mirror)
	assert_eq(mirror.block_type, Util.BLOCK_TYPE.MIRROR_SHORT)

func test_half_angled_mirror_promoted_to_long():
	var c = make_cell()
	var mirror := FakeBlock.new(Util.BLOCK_TYPE.MIRROR_SHORT)
	autofree(mirror)
	mirror.rotation = PI / 6.0  # 30 deg -> half direction
	c.set_block(mirror)
	assert_eq(mirror.block_type, Util.BLOCK_TYPE.MIRROR_LONG)
