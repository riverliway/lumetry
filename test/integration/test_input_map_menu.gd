extends GutTest
## Integration coverage for the Controls / input-map overlay (ui/input_map_menu.tscn):
## the 4/6-key toggle, the rebind rows built from the live map, a click-to-rebind
## capture, controller vs keyboard views, reset, and back. Loads the real scene, so
## it also guards the .tscn wiring the script relies on. The InputMap and SaveData
## are restored afterward so rebinds don't leak into other tests.
##
## No joypad is connected under headless test, so open() lands on the keyboard view
## and the Device toggle is hidden; the controller view is exercised by driving the
## menu's device flag directly.

const MenuScene := preload("res://ui/input_map_menu.tscn")

var _saved


func before_each() -> void:
	_saved = SaveData.data.duplicate(true)

func after_each() -> void:
	SaveData.data = _saved
	InputMap.load_from_project_settings()


func _open(scheme := "six_key") -> Control:
	SaveData.data["settings"]["movement_scheme"] = scheme
	var menu: Control = MenuScene.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame  # let _ready hide + wire
	menu.open()
	return menu


func _rows(menu: Control) -> Node:
	return menu.get_node("Center/Panel/Box/Rows")

func _caps(menu: Control) -> Array:
	var found: Array = []
	_gather(_rows(menu), found, func(n): return n is KeyCap)
	return found

func _find_cap(menu: Control, action: String) -> KeyCap:
	var button := _find_button(menu, action)
	return button.get_node("Cap") if button else null

func _find_button(menu: Control, action: String) -> Button:
	var found: Array = []
	_gather(_rows(menu), found, func(n): return n is Button and n.get_meta("action", "") == action)
	return found[0] if not found.is_empty() else null

func _gather(node: Node, out: Array, predicate: Callable) -> void:
	for child in node.get_children():
		if predicate.call(child):
			out.append(child)
		_gather(child, out, predicate)


func test_open_reflects_the_saved_scheme_and_toggles_it():
	var menu := await _open("four_key")
	var toggle := menu.get_node("Center/Panel/Box/Scheme/Toggle")
	assert_eq(toggle.text, "4-Key", "open reflects the saved scheme")
	toggle.pressed.emit()
	assert_eq(SaveData.get_setting("movement_scheme"), "six_key", "4-key -> 6-key")
	assert_eq(toggle.text, "6-Key", "label updates")


func test_six_key_view_lists_six_movement_plus_three_action_caps():
	assert_eq(_caps(await _open("six_key")).size(), 9, "6 movement + 3 action caps")

func test_four_key_view_lists_four_movement_plus_three_action_caps():
	assert_eq(_caps(await _open("four_key")).size(), 7, "4 movement + 3 action caps")


func test_scheme_toggle_rebuilds_the_rows():
	var menu := await _open("four_key")
	assert_eq(_caps(menu).size(), 7, "starts on the 4-key row set")
	menu.get_node("Center/Panel/Box/Scheme/Toggle").pressed.emit()
	assert_eq(_caps(menu).size(), 9, "switches to the 6-key row set")


func test_caps_show_the_current_bindings():
	var menu := await _open("six_key")
	assert_eq(_find_cap(menu, "move_up").key, "W", "move_up cap shows W")
	assert_eq(_find_cap(menu, "use").key, "Space", "use cap shows Space")


func test_rebinding_a_key_updates_the_cap_and_persists():
	var menu := await _open("six_key")
	menu._begin_listening("move_up", "key", _find_button(menu, "move_up"))
	var press := InputEventKey.new()
	press.physical_keycode = KEY_T
	press.pressed = true
	menu._input(press)  # captured as the new binding
	assert_eq(SaveData.get_key_binding("move_up"), KEY_T, "the rebind is saved")
	assert_eq(_find_cap(menu, "move_up").key, "T", "the rebuilt cap shows the new key")


func test_escape_cancels_a_rebind_without_changing_the_binding():
	var menu := await _open("six_key")
	menu._begin_listening("move_up", "key", _find_button(menu, "move_up"))
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	menu._input(esc)
	assert_eq(SaveData.get_key_binding("move_up"), 0, "no override was written")
	assert_eq(_find_cap(menu, "move_up").key, "W", "the cap is restored to W")


func test_controller_view_shows_movement_readonly_and_editable_actions():
	var menu := await _open("six_key")
	menu._showing_controller = true
	menu._rebuild_rows()
	# Movement is the stick/D-pad (a read-only row, no cap); only the three action
	# rows carry an editable button cap.
	assert_eq(_caps(menu).size(), 3, "only the action rows carry caps in the controller view")
	assert_not_null(_find_button(menu, "use"), "the interact button is rebindable")
	assert_null(_find_button(menu, "move_up"), "movement is not rebindable on a controller")


func test_rebinding_a_controller_button_persists():
	var menu := await _open("six_key")
	menu._showing_controller = true
	menu._rebuild_rows()
	menu._begin_listening("use", "btn", _find_button(menu, "use"))
	var press := InputEventJoypadButton.new()
	press.button_index = 3
	press.pressed = true
	menu._input(press)
	assert_eq(SaveData.get_button_binding("use"), 3, "the controller rebind is saved")


func test_device_toggle_hidden_without_a_controller():
	var menu := await _open()
	assert_false(menu.get_node("Center/Panel/Box/Device").visible, "no pad: device toggle hidden")
	assert_true(menu.get_node("Center/Panel/Box/Device/Toggle").disabled, "and disabled")


func test_reset_restores_default_bindings():
	var menu := await _open("six_key")
	InputMapper.rebind_key("use", KEY_J)
	menu.get_node("Center/Panel/Box/Reset").pressed.emit()
	assert_eq(SaveData.get_key_binding("use"), 0, "reset clears the override")
	assert_eq(_find_cap(menu, "use").key, "Space", "and the cap is back to Space")


func test_back_closes_and_emits():
	var menu := await _open()
	assert_true(menu.visible, "open shows the overlay")
	watch_signals(menu)
	menu.close()
	assert_false(menu.visible, "close hides it")
	assert_signal_emitted(menu, "closed")


func test_esc_closes_the_overlay():
	var menu := await _open()
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	menu._unhandled_input(esc)
	assert_false(menu.visible, "ESC closes the input-map overlay")
