extends GutTest
## Unit tests for tileset/laser/laser_emitter.gd.

const EmitterScene: PackedScene = preload("res://tileset/laser/laser_emitter.tscn")

func make_emitter():
	var emitter = EmitterScene.instantiate()
	add_child_autofree(emitter)
	return emitter


func test_block_type_is_laser_emitter():
	assert_eq(make_emitter().block_type, Util.BLOCK_TYPE.LASER_EMITTER)

func test_starts_activated():
	assert_true(make_emitter().activated)

func test_use_toggles_activation_off():
	var emitter = make_emitter()
	emitter.use()
	assert_false(emitter.activated)

func test_use_twice_returns_to_activated():
	var emitter = make_emitter()
	emitter.use()
	emitter.use()
	assert_true(emitter.activated)
