extends GutTest
## Unit tests for the global save file (global/save_data.gd).
##
## Each test uses a fresh instance pointed at a temp file (never the real
## user://save.json) and calls load_from_disk() manually -- instances aren't
## added to the tree, so _ready() doesn't run on its own.

const SaveDataScript := preload("res://global/save_data.gd")
const TEST_PATH := "user://test_save.json"


func _clear_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func before_each() -> void:
	_clear_file()

func after_each() -> void:
	_clear_file()

func _make():
	var s = autofree(SaveDataScript.new())
	s.save_path = TEST_PATH
	return s

func _write_raw(text: String) -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ------------------------------------------------------------------ defaults
func test_defaults_created_when_no_file_exists():
	var s = _make()
	s.load_from_disk()
	assert_eq(s.data["levels_unlocked"].size(), 18, "exactly 18 level flags")
	assert_true(s.is_level_unlocked(0), "level 1 unlocked by default")
	assert_false(s.is_level_unlocked(1), "level 2 locked by default")
	assert_false(s.is_sandbox_unlocked(), "sandbox locked by default")
	assert_eq(s.get_setting("music_audio"), 100)
	assert_eq(s.get_setting("sfx_audio"), 100)
	assert_eq(s.get_setting("colorblind_mode"), "default")
	assert_true(FileAccess.file_exists(TEST_PATH), "the file is created on first load")

# ---------------------------------------------------------------- round-trip
func test_save_and_reload_roundtrip():
	var a = _make()
	a.load_from_disk()
	a.unlock_level(3)
	a.set_sandbox_unlocked(true)
	a.set_setting("music_audio", 42)
	a.set_setting("colorblind_mode", "patterned")

	var b = _make()  # a separate instance reading the same file
	b.load_from_disk()
	assert_true(b.is_level_unlocked(3), "unlocked level persisted")
	assert_true(b.is_sandbox_unlocked(), "sandbox flag persisted")
	assert_eq(b.get_setting("music_audio"), 42, "audio persisted")
	assert_eq(b.get_setting("colorblind_mode"), "patterned", "enum persisted")

# ---------------------------------------------------------- load validation
func test_load_repairs_malformed_data():
	_write_raw('{"levels_unlocked":[true,true],"settings":{"music_audio":999,"colorblind_mode":"bogus"}}')
	var s = _make()
	s.load_from_disk()
	assert_eq(s.data["levels_unlocked"].size(), 18, "short array padded to 18")
	assert_true(s.is_level_unlocked(1), "provided true kept")
	assert_false(s.is_level_unlocked(5), "padded entries default to false")
	assert_eq(s.get_setting("music_audio"), 100, "out-of-range audio clamped")
	assert_eq(s.get_setting("colorblind_mode"), "default", "invalid enum falls back")
	assert_false(s.is_sandbox_unlocked(), "missing key filled from defaults")

func test_unparseable_file_falls_back_to_defaults():
	_write_raw("not valid json {{{")
	var s = _make()
	s.load_from_disk()
	assert_eq(s.data["levels_unlocked"].size(), 18)
	assert_true(s.is_level_unlocked(0), "defaults applied")

# ------------------------------------------------------------- settings guards
func test_set_setting_clamps_audio():
	var s = _make()
	s.load_from_disk()
	s.set_setting("sfx_audio", 150)
	assert_eq(s.get_setting("sfx_audio"), 100, "clamped high")
	s.set_setting("sfx_audio", -20)
	assert_eq(s.get_setting("sfx_audio"), 0, "clamped low")

func test_set_setting_rejects_invalid_colorblind_mode():
	var s = _make()
	s.load_from_disk()
	s.set_setting("colorblind_mode", "rainbow")
	assert_eq(s.get_setting("colorblind_mode"), "default", "invalid value ignored")

func test_set_setting_ignores_unknown_key():
	var s = _make()
	s.load_from_disk()
	s.set_setting("does_not_exist", 5)
	assert_false(s.data["settings"].has("does_not_exist"), "unknown key not stored")

# ------------------------------------------------------------- bounds & reset
func test_level_index_out_of_range_is_safe():
	var s = _make()
	s.load_from_disk()
	assert_false(s.is_level_unlocked(-1), "negative index")
	assert_false(s.is_level_unlocked(18), "index past the end")
	s.unlock_level(99)  # must not crash or grow the array
	assert_eq(s.data["levels_unlocked"].size(), 18)

func test_reset_restores_defaults():
	var s = _make()
	s.load_from_disk()
	s.unlock_level(5)
	s.set_sandbox_unlocked(true)
	s.reset()
	assert_false(s.is_level_unlocked(5), "progression cleared")
	assert_false(s.is_sandbox_unlocked(), "sandbox cleared")
	assert_true(s.is_level_unlocked(0), "level 1 back to unlocked")
