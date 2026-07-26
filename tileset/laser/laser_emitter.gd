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

func use() -> void:
  activated = !activated
