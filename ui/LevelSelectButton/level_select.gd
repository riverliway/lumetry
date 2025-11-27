extends Control


func _ready() -> void:
	pass # Replace with function body.


func _process(_delta: float) -> void:
	pass


func _on_level_1_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/level1/level_1.tscn")
