extends AnimatedSprite2D
class_name Player
signal attempt_move(direction: Util.DIRECTION) ## Emitted when the player inputs a movement direction
signal attempt_use(direction: Util.DIRECTION) ## Emitted when the player attempts to use an object, in the direction the player is facing

var block_type := Util.BLOCK_TYPE.PLAYER

## Movement input actions per scheme (see SaveData.MOVEMENT_SCHEMES). 4-key uses
## WASD with diagonals resolved by facing; 6-key maps one hex direction to each
## of Q/W/E/A/S/D. Menus always navigate with the WASD move_* actions regardless
## -- the scheme only changes how in-game movement input is interpreted here.
const _FOUR_KEY_ACTIONS := ["move_up", "move_down", "move_left", "move_right"]
const _SIX_KEY_ACTIONS := ["move_up_left", "move_up", "move_up_right", "move_left", "move_down", "move_right"]

## Controller movement, independent of the movement_scheme setting (that only
## governs the keyboard). The left stick (look_*) is analog and reaches all six
## hex directions by angle -- look, then move after the same pause as a keyboard
## tap. The D-pad (dpad_*) is four-directional and resolves diagonals by facing,
## exactly like the 4-key keyboard scheme. A held bumper is the sprint key.
const _LOOK_ACTIONS := ["look_up", "look_down", "look_left", "look_right"]
const _DPAD_ACTIONS := ["dpad_up", "dpad_down", "dpad_left", "dpad_right"]

var _move_start_pos := Vector2.ZERO ## The starting position of the current movement
var _move_target := Vector2.ZERO ## The target position the player is moving to
var _move_object = null ## The object to move (can be player or a pushed block)

var _state := Util.PLAYER_STATE.IDLE ## The current state of the player
var _queue_state := Util.PLAYER_STATE.IDLE ## A temporary variable to hold the queue between current and previous state
var _prev_state := Util.PLAYER_STATE.IDLE ## The state of the player in the previous frame
var _facing := Util.DIRECTION.DOWN

## Viewport-space mouse position last frame, for detecting motion. Seeded in
## _ready so the very first frame doesn't read as a spurious move.
var _last_mouse_screen := Vector2.ZERO

var _LOOK_DURATION := 0.2
var _MOVE_DURATION := 0.5
var _USE_DURATION := 1.0
var _time_left := 0.0


func _ready() -> void:
	_last_mouse_screen = _mouse_screen_position()


func _process(_delta: float) -> void:
	_time_left = max(_time_left - _delta, 0)

	# Mouse look is additive to the keyboard schemes: moving the mouse snaps the
	# facing to the cursor (a keyboard direction press overrides it again). A
	# parked cursor normally never retargets, so it can't fight a keyboard player
	# -- but while a mouse aim button is held the player is steering with the
	# cursor, so the facing keeps tracking it every frame even without mouse
	# motion. That matters while walking toward the cursor: the player's own
	# movement changes the player->cursor angle, so a held click must re-aim.
	var mouse_screen := _mouse_screen_position()
	var mouse_moved := mouse_screen != _last_mouse_screen
	_last_mouse_screen = mouse_screen
	if (mouse_moved or _mouse_aim_held()) and _state != Util.PLAYER_STATE.USING:
		_face(_cursor_direction())

	match _state:
		Util.PLAYER_STATE.IDLE:
			_process_idle()
		Util.PLAYER_STATE.LOOKING:
			_process_look()
		Util.PLAYER_STATE.MOVING:
			_process_move(_delta)
		Util.PLAYER_STATE.USING:
			_process_use()

	_prev_state = _queue_state
	_queue_state = _state


## Processes the idle state
func _process_idle() -> void:
	# Mouse buttons act on the current facing, which already tracks the cursor.
	# Left = move (hold to keep walking), right = use. Available at all times,
	# right alongside the keyboard.
	if Input.is_action_pressed('click_use'):
		attempt_use.emit(_facing)
		return
	if Input.is_action_pressed('click_move'):
		attempt_move.emit(_facing)
		return

	if Input.is_action_pressed('use'):
		attempt_use.emit(_facing)
		return

	var input_direction = _input_direction()
	if input_direction == _facing:
		# If the player is already facing the input direction, attempt to move
		attempt_move.emit(input_direction)
	elif _prev_state == Util.PLAYER_STATE.MOVING or (_sprinting() and input_direction != Util.DIRECTION.NONE):
		# Skip the look timer and walk straight away, either because the player
		# just finished a move (already mid-stride) or is holding the sprint key
		# to suppress the turn-in-place beat a fresh direction change normally has.
		_look(input_direction, false)
		attempt_move.emit(input_direction)
	else:
		# If the player is not facing the input direction, look in that direction
		_look(input_direction)


