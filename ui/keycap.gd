@tool
extends Panel
class_name KeyCap
## A single on-screen keycap: white text on a dark-blue rounded square (GEN-564's
## "key scene"). Feed it a key string -- a character ("a", "W") or a named key
## ("shift", "ctrl", "cmd", "enter", "delete", "space", ...) -- and, optionally, a
## cap size. Built to be created dynamically (see KeyCap.create) so a controls
## display can be rebuilt from whatever the current input map is.
##
## Named "KeyCap", not "Key", because `Key` is a built-in global enum in Godot.

## Dark blue behind the key text.
const COLOR_BG := Color(0.11, 0.16, 0.38)
## White key text.
const COLOR_TEXT := Color(1, 1, 1)
const FONT := preload("res://ui/TypeLightSans-KV84p.otf")
## Text height as a fraction of the cap height.
const FONT_RATIO := 0.52
## Corner rounding as a fraction of the cap height.
const CORNER_RATIO := 0.18
## Horizontal breathing room kept clear on each side when shrinking text to fit.
const SIDE_PADDING_RATIO := 0.14

## Pretty labels for named (non-character) keys. Anything not listed renders
## uppercased as-is, so single characters just work. Case-insensitive lookup.
const DISPLAY_NAMES := {
	"shift": "Shift",
	"ctrl": "Ctrl",
	"control": "Ctrl",
	"cmd": "Cmd",
	"meta": "Cmd",
	"alt": "Alt",
	"opt": "Opt",
	"enter": "Enter",
	"return": "Enter",
	"delete": "Delete",
	"backspace": "Delete",
	"space": "Space",
	"esc": "Esc",
	"escape": "Esc",
	"tab": "Tab",
	"up": "Up",
	"down": "Down",
	"left": "Left",
	"right": "Right",
}

## The key to show -- a character or a named key (case-insensitive).
@export var key: String = "A": set = set_key
## Pixel size of the cap. Width may exceed height for wide keys (e.g. a spacebar).
@export var cap_size: Vector2 = Vector2(72, 72): set = set_cap_size

@onready var _label: Label = $Label


func _ready() -> void:
	_rebuild()


func set_key(value: String) -> void:
	key = value
	if is_node_ready():
		_rebuild()


func set_cap_size(value: Vector2) -> void:
	cap_size = value
	if is_node_ready():
		_rebuild()


## Convenience for building caps in code: `KeyCap.create("W", Vector2(72, 72))`.
static func create(key_string: String, size := Vector2(72, 72)) -> KeyCap:
	var cap: KeyCap = preload("res://ui/keycap.tscn").instantiate()
	cap.key = key_string
	cap.cap_size = size
	return cap


func _rebuild() -> void:
	custom_minimum_size = cap_size
	size = cap_size
	var text := _display_text()
	_label.text = text
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", _fit_font_size(text))
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	add_theme_stylebox_override("panel", _make_stylebox())


## The text to render: a named key's pretty label, else the raw key uppercased.
func _display_text() -> String:
	var trimmed := key.strip_edges()
	var lower := trimmed.to_lower()
	if DISPLAY_NAMES.has(lower):
		return DISPLAY_NAMES[lower]
	return trimmed.to_upper()


## Font size scaled to the cap height, shrunk if the text would overflow the
## width (so "Delete" fits a square cap while "W" fills it).
func _fit_font_size(text: String) -> int:
	var base := int(round(cap_size.y * FONT_RATIO))
	var available := cap_size.x * (1.0 - SIDE_PADDING_RATIO * 2.0)
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x
	if width > available and width > 0.0:
		base = int(floor(base * available / width))
	return maxi(base, 8)


func _make_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	var r := int(round(cap_size.y * CORNER_RATIO))
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_detail = 8
	return sb
