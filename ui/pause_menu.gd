extends CanvasLayer
## In-level pause menu. The `pause` action (ESC) opens it and freezes the whole
## sim via get_tree().paused -- player movement, any in-flight rotation animation,
## and the ambient AnimSync clock all stop cleanly, since every one of them is
## driven by _process. ESC again, or Resume, unfreezes.
##
## Options: Resume, Reset Room (reloads the room to its start -- a stand-in until
## the in-place room-reset feature lands), Calibrations (opens the options overlay:
## audio, colorblind mode, text speed), and Quit to Level Select. The whole menu
## runs with PROCESS_MODE_ALWAYS (set in the scene) so it keeps working while the
## tree is paused; a child MenuNav drives the mouse/keyboard cursor.

const LEVEL_SELECT_SCENE := "res://level_select.tscn"

@onready var _menu: Control = $Menu
@onready var _nav: Node = $Menu/Center/Box/MenuNav
@onready var _options: Control = $Menu/Options


func _ready() -> void:
	_menu.hide()
	$Menu/Center/Box/Resume.pressed.connect(resume)
	$Menu/Center/Box/ResetRoom.pressed.connect(_on_reset_room)
	$Menu/Center/Box/Calibrations.pressed.connect(_on_calibrations)
	$Menu/Center/Box/Quit.pressed.connect(_on_quit)
	_options.closed.connect(_on_options_closed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _options.visible:
			return  # the options overlay owns ESC while it's up (it closes itself)
		if _menu.visible:
			resume()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	get_tree().paused = true
	_menu.show()
	_nav.focus_first()


func resume() -> void:
	_menu.hide()
	get_tree().paused = false


func _on_reset_room() -> void:
	get_tree().paused = false
	Transition.transition(func(): get_tree().reload_current_scene())


func _on_calibrations() -> void:
	_options.open()


func _on_options_closed() -> void:
	$Menu/Center/Box/Calibrations.grab_focus()  # return the cursor to the pause menu


func _on_quit() -> void:
	get_tree().paused = false
	Transition.change_scene_to(LEVEL_SELECT_SCENE)