## Processes the looking state
func _process_look() -> void:
	# If any new movement input is detected, look in that direction immediately
	if _movement_just_pressed():
		_look(_input_direction())

	if _time_left <= 0:
		_state = Util.PLAYER_STATE.IDLE


## Processes the moving state
func _process_move(_delta) -> void:
	if _time_left <= 0:
		_move_object.position = _move_target
		_state = Util.PLAYER_STATE.IDLE
	else:
		var t = 1.0 - (_time_left / _MOVE_DURATION)
		_move_object.position = _move_start_pos.lerp(_move_target, t)


## Processes the using state
func _process_use() -> void:
	if _time_left <= 0:
		_state = Util.PLAYER_STATE.IDLE


## Whether the six-key movement scheme is active (else four-key). Read live from
## the save so a change in the options menu takes effect without a reload.
func _six_key() -> bool:
	return SaveData.get_setting("movement_scheme") == "six_key"


## Whether the sprint key (shift) is held. Sprinting drops the look timer, so a
## direction press walks immediately instead of turning in place first.
func _sprinting() -> bool:
	return Input.is_action_pressed("sprint")


## Whether a movement input (keyboard for the active scheme, or the controller
## D-pad / left stick) was pressed this frame.
func _movement_just_pressed() -> bool:
	var actions = (_SIX_KEY_ACTIONS if _six_key() else _FOUR_KEY_ACTIONS) + _DPAD_ACTIONS + _LOOK_ACTIONS
	return actions.any(func(a): return Input.is_action_just_pressed(a))


## The intended hex direction from any input source: the keyboard first (per the
## active scheme), then the controller (left stick, else D-pad). Keyboard and
## controller aren't used at once, so checking the keyboard first leaves its
## behaviour untouched and only falls through to the controller when idle.
func _input_direction() -> Util.DIRECTION:
	var dir := _get_input_direction()
	if dir == Util.DIRECTION.NONE:
		dir = _controller_direction()
	return dir


## Keyboard movement direction, per the active scheme.
func _get_input_direction() -> Util.DIRECTION:
	return _input_direction_six_key() if _six_key() else _input_direction_four_key()


## Controller movement direction: the left stick (analog, six-way by angle) when
## it is pushed past the deadzone, else the D-pad (four-way, diagonals by facing).
func _controller_direction() -> Util.DIRECTION:
	var stick := _stick_direction()
	if stick != Util.DIRECTION.NONE:
		return stick
	return _dpad_direction()


## The left stick's hex direction, or NONE while it rests inside the deadzone.
func _stick_direction() -> Util.DIRECTION:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down", _deadzone())
	return Util.direction_from_vector(stick)


## The configured joystick deadzone, read live so the options slider applies at once.
func _deadzone() -> float:
	return SaveData.get_setting("joystick_deadzone")


## Four-key scheme: WASD, where a bare left/right resolves to an up- or
## down-diagonal based on the direction the player last looked (`_facing`).
func _input_direction_four_key() -> Util.DIRECTION:
	return _resolve_four_key("move_up", "move_down", "move_left", "move_right")


## The D-pad, resolved with the same four-key logic as the keyboard 4-key scheme
## regardless of the movement_scheme setting (a D-pad has only four directions).
func _dpad_direction() -> Util.DIRECTION:
	return _resolve_four_key("dpad_up", "dpad_down", "dpad_left", "dpad_right")


## Four-directional resolution shared by the keyboard 4-key scheme and the D-pad:
## up/down give the cardinal (or a diagonal when combined with left/right), while
## a bare left/right becomes an up- or down-diagonal based on `_facing`.
func _resolve_four_key(up: String, down: String, left: String, right: String) -> Util.DIRECTION:
	if Input.is_action_pressed(up):
		if Input.is_action_pressed(left):
			return Util.DIRECTION.UP_LEFT
		elif Input.is_action_pressed(right):
			return Util.DIRECTION.UP_RIGHT

		return Util.DIRECTION.UP

	if Input.is_action_pressed(down):
		if Input.is_action_pressed(left):
			return Util.DIRECTION.DOWN_LEFT
		elif Input.is_action_pressed(right):
			return Util.DIRECTION.DOWN_RIGHT

		return Util.DIRECTION.DOWN

	if Input.is_action_pressed(left):
		if _facing in [Util.DIRECTION.UP, Util.DIRECTION.UP_LEFT, Util.DIRECTION.UP_RIGHT]:
			return Util.DIRECTION.UP_LEFT

		return Util.DIRECTION.DOWN_LEFT

	if Input.is_action_pressed(right):
		if _facing in [Util.DIRECTION.UP, Util.DIRECTION.UP_LEFT, Util.DIRECTION.UP_RIGHT]:
			return Util.DIRECTION.UP_RIGHT

		return Util.DIRECTION.DOWN_RIGHT

	return Util.DIRECTION.NONE


