extends GutTest
## Unit tests for the InputMapper autoload (global/input_mapper.gd): overlaying
## saved rebinds onto the live InputMap, live rebinding with conflict-swap, keeping
## other event kinds intact, and resetting to defaults.
##
## Each test restores the InputMap from project settings and the saved bindings
## afterward, so a rebind can't leak into the many other tests that read the same
## move_* / use actions.

var _saved


func before_each() -> void:
	_saved = SaveData.data.duplicate(true)

func after_each() -> void:
	SaveData.data = _saved
	InputMap.load_from_project_settings()  # undo any live rebind this test made


func _key_code(action: String) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode if event.physical_keycode != 0 else event.keycode
	return 0

func _button_index(action: String) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return event.button_index
	return -1


func test_rebind_key_changes_the_live_binding_and_persists():
	InputMapper.rebind_key("use", KEY_F)
	assert_eq(_key_code("use"), KEY_F, "InputMap now maps use to F")
	assert_eq(SaveData.get_key_binding("use"), KEY_F, "the choice is saved")


func test_rebind_key_swaps_with_a_conflicting_action():
	# move_up defaults to W, move_down to S. Rebinding move_up onto S hands S's old
	# owner (move_down) move_up's freed key, so neither is left doubled or unbound.
	var up_before := _key_code("move_up")
	InputMapper.rebind_key("move_up", _key_code("move_down"))
	assert_eq(_key_code("move_up"), KEY_S, "move_up took S")
	assert_eq(_key_code("move_down"), up_before, "move_down inherited move_up's old key")


func test_apply_all_overlays_saved_overrides():
	SaveData.data["input_bindings"]["key"]["sprint"] = KEY_T
	InputMapper.apply_all()
	assert_eq(_key_code("sprint"), KEY_T, "a saved override is applied to the InputMap")


func test_rebind_button_changes_the_live_binding_and_persists():
	InputMapper.rebind_button("use", 3)
	assert_eq(_button_index("use"), 3, "use is now joypad button 3")
	assert_eq(SaveData.get_button_binding("use"), 3, "the choice is saved")


func test_rebind_key_leaves_the_joypad_button_intact():
	# use also has joypad button 0 by default; a keyboard rebind must not drop it.
	InputMapper.rebind_key("use", KEY_G)
	assert_eq(_button_index("use"), 0, "the joypad button survives a keyboard rebind")


func test_reset_defaults_restores_bindings_and_clears_overrides():
	InputMapper.rebind_key("use", KEY_J)
	InputMapper.reset_defaults()
	assert_eq(_key_code("use"), KEY_SPACE, "use is back to Space")
	assert_eq(SaveData.get_key_binding("use"), 0, "the override is cleared")


func test_current_key_label_reads_the_bound_key():
	assert_eq(InputMapper.current_key_label("move_up"), "W", "move_up reads W")
	InputMapper.rebind_key("move_up", KEY_T)
	assert_eq(InputMapper.current_key_label("move_up"), "T", "and follows a rebind")
