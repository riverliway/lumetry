extends GutTest
## Shared fixtures for the Lumetry test suite.
##
## Tests build their own isolated rooms from the stable *component* scenes
## (player, emitter, wall, mirror, prism, track) placed at controlled grid
## coordinates. Nothing here depends on the real puzzle levels, which change
## frequently. Integration tests extend this class.

const PlayerScene: PackedScene = preload("res://player/player.tscn")
const EmitterScene: PackedScene = preload("res://tileset/laser/laser_emitter.tscn")
const WallScene: PackedScene = preload("res://tileset/wall/wall.tscn")
const MirrorScene: PackedScene = preload("res://tileset/mirror/mirror.tscn")
const PrismScene: PackedScene = preload("res://tileset/prisim/prisim.tscn")
const TrackScene: PackedScene = preload("res://tileset/track/track.tscn")
const DetectorScene: PackedScene = preload("res://tileset/detector/detector.tscn")
const FocuserScene: PackedScene = preload("res://tileset/focuser/focuser.tscn")
const MeltableScene: PackedScene = preload("res://tileset/meltable/meltable.tscn")

# Grid geometry mirrors Room.Grid (WIDTH/HEIGHT/SIZE/START). Kept in one place so
# the fixture can compute exact cell centers without reaching into private state.
const GRID_WIDTH := 23
const GRID_HEIGHT := 12
const CELL_SIZE := Vector2(168, 192)
const GRID_START := Vector2(79, -17)

# Maps a hex direction to the Track child sprite that enables it (see track.gd).
const TRACK_DIR_NODES := {
	Util.DIRECTION.UP: "Top",
	Util.DIRECTION.DOWN: "Bottom",
	Util.DIRECTION.DOWN_LEFT: "BottomLeft",
	Util.DIRECTION.DOWN_RIGHT: "BottomRight",
	Util.DIRECTION.UP_LEFT: "TopLeft",
	Util.DIRECTION.UP_RIGHT: "TopRight",
}


## World-space center of grid cell (col, row) — matches Room.Grid._init.
func cell_center(col: int, row: int) -> Vector2:
	var px := GRID_START.x + CELL_SIZE.x * col
	var py := GRID_START.y + CELL_SIZE.y * row + (CELL_SIZE.y / 2.0 if col % 2 == 1 else 0.0)
	return Vector2(px, py)


## Instantiates a component scene positioned at a grid cell (optionally rotated).
func make_block(scene: PackedScene, col: int, row: int, rotation_rad := 0.0) -> Node2D:
	var block: Node2D = scene.instantiate()
	block.position = cell_center(col, row)
	block.rotation = rotation_rad
	return block


## Instantiates a Track at a cell with only the given directions enabled.
func make_track(col: int, row: int, dirs: Array) -> Node2D:
	var track: Node2D = TrackScene.instantiate()
	track.position = cell_center(col, row)
	for dir in TRACK_DIR_NODES:
		track.get_node(TRACK_DIR_NODES[dir]).visible = dirs.has(dir)
	return track


## Builds a Room with a Player (at player_cell) plus the supplied blocks, adds it
## to the scene tree so Room._ready() runs (grid built, blocks registered, laser
## physics resolved, player connected), and returns the Room. Auto-freed by GUT.
func build_room(blocks: Array, player_cell := Vector2i(5, 5)) -> Room:
	var room := Room.new()
	var player := PlayerScene.instantiate()
	player.name = "Player"
	player.position = cell_center(player_cell.x, player_cell.y)
	room.add_child(player)
	for block in blocks:
		room.add_child(block)
	add_child_autofree(room)
	return room


## Counts laser segments in the room that are currently lit.
func active_laser_count(room: Room) -> int:
	var count := 0
	for child in room.get_children():
		if child is LaserSegment and child.is_active():
			count += 1
	return count


## Collects the set of laser colors currently lit in the room.
func active_laser_colors(room: Room) -> Dictionary:
	var colors := {}
	for child in room.get_children():
		if child is LaserSegment and child.is_active():
			colors[child.color] = true
	return colors
