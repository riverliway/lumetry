extends "res://test/fixtures/game_test.gd"
## Integration tests for the laser hazard rules, driven through Room.Grid on
## isolated synthetic rooms.
##
## Two behaviours:
##  - Crossing: walking into an active beam is refused, and the room raises
##    `player_singed` so the first attempt ever can surface a hint.
##  - Frying: a beam that ends up on the player's OWN cell -- because the player
##    toggled an emitter they stood in front of, rotated a mirror into the beam,
##    or stepped into its path -- raises `player_fried`, leaving the beam ON so
##    the player can see what killed them (the Level shuts it off after a beat).
##    The load-time resolve never fries (the player isn't connected yet), so a
##    level can start with the player parked anywhere.

const RotationPadScene: PackedScene = preload("res://tileset/rotation/rotation_pad.tscn")


func _player_cell(room: Room, player: Node2D) -> Array:
	var c = room.grid.get_nearest_cell(player.position)
	return [c.c, c.r]


# --------------------------------------------------------------------- frying
func test_toggling_an_emitter_onto_yourself_fries_you():
	# Emitter one cell above the player, facing DOWN (toward them), starting off.
	var emitter := make_block(EmitterScene, 5, 5)
	emitter.laser_range = -1
	emitter.activated = false
	var room := build_room([emitter], Vector2i(5, 6))
	assert_eq(active_laser_count(room), 0, "no beam while the emitter is off")
	watch_signals(room)

	room.grid._attempt_use(Util.DIRECTION.UP)  # face and toggle the emitter on

	assert_signal_emitted(room, "player_fried", "toggling the beam onto yourself fries you")
	assert_signal_emit_count(room, "player_fried", 1, "it fires exactly once")
	# The emitter is LEFT ON (old behaviour switched it off here) so the player can
	# see what killed them; the Level shuts it off after the post-death beat.
	assert_true(emitter.activated, "the emitter stays on, not switched off by the fry")


func test_rotating_an_emitter_into_yourself_fries_you():
	# Emitter on a rotation pad above the player, aimed away (DOWN_RIGHT) so its
	# beam misses at first; one clockwise step re-aims it straight DOWN onto them.
	var emitter := make_block(EmitterScene, 5, 5, Util.get_rotation_from_direction(Util.DIRECTION.DOWN_RIGHT))
	emitter.laser_range = -1
	var pad := make_block(RotationPadScene, 5, 5)
	var room := build_room([emitter, pad], Vector2i(5, 6))
	watch_signals(room)

	room.rotate_pad(pad)  # DOWN_RIGHT -> DOWN, now aimed at the player
	room._process(1.0)  # the re-light (and so the fry) is held until the spin is half done

	assert_signal_emitted(room, "player_fried", "rotating the beam onto yourself fries you")
	assert_true(emitter.activated, "the emitter stays on, not switched off by the fry")


func test_stepping_into_a_beam_you_were_blocking_fries_you():
	# The player stands in a downward beam, blocking it (the cell below is dark).
	# Stepping down into that shadow lets the beam catch up and fry them.
	var emitter := make_block(EmitterScene, 5, 3)  # faces DOWN, column 5
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 5))
	var player := room.get_node("Player")
	assert_false(room.grid.grid[5][6].is_laser_active(), "the player's shadow is dark (precondition)")
	watch_signals(room)

	room.grid._attempt_move(Util.DIRECTION.DOWN)
	player._process(1.0)  # complete the move animation

	assert_eq(_player_cell(room, player), [5, 6], "the move into the dark cell was allowed")
	assert_signal_emitted(room, "player_fried", "the beam caught up and fried the player")
	assert_gt(active_laser_count(room), 0, "the killing beam stays on so the player can see it")


func test_shut_off_all_emitters_clears_the_beams():
	# The public shut-off the Level runs after the post-death beat: every emitter
	# goes off and the beams clear. (During real play this is what finally darkens
	# the beam that killed the player, once they have had a moment to see it.)
	var emitter := make_block(EmitterScene, 5, 5)  # faces DOWN, column 5
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(8, 8))  # player well clear of the beam
	assert_true(emitter.activated, "emitter starts on")
	assert_gt(active_laser_count(room), 0, "and its beam is drawn")

	room.shut_off_all_emitters()

	assert_false(emitter.activated, "shut_off_all_emitters switched the emitter off")
	assert_eq(active_laser_count(room), 0, "and cleared every beam")


func test_beam_that_never_reaches_the_player_does_not_fry():
	# A beam aimed away from the player is harmless -- the room must stay quiet.
	var emitter := make_block(EmitterScene, 5, 5)  # faces DOWN, player is UP of it
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 4))
	watch_signals(room)

	room.grid.handle_laser_physics()

	assert_signal_not_emitted(room, "player_fried", "a beam pointing away never fries")
	assert_true(emitter.activated, "the emitter is left on")


func test_starting_inside_a_beam_does_not_fry_on_load():
	# A room whose player happens to sit in a beam at load must NOT fry -- the
	# player is only connected after the initial resolve, so nothing triggers.
	var emitter := make_block(EmitterScene, 5, 3)  # faces DOWN onto the player
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 6))
	# build_room already ran Room._ready() (initial resolve + connect_player).
	assert_true(emitter.activated, "the emitter is still on -- no fry happened on load")
	assert_true(room.get_node("Player") != null, "player is present")


# ------------------------------------------------------------------- crossing
func test_crossing_a_beam_is_refused_and_singes():
	var emitter := make_block(EmitterScene, 7, 3)  # faces DOWN, beam down column 7
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(6, 5))
	var player := room.get_node("Player")
	assert_true(room.grid.grid[7][5].is_laser_active(), "the target cell is lit (precondition)")
	watch_signals(room)

	# (7,5) is DOWN_RIGHT of (6,5) and lies on the beam -> entry forbidden.
	room.grid._attempt_move(Util.DIRECTION.DOWN_RIGHT)
	player._process(1.0)

	assert_eq(_player_cell(room, player), [6, 5], "the player refused to enter the laser")
	assert_signal_emitted(room, "player_singed", "the refused crossing raised the singed hint")
	assert_signal_not_emitted(room, "player_fried", "being blocked is not the same as frying")


func test_moving_into_a_dark_empty_cell_does_not_singe():
	var room := build_room([], Vector2i(5, 5))
	var player := room.get_node("Player")
	watch_signals(room)

	room.grid._attempt_move(Util.DIRECTION.UP)
	player._process(1.0)

	assert_eq(_player_cell(room, player), [5, 4], "the player moved freely")
	assert_signal_not_emitted(room, "player_singed", "an ordinary move raises no hint")
