extends Control
## Reusable modal confirm dialog. Starts hidden; open() dims the screen, blocks
## the mouse from the menu behind it, and shows Confirm / Cancel. Mouse and
## keyboard both work (a child MenuNav drives the cursor; ESC cancels). Emits
## `confirmed` or `canceled` and hides itself either way.

signal confirmed
signal canceled

@onready var _message: Label = $Center/Panel/Box/Message
@onready var _confirm_button: Button = $Center/Panel/Box/Buttons/Confirm
@onready var _cancel_button: Button = $Center/Panel/Box/Buttons/Cancel


func _ready() -> void:
	hide()
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_on_cancel)


## Shows the dialog and puts the cursor on Cancel (the safe default). `message` and
## `confirm_text` optionally override the prompt and the confirm button's label; an
## empty string keeps whatever the scene already defines.
func open(message := "", confirm_text := "") -> void:
	if message != "":
		_message.text = message
	if confirm_text != "":
		_confirm_button.text = confirm_text
	show()
	_cancel_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):  # ESC cancels
		_on_cancel()
		get_viewport().set_input_as_handled()


func _on_confirm() -> void:
	hide()
	confirmed.emit()


func _on_cancel() -> void:
	hide()
	canceled.emit()
