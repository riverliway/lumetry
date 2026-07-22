extends GutTest
## Unit tests for tileset/laser/laser_segment.gd.

const SegmentScene: PackedScene = preload("res://tileset/laser/laser_segment.tscn")

func make_segment():
	var seg = SegmentScene.instantiate()
	add_child_autofree(seg)  # needed so @onready from/to initialize
	return seg


func test_clear_laser_deactivates():
	var seg = make_segment()
	seg.clear_laser()
	assert_false(seg.is_active())

func test_set_laser_activates():
	var seg = make_segment()
	seg.clear_laser()
	seg.set_laser(Util.DIRECTION.UP, Util.DIRECTION.DOWN, Util.LASER_COLOR.CYAN)
	assert_true(seg.is_active())

func test_set_laser_records_direction_and_color():
	var seg = make_segment()
	seg.set_laser(Util.DIRECTION.UP_LEFT, Util.DIRECTION.DOWN_RIGHT, Util.LASER_COLOR.MAGENTA)
	assert_eq(seg.from, Util.DIRECTION.UP_LEFT, "from")
	assert_eq(seg.to, Util.DIRECTION.DOWN_RIGHT, "to")
	assert_eq(seg.color, Util.LASER_COLOR.MAGENTA, "color")

func test_straight_through_beam_aligns_rotation_to_exit():
	var seg = make_segment()
	# UP -> DOWN is a straight line (opposite directions); rotation snaps to 'to'.
	seg.set_laser(Util.DIRECTION.UP, Util.DIRECTION.DOWN, Util.LASER_COLOR.WHITE)
	assert_almost_eq(seg.rotation, Util.get_rotation_from_direction(Util.DIRECTION.DOWN), 0.0001)
