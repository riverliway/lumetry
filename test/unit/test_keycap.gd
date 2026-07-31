extends GutTest
## Tests for the on-screen keycap (ui/keycap.gd): how a key string becomes the
## rendered label, and that the cap size drives the control's dimensions.

const KeyCapScene := preload("res://ui/keycap.tscn")


func _make(key: String, size := Vector2(72, 72)) -> KeyCap:
	var cap: KeyCap = KeyCapScene.instantiate()
	cap.key = key
	cap.cap_size = size
	add_child_autofree(cap)  # entering the tree runs _ready -> _rebuild
	return cap


func test_single_character_is_uppercased():
	assert_eq(_make("w")._label.text, "W", "a lowercase char renders uppercased")

func test_named_key_renders_its_pretty_label():
	assert_eq(_make("space")._label.text, "Space")
	assert_eq(_make("shift")._label.text, "Shift")
	assert_eq(_make("enter")._label.text, "Enter")
	assert_eq(_make("delete")._label.text, "Delete")

func test_named_key_lookup_is_case_insensitive_and_trimmed():
	assert_eq(_make(" SPACE ")._label.text, "Space", "trimmed and lowercased before lookup")

func test_aliases_map_to_the_same_label():
	assert_eq(_make("return")._label.text, "Enter", "return is an enter alias")
	assert_eq(_make("backspace")._label.text, "Delete", "backspace is a delete alias")

func test_cap_size_drives_the_control_size():
	var cap := _make("A", Vector2(120, 64))
	assert_eq(cap.custom_minimum_size, Vector2(120, 64), "cap_size sets the min size")
	assert_eq(cap.size, Vector2(120, 64), "and the actual size")

func test_wide_text_is_shrunk_to_fit_a_square_cap():
	# "Delete" on a square cap must shrink below the plain height-based size so it
	# does not overflow; "W" on the same cap keeps the full height-based size.
	var wide := _make("delete", Vector2(72, 72))
	var narrow := _make("W", Vector2(72, 72))
	var height_based := int(round(72 * KeyCap.FONT_RATIO))
	assert_eq(narrow._label.get_theme_font_size("font_size"), height_based, "a single char fills the cap")
	assert_lt(wide._label.get_theme_font_size("font_size"), height_based, "long text shrinks to fit width")

func test_create_helper_builds_a_configured_cap():
	var cap := KeyCap.create("E", Vector2(50, 50))
	add_child_autofree(cap)
	assert_eq(cap._label.text, "E")
	assert_eq(cap.custom_minimum_size, Vector2(50, 50))
