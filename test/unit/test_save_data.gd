extends GutTest
## Unit tests for the global save file (global/save_data.gd) and its redundant
## A/B slot storage.
##
## Each test uses a fresh instance pointed at a temp base path (never the real
## user://save.json) and calls load_from_disk() manually -- instances aren't
## added to the tree, so _ready() doesn't run on its own.

const SaveDataScript := preload("res://global/save_data.gd")
const TEST_PATH := "user://test_save.json"


func _slot(i: int) -> String:
	return "%s.%d.%s" % [TEST_PATH.get_basename(), i, TEST_PATH.get_extension()]

func _clear() -> void:
	for p in [_slot(0), _slot(1), TEST_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func before_each() -> void:
	_clear()

func after_each() -> void:
	_clear()

func _make():
	var s = autofree(SaveDataScript.new())
	s.save_path = TEST_PATH
	return s

func _write_file(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

## A full, valid payload dict (top-level keys overridable).
func _valid_payload(overrides := {}) -> Dictionary:
	var p := {
		"levels_unlocked": [true, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false],
		"sandbox_unlocked": false,
		"settings": {"music_audio": 100, "sfx_audio": 100, "colorblind_mode": "default"},
	}
	for k in overrides:
		p[k] = overrides[k]
	return p

## A slot envelope with a correct checksum for `payload`.
func _envelope(timestamp: float, payload: Dictionary) -> String:
	var payload_text := JSON.stringify(payload)
	return JSON.stringify({
		"timestamp": timestamp,
		"checksum": payload_text.sha256_text(),
		"payload": payload_text,
	})

## A slot envelope whose checksum does NOT match its payload.
func _bad_checksum_envelope(timestamp: float, payload: Dictionary) -> String:
	var payload_text := JSON.stringify(payload)
	return JSON.stringify({"timestamp": timestamp, "checksum": "not_a_valid_hash", "payload": payload_text})


# ------------------------------------------------------------------ defaults
func test_defaults_created_when_no_slots_exist():
	var s = _make()
	s.load_from_disk()
	assert_eq(s.data["levels_unlocked"].size(), 18, "exactly 18 level flags")
	assert_true(s.is_level_unlocked(0), "level 1 unlocked by default")
	assert_false(s.is_level_unlocked(1), "level 2 locked by default")
	assert_false(s.is_sandbox_unlocked(), "sandbox locked by default")
	assert_eq(s.get_setting("music_audio"), 100)
	assert_eq(s.get_setting("colorblind_mode"), "default")
	assert_true(FileAccess.file_exists(_slot(0)), "both slots created for redundancy")
	assert_true(FileAccess.file_exists(_slot(1)), "both slots created for redundancy")

# ---------------------------------------------------------------- round-trip
func test_save_and_reload_roundtrip():
	var a = _make()
	a.load_from_disk()
	a.unlock_level(3)
	a.set_sandbox_unlocked(true)
	a.set_setting("music_audio", 42)
	a.set_setting("colorblind_mode", "patterned")

	var b = _make()  # a separate instance reading the same slots
	b.load_from_disk()
	assert_true(b.is_level_unlocked(3), "unlocked level persisted")
	assert_true(b.is_sandbox_unlocked(), "sandbox flag persisted")
	assert_eq(b.get_setting("music_audio"), 42, "audio persisted")
	assert_eq(b.get_setting("colorblind_mode"), "patterned", "enum persisted")

# ------------------------------------------------------- A/B slot robustness
func test_prefers_slot_with_newer_timestamp():
	_write_file(_slot(0), _envelope(100.0, _valid_payload({"settings": {"music_audio": 10, "sfx_audio": 100, "colorblind_mode": "default"}})))
	_write_file(_slot(1), _envelope(200.0, _valid_payload({"settings": {"music_audio": 90, "sfx_audio": 100, "colorblind_mode": "default"}})))
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("music_audio"), 90, "the newer timestamp wins")

func test_falls_back_when_newest_slot_is_corrupt():
	# slot 0 is the intact previous save; slot 1 is a torn/garbage write.
	_write_file(_slot(0), _envelope(100.0, _valid_payload({"settings": {"music_audio": 10, "sfx_audio": 100, "colorblind_mode": "default"}})))
	_write_file(_slot(1), "torn write {{{")
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("music_audio"), 10, "used the intact older slot")

func test_checksum_mismatch_rejects_slot_even_if_newer():
	# slot 0 has a newer timestamp but a tampered checksum -> must be rejected.
	_write_file(_slot(0), _bad_checksum_envelope(999.0, _valid_payload({"settings": {"music_audio": 10, "sfx_audio": 100, "colorblind_mode": "default"}})))
	_write_file(_slot(1), _envelope(100.0, _valid_payload({"settings": {"music_audio": 90, "sfx_audio": 100, "colorblind_mode": "default"}})))
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("music_audio"), 90, "tampered slot rejected despite newer timestamp")

func test_corruption_fallback_end_to_end():
	var a = _make()
	a.load_from_disk()          # creates both slots
	a.set_setting("music_audio", 30)  # writes one slot
	a.set_setting("music_audio", 77)  # writes the other (now the newest)
	_write_file(_slot(a._last_slot), "corrupt{{{")  # destroy the newest good slot
	var b = _make()
	b.load_from_disk()
	assert_eq(b.get_setting("music_audio"), 30, "fell back to the previous good slot")

func test_repairs_missing_slot_on_load():
	var a = _make()
	a.load_from_disk()  # both slots exist
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot(0)))
	assert_false(FileAccess.file_exists(_slot(0)), "one slot removed")
	var b = _make()
	b.load_from_disk()
	assert_true(FileAccess.file_exists(_slot(0)), "missing slot repaired on load")
	assert_true(FileAccess.file_exists(_slot(1)), "existing slot intact")

func test_defaults_when_both_slots_corrupt():
	_write_file(_slot(0), "garbage{{{")
	_write_file(_slot(1), "also not json")
	var s = _make()
	s.load_from_disk()
	assert_true(s.is_level_unlocked(0), "defaults applied when neither slot is valid")
	assert_true(FileAccess.file_exists(_slot(0)), "slots rewritten with valid defaults")
	assert_true(FileAccess.file_exists(_slot(1)))

# ---------------------------------------------------------- load validation
func test_load_repairs_malformed_values():
	_write_file(_slot(0), _envelope(100.0, {
		"levels_unlocked": [true, true],
		"settings": {"music_audio": 999, "colorblind_mode": "bogus"},
	}))
	var s = _make()
	s.load_from_disk()
	assert_eq(s.data["levels_unlocked"].size(), 18, "short array padded to 18")
	assert_true(s.is_level_unlocked(1), "provided true kept")
	assert_false(s.is_level_unlocked(5), "padded entries default to false")
	assert_eq(s.get_setting("music_audio"), 100, "out-of-range audio clamped")
	assert_eq(s.get_setting("colorblind_mode"), "default", "invalid enum falls back")
	assert_false(s.is_sandbox_unlocked(), "missing key filled from defaults")

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
