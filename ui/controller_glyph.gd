@tool
extends Control
class_name ControllerGlyph
## Placeholder gamepad icon, drawn in code -- a white rounded body with a d-pad,
## two analog sticks and four face buttons. GEN-564 marks the real controller art
## as TBD; swap this for a texture (or the Controller Icons addon) when it lands.

const COLOR_BODY := Color(1, 1, 1)
const COLOR_DETAIL := KeyCap.COLOR_BG  # dark blue, matches the keycaps

@export var glyph_size := Vector2(108, 68): set = set_glyph_size


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
	var line_w := maxf(2.0, h * 0.06)

	# Body: a wide, rounded white rectangle (a gamepad silhouette).
	var body := StyleBoxFlat.new()
	body.bg_color = COLOR_BODY
	var r := int(h * 0.42)
	body.corner_radius_top_left = r
	body.corner_radius_top_right = r
	body.corner_radius_bottom_left = r
	body.corner_radius_bottom_right = r
	body.corner_detail = 8
	draw_style_box(body, Rect2(Vector2.ZERO, glyph_size))

	# D-pad (left): a plus made of two thin bars.
	var dpad := Vector2(w * 0.26, h * 0.42)
	var arm := h * 0.16
	draw_line(Vector2(dpad.x - arm, dpad.y), Vector2(dpad.x + arm, dpad.y), COLOR_DETAIL, line_w)
	draw_line(Vector2(dpad.x, dpad.y - arm), Vector2(dpad.x, dpad.y + arm), COLOR_DETAIL, line_w)

	# Face buttons (right): four small circles in a diamond.
	var face := Vector2(w * 0.74, h * 0.42)
	var spread := h * 0.17
	var dot := h * 0.06
	draw_circle(Vector2(face.x, face.y - spread), dot, COLOR_DETAIL)
	draw_circle(Vector2(face.x, face.y + spread), dot, COLOR_DETAIL)
	draw_circle(Vector2(face.x - spread, face.y), dot, COLOR_DETAIL)
	draw_circle(Vector2(face.x + spread, face.y), dot, COLOR_DETAIL)

	# Analog sticks: two outlined circles low and central.
	var stick_r := h * 0.11
	draw_arc(Vector2(w * 0.42, h * 0.72), stick_r, 0, TAU, 20, COLOR_DETAIL, line_w)
	draw_arc(Vector2(w * 0.58, h * 0.72), stick_r, 0, TAU, 20, COLOR_DETAIL, line_w)
