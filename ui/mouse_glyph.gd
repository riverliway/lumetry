@tool
extends Control
class_name MouseGlyph
## Placeholder mouse icon, drawn in code -- a white rounded body with a left/right
## button split and a scroll wheel. GEN-564 marks the real mouse art as TBD; swap
## this for a texture when it lands.

const COLOR_BODY := Color(1, 1, 1)
const COLOR_DETAIL := KeyCap.COLOR_BG  # dark blue, matches the keycaps

@export var glyph_size := Vector2(52, 76): set = set_glyph_size


func set_glyph_size(value: Vector2) -> void:
	glyph_size = value
	custom_minimum_size = value
	size = value
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = glyph_size
	size = glyph_size
	queue_redraw()


func _draw() -> void:
	var w := glyph_size.x
	var h := glyph_size.y
	var line_w := maxf(2.0, w * 0.06)

	# Body: a white, heavily rounded rectangle (capsule-ish, like a mouse shell).
	var body := StyleBoxFlat.new()
	body.bg_color = COLOR_BODY
	var r := int(w * 0.45)
	body.corner_radius_top_left = r
	body.corner_radius_top_right = r
	body.corner_radius_bottom_left = r
	body.corner_radius_bottom_right = r
	body.corner_detail = 8
	draw_style_box(body, Rect2(Vector2.ZERO, glyph_size))

	# Button area: a horizontal divider, and a vertical split between L/R buttons.
	var divider_y := h * 0.42
	var inset := w * 0.12
	draw_line(Vector2(inset, divider_y), Vector2(w - inset, divider_y), COLOR_DETAIL, line_w)
	draw_line(Vector2(w * 0.5, h * 0.08), Vector2(w * 0.5, divider_y), COLOR_DETAIL, line_w)

	# Scroll wheel: a short thick bar centered in the split.
	draw_line(Vector2(w * 0.5, h * 0.14), Vector2(w * 0.5, h * 0.26), COLOR_DETAIL, line_w * 1.6)
