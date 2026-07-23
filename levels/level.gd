extends Node2D
class_name Level
## Root node for a playable room.
##
## room.gd is the shared, generalized puzzle engine (one per room, as the `Room`
## child). This base presents that room: it generates the hex floor to match the
## room's grid size, and uniformly scales the whole level so the entire board is
## always on screen -- a bigger grid renders smaller, a smaller grid larger. The
## view never pans or follows the player.
##
## Room-specific subclasses (e.g. level_1.gd) extend this to add their own logic
## (win conditions, dialogue, transitions); they must call super._ready().
##
## Scene convention: a Level has a `Room` child (the engine) and may have a
## `Floor` child (an empty Node2D) that the generated floor tiles are placed under.

const FLOOR_TEXTURE := preload("res://tileset/floor/Floor.png")

@onready var room: Room = $Room


func _ready() -> void:
	generate_floor()
	fit_to_screen()


## Lays one floor tile at every grid cell, under the "Floor" child if present.
## The floor is generated (not hand-placed) so it always matches the room size.
func generate_floor() -> void:
	var floor_root := get_node_or_null("Floor")
	if floor_root == null or room == null:
		return
	for center in room.grid.cell_centers():
		var tile := Sprite2D.new()
		tile.texture = FLOOR_TEXTURE
		tile.position = center
		floor_root.add_child(tile)


## Uniformly scales and centers this level so the room's board bounds fit the
## design viewport, keeping the whole room visible. Safe to re-run.
func fit_to_screen() -> void:
	if room == null or room.grid == null:
		return
	var design := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 3840),
		ProjectSettings.get_setting("display/window/size/viewport_height", 2160))
	var bounds := room.grid.board_bounds()
	var s: float = min(design.x / bounds.size.x, design.y / bounds.size.y)
	scale = Vector2(s, s)
	# Center the scaled board: map its top-left corner to the centered offset.
	position = (design - bounds.size * s) / 2.0 - bounds.position * s
