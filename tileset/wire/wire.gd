@tool
extends Node2D
class_name Wire
## Purely cosmetic wiring. Holds an arbitrary number of child Sprite2D segments
## that together draw a line from a detector to the thing it powers. Each segment
## is a rounded spoke -- the same shape as a Track arm, but much thinner and in red
## -- radiating from a hex cell; where two meet they blend into a smooth joint. A
## single activate()/deactivate() (or setting `activated`) brightens or dims the
## whole run, so a level wires up visual feedback with one call:
##   $Wire.activate()
## It is decoration only -- no block_type, not part of the grid/laser physics.
##
## Placement: add the Wire as a child of the LEVEL ROOT (a sibling of Floor/Room,
## NOT a child of Room -- Room._ready would try to load it as a grid block and it
## has no block_type). Then add/duplicate Sprite2D children and drag them into
## place; while `snap_enabled` is on, each segment locks to the nearest hex cell
## center and the nearest of the six hex spoke angles as you move it (editor
## only), so a wire stays collinear with the cells and beams it runs alongside.
## The child sprites render nothing themselves -- this node draws every segment.

## Hex-grid geometry. Mirrors Room.Grid in levels/room.gd (SIZE / START and the
## odd-column half-cell shift) and tools/generate_floor.py -- keep the three in
## sync if the board geometry ever changes.
const SIZE := Vector2(168, 192)   ## pixels between columns / rows
const START := Vector2(79, -17)   ## world center of cell (0, 0)

## The rounded-segment look, mirroring Track but much thinner and in red: a darker
## red body with a smaller, lighter red core layered on top. Every body of one
## shade is drawn before the next, so segments meeting at a joint blend cleanly.
@export var outer_color := Color("5c1616")   ## darker red (body)
@export var inner_color := Color("d84b4b")   ## lighter red (core)

## Half-width of the darker body (and radius of its rounded cap); the lighter core
## is INNER_RADIUS. Much smaller than a Track arm -- a wire is a thin line. ARM_LENGTH
## reaches half a cell so neighbouring segments meet.
const OUTER_RADIUS := 9.0
const INNER_RADIUS := 5.0
const ARM_LENGTH := 98.0

## How far an unpowered run is dimmed (multiplies every color above).
const DEACTIVATED_MODULATE := Color(0.5, 0.5, 0.5)

## Whether the wire currently reads as powered. Exported so a level can set the
## default in the editor; level code flips it via activate()/deactivate().
@export var activated := false: set = set_activated
## Editor-only: snap segments onto the hex grid as they are placed. Turn off if
## you ever want to hand-place a segment off the lattice.
@export var snap_enabled := true


func _ready() -> void:
	# The child sprites are now just position/rotation markers -- drop their old
	# texture so only this node's drawing shows.
	for sprite in _segments(self):
		sprite.texture = null
	_refresh()
	# Snapping is an authoring aid; the saved scene is already grid-perfect, so
	# there is nothing to do at runtime.
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	# Re-snaps each segment to the grid every frame while editing, and redraws to
	# match. Writes only when a segment is actually off its target, so a settled
	# wire never marks the scene dirty; a segment being dragged jumps cell-to-cell.
	if not Engine.is_editor_hint() or not snap_enabled:
		return
	var moved := false
	for sprite in _segments(self):
		if sprite.texture != null:
			sprite.texture = null  # a freshly duplicated segment; markers stay bare
			moved = true
		var target_pos := _nearest_cell_center(sprite.global_position)
		if not sprite.global_position.is_equal_approx(target_pos):
			sprite.global_position = target_pos
			moved = true
		var target_rot := _nearest_hex_rotation(sprite.global_rotation)
		if absf(wrapf(target_rot - sprite.global_rotation, -PI, PI)) > 0.0001:
			sprite.global_rotation = target_rot
			moved = true
	if moved:
		queue_redraw()


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


## Applies the current power state -- the whole run dims when unpowered -- and redraws.
func _refresh() -> void:
	modulate = Color.WHITE if activated else DEACTIVATED_MODULATE
	queue_redraw()


func _draw() -> void:
	# Every darker body first, then every lighter core, so two segments sharing a
	# joint blend into a smooth corner instead of one body's edge cutting across the
	# other's core (the same layering that gives Track its clean turns).
	var segs := _segments(self)
	var inv := get_global_transform().affine_inverse()
	for seg in segs:
		_draw_segment(inv * seg.get_global_transform(), OUTER_RADIUS, outer_color)
	for seg in segs:
		_draw_segment(inv * seg.get_global_transform(), INNER_RADIUS, inner_color)


## Draws one rounded segment (a rectangle capped by a semicircle at its origin) in
## this node's space, placed by `xform` (a segment marker's transform relative to us).
func _draw_segment(xform: Transform2D, radius: float, color: Color) -> void:
	draw_set_transform_matrix(xform)
	draw_circle(Vector2.ZERO, radius, color)
	draw_rect(Rect2(-radius, 0.0, radius * 2.0, ARM_LENGTH), color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


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
