extends GutTest
## Tests for the reusable menu navigation helper (ui/menu_nav.gd): enabled buttons
## become focusable cursor targets, disabled ones are skipped, and the cursor
## starts on the first enabled button. Setup is deferred, so tests await a frame.

const MenuNavScript := preload("res://ui/menu_nav.gd")


## A Control holding `count` buttons (those in `disabled` start disabled) plus a
## MenuNav child, added to the tree so the deferred setup runs.
func _make_menu(count := 3, disabled := []) -> Control:
	var root := Control.new()
	for i in range(count):
		var button := Button.new()
		button.name = "B%d" % i
		button.disabled = i in disabled
		root.add_child(button)
	var nav := Node.new()
	nav.set_script(MenuNavScript)
	root.add_child(nav)
	add_child_autofree(root)
	return root


func test_first_enabled_button_gets_the_cursor():
	var root := _make_menu()
	await get_tree().process_frame  # let the deferred _setup run
	assert_eq(root.get_node("B0").focus_mode, Control.FOCUS_ALL, "enabled buttons are focusable")
	assert_true(root.get_node("B0").has_focus(), "cursor starts on the first button")


func test_disabled_buttons_are_skipped():
	var root := _make_menu(3, [0])  # first button disabled
	await get_tree().process_frame
	assert_eq(root.get_node("B0").focus_mode, Control.FOCUS_NONE, "disabled button is not a cursor target")
	assert_true(root.get_node("B1").has_focus(), "cursor skips to the first enabled button")


func test_wasd_moves_the_cursor_by_geometry():
	var root := Control.new()
	var top := Button.new()
	top.name = "Top"
	top.position = Vector2(0, 0)
	top.size = Vector2(300, 100)
	root.add_child(top)
	var bottom := Button.new()
	bottom.name = "Bottom"
	bottom.position = Vector2(0, 400)
	bottom.size = Vector2(300, 100)
	root.add_child(bottom)
	var nav := Node.new()
	nav.set_script(MenuNavScript)
	root.add_child(nav)
	add_child_autofree(root)
	await get_tree().process_frame
	assert_true(top.has_focus(), "cursor starts on the top button")
	var event := InputEventAction.new()
	event.action = "move_down"
	event.pressed = true
	nav._unhandled_input(event)
	assert_true(bottom.has_focus(), "move_down moves the cursor to the lower button")


func test_sliders_are_targets_and_left_right_adjust_them():
	var root := Control.new()
	var slider := HSlider.new()
	slider.name = "S"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = 50
	slider.size = Vector2(300, 60)
	root.add_child(slider)
	var nav := Node.new()
	nav.set_script(MenuNavScript)
	root.add_child(nav)
	add_child_autofree(root)
	await get_tree().process_frame
	assert_eq(slider.focus_mode, Control.FOCUS_ALL, "slider is a focusable target")
	assert_true(slider.has_focus(), "cursor starts on the slider")

	var right := InputEventAction.new()
	right.action = "move_right"
	right.pressed = true
	nav._unhandled_input(right)
	assert_eq(slider.value, 55.0, "move_right steps the slider up")

	var left := InputEventAction.new()
	left.action = "move_left"
	left.pressed = true
	nav._unhandled_input(left)
	assert_eq(slider.value, 50.0, "move_left steps the slider down")
