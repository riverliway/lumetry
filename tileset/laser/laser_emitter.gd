extends AnimatedSprite2D

@export var laser_range := -1 ## The range of the laser, -1 for infinite

var block_type = Util.BLOCK_TYPE.LASER_EMITTER

var activated = true

func use() -> void:
  activated = !activated
