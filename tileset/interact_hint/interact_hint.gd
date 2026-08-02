extends Node2D
class_name InteractHint
## A pulsing yellow disc drawn behind an interactable block -- a laser emitter or a
## rotation pad -- as a "there is something to do here" nudge. It is hand-placed in
## a level scene as a child of the block; the grid dismisses it the first time the
## player interacts with a block of that kind, in ANY level
## (Room.Grid._attempt_use -> _mark_first_interaction).
##
## Drawn like ColorSymbol rather than a sprite, so it needs no art: a filled circle,
## larger than the block sprite so it reads as a halo around it, whose opacity
## breathes on a sine of the time it has been alive (which, since a room spawns its
## hints at load, is effectively "time in room"). It sits one z-step behind its
## owner, so the block always renders on top of the glow (the halo shows as a ring
## poking out past the block's edges).
##
## There are only two in the whole game -- hand-placed in the scene behind level
## 2's emitter and level 4's rotation pad -- each nudging the player toward their
## first interaction with that kind of block. `hint_id` is the persistent save key
## for the KIND ("emitter" / "pad"), shared by every hint of that kind: once the
## player interacts with any emitter (or any pad), the grid records the key and no
## hint of that kind ever appears again, in any session.
##
## On top of the halo, while the hint is alive it also pops a "Space" keycap in the
## bottom-left of the screen whenever the player is standing in a cell adjacent to
## the hinted block AND facing it -- i.e. the exact moment pressing the use verb
## would interact with it (this mirrors Room.Grid._attempt_use's front-cell check).
## The prompt lives in a screen-space CanvasLayer so the room's fit-to-screen scale
## doesn't shrink it, like the reset overlay (see ui/reset_hold.gd).

## Persistent save key for this hint's KIND -- "emitter" or "pad" -- shared by every
## hint of that kind and matched by Room.Grid on interaction. A hint whose key is
## already recorded frees itself on load; empty means "not persisted" (tests only).
@export var hint_id: String = ""

## Bigger than the block sprites it sits behind (the emitter renders ~210x183 px,
## the pad ~220x192) so the disc is visible as a halo ring around them rather than
## being fully occluded by the block drawn on top.
const RADIUS := 130.0
const COLOR := Color(1.0, 0.85, 0.1)  ## warm yellow
## Opacity swings between these on the sine. 0..1 gives a full blink; nudge them
## inward for a gentler glow.
const MIN_OPACITY := 0.0
const MAX_OPACITY := 1.0
const PERIOD := 1.4  ## seconds for one full dim -> bright -> dim pulse

## The "press this" keycap shown at screen bottom-left while the player is lined up
## to interact. Sized big to match the reset overlay's presence at the 3840x2160
## base resolution, and inset from the corner by PROMPT_MARGIN.
const PROMPT_KEY := "space"
const PROMPT_CAP_SIZE := Vector2(480, 160)  ## wide, so it reads as a spacebar
const PROMPT_MARGIN := 100.0

var _room_time := 0.0  ## seconds this hint has been alive (~time in room)

## The block this hint sits behind (its parent) and the room that owns the grid,
## resolved once in _ready. The Space prompt's screen-space layer and the keycap
## inside it are built lazily; null until then, and stay null on a bare hint node
## with no owning room (tests).
var _block: Node2D = null
var _room: Room = null
var _prompt_layer: CanvasLayer = null
var _prompt_cap: KeyCap = null


func _ready() -> void:
	z_index = -1  # relative to the owner block (z_as_relative defaults to true)
	# Already dismissed in an earlier session? Never show it again.
	if hint_id != "" and SaveData.has_seen_hint(hint_id):
		hide()
		queue_free()
		return

	_block = get_parent() as Node2D  # null on a bare hint node with no block parent (tests)
	_room = _find_room()
	_build_prompt()


func _process(delta: float) -> void:
	_room_time += delta
	queue_redraw()
	_update_prompt()


## Records this hint as interacted-with (so it never returns) and removes it. The
## grid calls this the first time the player uses the block it sits behind. Freeing
## the hint also frees the prompt layer parented to it, so the keycap goes away.
func dismiss() -> void:
	if hint_id != "":
		SaveData.mark_hint_seen(hint_id)
	queue_free()


## The nearest Room ancestor (owner of the grid and player), or null if this hint
## isn't placed under one -- e.g. a bare hint node in a unit test.
func _find_room() -> Room:
	var node := get_parent()
	while node != null:
		if node is Room:
			return node
		node = node.get_parent()
	return null


## Builds the hidden screen-space prompt: a wide "Space" keycap in its own
## CanvasLayer (so the room's fit-to-screen scale leaves it alone), parented to the
## hint so it is freed together with it on dismissal.
func _build_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_cap = KeyCap.create(PROMPT_KEY, PROMPT_CAP_SIZE)
	_prompt_layer.add_child(_prompt_cap)
	_prompt_layer.visible = false
	add_child(_prompt_layer)


## Shows the keycap only while the player is lined up to interact, re-pinning it to
## the bottom-left corner each frame so it survives a window resize.
func _update_prompt() -> void:
	if _prompt_layer == null:
		return
	var active := facing_prompt_active()
	_prompt_layer.visible = active
	if not active:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen := viewport.get_visible_rect().size
	_prompt_cap.position = Vector2(PROMPT_MARGIN, screen.y - PROMPT_MARGIN - _prompt_cap.size.y)


## Whether pressing the use verb right now would interact with the block this hint
## sits behind: the player must occupy a cell adjacent to it and be facing it (the
## cell in front of the player is this hint's cell). False until the hint is bound
## to a live room with a connected player.
func facing_prompt_active() -> bool:
	if _room == null or _block == null:
		return false
	var grid = _room.grid
	if grid == null or grid.player == null:
		return false
	return front_cell_is(grid, grid.player.position, grid.player.get_facing(), _block.position)


## Whether the cell in front of a player at `player_position` facing `facing` is the
## cell holding `block_position`. Pure (takes the grid + plain values) so the
## line-of-interaction rule can be unit-tested without driving player input, the
## same way opacity_for is tested without a node.
static func front_cell_is(grid, player_position: Vector2, facing: Util.DIRECTION, block_position: Vector2) -> bool:
	if grid == null:
		return false
	var front = grid.go(grid.get_nearest_cell(player_position), facing)
	return front != null and front == grid.get_nearest_cell(block_position)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(COLOR.r, COLOR.g, COLOR.b, opacity_for(_room_time)))


## The pulse opacity at `room_time` seconds: a smooth sine mapped from [-1,1] to
## [MIN_OPACITY, MAX_OPACITY]. Static so it can be unit-tested without a node.
static func opacity_for(room_time: float) -> float:
	var s := 0.5 + 0.5 * sin(TAU * room_time / PERIOD)  # 0..1, smooth
	return lerp(MIN_OPACITY, MAX_OPACITY, s)
