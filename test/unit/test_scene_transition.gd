extends GutTest
## Tests for the fade transition (global/scene_transition.gd). Uses a fresh
## instance -- never the Transition autoload, so no real scene swap happens --
## and drives transition() with a harmless action. Fades are shortened so the
## tests stay fast.

const TransitionScript := preload("res://global/scene_transition.gd")


func _make() -> CanvasLayer:
	var t: CanvasLayer = add_child_autofree(TransitionScript.new())  # _ready builds the overlay
	t.fade_duration = 0.01
	return t


func test_overlay_starts_transparent_and_covers_the_screen():
	var t = _make()
	await get_tree().process_frame
	var overlay: ColorRect = t._overlay
	assert_eq(overlay.color, Color(0, 0, 0, 0), "overlay starts as transparent black")
	assert_eq(overlay.anchor_right, 1.0, "overlay spans the viewport width")
	assert_eq(overlay.anchor_bottom, 1.0, "overlay spans the viewport height")
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "overlay ignores input when idle")


func test_transition_runs_action_while_black_then_fades_back_in():
	var t = _make()
	await get_tree().process_frame
	var alpha_when_run := [-1.0]  # array so the lambda can report back (locals capture by value)
	await t.transition(func(): alpha_when_run[0] = t._overlay.color.a)
	assert_almost_eq(alpha_when_run[0], 1.0, 0.001, "the action runs while the screen is fully black")
	assert_almost_eq(t._overlay.color.a, 0.0, 0.001, "faded back in afterwards")
	assert_eq(t._overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "input passes through again when idle")
	assert_false(t._busy, "not busy after finishing")


func test_transition_is_ignored_while_already_transitioning():
	var t = _make()
	await get_tree().process_frame
	var second_ran := [false]  # array so the lambda can report back
	t.transition(func(): pass)              # start one (not awaited)
	t.transition(func(): second_ran[0] = true)  # try another immediately
	assert_true(t._busy, "a transition is in progress")
	assert_false(second_ran[0], "a second transition is ignored while one is running")
	await get_tree().create_timer(0.1).timeout  # let the first finish before teardown
