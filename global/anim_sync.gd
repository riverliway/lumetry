# This script is loaded as a global in the project settings
extends Node
## Global animation clock.
##
## Every ambient looping AnimatedSprite2D in the game (the player, laser
## emitters, laser segments, ...) derives its displayed frame from this single
## clock, so they can never fall out of phase. This matters because sprites are
## created at different times -- e.g. a laser segment is instantiated the moment
## the player pushes a mirror into a new beam path, partway through the cycle.
## If each sprite ran its own timer that new segment would flicker off-beat.
##
## Sprites opt in by joining the [code]synced_anim[/code] group. Their own
## playback is left stopped (no [code]autoplay[/code], select animations with
## [code]animation =[/code] rather than [code]play()[/code]); this node is the
## sole driver of their [code]frame[/code].

const GROUP := "synced_anim"
const FPS := 1.0 ## Frames advanced per second. Matches the sprites' speed 1.0 / duration 1.0.

var _elapsed := 0.0 ## Seconds since the clock started, shared by every synced sprite.

func _process(delta: float) -> void:
	_elapsed += delta
	for node in get_tree().get_nodes_in_group(GROUP):
		sync(node)


## Snaps a single sprite's frame to the global clock immediately. Call this
## right after creating/showing a synced sprite so it never displays a stale
## frame for even one tick (e.g. a laser segment spawned mid-cycle).
func sync(node: Node) -> void:
	var sprite := node as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if count > 0:
		sprite.frame = int(_elapsed * FPS) % count