## Six-key scheme: one hex direction per key -- Q/W/E across the top row,
## A/S/D across the bottom -- with no facing-dependent resolution.
func _input_direction_six_key() -> Util.DIRECTION:
	if Input.is_action_pressed('move_up_left'):    # Q
		return Util.DIRECTION.UP_LEFT
	if Input.is_action_pressed('move_up'):         # W
		return Util.DIRECTION.UP
	if Input.is_action_pressed('move_up_right'):   # E
		return Util.DIRECTION.UP_RIGHT
	if Input.is_action_pressed('move_left'):       # A
		return Util.DIRECTION.DOWN_LEFT
	if Input.is_action_pressed('move_down'):       # S
		return Util.DIRECTION.DOWN
	if Input.is_action_pressed('move_right'):      # D
		return Util.DIRECTION.DOWN_RIGHT

	return Util.DIRECTION.NONE


## Makes the player look in a given direction without moving. Enters the LOOKING
## state (with a turn cooldown unless suppressed) so a keyboard tap turns before
## it walks; the actual facing/sprite change is shared with mouse aiming via _face.
func _look(direction: Util.DIRECTION, start_cooldown=true) -> void:
	if direction == Util.DIRECTION.NONE:
		return

	_face(direction)
	_state = Util.PLAYER_STATE.LOOKING
	if start_cooldown:
		_time_left = _LOOK_DURATION


## Points the sprite in `direction` -- facing, horizontal flip, and animation --
## without touching the state machine. Shared by keyboard look (_look) and the
## continuous mouse aiming in _process, which must not knock the player out of
## its current state. A NONE direction (e.g. the cursor sitting on the player)
## leaves the facing untouched.
func _face(direction: Util.DIRECTION) -> void:
	if direction == Util.DIRECTION.NONE:
		return

	_facing = direction
	if direction in [Util.DIRECTION.UP_LEFT, Util.DIRECTION.DOWN_LEFT]:
		scale.x = -abs(scale.x)
	else:
		scale.x = abs(scale.x)

	# Select the animation only -- AnimSync drives the frame so every idle
	# stays in phase with the lasers and emitters.
	if direction == Util.DIRECTION.UP:
		animation = 'idle_up'
	elif direction == Util.DIRECTION.DOWN:
		animation = 'idle_down'
	elif direction in [Util.DIRECTION.UP_LEFT, Util.DIRECTION.UP_RIGHT]:
		animation = 'idle_upright'
	else:
		animation = 'idle_downright'


## Whether a mouse aim button (move or use, the same buttons _process_idle acts
## on) is held. While held the player is steering with the cursor, so _process
## keeps the facing tracking it each frame -- including as the player walks and
## its own movement, not the mouse, changes the player->cursor angle.
func _mouse_aim_held() -> bool:
	return Input.is_action_pressed('click_move') or Input.is_action_pressed('click_use')


## The hex direction from the player toward the mouse cursor, or NONE when the
## cursor sits on the player. Uses global positions, so the uniform level scale
## doesn't matter -- a uniform scale preserves the angle.
func _cursor_direction() -> Util.DIRECTION:
	return Util.direction_from_vector(get_global_mouse_position() - global_position)


## The mouse position in viewport (screen) space, or ZERO if the node isn't in a
## viewport yet. Used only to detect motion between frames.
func _mouse_screen_position() -> Vector2:
	var vp := get_viewport()
	return vp.get_mouse_position() if vp != null else Vector2.ZERO


## Actually starts the movement animation of the character to a new position
func move(move_object, new_pos: Vector2, old_pos: Vector2) -> void:
	_move_object = move_object
	_move_target = new_pos
	_move_start_pos = old_pos
	_state = Util.PLAYER_STATE.MOVING
	_time_left = _MOVE_DURATION


func use() -> void:
	_state = Util.PLAYER_STATE.USING
	_time_left = _USE_DURATION
