extends AnimatedSprite2D

var block_type = Util.BLOCK_TYPE.LASER_EMITTER

var activated = true

func use() -> void:
  activated = !activated
