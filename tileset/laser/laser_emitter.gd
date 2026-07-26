extends AnimatedSprite2D

@export var laser_range := -1 ## The range of the laser, -1 for infinite
## Whether the player can toggle this emitter on/off with the use verb. When
## false, using it does nothing (the grid skips it in _attempt_use); level code
## can still toggle the emitter programmatically via use().
@export var interactable := true

var block_type = Util.BLOCK_TYPE.LASER_EMITTER

var activated = true

func use() -> void:
  activated = !activated
