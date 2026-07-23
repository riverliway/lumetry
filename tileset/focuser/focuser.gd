extends Sprite2D
class_name LaserFocuser
## Joule's focuser -- the opposite of a prism. A prism takes one beam and splits
## it three ways; a focuser takes three beams in through the ports on its back
## and emits a single DESTRUCTIVE beam out the front (the direction it faces).
## The destructive beam is the only light that melts blocks.
##
## The three back ports are the facing direction's opposite and its two
## neighbors (see Grid.focuser_back_ports). Input beams are accumulated across a
## laser resolution pass; once all three ports carry a beam the focuser fires.
## Placeholder sprite is a copy of the prism.

var block_type := Util.BLOCK_TYPE.LASER_FOCUSER

## The beam color currently entering each fed back port (from_dir -> color).
var _ports := {}
## Whether the focuser has already emitted its destructive beam this pass, so the
## resolution fixpoint doesn't fire it twice.
var has_emitted := false


## Clears accumulated inputs at the start of a laser resolution pass.
func reset_ports() -> void:
	_ports.clear()
	has_emitted = false


## Records a beam of `color` arriving through the back port at `from_dir`.
func feed_port(from_dir: Util.DIRECTION, color: Util.LASER_COLOR) -> void:
	_ports[from_dir] = color


## True once all three back ports carry a beam -- the focuser is ready to fire.
func is_ready() -> bool:
	return _ports.size() >= 3
