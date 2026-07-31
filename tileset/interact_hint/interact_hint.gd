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

var _room_time := 0.0  ## seconds this hint has been alive (~time in room)


func _ready() -> void:
	z_index = -1  # relative to the owner block (z_as_relative defaults to true)
	# Already dismissed in an earlier session? Never show it again.
	if hint_id != "" and SaveData.has_seen_hint(hint_id):
		hide()
		queue_free()


func _process(delta: float) -> void:
	_room_time += delta
	queue_redraw()


## Records this hint as interacted-with (so it never returns) and removes it. The
## grid calls this the first time the player uses the block it sits behind.
func dismiss() -> void:
	if hint_id != "":
		SaveData.mark_hint_seen(hint_id)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(COLOR.r, COLOR.g, COLOR.b, opacity_for(_room_time)))


## The pulse opacity at `room_time` seconds: a smooth sine mapped from [-1,1] to
## [MIN_OPACITY, MAX_OPACITY]. Static so it can be unit-tested without a node.
static func opacity_for(room_time: float) -> float:
	var s := 0.5 + 0.5 * sin(TAU * room_time / PERIOD)  # 0..1, smooth
	return lerp(MIN_OPACITY, MAX_OPACITY, s)
