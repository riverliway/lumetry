extends GutTest
## Unit tests for tileset/laser/mirror_segment.gd -- the half-beam sprite drawn
## inside a mirror cell. It picks the short/long cut, tints it via the shared
## LaserSegment.LASER_MODULATE table, and places it with the Transform2D the grid
## computed. (The bounce geometry itself is covered in test_laser_physics.gd.)

const MirrorSegmentScene: PackedScene = preload("res://tileset/laser/mirror_segment.tscn")


func _make():
	var seg = MirrorSegmentScene.instantiate()
	add_child_autofree(seg)
	return seg


func test_clear_laser_deactivates():
	var seg = _make()
	seg.clear_laser()
	assert_false(seg.is_active())


func test_set_mirror_activates():
	var seg = _make()
	seg.clear_laser()
	seg.set_mirror(false, Util.LASER_COLOR.WHITE, Transform2D.IDENTITY)
	assert_true(seg.is_active())


func test_short_and_long_pick_their_animation():
	var seg = _make()
	seg.set_mirror(false, Util.LASER_COLOR.WHITE, Transform2D.IDENTITY)
	assert_eq(seg.animation, "short", "short bounce uses the short cut")
	seg.set_mirror(true, Util.LASER_COLOR.WHITE, Transform2D.IDENTITY)
	assert_eq(seg.animation, "long", "long bounce uses the long cut")


func test_set_mirror_applies_the_transform():
	var seg = _make()
	var xf := Transform2D(0.5, Vector2(120, -30))  # rotation + position
	seg.set_mirror(true, Util.LASER_COLOR.CYAN, xf)
	assert_eq(seg.transform, xf, "sprite placed with the supplied transform")


func test_color_drives_the_tint():
	var seg = _make()
	seg.set_mirror(false, Util.LASER_COLOR.MAGENTA, Transform2D.IDENTITY)
	assert_eq(seg.self_modulate, LaserSegment.LASER_MODULATE[Util.LASER_COLOR.MAGENTA],
		"tinted from the shared laser color table")
