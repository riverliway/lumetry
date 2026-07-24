extends GutTest
## Tests for the colorblind glyph overlay (tileset/color_symbol/color_symbol.gd):
## it shows only when the owner has marked it active AND colorblind mode is
## "patterned", and it reacts to a live mode change. The colorblind mode is set on
## SaveData.data directly (no disk write) and restored after each test.

const ColorSymbolScript := preload("res://tileset/color_symbol/color_symbol.gd")

var _saved


func before_each() -> void:
	_saved = SaveData.data.duplicate(true)

func after_each() -> void:
	SaveData.data = _saved


func _make_symbol():
	var s = ColorSymbolScript.new()
	add_child_autofree(s)  # in the tree so _ready connects the mode signal
	return s


func _set_mode(mode: String) -> void:
	SaveData.data["settings"]["colorblind_mode"] = mode


func test_hidden_in_default_mode_even_when_active():
	_set_mode("default")
	var sym = _make_symbol()
	await get_tree().process_frame
	sym.set_active(true)
	assert_false(sym.visible, "no glyph while colorblind mode is off")


func test_visible_only_when_active_and_patterned():
	_set_mode("patterned")
	var sym = _make_symbol()
	await get_tree().process_frame
	assert_false(sym.visible, "hidden until the owner marks it active")
	sym.set_active(true)
	assert_true(sym.visible, "shown when active and patterned")
	sym.set_active(false)
	assert_false(sym.visible, "hidden again when the owner goes inactive")


func test_reacts_to_a_live_mode_change():
	_set_mode("default")
	var sym = _make_symbol()
	await get_tree().process_frame
	sym.set_active(true)
	assert_false(sym.visible, "off while in default mode")
	_set_mode("patterned")
	SaveData.setting_changed.emit("colorblind_mode", "patterned")
	assert_true(sym.visible, "turns on when the mode-change signal fires")
