extends GutTest
## Unit tests for the player controller's own state machine (player/player.gd):
## look (facing / sprite flip / animation / LOOKING state + cooldown), the move and
## use animations driven through _process, and _get_input_direction's six-way +
## diagonal resolution. The grid-side movement/pushing rules are covered separately
## in test/integration/test_movement.gd; this exercises the player in isolation.
##
## _process is disabled after instantiation so only the manual _process(delta) calls
## here drive the animation, and every simulated Input action is released after each
## test so a leaked press can't bleed into the next one.

const PlayerScene: PackedScene = preload("res://player/player.tscn")

const MOVE_ACTIONS := ["move_up", "move_down", "move_left", "move_right",
	"move_up_left", "move_up_right", "use", "click_move", "click_use", "sprint"]

var _saved_settings


func _make_player() -> Player:
	var player: Player = PlayerScene.instantiate()
	add_child_autofree(player)
	player.set_process(false)  # drive _process manually, no auto-ticks
	return player


func before_each() -> void:
	# Snapshot settings so a test switching the movement scheme can't leak into
	# the next test (mutated in-memory only, never written to disk here). Pin the
	# scheme to a deterministic 4-key baseline regardless of the shipped default;
	# the 6-key tests override it explicitly. (The shipped default itself is
	# asserted in test_save_data.gd, not here.)
	_saved_settings = SaveData.data["settings"].duplicate(true)
	_set_scheme("four_key")


func after_each() -> void:
	for action in MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	SaveData.data["settings"] = _saved_settings


## Switches the in-memory movement scheme for a test (no disk write).
func _set_scheme(scheme: String) -> void:
	SaveData.data["settings"]["movement_scheme"] = scheme


# ---------------------------------------------------------------------- look
func test_look_up_sets_facing_animation_and_looking_state():
	var p = _make_player()
	p._look(Util.DIRECTION.UP)
	assert_eq(p._facing, Util.DIRECTION.UP, "faces up")
	assert_eq(p.animation, "idle_up", "up animation selected")
	assert_eq(p._state, Util.PLAYER_STATE.LOOKING, "entered the LOOKING state")
	assert_almost_eq(p._time_left, p._LOOK_DURATION, 0.0001, "look cooldown armed")

func test_look_down_uses_down_animation():
	var p = _make_player()
	p._look(Util.DIRECTION.DOWN)
	assert_eq(p.animation, "idle_down")

func test_look_upright_shares_the_upright_animation():
	var p = _make_player()
	p._look(Util.DIRECTION.UP_RIGHT)
	assert_eq(p.animation, "idle_upright", "up diagonals share one animation")
	assert_gt(p.scale.x, 0.0, "facing right is not mirrored")

func test_look_upleft_mirrors_the_sprite():
	var p = _make_player()
	p._look(Util.DIRECTION.UP_LEFT)
	assert_eq(p.animation, "idle_upright", "left diagonal reuses the upright frames")
	assert_lt(p.scale.x, 0.0, "facing left flips the sprite on x")

func test_look_downleft_uses_downright_animation_flipped():
	var p = _make_player()
	p._look(Util.DIRECTION.DOWN_LEFT)
	assert_eq(p.animation, "idle_downright", "down diagonals share one animation")
	assert_lt(p.scale.x, 0.0, "facing left flips the sprite")

func test_look_downright_is_not_flipped():
	var p = _make_player()
	p._look(Util.DIRECTION.DOWN_RIGHT)
	assert_eq(p.animation, "idle_downright")
	assert_gt(p.scale.x, 0.0, "facing right is not mirrored")

func test_look_none_is_a_noop():
	var p = _make_player()
	var facing_before = p._facing
	p._look(Util.DIRECTION.NONE)
	assert_eq(p._facing, facing_before, "NONE leaves facing unchanged")
	assert_ne(p._state, Util.PLAYER_STATE.LOOKING, "NONE does not enter LOOKING")

func test_look_without_cooldown_skips_the_timer():
	var p = _make_player()
	p._time_left = 0.0
	p._look(Util.DIRECTION.UP, false)
	assert_eq(p._time_left, 0.0, "start_cooldown=false leaves the timer unset")


# ---------------------------------------------------------------------- face
func test_face_aims_the_sprite_without_touching_the_state():
	# _face is the shared aiming used by mouse look: facing + animation + flip,
	# but no LOOKING state and no cooldown (unlike _look).
	var p = _make_player()
	p._state = Util.PLAYER_STATE.IDLE
	p._time_left = 0.0
	p._face(Util.DIRECTION.UP_LEFT)
	assert_eq(p._facing, Util.DIRECTION.UP_LEFT, "facing updated")
	assert_eq(p.animation, "idle_upright", "up diagonal animation")
	assert_lt(p.scale.x, 0.0, "left diagonal flips the sprite")
	assert_eq(p._state, Util.PLAYER_STATE.IDLE, "state is left untouched")
	assert_eq(p._time_left, 0.0, "no cooldown armed")

