extends Node2D
class_name Track

## A track lets certain blocks be pushed along fixed hex directions. It is drawn,
## not sprited: each enabled direction is a rounded line segment radiating from the
## cell center -- a dark navy body with a smaller, lighter body layered on top.
##
## Every dark body is drawn before every light body, so arms sharing this cell's
## center blend into smooth corners automatically: the light centers join without a
## dark seam cutting across them, whatever order the arms happen to be drawn in.

var block_type := Util.BLOCK_TYPE.TRACK
var directions: Array[Util.DIRECTION] = []

## Each child node is a visibility flag for the direction it enables. The level
## scenes toggle these children's `visible` to pick a track's shape; the children
## render nothing themselves -- this node draws every visible arm.
const ARM_DIRS := {
	"Top": Util.DIRECTION.UP,
	"Bottom": Util.DIRECTION.DOWN,
	"BottomLeft": Util.DIRECTION.DOWN_LEFT,
	"TopLeft": Util.DIRECTION.UP_LEFT,
	"TopRight": Util.DIRECTION.UP_RIGHT,
	"BottomRight": Util.DIRECTION.DOWN_RIGHT,
}

## Dark outer body and the lighter body layered on top of it.
@export var outer_color := Color("3d5aa8")
@export var inner_color := Color("141d3b")
@export var border_color := Color("5aa4c1ff")

## Half-width of the dark body, which is also the radius of its rounded center cap.
## The inner body is BORDER thinner on each side. ARM_LENGTH reaches from the cell
## center to the shared edge with a neighbor (~half a cell), so adjacent arms meet.
const OUTER_RADIUS := 26.0
const INNER_RADIUS := 9.0
const BORDER_SIZE := 2
const ARM_LENGTH := 98.0


func _ready() -> void:
	for arm_name in ARM_DIRS:
		if get_node(arm_name).is_visible():
			directions.append(ARM_DIRS[arm_name])
	queue_redraw()


func _draw() -> void:
	for dir in directions:
		_draw_arm(dir, OUTER_RADIUS + BORDER_SIZE, border_color)
	for dir in directions:
		_draw_arm(dir, OUTER_RADIUS, outer_color)
	for dir in directions:
		_draw_arm(dir, OUTER_RADIUS - INNER_RADIUS + BORDER_SIZE, border_color)
	for dir in directions:
		_draw_arm(dir, OUTER_RADIUS - INNER_RADIUS, inner_color)


## Draws one rounded segment for `dir`: a rectangle extending outward from the cell
## center, capped by a semicircle centered on that origin, in the given color.
func _draw_arm(dir: Util.DIRECTION, radius: float, color: Color) -> void:
	draw_set_transform(Vector2.ZERO, Util.get_rotation_from_direction(dir))
	draw_circle(Vector2.ZERO, radius, color)
	draw_rect(Rect2(-radius, 0.0, radius * 2.0, ARM_LENGTH), color)
	draw_set_transform(Vector2.ZERO, 0.0)
