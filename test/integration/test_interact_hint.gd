extends "res://test/fixtures/game_test.gd"
## Tests for the interact-hint nudge (tileset/interact_hint/interact_hint.gd): its
## sine opacity pulse, the "already dismissed -> never appears" save gating, and
## the grid dismissing the hint the first time the player uses the block it sits
## behind.
##
## The two real hints live in level_2.tscn / level_4.tscn; per the suite's
## convention these tests never load those scenes -- they drive the mechanism on a
## bare hint node and on synthetic rooms with a hand-placed hint.

const HintScript := preload("res://tileset/interact_hint/interact_hint.gd")

var _saved_hints: Array


func before_each() -> void:
	# Snapshot the global save's dismissed-hint list; a test toggling it in memory
	# (never to disk) must not leak into the next one or the real save.
	_saved_hints = SaveData.data["seen_hints"].duplicate()


func after_each() -> void:
	SaveData.data["seen_hints"] = _saved_hints


# --------------------------------------------------------------- opacity pulse
func test_opacity_stays_within_bounds():
	for i in range(0, 40):
		var a := HintScript.opacity_for(i * 0.1)
		assert_between(a, HintScript.MIN_OPACITY, HintScript.MAX_OPACITY,
			"opacity in range at t=%s" % (i * 0.1))

func test_opacity_pulses_up_from_its_midpoint():
	var mid := 0.5 * (HintScript.MIN_OPACITY + HintScript.MAX_OPACITY)
	assert_almost_eq(HintScript.opacity_for(0.0), mid, 0.001, "starts mid-pulse (sin 0)")
	assert_gt(HintScript.opacity_for(HintScript.PERIOD / 4.0), mid, "brightens toward the peak")
	assert_almost_eq(HintScript.opacity_for(HintScript.PERIOD), mid, 0.001, "one period later, back to mid")


# ------------------------------------------------------------- save gating
func test_an_unseen_hint_stays_visible():
	SaveData.data["seen_hints"] = []
	var h = HintScript.new()
	h.hint_id = "test_hint"
	add_child(h)  # _ready runs
	var stayed := not h.is_queued_for_deletion()
	h.free()  # deterministic cleanup (it did not free itself)
	assert_true(stayed, "an un-dismissed hint remains")

func test_a_previously_dismissed_hint_removes_itself_on_load():
	SaveData.data["seen_hints"] = ["test_hint"]
	var h = HintScript.new()
	h.hint_id = "test_hint"
	add_child(h)  # _ready runs and frees it (so no explicit cleanup)
	assert_true(h.is_queued_for_deletion(), "a hint already dismissed never reappears")
	await get_tree().process_frame  # let the self-free complete so no child lingers

func test_a_hint_without_an_id_is_never_gated():
	SaveData.data["seen_hints"] = ["something"]
	var h = HintScript.new()  # hint_id defaults to "" (test-only, unpersisted)
	add_child(h)
	var stayed := not h.is_queued_for_deletion()
	h.free()
	assert_true(stayed, "an id-less hint ignores the save")


# ----------------------------------------------- dismissed on first interaction
func test_using_an_emitter_dismisses_its_hint():
	# Player above the emitter (out of its downward beam, so no fry), facing it.
	var emitter := make_block(EmitterScene, 5, 5)
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 4))
	var hint = HintScript.new()  # id-less: its own dismiss() persists nothing
	emitter.add_child(hint)
	assert_false(hint.is_queued_for_deletion(), "hint present before interacting")

	room.grid._attempt_use(Util.DIRECTION.DOWN)  # face and toggle the emitter

	assert_true(hint.is_queued_for_deletion(), "using the emitter dismissed its hint")

func test_rotating_a_pad_dismisses_its_hint():
	var pad := make_block(RotationPadScene, 5, 5)
	var room := build_room([pad], Vector2i(5, 4))
	var hint = HintScript.new()
	pad.add_child(hint)

	room.grid._attempt_use(Util.DIRECTION.DOWN)  # face and rotate the pad

	assert_true(hint.is_queued_for_deletion(), "rotating the pad dismissed its hint")

