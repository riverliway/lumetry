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
	# facing to the cursor (a keyboard direction press overrides it again). Only
	# a genuine move retargets, so a parked cursor never fights a keyboard player.
	var mouse_screen := _mouse_screen_position()
	var mouse_moved := mouse_screen != _last_mouse_screen
	_last_mouse_screen = mouse_screen
	if mouse_moved and _state != Util.PLAYER_STATE.USING:
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

	var input_direction = _get_input_direction()
	if input_direction == _facing:
		# If the player is already facing the input direction, attempt to move
		attempt_move.emit(input_direction)
	elif _prev_state == Util.PLAYER_STATE.MOVING:
		# If the player just finished moving, we can skip the timer
		_look(input_direction, false)
		attempt_move.emit(input_direction)
	else:
		# If the player is not facing the input direction, look in that direction
		_look(input_direction)


## Processes the looking state
func _process_look() -> void:
	# If any new movement input is detected, look in that direction immediately
	if _movement_just_pressed():
		_look(_get_input_direction())

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


## Whether a movement key for the active scheme was pressed this frame.
func _movement_just_pressed() -> bool:
	var actions = _SIX_KEY_ACTIONS if _six_key() else _FOUR_KEY_ACTIONS
	return actions.any(func(a): return Input.is_action_just_pressed(a))


## Determines the movement direction from the current input, per the active scheme.
func _get_input_direction() -> Util.DIRECTION:
	return _input_direction_six_key() if _six_key() else _input_direction_four_key()


## Four-key scheme: WASD, where a bare left/right resolves to an up- or
## down-diagonal based on the direction the player last looked (`_facing`).
func _input_direction_four_key() -> Util.DIRECTION:
	if Input.is_action_pressed('move_up'):
		if Input.is_action_pressed('move_left'):
			return Util.DIRECTION.UP_LEFT
		elif Input.is_action_pressed('move_right'):
			return Util.DIRECTION.UP_RIGHT

		return Util.DIRECTION.UP

	if Input.is_action_pressed('move_down'):
		if Input.is_action_pressed('move_left'):
			return Util.DIRECTION.DOWN_LEFT
		elif Input.is_action_pressed('move_right'):
			return Util.DIRECTION.DOWN_RIGHT

		return Util.DIRECTION.DOWN

	if Input.is_action_pressed('move_left'):
		if _facing in [Util.DIRECTION.UP, Util.DIRECTION.UP_LEFT, Util.DIRECTION.UP_RIGHT]:
			return Util.DIRECTION.UP_LEFT

		return Util.DIRECTION.DOWN_LEFT

	if Input.is_action_pressed('move_right'):
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
