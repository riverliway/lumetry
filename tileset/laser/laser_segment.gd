extends AnimatedSprite2D
class_name LaserSegment

@onready var from = Util.DIRECTION.NONE ## The direction the laser is coming from
@onready var to = Util.DIRECTION.NONE ## The direction the laser is going to

var color: Util.LASER_COLOR = Util.LASER_COLOR.WHITE ## The color of the laser

## Tint applied over the white base sprite to produce each laser color.
## The white sprite is a pure grayscale ramp with a (1,1,1) highlight, so
## multiplying it by these values reproduces the old per-color sprites.
const LASER_MODULATE := {
	Util.LASER_COLOR.WHITE:       Color(1.0, 1.0, 1.0),
	Util.LASER_COLOR.CYAN:        Color(0.737, 0.756, 1.0),
	Util.LASER_COLOR.MAGENTA:     Color(0.910, 0.738, 1.0),
	Util.LASER_COLOR.YELLOW:      Color(1.0, 0.930, 0.740),
	Util.LASER_COLOR.DESTRUCTIVE: Color(1.0, 0.35, 0.30),
}

## How far a finite-range beam is darkened toward black relative to an infinite
## one, so the two read as visually distinct (a finite emitter fires a dimmer
## beam). Applied over the per-color tint above -- every colored split of a
## finite beam is dimmed too. RGB only: alpha carries the fade-tail and the
## traveling-beam reveal, so darkening must leave it alone (Color.darkened does).
## The finite-emitter sprite is pre-darkened by the same amount in
## tools/image_compiler.py so beam and emitter match.
const FINITE_DARKEN := 0.45

## The tint to apply over the white base sprite for a beam of `color`, dimmed if
## the beam is finite-range. Shared by every laser sprite type (straight,
## mirror, prism, half-beam) so they dim in lockstep.
static func beam_modulate(color: Util.LASER_COLOR, finite: bool) -> Color:
	var tint: Color = LASER_MODULATE.get(color, Color.WHITE)
	return tint.darkened(FINITE_DARKEN) if finite else tint

## The colorblind glyph overlay, if present (null in stripped-down test rigs).
@onready var _symbol: ColorSymbol = get_node_or_null("ColorSymbol")

## Deactivates the laser
func clear_laser() -> void:
	hide()
	if _symbol:
		_symbol.set_active(false)


## Checks if the laser is activated
func is_active() -> bool:
	return visible


## Sets this laser segment to be active
## [br]`from` The direction the laser is coming from
## [br]`to` The direction the laser is going to
## [br]`beam_rotation` The sprite rotation (radians) aligning the beam to the
## true pixel angle between cell centers -- see Grid.laser_rotation. Using the
## real geometry rather than an idealized 60-degree hex angle keeps angled
## beams collinear with the cells they pass through (no per-segment jag).
## [br]`fade` Draw the dissolving-tail sprite instead of the solid beam -- used for
## the final cell of a finite-range beam, so it peters out rather than cutting off.
## [br]`finite` Dim the beam (see beam_modulate) -- true for every cell of a
## finite-range beam, so the whole beam reads as weaker, not just its faded tip.
func set_laser(pfrom: Util.DIRECTION, pto: Util.DIRECTION, laser_color: Util.LASER_COLOR, beam_rotation: float, fade := false, finite := false) -> void:
	color = laser_color
	animation = 'fade' if fade else 'white'
	AnimSync.sync(self)
	self_modulate = beam_modulate(color, finite)
	if _symbol:
		_symbol.set_symbol(color)
		_symbol.set_active(true)

	from = pfrom
	to = pto

	show()
	var angle_from = Util.get_rotation_from_direction(from)
	var angle_to = Util.get_rotation_from_direction(to)

	if is_equal_approx(abs(angle_from - angle_to), PI):
		rotation = beam_rotation
