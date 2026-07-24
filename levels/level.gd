extends Node2D
class_name Level
## Root node for a playable room.
##
## room.gd is the shared, generalized puzzle engine (one per room, as the `Room`
## child). This base presents that room: it uniformly scales the whole level so
## the entire board is always on screen -- a bigger grid renders smaller, a
## smaller grid larger. The view never pans or follows the player.
##
## The hex floor tiles are NOT generated here: they are baked into the scene
## (under a `Floor` node) by the external tool tools/generate_floor.py, so the
## grid is visible in the editor while authoring. Re-run that tool only when the
## room's grid size changes. This base does dim the floor cells that sit under a
## wall at runtime -- it knows the live wall positions, so that needs no re-bake.
##
## Room-specific subclasses (e.g. level_1.gd) extend this to add their own logic
## (win conditions, dialogue, transitions); they must call super._ready().

## Dim tint for floor cells under a wall, so the arena boundary reads darker than
## the open, movable cells. Matches the old hand-authored `is_background` look.
const WALL_FLOOR_MODULATE := Color("ffffff26")
## Pause menu overlay, added to every room so ESC always has a menu behind it.
const PAUSE_MENU := preload("res://ui/pause_menu.tscn")

@onready var room: Room = $Room


func _ready() -> void:
	dim_wall_floor()
	fit_to_screen()
	add_child(PAUSE_MENU.instantiate())


## Dims each baked floor tile that sits on a wall cell, marking the non-playable
## boundary. Derived from the live grid, so it always matches the actual walls.
func dim_wall_floor() -> void:
	var floor_root := get_node_or_null("Floor")
	if floor_root == null or room == null:
		return
	for tile in floor_root.get_children():
		if tile is CanvasItem and room.grid.get_nearest_cell(tile.position).get_block_type() == Util.BLOCK_TYPE.WALL:
			tile.modulate = WALL_FLOOR_MODULATE


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
