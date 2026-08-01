extends Control
## The Controls screen (GEN-565): the user-defined input map, opened from the
## Calibrations menu. It offers the 4-key / 6-key movement toggle and lets the
## player rebind every keyboard input -- and, when a controller is connected, the
## controller's face buttons -- to keys/buttons of their choosing.
##
## A reusable overlay, instanced into the options menu (which is itself instanced
## into the title and pause menus). It runs with PROCESS_MODE_ALWAYS so it works
## while the game is paused. Back or ESC closes it and emits `closed`.
##
## Each rebind control is a KeyCap (GEN-564's key scene, reused per the ticket)
## wrapped in a flat Button so MenuNav's WASD/controller cursor can land on it.
## Activating one enters a "listening" state: the next key (or joypad button)
## becomes the binding, ESC cancels. Rebinds are applied to the live InputMap and
## persisted through the InputMapper autoload, which also swaps a key/button away
## from any other action that already held it, so nothing is left double-bound.
##
## The rebind rows are rebuilt from the live input map whenever the scheme or the
## shown device changes, so the caps always mirror the real bindings. Movement in
## the controller view is shown read-only: controller movement is the stick/D-pad,
## which isn't a single remappable button.

signal closed

## Label shown for each movement scheme (keys mirror SaveData.MOVEMENT_SCHEMES).
const MOVEMENT_LABEL := {"four_key": "4-Key", "six_key": "6-Key"}

## Non-movement actions listed in both device views (action, row label).
const ACTION_ROWS := [["sprint", "Sprint"], ["use", "Interact"], ["pause", "Pause"]]

## Keyboard movement rows per scheme (action, row label). The labels name the hex
## direction each key drives, matching the player controller's interpretation.
const SIX_KEY_ROWS := [
	["move_up_left", "Up-Left"], ["move_up", "Up"], ["move_up_right", "Up-Right"],
	["move_left", "Down-Left"], ["move_down", "Down"], ["move_right", "Down-Right"],
]
const FOUR_KEY_ROWS := [
	["move_up", "Up"], ["move_left", "Left"], ["move_down", "Down"], ["move_right", "Right"],
]

## Pixel size of the rebind keycaps.
const CAP := Vector2(120, 120)
## Width of the value column, matched to the toggle buttons so caps line up.
const VALUE_WIDTH := 1060.0

@onready var _scheme_row: HBoxContainer = $Center/Panel/Box/Scheme
@onready var _scheme_toggle: Button = $Center/Panel/Box/Scheme/Toggle
@onready var _device_row: HBoxContainer = $Center/Panel/Box/Device
@onready var _device_toggle: Button = $Center/Panel/Box/Device/Toggle
@onready var _rows: VBoxContainer = $Center/Panel/Box/Rows
@onready var _reset: Button = $Center/Panel/Box/Reset
@onready var _back: Button = $Center/Panel/Box/Back
@onready var _nav: Node = $Center/Panel/Box/MenuNav

## Whether the controller map (not the keyboard map) is currently shown.
var _showing_controller := false

## The action currently being rebound (""=none) and the kind ("key"/"btn") of
## event awaited. While an action is set, all input is captured as its new binding
## rather than acted on.
var _listen_action := ""
var _listen_kind := ""


func _ready() -> void:
	hide()
	_scheme_toggle.pressed.connect(_toggle_scheme)
	_device_toggle.pressed.connect(_toggle_device)
	_reset.pressed.connect(_on_reset)
	_back.pressed.connect(close)


## Shows the screen, syncing the toggles and building the rebind rows for the
## current device (the controller map when a pad is connected, else the keyboard).
func open() -> void:
	_refresh_scheme_label()
	# The device toggle only makes sense with a pad attached; hidden AND disabled
	# otherwise, so MenuNav never lands the cursor on it (as options does for Reset).
	var has_pad := not Input.get_connected_joypads().is_empty()
	_device_row.visible = has_pad
	_device_toggle.disabled = not has_pad
	_showing_controller = has_pad  # default to the controller map when one is present
	_refresh_device_label()
	_rebuild_rows()
	show()
	_nav.focus_first()


func close() -> void:
	_cancel_listening()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# ESC backs out (while listening, _input consumes ESC to cancel the rebind, so
	# it never reaches here mid-capture).
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


## While listening, the next key/button press is captured as the binding (ESC
## cancels); otherwise a device press switches the shown map to match it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listen_action != "":
		_capture_rebind(event)
	else:
		_switch_device_to_match(event)


# ------------------------------------------------------------------- toggles
func _toggle_scheme() -> void:
	var current: String = SaveData.get_setting("movement_scheme")
	SaveData.set_setting("movement_scheme", "six_key" if current == "four_key" else "four_key")
	_refresh_scheme_label()
	_rebuild_rows()
	_scheme_toggle.grab_focus()  # keep the cursor put across the rebuild


func _refresh_scheme_label() -> void:
	_scheme_toggle.text = MOVEMENT_LABEL.get(SaveData.get_setting("movement_scheme"), "6-Key")


func _toggle_device() -> void:
	_showing_controller = not _showing_controller
	_refresh_device_label()
	_rebuild_rows()
	_device_toggle.grab_focus()


func _refresh_device_label() -> void:
	_device_toggle.text = "Controller" if _showing_controller else "Keyboard"


func _on_reset() -> void:
	InputMapper.reset_defaults()
	_rebuild_rows()
	_reset.grab_focus()


