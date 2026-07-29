extends Sprite2D

const _SHORT_TEXTURE := preload("res://tileset/mirror/mirror_short.png")
const _LONG_TEXTURE := preload("res://tileset/mirror/mirror_long.png")

var block_type = Util.BLOCK_TYPE.MIRROR_SHORT

## Swaps the sprite to match the mirror's finalized short/long type. A mirror is
## authored as short by default and Room.Cell.set_block() promotes it to long when
## it's placed at a half-direction rotation; it calls this so the sprite follows.
func apply_type_sprite() -> void:
	texture = _LONG_TEXTURE if block_type == Util.BLOCK_TYPE.MIRROR_LONG else _SHORT_TEXTURE
