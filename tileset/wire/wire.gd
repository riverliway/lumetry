@tool
extends Node2D
class_name Wire
## Purely cosmetic wiring. Holds an arbitrary number of child Sprite2D segments
## that together draw a line from a detector to the thing it powers. A single
## activate()/deactivate() (or setting `activated`) swaps every segment between
## its lit and unlit texture, so a level wires up visual feedback with one call:
##   $Wire.activate()
## It is decoration only -- no block_type, not part of the grid/laser physics.
##
## Placement: add the Wire as a child of the LEVEL ROOT (a sibling of Floor/Room,
## NOT a child of Room -- Room._ready would try to load it as a grid block and it
## has no block_type). Then add/duplicate Sprite2D children and drag them into
## place; while `snap_enabled` is on, each segment locks to the nearest hex cell
## center and the nearest of the six hex spoke angles as you move it (editor
## only), so a wire stays collinear with the cells and beams it runs alongside.

const TEXTURE_ACTIVATED := preload("res://tileset/wire/wire_activated.png")
const TEXTURE_DEACTIVATED := preload("res://tileset/wire/wire_deactivated.png")

## Hex-grid geometry. Mirrors Room.Grid in levels/room.gd (SIZE / START and the
## odd-column half-cell shift) and tools/generate_floor.py -- keep the three in
## sync if the board geometry ever changes.
const SIZE := Vector2(168, 192)   ## pixels between columns / rows
const START := Vector2(79, -17)   ## world center of cell (0, 0)

## Whether the wire currently reads as powered. Exported so a level can set the
## default in the editor; level code flips it via activate()/deactivate().
@export var activated := false: set = set_activated
## Editor-only: snap segments onto the hex grid as they are placed. Turn off if
## you ever want to hand-place a segment off the lattice.
@export var snap_enabled := true


func _ready() -> void:
	_refresh()
	# Snapping is an authoring aid; the saved scene is already grid-perfect, so
	# there is nothing to do at runtime.
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	# Re-snaps each segment to the grid every frame while editing. Writes only
	# when a segment is actually off its target, so a settled wire never marks
	# the scene dirty; a segment being dragged jumps cell-to-cell as it moves.
	if not Engine.is_editor_hint() or not snap_enabled:
		return
	for sprite in _segments(self):
		var target_pos := _nearest_cell_center(sprite.global_position)
		if not sprite.global_position.is_equal_approx(target_pos):
			sprite.global_position = target_pos
		var target_rot := _nearest_hex_rotation(sprite.global_rotation)
		if absf(wrapf(target_rot - sprite.global_rotation, -PI, PI)) > 0.0001:
			sprite.global_rotation = target_rot


## Light every segment.
func activate() -> void:
	set_activated(true)


## Dim every segment.
func deactivate() -> void:
	set_activated(false)


func set_activated(value: bool) -> void:
	activated = value
	if is_node_ready():
		_refresh()


## Swaps every Sprite2D descendant to the texture matching the current state.
func _refresh() -> void:
	var texture := TEXTURE_ACTIVATED if activated else TEXTURE_DEACTIVATED
	for sprite in _segments(self):
		sprite.texture = texture


## The world center of the hex cell nearest `p`. Same nearest-cell math as
## Room.Grid.get_nearest_cell, minus the clamp to a fixed board size.
func _nearest_cell_center(p: Vector2) -> Vector2:
	var col := roundi((p.x - START.x) / SIZE.x)
	var shift := SIZE.y / 2.0 if col % 2 != 0 else 0.0
	var row := roundi((p.y - START.y - shift) / SIZE.y)
	return Vector2(START.x + SIZE.x * col, START.y + SIZE.y * row + shift)


## The one of the six hex spoke rotations closest to `current`. Uses the grid's
## true pixel geometry (a diagonal step is (SIZE.x, SIZE.y/2), ~60.26 deg from
## vertical), matching Grid.laser_rotation so wires stay collinear with beams.
func _nearest_hex_rotation(current: float) -> float:
	# World-space offsets to a cell's six neighbors (down, up, and the four
	# diagonals), derived from the grid geometry so a spoke lines up with a step.
	var offsets := [
		Vector2(0, SIZE.y), Vector2(0, -SIZE.y),
		Vector2(SIZE.x, SIZE.y / 2.0), Vector2(-SIZE.x, SIZE.y / 2.0),
		Vector2(SIZE.x, -SIZE.y / 2.0), Vector2(-SIZE.x, -SIZE.y / 2.0),
	]
	var best := 0.0
	var best_diff := TAU
	for offset in offsets:
		# The sprite points DOWN (+y) at rotation 0, so subtract that reference.
		var rot: float = offset.angle() - PI / 2.0
		var diff := absf(wrapf(rot - current, -PI, PI))
		if diff < best_diff:
			best_diff = diff
			best = rot
	return best


## Collects every Sprite2D under `node` (recursively), so nested groupings of
## segments still all respond to a single activate() call.
func _segments(node: Node) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for child in node.get_children():
		if child is Sprite2D:
			found.append(child)
		found.append_array(_segments(child))
	return found
