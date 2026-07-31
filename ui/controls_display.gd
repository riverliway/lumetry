extends CanvasLayer
class_name ControlsDisplay
## Bottom-left HUD that teaches a first-time player how to move and interact. It
## shows one of two views and swaps between them based on the device last used:
##
##  - keyboard/mouse: the movement keys (a hex of six, or WASD, per the current
##    movement_scheme) with the spacebar under them, then "or", then a mouse; and
##  - controller: a gamepad glyph "+" the confirm button (A, or X on PlayStation).
##
## Built dynamically from the live input map, so it follows key remaps and the
## movement scheme. Shown only until the player first clears level 1 (GEN-564).

const KeyCapScene := preload("res://ui/keycap.tscn")
const MouseGlyphScene := preload("res://ui/mouse_glyph.tscn")
const ControllerGlyphScene := preload("res://ui/controller_glyph.tscn")

const CAP := Vector2(52, 52)          ## a movement key
const CLUSTER_GAP := Vector2(6, 6)    ## spacing between movement keys
const SPACE_HEIGHT := 40.0            ## the spacebar's height (its width spans the cluster)

## Which grid cell (col, row) each movement action occupies in each scheme. Keys
## are read live from the input map; only the layout is fixed here.
const _SIX_HEX := {
	"move_up": Vector2i(1, 0),
	"move_up_left": Vector2i(0, 1),
	"move_up_right": Vector2i(2, 1),
	"move_left": Vector2i(0, 2),
	"move_right": Vector2i(2, 2),
	"move_down": Vector2i(1, 3),
}
const _FOUR_WASD := {
	"move_up": Vector2i(1, 0),
	"move_left": Vector2i(0, 1),
	"move_down": Vector2i(1, 1),
	"move_right": Vector2i(2, 1),
}

@onready var _chip: PanelContainer = $Chip

var _showing_controller := false


func _ready() -> void:
	if SaveData.is_level_completed(0):
		# The player has already cleared level 1 -- they know the controls.
		hide()
		set_process_input(false)
		return
	_style_chip()
	_show_view(_showing_controller)


## Live device switching: a joypad press (or a real stick push) flips to the
## controller view; a key or mouse button flips back. Mouse motion is ignored so
## a resting hand on the pad doesn't cause flicker.
func _input(event: InputEvent) -> void:
	var controller := _showing_controller
	if event is InputEventJoypadButton and event.pressed:
		controller = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		controller = true
	elif event is InputEventKey and event.pressed:
		controller = false
	elif event is InputEventMouseButton and event.pressed:
		controller = false
	if controller != _showing_controller:
		_show_view(controller)


func _show_view(controller: bool) -> void:
	_showing_controller = controller
	# Detach synchronously (queue_free alone is deferred, which would leave the old
	# view overlapping the new one for a frame).
	for child in _chip.get_children():
		_chip.remove_child(child)
		child.queue_free()
	_chip.add_child(_build_controller_view() if controller else _build_keyboard_view())


# --------------------------------------------------------------- keyboard view
func _build_keyboard_view() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var movement := VBoxContainer.new()
	movement.add_theme_constant_override("separation", 8)
	movement.alignment = BoxContainer.ALIGNMENT_CENTER
	var cluster := _movement_cluster()
	movement.add_child(cluster)
	movement.add_child(_keycap("space", Vector2(cluster.custom_minimum_size.x, SPACE_HEIGHT)))

	row.add_child(movement)
	row.add_child(_text_label("or", 32))
	var mouse := MouseGlyphScene.instantiate()
	row.add_child(mouse)
	return row


## The movement keys laid out for the current scheme: a hexagon of six, or WASD.
func _movement_cluster() -> Control:
	var six: bool = SaveData.get_setting("movement_scheme") == "six_key"
	var layout := _SIX_HEX if six else _FOUR_WASD
	var step := CAP + CLUSTER_GAP
	var cluster := Control.new()
	var max_cell := Vector2i.ZERO
	for action in layout:
		var cell: Vector2i = layout[action]
		var cap := _keycap(_action_key_label(action), CAP)
		cap.position = Vector2(cell.x * step.x, cell.y * step.y)
		cluster.add_child(cap)
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	cluster.custom_minimum_size = Vector2(max_cell.x, max_cell.y) * step + CAP
	return cluster


# ------------------------------------------------------------- controller view
func _build_controller_view() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(ControllerGlyphScene.instantiate())
	row.add_child(_text_label("+", 40))
	row.add_child(_keycap(ControllerType.confirm_label(ControllerType.kind_of()), CAP))
	return row


# ------------------------------------------------------------------- factories
func _keycap(key: String, cap_size: Vector2) -> KeyCap:
	var cap: KeyCap = KeyCapScene.instantiate()
	cap.key = key
	cap.cap_size = cap_size
	return cap


func _text_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", KeyCap.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## The readable key bound to `action` (first keyboard event), e.g. "W". Reads the
## live input map so remaps and scheme changes are reflected.
func _action_key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event: InputEventKey = event
			var code: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
			return OS.get_keycode_string(code)
	return "?"


## Dark translucent rounded chip behind the content, with padding.
func _style_chip() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	for corner in ["corner_radius_top_left", "corner_radius_top_right",
			"corner_radius_bottom_left", "corner_radius_bottom_right"]:
		sb.set(corner, 14)
	sb.corner_detail = 8
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_chip.add_theme_stylebox_override("panel", sb)
