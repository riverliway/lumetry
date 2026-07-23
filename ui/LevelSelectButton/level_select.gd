extends Control
## Level-select screen. Each "LevelN" button (N = 1..18) opens
## levels/levelN/level_N.tscn. Buttons are wired up generically by name so
## adding or reordering them needs no per-button handler. Each button reflects the
## level's SaveData state (0-based): LOCKED is disabled and inert, UNLOCKED is
## playable, and COMPLETED is playable and tinted.
##
## A child MenuNav drives the focus cursor (mouse hover + WASD); ESC backs out to
## the title menu.

const TITLE_MENU_SCENE := "res://title_menu.tscn"
## Tint applied to a completed level's button. Placeholder until completed-state
## button art exists.
const COMPLETED_TINT := Color(0.55, 1.0, 0.55)

func _ready() -> void:
	for child in get_children():
		if child is TextureButton and String(child.name).begins_with("Level"):
			var number := String(child.name).trim_prefix("Level").to_int()
			if number < 1:
				continue
			match SaveData.get_level_state(number - 1):
				SaveData.LevelState.LOCKED:
					child.disabled = true
				SaveData.LevelState.COMPLETED:
					child.modulate = COMPLETED_TINT
					child.pressed.connect(_open_level.bind(number))
				_:  # UNLOCKED
					child.pressed.connect(_open_level.bind(number))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):  # ESC: back to the title menu
		get_tree().change_scene_to_file(TITLE_MENU_SCENE)
		get_viewport().set_input_as_handled()


func _open_level(number: int) -> void:
	get_tree().change_scene_to_file("res://levels/level%d/level_%d.tscn" % [number, number])
