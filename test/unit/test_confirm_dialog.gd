extends GutTest
## Unit tests for the reusable modal confirm dialog (ui/confirm_dialog.gd): it starts
## hidden, open() shows it with the cursor on the safe Cancel default (and can
## override the message / confirm label), Confirm and Cancel each emit their signal
## and hide, and ESC cancels. It's used by both the title menu and the options menu.

const ConfirmDialogScene: PackedScene = preload("res://ui/confirm_dialog.tscn")


func _make():
	var dialog = ConfirmDialogScene.instantiate()
	add_child_autofree(dialog)
	return dialog


func _confirm_button(dialog):
	return dialog.get_node("Center/Panel/Box/Buttons/Confirm")

func _cancel_button(dialog):
	return dialog.get_node("Center/Panel/Box/Buttons/Cancel")

func _esc_event() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "pause"
	e.pressed = true
	return e


func test_starts_hidden():
	var dialog = _make()
	await get_tree().process_frame  # let _ready hide it and wire the buttons
	assert_false(dialog.visible, "dialog starts hidden")


func test_open_shows_and_focuses_cancel():
	var dialog = _make()
	await get_tree().process_frame
	dialog.open()
	assert_true(dialog.visible, "open() shows the dialog")
	assert_true(_cancel_button(dialog).has_focus(), "cursor starts on Cancel (the safe default)")


func test_open_overrides_message_and_confirm_label():
	var dialog = _make()
	await get_tree().process_frame
	dialog.open("Delete everything?", "Delete")
	assert_eq(dialog.get_node("Center/Panel/Box/Message").text, "Delete everything?", "message overridden")
	assert_eq(_confirm_button(dialog).text, "Delete", "confirm label overridden")


func test_empty_overrides_keep_existing_text():
	var dialog = _make()
	await get_tree().process_frame
	var original_message = dialog.get_node("Center/Panel/Box/Message").text
	var original_confirm = _confirm_button(dialog).text
	dialog.open()  # no overrides
	assert_eq(dialog.get_node("Center/Panel/Box/Message").text, original_message, "message unchanged")
	assert_eq(_confirm_button(dialog).text, original_confirm, "confirm label unchanged")


func test_confirm_emits_and_hides():
	var dialog = _make()
	await get_tree().process_frame
	dialog.open()
	watch_signals(dialog)
	_confirm_button(dialog).pressed.emit()
	assert_signal_emitted(dialog, "confirmed", "Confirm emits confirmed")
	assert_signal_not_emitted(dialog, "canceled", "Confirm does not also cancel")
	assert_false(dialog.visible, "confirming hides the dialog")


func test_cancel_emits_and_hides():
	var dialog = _make()
	await get_tree().process_frame
	dialog.open()
	watch_signals(dialog)
	_cancel_button(dialog).pressed.emit()
	assert_signal_emitted(dialog, "canceled", "Cancel emits canceled")
	assert_signal_not_emitted(dialog, "confirmed", "Cancel does not also confirm")
	assert_false(dialog.visible, "canceling hides the dialog")


func test_esc_cancels():
	var dialog = _make()
	await get_tree().process_frame
	dialog.open()
	watch_signals(dialog)
	dialog._unhandled_input(_esc_event())
	assert_signal_emitted(dialog, "canceled", "ESC cancels the dialog")
	assert_false(dialog.visible, "ESC hides the dialog")


func test_esc_ignored_while_hidden():
	var dialog = _make()
	await get_tree().process_frame  # stays hidden; never opened
	watch_signals(dialog)
	dialog._unhandled_input(_esc_event())
	assert_signal_not_emitted(dialog, "canceled", "a hidden dialog ignores ESC")