func test_face_none_leaves_facing_unchanged():
	var p = _make_player()
	var before = p._facing
	p._face(Util.DIRECTION.NONE)
	assert_eq(p._facing, before, "a NONE aim (cursor on the player) is a no-op")


# ----------------------------------------------------------- mouse buttons
func test_left_click_moves_toward_the_current_facing():
	var p = _make_player()
	p._facing = Util.DIRECTION.UP_RIGHT
	watch_signals(p)
	Input.action_press("click_move")
	p._process_idle()
	# left click moves in whatever direction the player faces
	assert_signal_emitted_with_parameters(p, "attempt_move", [Util.DIRECTION.UP_RIGHT])

func test_right_click_uses_in_the_current_facing():
	var p = _make_player()
	p._facing = Util.DIRECTION.DOWN
	watch_signals(p)
	Input.action_press("click_use")
	p._process_idle()
	# right click uses in the facing direction
	assert_signal_emitted_with_parameters(p, "attempt_use", [Util.DIRECTION.DOWN])

func test_mouse_and_keyboard_moves_coexist():
	# With no click held, the keyboard path still drives movement -- the two
	# schemes live side by side.
	var p = _make_player()
	p._facing = Util.DIRECTION.UP
	watch_signals(p)
	Input.action_press("move_up")  # four_key baseline -> UP, which matches facing
	p._process_idle()
	# a keyboard press still moves while mouse controls are available
	assert_signal_emitted_with_parameters(p, "attempt_move", [Util.DIRECTION.UP])

func test_keyboard_use_still_works_alongside_mouse():
	var p = _make_player()
	watch_signals(p)
	Input.action_press("use")
	p._process_idle()
	assert_signal_emitted(p, "attempt_use", "the keyboard use key still fires")


# --------------------------------------------------------------------- sprint
func test_new_direction_looks_first_and_arms_the_timer_without_sprint():
	# The baseline the sprint case contrasts with: turning to a new direction
	# enters LOOKING with the cooldown and does NOT move yet.
	var p = _make_player()
	p._facing = Util.DIRECTION.DOWN
	watch_signals(p)
	Input.action_press("move_up")  # four_key -> UP, different from facing
	p._process_idle()
	assert_signal_not_emitted(p, "attempt_move", "a fresh turn does not move on the same press")
	assert_eq(p._state, Util.PLAYER_STATE.LOOKING, "entered LOOKING to turn first")
	assert_almost_eq(p._time_left, p._LOOK_DURATION, 0.0001, "look cooldown armed")

func test_sprint_skips_the_look_timer_and_moves_immediately():
	# Holding sprint, a press in a new direction walks at once -- no LOOKING beat.
	var p = _make_player()
	p._facing = Util.DIRECTION.DOWN
	watch_signals(p)
	Input.action_press("sprint")
	Input.action_press("move_up")  # four_key -> UP, different from facing
	p._process_idle()
	assert_signal_emitted_with_parameters(p, "attempt_move", [Util.DIRECTION.UP])
	assert_eq(p._facing, Util.DIRECTION.UP, "still turns to face the new direction")
	assert_eq(p._time_left, 0.0, "but no look cooldown is armed -- the timer is skipped")

func test_sprint_with_no_direction_does_not_move():
	# Shift alone is inert; it only suppresses the turn beat for a real direction.
	var p = _make_player()
	watch_signals(p)
	Input.action_press("sprint")
	p._process_idle()
	assert_signal_not_emitted(p, "attempt_move", "holding sprint without a direction is a no-op")


# ---------------------------------------------------------------------- move
func test_move_enters_moving_state_and_arms_the_timer():
	var p = _make_player()
	var obj := Node2D.new()
	add_child_autofree(obj)
	p.move(obj, Vector2(100, 0), Vector2(0, 0))
	assert_eq(p._state, Util.PLAYER_STATE.MOVING, "entered MOVING")
	assert_almost_eq(p._time_left, p._MOVE_DURATION, 0.0001, "move timer armed")

