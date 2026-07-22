extends GutTest
## Unit tests for tileset/rotation/rotation_pad.gd.
## The pad animates a 60-degree rotation of itself and a target block over
## _ROTATION_DURATION seconds; _process(delta) is driven manually here.

const RotationPadScene: PackedScene = preload("res://tileset/rotation/rotation_pad.tscn")

func make_pad():
	var pad = RotationPadScene.instantiate()
	add_child_autofree(pad)
	pad.set_process(false)  # drive _process manually, no auto-ticks
	pad.rotation = 0.0
	return pad


func test_block_type_is_rotation_pad():
	assert_eq(make_pad().block_type, Util.BLOCK_TYPE.ROTATION_PAD)

func test_idle_pad_does_not_rotate():
	var pad = make_pad()
	pad.rotation = 1.234
	pad._process(0.5)
	assert_almost_eq(pad.rotation, 1.234, 0.0001)

func test_completed_rotation_turns_pad_60_degrees():
	var pad = make_pad()
	var block := Node2D.new()
	add_child_autofree(block)
	block.rotation = 0.0
	pad.perform_rotation(block)
	pad._process(1.0)  # exceed the 0.75s duration to force completion + snap
	assert_almost_eq(pad.rotation, deg_to_rad(60.0), 0.001, "pad snapped to +60 deg")

func test_completed_rotation_turns_target_block_60_degrees():
	var pad = make_pad()
	var block := Node2D.new()
	add_child_autofree(block)
	block.rotation = 0.0
	pad.perform_rotation(block)
	pad._process(1.0)
	assert_almost_eq(block.rotation, deg_to_rad(60.0), 0.001, "block snapped to +60 deg")

func test_partial_rotation_is_in_progress():
	var pad = make_pad()
	var block := Node2D.new()
	add_child_autofree(block)
	pad.perform_rotation(block)
	pad._process(0.1)  # part-way through the 0.75s animation
	assert_gt(pad.rotation, 0.0, "pad has begun rotating")
	assert_lt(pad.rotation, deg_to_rad(60.0), "but has not finished")
