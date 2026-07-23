extends Control
## The game's title menu (the main scene). Three options:
##   Experiments  -- opens the level select
##   Calibrations -- opens the settings menu (not implemented yet)
##   Drop Out     -- quits, after a confirmation
## Mouse and keyboard both work (a child MenuNav drives the focus cursor).
## Quitting -- via Drop Out or ESC -- asks for confirmation first.

const LEVEL_SELECT_SCENE := "res://level_select.tscn"

@onready var _confirm: Control = $Confirm


func _ready() -> void:
	$Center/Menu/Experiments.pressed.connect(_on_experiments)
	$Center/Menu/Calibrations.pressed.connect(_on_calibrations)
	$Center/Menu/DropOut.pressed.connect(_confirm_quit)
	_confirm.confirmed.connect(_quit)
	_confirm.canceled.connect(_on_quit_canceled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _confirm.visible:  # ESC: back out
		_confirm_quit()
		get_viewport().set_input_as_handled()


func _on_experiments() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func _on_calibrations() -> void:
	# TODO: open the calibrations (settings) menu once it exists.
	push_warning("Calibrations menu not implemented yet")


func _confirm_quit() -> void:
	_confirm.open()


func _quit() -> void:
	get_tree().quit()


func _on_quit_canceled() -> void:
	$Center/Menu/DropOut.grab_focus()  # return the cursor to the menu
