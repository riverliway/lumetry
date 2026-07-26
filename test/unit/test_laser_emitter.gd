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

func test_interactable_by_default():
	assert_true(make_emitter().interactable, "emitters are player-interactable unless configured otherwise")

func test_use_still_toggles_a_non_interactable_emitter():
	# `interactable` only gates the player's use verb (see Room.Grid._attempt_use);
	# a direct use() call -- how level code drives an emitter -- still toggles it.
	var emitter = make_emitter()
	emitter.interactable = false
	emitter.use()
	assert_false(emitter.activated, "programmatic use() ignores the interactable flag")
