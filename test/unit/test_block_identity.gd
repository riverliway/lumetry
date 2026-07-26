extends "res://test/fixtures/game_test.gd"
## Every placeable block declares a `block_type` that the grid's laser physics and
## push/use rules switch on, so a wrong constant silently breaks a whole mechanic.
## The emitter / detector / focuser / rotation-pad blocks assert their own type in
## their dedicated suites; this covers the remaining passive blocks -- wall, both
## mirror shapes, prism, and meltable.

func test_wall_block_type():
	var w = WallScene.instantiate()
	assert_eq(w.block_type, Util.BLOCK_TYPE.WALL)
	w.free()

func test_mirror_defaults_to_short():
	# The scene declares MIRROR_SHORT; a cell promotes it to MIRROR_LONG only when
	# it is placed at a half-angle (see test_cell.gd).
	var m = MirrorScene.instantiate()
	assert_eq(m.block_type, Util.BLOCK_TYPE.MIRROR_SHORT)
	m.free()

func test_prism_block_type():
	var p = PrismScene.instantiate()
	assert_eq(p.block_type, Util.BLOCK_TYPE.PRISIM)
	p.free()

func test_meltable_block_type():
	var m = MeltableScene.instantiate()
	assert_eq(m.block_type, Util.BLOCK_TYPE.MELTABLE)
	m.free()
