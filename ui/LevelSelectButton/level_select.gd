extends Control
## Level-select screen. Each "LevelN" button (N = 1..18) opens
## levels/levelN/level_N.tscn. Buttons are wired up generically by name so
## adding or reordering them needs no per-button handler. A level that isn't
## unlocked in the save file (SaveData, 0-based) is shown disabled and inert.
##
## A child MenuNav drives the focus cursor (mouse hover + WASD); ESC backs out to
## the title menu.

const TITLE_MENU_SCENE := "res://title_menu.tscn"

func _ready() -> void:
	for child in get_children():
		if child is TextureButton and String(child.name).begins_with("Level"):
			var number := String(child.name).trim_prefix("Level").to_int()
			if number < 1:
				continue
			if SaveData.is_level_unlocked(number - 1):
				child.pressed.connect(_open_level.bind(number))
			else:
				child.disabled = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):  # ESC: back to the title menu
		get_tree().change_scene_to_file(TITLE_MENU_SCENE)
		get_viewport().set_input_as_handled()


func _open_level(number: int) -> void:
	get_tree().change_scene_to_file("res://levels/level%d/level_%d.tscn" % [number, number])
