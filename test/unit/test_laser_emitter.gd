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

func test_interactable_emitter_shows_default_animation():
	assert_eq(make_emitter().animation, &"default")

func test_locked_emitter_shows_disabled_animation():
	# A non-interactable emitter is greyed out via the "disabled" animation, chosen
	# in _ready(); set the flag before adding to the tree so _ready sees it.
	var emitter = EmitterScene.instantiate()
	emitter.interactable = false
	add_child_autofree(emitter)
	assert_eq(emitter.animation, &"disabled")

## _ready reads laser_range/interactable, so configure the emitter before it
## enters the tree (add_child runs _ready).
func make_configured_emitter(laser_range: int, interactable: bool):
	var emitter = EmitterScene.instantiate()
	emitter.laser_range = laser_range
	emitter.interactable = interactable
	add_child_autofree(emitter)
	return emitter

func test_finite_emitter_shows_the_dimmed_finite_animation():
	# A finite-range emitter (laser_range != -1) reads as weaker via a dimmed
	# sprite, matching the dimmed beam it fires.
	assert_eq(make_configured_emitter(5, true).animation, &"finite")

func test_finite_locked_emitter_combines_both_cues():
	# Finiteness and locked-ness are independent cues, so a finite locked emitter
	# gets the dimmed *and* greyed-out sprite.
	assert_eq(make_configured_emitter(5, false).animation, &"finite_disabled")

func test_infinite_emitter_is_not_finite_dimmed():
	assert_eq(make_configured_emitter(-1, true).animation, &"default")
