extends Control
## The game's title menu (the main scene). Three options:
##   Experiments  -- opens the level select
##   Calibrations -- opens the settings menu (not implemented yet)
##   Drop Out     -- quits the game
## Mouse and keyboard both work; MenuNav (a child node) drives the focus cursor,
## and ESC backs out of the game -- at the top level that means quitting.

const LEVEL_SELECT_SCENE := "res://level_select.tscn"


func _ready() -> void:
	$Center/Menu/Experiments.pressed.connect(_on_experiments)
	$Center/Menu/Calibrations.pressed.connect(_on_calibrations)
	$Center/Menu/DropOut.pressed.connect(_on_drop_out)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):  # ESC: back out of the game
		_on_drop_out()
		get_viewport().set_input_as_handled()


func _on_experiments() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func _on_calibrations() -> void:
	# TODO: open the calibrations (settings) menu once it exists.
	push_warning("Calibrations menu not implemented yet")


func _on_drop_out() -> void:
	get_tree().quit()