func test_using_an_emitter_dismisses_every_emitter_hint():
	# The flag is per KIND: interacting with ONE emitter retires the nudge on ALL
	# emitters, so a hint behind a different emitter in the room also clears.
	var used := make_block(EmitterScene, 5, 5)
	used.laser_range = -1
	var other := make_block(EmitterScene, 9, 5)
	other.laser_range = -1
	var room := build_room([used, other], Vector2i(5, 4))
	var hint = HintScript.new()
	other.add_child(hint)

	room.grid._attempt_use(Util.DIRECTION.DOWN)  # uses `used`, not `other`

	assert_true(hint.is_queued_for_deletion(), "using any emitter clears every emitter hint")

func test_using_an_emitter_leaves_a_pad_hint_alone():
	# Per KIND: an emitter interaction must not touch a rotation pad's hint.
	var emitter := make_block(EmitterScene, 5, 5)
	emitter.laser_range = -1
	var pad := make_block(RotationPadScene, 9, 5)
	var room := build_room([emitter, pad], Vector2i(5, 4))
	var hint = HintScript.new()
	pad.add_child(hint)

	room.grid._attempt_use(Util.DIRECTION.DOWN)  # toggles the emitter, not the pad

	assert_false(hint.is_queued_for_deletion(), "an emitter interaction leaves pad hints alone")

func test_interacting_records_the_kind_flag():
	# The persistent flag flips on the first interaction with the KIND, even for an
	# emitter that carries no hint node (so a later level's hint is pre-suppressed).
	SaveData.data["seen_hints"] = []
	var emitter := make_block(EmitterScene, 5, 5)
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 4))

	room.grid._attempt_use(Util.DIRECTION.DOWN)  # toggle the emitter

	assert_true(SaveData.has_seen_hint("emitter"), "first emitter use records the emitter flag")


# ------------------------------------------- Space prompt (line-of-interaction)
# The prompt shows exactly when the cell the player faces is the hinted block's
# cell -- the same front-cell rule the use verb resolves through.
func test_front_cell_is_true_when_adjacent_and_facing_the_block():
	var emitter := make_block(EmitterScene, 5, 5)
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 4))  # one cell above, facing down
	assert_true(HintScript.front_cell_is(room.grid, cell_center(5, 4), Util.DIRECTION.DOWN, cell_center(5, 5)),
		"the faced down-neighbour is the block's cell")

func test_front_cell_is_false_when_facing_away():
	var emitter := make_block(EmitterScene, 5, 5)
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 4))
	assert_false(HintScript.front_cell_is(room.grid, cell_center(5, 4), Util.DIRECTION.UP, cell_center(5, 5)),
		"adjacent but facing the other way")

func test_front_cell_is_false_when_not_adjacent():
	var emitter := make_block(EmitterScene, 5, 5)
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 2))
	assert_false(HintScript.front_cell_is(room.grid, cell_center(5, 2), Util.DIRECTION.DOWN, cell_center(5, 5)),
		"facing the block from two cells away -- the front cell is the gap")

func test_prompt_active_uses_the_players_live_facing():
	# The player defaults to facing DOWN and sits one cell above the emitter, so the
	# use verb (and thus the prompt) is lined up with the block behind the hint.
	var emitter := make_block(EmitterScene, 5, 5)
	emitter.laser_range = -1
	var room := build_room([emitter], Vector2i(5, 4))
	var hint = HintScript.new()
	emitter.add_child(hint)  # _ready binds it to the room + connected player
	assert_true(hint.facing_prompt_active(), "adjacent above, facing down -> prompt")

func test_prompt_inactive_when_player_is_not_lined_up():
	var emitter := make_block(EmitterScene, 5, 5)
	emitter.laser_range = -1
	# Facing down from (4,4) lands on (4,5), not the emitter's (5,5).
	var room := build_room([emitter], Vector2i(4, 4))
	var hint = HintScript.new()
	emitter.add_child(hint)
	assert_false(hint.facing_prompt_active(), "not facing the block's cell -> no prompt")

func test_prompt_inactive_on_a_hint_with_no_owning_room():
	# A bare hint node (unit context) has no grid/player, so it never prompts.
	var hint = HintScript.new()
	add_child(hint)
	var inactive := not hint.facing_prompt_active()
	hint.free()
	assert_true(inactive, "no room bound -> no prompt, and no crash")


const RotationPadScene: PackedScene = preload("res://tileset/rotation/rotation_pad.tscn")
