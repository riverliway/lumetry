# This script is loaded as a global in the project settings (autoloaded as `InputMapper`).
extends Node
## Applies the player's saved input remaps (GEN-565) to the live InputMap at boot
## and mediates live rebinding from the Controls screen (ui/input_map_menu.gd).
##
## The project's [input] map in project.godot is the source of the *default*
## bindings; SaveData stores only the player's overrides. On boot we overlay those
## overrides onto the InputMap. A rebind replaces just the primary event of the
## kind being changed -- the keyboard key, or the joypad button -- so an action's
## other events (e.g. `use`'s mouse-independent Space/Enter pair, or `pause`'s
## joypad button) survive a keyboard remap and vice versa. Resetting reloads the
## InputMap straight from project settings, restoring every default event exactly.
##
## Only these actions are rebindable. Movement is here for the keyboard (the six
## hex keys, a superset of the four WASD keys) but NOT for the joypad: controller
## movement is the analog stick / D-pad and isn't a single remappable button.

## Keyboard actions whose primary key the player may rebind.
const KEYBOARD_ACTIONS := [
	"move_up_left", "move_up", "move_up_right", "move_left", "move_down", "move_right",
	"sprint", "use", "pause",
]
## Joypad actions whose primary button the player may rebind (movement excluded).
const JOYPAD_ACTIONS := ["use", "sprint", "pause"]


func _ready() -> void:
	apply_all()


## Overlays every saved override onto the InputMap. Safe to call any time; an
## action with no override is left at its project default.
func apply_all() -> void:
	for action in KEYBOARD_ACTIONS:
		var code := SaveData.get_key_binding(action)
		if code != 0:
			_apply_key(action, code)
	for action in JOYPAD_ACTIONS:
		var index := SaveData.get_button_binding(action)
		if index >= 0:
			_apply_button(action, index)


## Rebinds `action`'s keyboard key to `keycode` (a physical keycode), live and
## persisted. If another rebindable keyboard action already holds that key the two
## swap, so no two actions ever share a key and none is left unbound.
func rebind_key(action: String, keycode: int) -> void:
	var clash := _keyboard_action_using(keycode, action)
	if clash != "":
		var freed := current_key_code(action)
		_apply_key(clash, freed)
		SaveData.set_key_binding(clash, freed)
	_apply_key(action, keycode)
	SaveData.set_key_binding(action, keycode)


## Rebinds `action`'s joypad button to `index`, live and persisted, swapping with
## any rebindable joypad action already holding that button (as rebind_key does).
func rebind_button(action: String, index: int) -> void:
	var clash := _joypad_action_using(index, action)
	if clash != "":
		var freed := current_button_index(action)
		_apply_button(clash, freed)
		SaveData.set_button_binding(clash, freed)
	_apply_button(action, index)
	SaveData.set_button_binding(action, index)


## Restores every default binding (reloading the InputMap from project settings,
## so secondary events return too) and clears the saved overrides.
func reset_defaults() -> void:
	InputMap.load_from_project_settings()
	SaveData.clear_input_bindings()


## The physical keycode currently bound to `action`'s keyboard key, or 0 if none.
func current_key_code(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode if event.physical_keycode != 0 else event.keycode
	return 0


## The joypad button index currently bound to `action`, or -1 if none.
func current_button_index(action: String) -> int:
	if not InputMap.has_action(action):
		return -1
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return event.button_index
	return -1


## A readable label ("W", "Space", "Shift") for `action`'s current keyboard key,
## suitable to feed a KeyCap.
func current_key_label(action: String) -> String:
	var code := current_key_code(action)
	return OS.get_keycode_string(code) if code != 0 else "?"


# ------------------------------------------------------------------- internal
## The first rebindable keyboard action other than `except` currently using
## `keycode`, or "" if none -- used to swap on a conflicting rebind.
func _keyboard_action_using(keycode: int, except: String) -> String:
	for action in KEYBOARD_ACTIONS:
		if action != except and current_key_code(action) == keycode:
			return action
	return ""


## The first rebindable joypad action other than `except` currently using `index`.
func _joypad_action_using(index: int, except: String) -> String:
	for action in JOYPAD_ACTIONS:
		if action != except and current_button_index(action) == index:
			return action
	return ""


## Replaces `action`'s keyboard event(s) with a single physical-keycode event,
## leaving its joypad/mouse events untouched.
func _apply_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action, key)


## Replaces `action`'s joypad-button event(s) with a single one, leaving its
## keyboard/mouse/motion events untouched.
func _apply_button(action: String, index: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
	var button := InputEventJoypadButton.new()
	button.button_index = index
	InputMap.action_add_event(action, button)
