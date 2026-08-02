extends GutTest
## Unit tests for the hold-to-reset meter (ui/reset_hold.gd): the R-held timer that
## reloads the room, and the release-cancels behaviour. _process is driven manually
## so the timing is deterministic, and the actual scene reload is disconnected so a
## completed hold can be asserted without reloading the test runner itself.

const ResetHoldScript := preload("res://ui/reset_hold.gd")


func _make_meter() -> Control:
	var m := Control.new()
	m.set_script(ResetHoldScript)
	add_child_autofree(m)
	m.set_process(false)  # drive _process manually, no auto-ticks
	# Never actually reload the current (test) scene when a hold completes here.
	if m.reset_fired.is_connected(m._reload_room):
		m.reset_fired.disconnect(m._reload_room)
	return m


func after_each() -> void:
	if Input.is_action_pressed("reset"):
		Input.action_release("reset")


func test_holding_fills_the_meter_over_time():
	var m = _make_meter()
	Input.action_press("reset")
	m._process(1.0)
	assert_almost_eq(m._held, 1.0, 0.001, "one second held")
	m._process(1.0)
	assert_almost_eq(m._held, 2.0, 0.001, "accumulates while held")

func test_releasing_before_the_end_empties_the_meter():
	var m = _make_meter()
	Input.action_press("reset")
	m._process(2.0)
	assert_gt(m._held, 0.0, "meter partway up")
	Input.action_release("reset")
	m._process(0.1)
	assert_eq(m._held, 0.0, "releasing empties the meter, so it disappears")

func test_a_full_hold_fires_the_reset():
	var m = _make_meter()
	watch_signals(m)
	Input.action_press("reset")
	m._process(ResetHold.HOLD_DURATION + 0.5)  # one tick past the threshold
	assert_signal_emitted(m, "reset_fired", "holding the full duration fires the reset")

func test_held_time_is_capped_at_the_duration():
	var m = _make_meter()
	Input.action_press("reset")
	m._process(10.0)
	assert_almost_eq(m._held, ResetHold.HOLD_DURATION, 0.001, "the meter never overfills")

func test_reset_fires_exactly_once_per_hold():
	var m = _make_meter()
	watch_signals(m)
	Input.action_press("reset")
	m._process(ResetHold.HOLD_DURATION + 0.1)  # fires
	m._process(ResetHold.HOLD_DURATION + 0.1)  # still held -> must not fire again
	assert_signal_emit_count(m, "reset_fired", 1, "the reset fires once, not every frame after")

func test_an_unheld_meter_never_fills():
	var m = _make_meter()
	m._process(1.0)  # nothing pressed
	assert_eq(m._held, 0.0, "an idle meter stays empty")
