extends Sprite2D
class_name Crate
## A solid block, like a wall, except it is opaque to lasers: a beam stops dead
## against it instead of passing through (walls are deliberately laser-
## transparent). The block itself doesn't move the player and, off a track, is
## not pushable. When light strikes it the grid draws a flat-cut half-beam into
## the crate cell -- the same half-beam a prism uses for its incoming light --
## and the crate sprite (higher z-index) hides the cut end, so the beam looks
## like it hits the crate face (see Grid._draw_crate_hit). Placeholder sprite is
## a copy of the prism for the artist to replace later.

var block_type := Util.BLOCK_TYPE.CRATE
