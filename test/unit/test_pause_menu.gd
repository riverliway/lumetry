extends GutTest
## Tests for the in-level pause menu (ui/pause_menu.gd). Loads the pause menu
## scene in isolation (never a real level) and drives the pause action directly.
## after_each clears get_tree().paused so a failing test can't leave the whole
## suite frozen. Reset/Quit are only checked for wiring -- pressing them would
## reload/swap the test's scene.

const PauseMenuScene := preload("res://ui/pause_menu.tscn")


func after_each() -> void:
	get_tree().paused = false


func _make() -> CanvasLayer:
	return add_child_autofree(PauseMenuScene.instantiate())


func _pause_event() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "pause"
	e.pressed = true
	return e


func test_starts_hidden_with_all_options_wired():
	var pm = _make()
	await get_tree().process_frame
	assert_false(pm.get_node("Menu").visible, "menu starts hidden")
	for button_name in ["Resume", "ResetRoom", "Calibrations", "Quit"]:
		var button: Button = pm.get_node("Menu/Center/Box/%s" % button_name)
		assert_gt(button.pressed.get_connections().size(), 0, "%s is wired" % button_name)


func test_pause_action_opens_and_freezes_then_closes():
	var pm = _make()
	await get_tree().process_frame
	pm._unhandled_input(_pause_event())
	assert_true(pm.get_node("Menu").visible, "ESC opens the menu")
	assert_true(get_tree().paused, "opening freezes the sim")
	pm._unhandled_input(_pause_event())
	assert_false(pm.get_node("Menu").visible, "ESC again closes the menu")
	assert_false(get_tree().paused, "closing unfreezes the sim")


func test_open_puts_the_cursor_on_the_first_option():
	var pm = _make()
	await get_tree().process_frame
	pm._unhandled_input(_pause_event())
	assert_true(pm.get_node("Menu/Center/Box/Resume").has_focus(), "cursor starts on Resume")


func test_resume_unpauses_and_hides():
	var pm = _make()
	await get_tree().process_frame
	pm._unhandled_input(_pause_event())  # open
	pm.resume()
	assert_false(pm.get_node("Menu").visible, "resume hides the menu")
	assert_false(get_tree().paused, "resume unfreezes the sim")
