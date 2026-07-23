extends Sprite2D
class_name Meltable
## A block that the DESTRUCTIVE beam melts. It is solid to ordinary light (a
## normal beam stops against it), but a destructive beam removes it, after which
## the laser physics re-resolves so the freshly cleared cell lets light through
## (see Grid.handle_laser_physics). Placeholder sprite is a tinted copy of the
## prism to tell it apart from other blocks.

var block_type := Util.BLOCK_TYPE.MELTABLE
