extends GutTest
## Unit tests for tileset/laser/prism_segment.gd -- one of the four flat-cut
## half-beams drawn inside a prism cell. It tints the white sprite via the shared
## LaserSegment.LASER_MODULATE table and places it with the Transform2D the grid
## computed. (The four-way split itself is covered in test_laser_physics.gd.)

const PrismSegmentScene: PackedScene = preload("res://tileset/laser/prism_segment.tscn")


func _make():
	var seg = PrismSegmentScene.instantiate()
	add_child_autofree(seg)
	return seg


func test_clear_laser_deactivates():
	var seg = _make()
	seg.clear_laser()
	assert_false(seg.is_active())


func test_set_prism_activates():
	var seg = _make()
	seg.clear_laser()
	seg.set_prism(Util.LASER_COLOR.YELLOW, Transform2D.IDENTITY)
	assert_true(seg.is_active())


func test_set_prism_applies_the_transform():
	var seg = _make()
	var xf := Transform2D(-1.2, Vector2(40, 55))
	seg.set_prism(Util.LASER_COLOR.CYAN, xf)
	assert_eq(seg.transform, xf, "sprite placed with the supplied transform")


func test_color_drives_the_tint():
	var seg = _make()
	seg.set_prism(Util.LASER_COLOR.YELLOW, Transform2D.IDENTITY)
	assert_eq(seg.self_modulate, LaserSegment.LASER_MODULATE[Util.LASER_COLOR.YELLOW],
		"tinted from the shared laser color table")