# ------------------------------------------------------------------ the rows
## Rebuilds the rebind rows for the current device + scheme and re-scans MenuNav
## so its cursor can reach the new caps. Detaches the old rows synchronously so
## they don't overlap the new ones for a frame (queue_free alone is deferred).
func _rebuild_rows() -> void:
	# The 4/6-key scheme governs only keyboard movement, so it's offered in the
	# keyboard view alone; hidden AND disabled elsewhere so MenuNav skips it.
	_scheme_row.visible = not _showing_controller
	_scheme_toggle.disabled = _showing_controller
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _showing_controller:
		_rows.add_child(_readonly_row("Movement", "Stick / D-Pad"))
		for row in ACTION_ROWS:
			_rows.add_child(_button_row(row[0], row[1]))
	else:
		for row in (SIX_KEY_ROWS if _six_key() else FOUR_KEY_ROWS):
			_rows.add_child(_key_row(row[0], row[1]))
		for row in ACTION_ROWS:
			_rows.add_child(_key_row(row[0], row[1]))
	_nav.refresh()


## A keyboard rebind row: the action label and a cap showing its current key,
## which activates keyboard-key listening when pressed.
func _key_row(action: String, label: String) -> HBoxContainer:
	var cap := _rebind_button(action)
	_set_cap_text(cap, InputMapper.current_key_label(action))
	cap.pressed.connect(_begin_listening.bind(action, "key", cap))
	return _row(label, cap)


## A controller-button rebind row: the action label and a cap showing its current
## button, which activates joypad-button listening when pressed.
func _button_row(action: String, label: String) -> HBoxContainer:
	var cap := _rebind_button(action)
	_set_cap_text(cap, ControllerType.button_label(ControllerType.kind_of(), InputMapper.current_button_index(action)))
	cap.pressed.connect(_begin_listening.bind(action, "btn", cap))
	return _row(label, cap)


## A non-editable row (the label and a plain value in the cap column), used for
## controller movement, which isn't rebindable.
func _readonly_row(label: String, value: String) -> HBoxContainer:
	var text := Label.new()
	text.text = value
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return _row(label, text)


## Assembles a row: a fixed-width name label on the left, `value` centered in the
## value column on the right (so caps align under the toggle buttons above).
func _row(label: String, value: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(700, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var cell := CenterContainer.new()
	cell.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(value)
	row.add_child(cell)
	return row


## A flat Button sized to a keycap, with a KeyCap (reused scene) drawn inside it
## and a focus ring so the cursor is visible. `action` is stored so the button can
## be re-found and re-focused after a rebuild.
func _rebind_button(action: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CAP
	button.set_meta("action", action)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", _focus_ring())
	var cap := KeyCap.create("?", CAP)
	cap.name = "Cap"
	_ignore_mouse(cap)  # clicks fall through the cap to the button
	button.add_child(cap)
	return button


func _set_cap_text(button: Button, key_string: String) -> void:
	(button.get_node("Cap") as KeyCap).key = key_string


# ------------------------------------------------------------------ rebinding
func _begin_listening(action: String, kind: String, button: Button) -> void:
	_listen_action = action
	_listen_kind = kind
	_set_cap_text(button, "...")  # prompt: awaiting the new input
	_nav.set_process(false)  # pause the stick-polling cursor while we capture a raw press


## Interprets a press while listening: ESC cancels, otherwise a key (or joypad
## button, per the kind awaited) becomes the new binding. Consumes the event so it
## doesn't leak to the focused button, MenuNav, or the game underneath.
func _capture_rebind(event: InputEvent) -> void:
	var canceled: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if canceled:
		_stop_listening()
		get_viewport().set_input_as_handled()
		return
	if _listen_kind == "key" and event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		InputMapper.rebind_key(_listen_action, code)
		_stop_listening()
		get_viewport().set_input_as_handled()
	elif _listen_kind == "btn" and event is InputEventJoypadButton and event.pressed:
		InputMapper.rebind_button(_listen_action, event.button_index)
		_stop_listening()
		get_viewport().set_input_as_handled()


## Ends the listening state and rebuilds the rows (a rebind may have swapped
## another action's cap), re-focusing the acted row so the cursor stays put.
func _stop_listening() -> void:
	var action := _listen_action
	_cancel_listening()
	_rebuild_rows()
	_focus_action_button(action)


## Clears the listening state without touching the rows -- used when the screen
## closes mid-capture.
func _cancel_listening() -> void:
	if _listen_action == "":
		return
	_listen_action = ""
	_listen_kind = ""
	_nav.set_process(true)


func _focus_action_button(action: String) -> void:
	for row in _rows.get_children():
		for child in row.get_children():
			for leaf in child.get_children():
				if leaf is Button and leaf.get_meta("action", "") == action:
					leaf.grab_focus()
					return


# --------------------------------------------------------------- device swap
## Switches the shown map to the device a press came from -- a joypad press/stick
## push shows the controller map, a key/mouse press the keyboard map. Ignored
## unless a pad is connected (the toggle is hidden then, so only one map exists).
func _switch_device_to_match(event: InputEvent) -> void:
	if _device_toggle.disabled:
		return
	var controller := _showing_controller
	if event is InputEventJoypadButton and event.pressed:
		controller = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		controller = true
	elif event is InputEventKey and event.pressed:
		controller = false
	elif event is InputEventMouseButton and event.pressed:
		controller = false
	if controller != _showing_controller:
		_showing_controller = controller
		_refresh_device_label()
		_rebuild_rows()
		_nav.focus_first()


# ------------------------------------------------------------------- helpers
func _six_key() -> bool:
	return SaveData.get_setting("movement_scheme") == "six_key"


## A transparent-fill outline drawn behind a focused rebind cap, so the cursor is
## visible on the otherwise flat button.
func _focus_ring() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0)
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(int(CAP.y * 0.18))
	return sb


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
