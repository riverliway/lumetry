extends AnimatedSprite2D

@export var laser_range := -1 ## The range of the laser, -1 for infinite
## The emitter's starting on/off state. Exported so a level can set the default
## in the editor; from there use() toggles it, and the grid only propagates a
## beam while it is true (see Room.Grid._resolve_lasers).
@export var activated := true
## Whether the player can toggle this emitter on/off with the use verb. When
## false, using it does nothing (the grid skips it in _attempt_use); level code
## can still toggle the emitter programmatically via use().
@export var interactable := true

var block_type = Util.BLOCK_TYPE.LASER_EMITTER

func _ready() -> void:
	# Two independent visual cues, each a frame-for-frame variant of the active
	# sprite so the global anim clock drives them all identically:
	#  * Locked emitters (interactable == false) show the greyed-out sprite.
	#  * Finite-range emitters (laser_range != -1) show a dimmer sprite, matching
	#    the darker beam they fire (see LaserSegment.beam_modulate) so a limited
	#    emitter reads as limited before it's even switched on.
	var finite := laser_range != -1
	if interactable:
		animation = &"finite" if finite else &"default"
	else:
		animation = &"finite_disabled" if finite else &"disabled"

func use() -> void:
	activated = !activated
