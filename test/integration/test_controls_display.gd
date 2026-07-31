extends GutTest
## Tests for ui/controls_display.gd: the level-1-completion gate, and the two
## views it builds from the current movement scheme. Extends GutTest directly (not
## the game_test fixture) since it needs no Room -- it is a pure HUD overlay.

const DisplayScene := preload("res://ui/controls_display.tscn")

var _saved_levels: Array
var _saved_scheme


func before_each() -> void:
	_saved_levels = SaveData.data["levels"].duplicate()
	_saved_scheme = SaveData.get_setting("movement_scheme")


func after_each() -> void:
	SaveData.data["levels"] = _saved_levels
	SaveData.data["settings"]["movement_scheme"] = _saved_scheme


func _open(completed: bool, scheme := "six_key") -> ControlsDisplay:
	SaveData.data["levels"][0] = SaveData.LevelState.COMPLETED if completed else SaveData.LevelState.UNLOCKED
	SaveData.data["settings"]["movement_scheme"] = scheme
	var display: ControlsDisplay = DisplayScene.instantiate()
	add_child_autofree(display)  # entering the tree runs _ready
	return display


func _count(display: Node, predicate: Callable) -> int:
	var n := 0
	for child in display.get_children():
		if predicate.call(child):
			n += 1
		n += _count(child, predicate)
	return n


func test_hidden_once_level_1_is_completed():
	assert_false(_open(true).visible, "the display stays hidden after clearing level 1")

func test_shown_before_level_1_is_completed():
	assert_true(_open(false).visible, "the display shows for a first-time player")

func test_six_key_scheme_shows_six_movement_keys_plus_space():
	# 6 hex movement caps + the spacebar cap = 7 keycaps.
	assert_eq(_count(_open(false, "six_key"), func(n): return n is KeyCap), 7)

func test_four_key_scheme_shows_four_movement_keys_plus_space():
	# 4 WASD caps + the spacebar cap = 5 keycaps.
	assert_eq(_count(_open(false, "four_key"), func(n): return n is KeyCap), 5)

func test_keyboard_view_offers_the_mouse_alternative():
	assert_eq(_count(_open(false), func(n): return n is MouseGlyph), 1)

func test_controller_view_shows_a_gamepad_and_confirm_button():
	var display := _open(false)
	display._show_view(true)
	assert_eq(_count(display, func(n): return n is ControllerGlyph), 1, "a gamepad glyph")
	assert_eq(_count(display, func(n): return n is MouseGlyph), 0, "no mouse in controller view")
	assert_eq(_count(display, func(n): return n is KeyCap), 1, "just the confirm button cap")

func test_switching_views_replaces_content():
	var display := _open(false)
	assert_eq(_count(display, func(n): return n is MouseGlyph), 1, "keyboard view first")
	display._show_view(true)
	assert_eq(_count(display, func(n): return n is ControllerGlyph), 1, "then controller view")
	display._show_view(false)
	assert_eq(_count(display, func(n): return n is MouseGlyph), 1, "and back to keyboard")
