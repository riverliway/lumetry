extends Control
## Level-select screen. Each "LevelN" button (N = 1..18) opens
## levels/levelN/level_N.tscn. Buttons are wired up generically by name so
## adding or reordering them needs no per-button handler.

func _ready() -> void:
	for child in get_children():
		if child is TextureButton and String(child.name).begins_with("Level"):
			var number := String(child.name).trim_prefix("Level").to_int()
			if number >= 1:
				child.pressed.connect(_open_level.bind(number))


func _open_level(number: int) -> void:
	get_tree().change_scene_to_file("res://levels/level%d/level_%d.tscn" % [number, number])
