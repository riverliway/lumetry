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
