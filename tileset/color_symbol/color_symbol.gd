extends Node2D
class_name ColorSymbol
## A shape-coded glyph that makes a laser color distinguishable by more than hue,
## for the colorblind ("patterned") mode. One is attached to every beam segment
## and every detector; it draws the glyph for its owner's current LASER_COLOR.
##
## It shows only when BOTH the owner has marked it active (a beam is lit, or a
## detector is being struck) AND SaveData's colorblind_mode is "patterned", so in
## the default mode the game looks untouched. It reacts to a live mode change via
## SaveData.setting_changed, so toggling the option in the pause menu updates every
## on-screen beam and detector at once without recomputing the laser physics.
##
## Each color gets a distinct silhouette (see _draw): the shapes carry the meaning,
## the fill/outline just keep them legible over a bright beam.

## Glyph half-extent, in the owner sprite's local space (cells are ~200px wide).
const RADIUS := 46.0
## Filled body: near-black so the shape reads as a solid mark over a pale beam.
const FILL := Color(0.05, 0.05, 0.05, 0.92)
## Bright rim so the mark also stands out against dark cells and the player.
const OUTLINE := Color(1, 1, 1, 0.95)
const OUTLINE_WIDTH := 7.0

var _color: Util.LASER_COLOR = Util.LASER_COLOR.WHITE
var _active := false


func _ready() -> void:
	SaveData.setting_changed.connect(_on_setting_changed)
	_apply_visibility()


## Sets which laser color's glyph to draw.
func set_symbol(color: Util.LASER_COLOR) -> void:
	if _color != color:
		_color = color
		queue_redraw()


## Marks whether the owner currently wants the glyph shown (beam lit / detector hit).
## Actual visibility is still gated on colorblind mode being enabled.
func set_active(active: bool) -> void:
	if _active != active:
		_active = active
		_apply_visibility()


func _on_setting_changed(key: String, _value) -> void:
	if key == "colorblind_mode":
		_apply_visibility()
		queue_redraw()


func _apply_visibility() -> void:
	visible = _active and SaveData.get_setting("colorblind_mode") == "patterned"


func _draw() -> void:
	if not visible:
		return
	match _color:
		Util.LASER_COLOR.CYAN:        _draw_circle_glyph()
		Util.LASER_COLOR.MAGENTA:     _draw_polygon_glyph(_triangle())
		Util.LASER_COLOR.YELLOW:      _draw_polygon_glyph(_square())
		Util.LASER_COLOR.WHITE:       _draw_polygon_glyph(_diamond())
		Util.LASER_COLOR.DESTRUCTIVE: _draw_cross()


func _draw_circle_glyph() -> void:
	draw_circle(Vector2.ZERO, RADIUS, FILL)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, OUTLINE, OUTLINE_WIDTH, true)


## Fills `points` and strokes their closed outline.
func _draw_polygon_glyph(points: PackedVector2Array) -> void:
	draw_colored_polygon(points, FILL)
	var closed := points.duplicate()
	closed.push_back(points[0])
	draw_polyline(closed, OUTLINE, OUTLINE_WIDTH, true)


func _draw_cross() -> void:
	var r := RADIUS * 0.85
	draw_line(Vector2(-r, -r), Vector2(r, r), OUTLINE, OUTLINE_WIDTH * 2.2, true)
	draw_line(Vector2(-r, r), Vector2(r, -r), OUTLINE, OUTLINE_WIDTH * 2.2, true)
	draw_line(Vector2(-r, -r), Vector2(r, r), FILL, OUTLINE_WIDTH, true)
	draw_line(Vector2(-r, r), Vector2(r, -r), FILL, OUTLINE_WIDTH, true)


func _triangle() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -RADIUS),
		Vector2(RADIUS * 0.87, RADIUS * 0.5),
		Vector2(-RADIUS * 0.87, RADIUS * 0.5),
	])


func _square() -> PackedVector2Array:
	var s := RADIUS * 0.8
	return PackedVector2Array([
		Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s),
	])


func _diamond() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -RADIUS), Vector2(RADIUS, 0), Vector2(0, RADIUS), Vector2(-RADIUS, 0),
	])