func test_move_interpolates_partway_then_snaps_on_completion():
	var p = _make_player()
	var obj := Node2D.new()
	add_child_autofree(obj)
	obj.position = Vector2(0, 0)
	p.move(obj, Vector2(100, 0), Vector2(0, 0))
	p._process(p._MOVE_DURATION / 2.0)  # halfway
	assert_almost_eq(obj.position.x, 50.0, 1.0, "object lerps toward the target")
	assert_eq(p._state, Util.PLAYER_STATE.MOVING, "still animating at the halfway point")
	p._process(p._MOVE_DURATION)  # exceed the remaining time -> completion
	assert_almost_eq(obj.position, Vector2(100, 0), Vector2(0.5, 0.5), "snaps exactly to target")
	assert_eq(p._state, Util.PLAYER_STATE.IDLE, "returns to IDLE when the move finishes")


# ----------------------------------------------------------------------- use
func test_use_enters_using_state_then_returns_to_idle():
	var p = _make_player()
	p.use()
	assert_eq(p._state, Util.PLAYER_STATE.USING, "entered USING")
	assert_almost_eq(p._time_left, p._USE_DURATION, 0.0001, "use timer armed")
	p._process(p._USE_DURATION + 0.1)  # run past the duration
	assert_eq(p._state, Util.PLAYER_STATE.IDLE, "returns to IDLE after the use finishes")


# --------------------------------------------------------- _get_input_direction
func test_input_direction_cardinals():
	var p = _make_player()
	Input.action_press("move_up")
	assert_eq(p._get_input_direction(), Util.DIRECTION.UP, "up")
	Input.action_release("move_up")
	Input.action_press("move_down")
	assert_eq(p._get_input_direction(), Util.DIRECTION.DOWN, "down")

func test_input_direction_up_diagonals():
	var p = _make_player()
	Input.action_press("move_up")
	Input.action_press("move_left")
	assert_eq(p._get_input_direction(), Util.DIRECTION.UP_LEFT, "up+left")
	Input.action_release("move_left")
	Input.action_press("move_right")
	assert_eq(p._get_input_direction(), Util.DIRECTION.UP_RIGHT, "up+right")

func test_input_direction_down_diagonals():
	var p = _make_player()
	Input.action_press("move_down")
	Input.action_press("move_left")
	assert_eq(p._get_input_direction(), Util.DIRECTION.DOWN_LEFT, "down+left")
	Input.action_release("move_left")
	Input.action_press("move_right")
	assert_eq(p._get_input_direction(), Util.DIRECTION.DOWN_RIGHT, "down+right")

func test_lateral_input_resolves_by_current_facing():
	# A bare left/right press has no vertical component, so the current facing
	# decides whether it becomes an up- or down-diagonal.
	var p = _make_player()
	p._facing = Util.DIRECTION.UP
	Input.action_press("move_left")
	assert_eq(p._get_input_direction(), Util.DIRECTION.UP_LEFT, "left while facing up -> up-left")
	Input.action_release("move_left")
	p._facing = Util.DIRECTION.DOWN
	Input.action_press("move_right")
	assert_eq(p._get_input_direction(), Util.DIRECTION.DOWN_RIGHT, "right while facing down -> down-right")

func test_input_direction_none_when_idle():
	var p = _make_player()
	assert_eq(p._get_input_direction(), Util.DIRECTION.NONE, "no input -> NONE")


# ----------------------------------------------- _get_input_direction (6-key)
func test_six_key_maps_each_key_to_one_hex_direction():
	var p = _make_player()
	_set_scheme("six_key")
	var cases := {
		"move_up_left": Util.DIRECTION.UP_LEFT,     # Q
		"move_up": Util.DIRECTION.UP,               # W
		"move_up_right": Util.DIRECTION.UP_RIGHT,   # E
		"move_left": Util.DIRECTION.DOWN_LEFT,      # A
		"move_down": Util.DIRECTION.DOWN,           # S
		"move_right": Util.DIRECTION.DOWN_RIGHT,    # D
	}
	for action in cases:
		Input.action_press(action)
		assert_eq(p._get_input_direction(), cases[action], "%s -> expected direction" % action)
		Input.action_release(action)

func test_six_key_lateral_keys_ignore_facing():
	# Unlike 4-key, a bare A/D is absolute (down-left/right) regardless of facing.
	var p = _make_player()
	_set_scheme("six_key")
	p._facing = Util.DIRECTION.UP
	Input.action_press("move_left")
	assert_eq(p._get_input_direction(), Util.DIRECTION.DOWN_LEFT, "A is always down-left in 6-key")

func test_six_key_ignores_the_diagonal_keys_in_four_key_mode():
	# Q/E do nothing under the default 4-key scheme.
	var p = _make_player()
	Input.action_press("move_up_left")
	assert_eq(p._get_input_direction(), Util.DIRECTION.NONE, "Q is inert in 4-key mode")
