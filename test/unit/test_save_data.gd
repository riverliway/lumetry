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
		"levels": [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],  # UNLOCKED, rest LOCKED
		"sandbox_unlocked": false,
		"settings": {"music_audio": 100, "sfx_audio": 100, "colorblind_mode": "default"},
	}
	for k in overrides:
		p[k] = overrides[k]
	return p

## A slot envelope with a correct checksum for `payload`.
func _envelope(counter: int, timestamp: float, payload: Dictionary) -> String:
	var payload_text := JSON.stringify(payload)
	return JSON.stringify({
		"counter": counter,
		"timestamp": timestamp,
		"checksum": payload_text.sha256_text(),
		"payload": payload_text,
	})

## A slot envelope whose checksum does NOT match its payload.
func _bad_checksum_envelope(counter: int, timestamp: float, payload: Dictionary) -> String:
	var payload_text := JSON.stringify(payload)
	return JSON.stringify({"counter": counter, "timestamp": timestamp, "checksum": "not_a_valid_hash", "payload": payload_text})


# ------------------------------------------------------------------ defaults
func test_defaults_created_when_no_slots_exist():
	var s = _make()
	s.load_from_disk()
	assert_eq(s.data["levels"].size(), 18, "exactly 18 level states")
	assert_eq(s.get_level_state(0), s.LevelState.UNLOCKED, "level 1 unlocked by default")
	assert_eq(s.get_level_state(1), s.LevelState.LOCKED, "level 2 locked by default")
	assert_false(s.is_level_completed(0), "no level completed by default")
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
	a.complete_level(5)
	a.set_sandbox_unlocked(true)
	a.set_setting("music_audio", 42)
	a.set_setting("colorblind_mode", "patterned")

	var b = _make()  # a separate instance reading the same slots
	b.load_from_disk()
	assert_true(b.is_level_unlocked(3), "unlocked level persisted")
	assert_true(b.is_level_completed(5), "completed level persisted")
	assert_eq(b.get_level_state(6), b.LevelState.UNLOCKED, "completing a level unlocked the next")
	assert_true(b.is_sandbox_unlocked(), "sandbox flag persisted")
	assert_eq(b.get_setting("music_audio"), 42, "audio persisted")
	assert_eq(b.get_setting("colorblind_mode"), "patterned", "enum persisted")

# ------------------------------------------------------- A/B slot robustness
func test_prefers_slot_with_higher_counter():
	_write_file(_slot(0), _envelope(1, 100.0, _valid_payload({"settings": {"music_audio": 10, "sfx_audio": 100, "colorblind_mode": "default"}})))
	_write_file(_slot(1), _envelope(2, 200.0, _valid_payload({"settings": {"music_audio": 90, "sfx_audio": 100, "colorblind_mode": "default"}})))
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("music_audio"), 90, "the higher counter wins")

func test_counter_is_source_of_truth_over_timestamp():
	# slot 0 is the genuinely newer write (higher counter) but its timestamp is
	# OLDER -- as if the system clock jumped backward. The counter must win.
	_write_file(_slot(0), _envelope(5, 100.0, _valid_payload({"settings": {"music_audio": 10, "sfx_audio": 100, "colorblind_mode": "default"}})))
	_write_file(_slot(1), _envelope(4, 999.0, _valid_payload({"settings": {"music_audio": 90, "sfx_audio": 100, "colorblind_mode": "default"}})))
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("music_audio"), 10, "higher counter wins even with an older timestamp")

func test_falls_back_when_newest_slot_is_corrupt():
	# slot 0 is the intact previous save; slot 1 is a torn/garbage write.
	_write_file(_slot(0), _envelope(1, 100.0, _valid_payload({"settings": {"music_audio": 10, "sfx_audio": 100, "colorblind_mode": "default"}})))
	_write_file(_slot(1), "torn write {{{")
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("music_audio"), 10, "used the intact older slot")

func test_checksum_mismatch_rejects_slot_even_if_newer():
	# slot 0 has a higher counter but a tampered checksum -> must be rejected.
	_write_file(_slot(0), _bad_checksum_envelope(2, 999.0, _valid_payload({"settings": {"music_audio": 10, "sfx_audio": 100, "colorblind_mode": "default"}})))
	_write_file(_slot(1), _envelope(1, 100.0, _valid_payload({"settings": {"music_audio": 90, "sfx_audio": 100, "colorblind_mode": "default"}})))
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("music_audio"), 90, "tampered slot rejected despite higher counter")

func test_counter_advances_across_saves_and_reloads():
	var a = _make()
	a.load_from_disk()  # first run writes both slots -> counter 2
	assert_eq(a._counter, 2, "two initial writes bumped the counter to 2")
	a.set_setting("music_audio", 50)
	assert_eq(a._counter, 3, "each save increments the counter")
	var b = _make()
	b.load_from_disk()  # a separate instance reading the same slots
	assert_eq(b._counter, 3, "reload resumes from the stored counter, not a reset")
	b.set_setting("music_audio", 60)
	assert_eq(b._counter, 4, "keeps climbing past the reloaded value")

func test_load_records_last_played_from_winning_slot():
	_write_file(_slot(0), _envelope(1, 100.0, _valid_payload()))
	_write_file(_slot(1), _envelope(2, 250.0, _valid_payload()))
	var s = _make()
	s.load_from_disk()
	assert_eq(s.last_played, 250.0, "last_played is the timestamp of the newest (highest-counter) slot")

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
	_write_file(_slot(0), _envelope(1, 100.0, {
		"levels": [1, 2, 99, -3],  # UNLOCKED, COMPLETED, then out-of-range values
		"settings": {"music_audio": 999, "colorblind_mode": "bogus"},
	}))
	var s = _make()
	s.load_from_disk()
	assert_eq(s.data["levels"].size(), 18, "short array padded to 18")
	assert_eq(s.get_level_state(1), s.LevelState.COMPLETED, "provided state kept")
	assert_eq(s.get_level_state(2), s.LevelState.COMPLETED, "too-high state clamped to COMPLETED")
	assert_eq(s.get_level_state(3), s.LevelState.LOCKED, "negative state clamped to LOCKED")
	assert_eq(s.get_level_state(5), s.LevelState.LOCKED, "padded entries default to LOCKED")
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

func test_master_audio_default_and_clamp():
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("master_audio"), 100, "master defaults to 100")
	s.set_setting("master_audio", 250)
	assert_eq(s.get_setting("master_audio"), 100, "clamped high")
	s.set_setting("master_audio", -5)
	assert_eq(s.get_setting("master_audio"), 0, "clamped low")

func test_text_speed_default_and_validation():
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("text_speed"), "normal", "text speed defaults to normal")
	s.set_setting("text_speed", "fast")
	assert_eq(s.get_setting("text_speed"), "fast", "valid value stored")
	s.set_setting("text_speed", "warp")
	assert_eq(s.get_setting("text_speed"), "fast", "invalid value ignored")

func test_movement_scheme_default_and_validation():
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_setting("movement_scheme"), "six_key", "movement defaults to 6-key")
	s.set_setting("movement_scheme", "four_key")
	assert_eq(s.get_setting("movement_scheme"), "four_key", "valid scheme stored")
	s.set_setting("movement_scheme", "ten_key")
	assert_eq(s.get_setting("movement_scheme"), "four_key", "invalid scheme ignored")

func test_joystick_deadzone_default_and_clamp():
	var s = _make()
	s.load_from_disk()
	assert_almost_eq(s.get_setting("joystick_deadzone"), 0.2, 0.0001, "deadzone defaults to 0.2")
	s.set_setting("joystick_deadzone", 0.35)
	assert_almost_eq(s.get_setting("joystick_deadzone"), 0.35, 0.0001, "valid fraction stored")
	s.set_setting("joystick_deadzone", 5.0)
	assert_almost_eq(s.get_setting("joystick_deadzone"), s.DEADZONE_MAX, 0.0001, "clamped to the max so the stick is never dead")
	s.set_setting("joystick_deadzone", -1.0)
	assert_eq(s.get_setting("joystick_deadzone"), 0.0, "clamped low to zero")

func test_joystick_deadzone_survives_a_save_reload():
	# The whole point of the setting is persistence; prove it round-trips a float.
	var s = _make()
	s.load_from_disk()
	s.set_setting("joystick_deadzone", 0.45)
	var reloaded = _make()
	reloaded.load_from_disk()
	assert_almost_eq(reloaded.get_setting("joystick_deadzone"), 0.45, 0.0001, "deadzone persisted across a reload")

func test_setting_changed_signal_carries_key_and_value():
	var s = _make()
	s.load_from_disk()
	watch_signals(s)
	s.set_setting("music_audio", 55)
	assert_signal_emitted_with_parameters(s, "setting_changed", ["music_audio", 55])

func test_setting_changed_not_emitted_for_invalid_value():
	var s = _make()
	s.load_from_disk()
	watch_signals(s)
	s.set_setting("text_speed", "nope")
	assert_signal_not_emitted(s, "setting_changed")

# --------------------------------------------------------------- progression
func test_complete_level_unlocks_the_next():
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_level_state(1), s.LevelState.LOCKED, "level 2 starts locked")
	s.complete_level(0)
	assert_eq(s.get_level_state(0), s.LevelState.COMPLETED, "level 1 marked completed")
	assert_eq(s.get_level_state(1), s.LevelState.UNLOCKED, "completing level 1 unlocked level 2")

func test_unlock_never_downgrades_a_completed_level():
	var s = _make()
	s.load_from_disk()
	s.complete_level(2)
	s.unlock_level(2)
	assert_eq(s.get_level_state(2), s.LevelState.COMPLETED, "unlock leaves a completed level completed")

func test_complete_last_level_is_safe():
	var s = _make()
	s.load_from_disk()
	s.complete_level(17)  # LEVEL_COUNT - 1: no next level to unlock
	assert_eq(s.get_level_state(17), s.LevelState.COMPLETED, "last level completed")
	assert_eq(s.data["levels"].size(), 18, "array not grown")

# ------------------------------------------------------------- bounds & reset
func test_level_index_out_of_range_is_safe():
	var s = _make()
	s.load_from_disk()
	assert_false(s.is_level_unlocked(-1), "negative index")
	assert_false(s.is_level_unlocked(18), "index past the end")
	assert_eq(s.get_level_state(18), s.LevelState.LOCKED, "out-of-range state is LOCKED")
	s.unlock_level(99)  # must not crash or grow the array
	s.complete_level(99)  # must not crash or grow the array
	assert_eq(s.data["levels"].size(), 18)

func test_reset_restores_defaults():
	var s = _make()
	s.load_from_disk()
	s.complete_level(5)
	s.set_sandbox_unlocked(true)
	s.reset()
	assert_eq(s.get_level_state(5), s.LevelState.LOCKED, "progression cleared")
	assert_eq(s.get_level_state(6), s.LevelState.LOCKED, "auto-unlocked next cleared too")
	assert_false(s.is_sandbox_unlocked(), "sandbox cleared")
	assert_eq(s.get_level_state(0), s.LevelState.UNLOCKED, "level 1 back to unlocked")

func test_unlock_all_opens_every_level_and_the_sandbox():
	var s = _make()
	s.load_from_disk()
	s.complete_level(2)  # a completed level should survive the unlock
	s.unlock_all()
	for i in range(s.LEVEL_COUNT):
		assert_true(s.is_level_unlocked(i), "level %d accessible after unlock_all" % i)
	assert_eq(s.get_level_state(2), s.LevelState.COMPLETED, "unlock_all never downgrades a completed level")
	assert_true(s.is_sandbox_unlocked(), "sandbox unlocked")
	assert_eq(s.data["levels"].size(), s.LEVEL_COUNT, "array not grown")


# ------------------------------------------------------------- seen dialogues
func test_no_dialogues_seen_by_default():
	var s = _make()
	s.load_from_disk()
	assert_false(s.has_seen_dialogue("singed"), "nothing has been shown yet")

func test_marking_a_dialogue_seen_persists_across_reload():
	var a = _make()
	a.load_from_disk()
	a.mark_dialogue_seen("singed")
	assert_true(a.has_seen_dialogue("singed"), "recorded on the live instance")
	var b = _make()
	b.load_from_disk()  # a separate instance reading the same slots
	assert_true(b.has_seen_dialogue("singed"), "the record survived the reload")

func test_marking_a_dialogue_seen_twice_is_idempotent():
	var s = _make()
	s.load_from_disk()  # two initial writes -> counter 2
	s.mark_dialogue_seen("singed")
	assert_eq(s._counter, 3, "the first mark saves")
	s.mark_dialogue_seen("singed")
	assert_eq(s._counter, 3, "marking the same dialogue again does not save")
	assert_eq(s.data["seen_dialogues"].size(), 1, "and does not duplicate the id")

func test_reset_clears_seen_dialogues():
	var s = _make()
	s.load_from_disk()
	s.mark_dialogue_seen("singed")
	s.reset()
	assert_false(s.has_seen_dialogue("singed"), "reset wipes the seen-dialogue record")

func test_normalize_keeps_only_unique_string_dialogue_ids():
	# A hand-written slot with junk mixed in loads back as clean, deduped strings.
	_write_file(_slot(1), _envelope(1, 100.0, _valid_payload({
		"seen_dialogues": ["singed", "singed", 42, null, "fried"],
	})))
	var s = _make()
	s.load_from_disk()
	assert_eq(s.data["seen_dialogues"], ["singed", "fried"], "non-strings dropped, duplicates collapsed")


# ----------------------------------------------------------------- seen hints
func test_no_hints_seen_by_default():
	var s = _make()
	s.load_from_disk()
	assert_false(s.has_seen_hint("emitter"), "no interact hint dismissed yet")

func test_marking_a_hint_seen_persists_across_reload():
	var a = _make()
	a.load_from_disk()
	a.mark_hint_seen("emitter")
	assert_true(a.has_seen_hint("emitter"), "recorded on the live instance")
	var b = _make()
	b.load_from_disk()  # a separate instance reading the same slots
	assert_true(b.has_seen_hint("emitter"), "the dismissal survived the reload")

func test_marking_a_hint_seen_twice_is_idempotent():
	var s = _make()
	s.load_from_disk()  # two initial writes -> counter 2
	s.mark_hint_seen("pad")
	assert_eq(s._counter, 3, "the first mark saves")
	s.mark_hint_seen("pad")
	assert_eq(s._counter, 3, "marking the same hint again does not save")
	assert_eq(s.data["seen_hints"].size(), 1, "and does not duplicate the id")

func test_reset_clears_seen_hints():
	var s = _make()
	s.load_from_disk()
	s.mark_hint_seen("emitter")
	s.reset()
	assert_false(s.has_seen_hint("emitter"), "reset wipes the dismissed-hint record")

func test_seen_hints_and_dialogues_are_independent():
	var s = _make()
	s.load_from_disk()
	s.mark_hint_seen("emitter")
	assert_false(s.has_seen_dialogue("emitter"), "a dismissed hint is not a seen dialogue")


# ------------------------------------------------------------- input bindings
func test_no_input_bindings_by_default():
	var s = _make()
	s.load_from_disk()
	assert_eq(s.get_key_binding("use"), 0, "no keyboard override -> 0 (use the default)")
	assert_eq(s.get_button_binding("use"), -1, "no joypad override -> -1 (use the default)")

func test_set_and_get_input_bindings():
	var s = _make()
	s.load_from_disk()
	s.set_key_binding("use", 70)      # KEY_F
	s.set_button_binding("sprint", 3)
	assert_eq(s.get_key_binding("use"), 70, "keyboard override stored")
	assert_eq(s.get_button_binding("sprint"), 3, "joypad override stored")

func test_clear_input_bindings():
	var s = _make()
	s.load_from_disk()
	s.set_key_binding("use", 70)
	s.set_button_binding("sprint", 3)
	s.clear_input_bindings()
	assert_eq(s.get_key_binding("use"), 0, "keyboard override cleared")
	assert_eq(s.get_button_binding("sprint"), -1, "joypad override cleared")

func test_input_bindings_survive_a_save_reload():
	var s = _make()
	s.load_from_disk()
	s.set_key_binding("move_up", 84)  # KEY_T
	var reloaded = _make()
	reloaded.load_from_disk()  # a separate instance reading the same slots
	assert_eq(reloaded.get_key_binding("move_up"), 84, "the override persisted across a reload")

func test_normalize_keeps_only_int_input_bindings():
	var s = _make()
	var loaded = _valid_payload({"input_bindings": {"key": {"use": 70, "bad": "x"}, "btn": {"sprint": 3.0}}})
	var result = s._normalize(loaded)
	assert_eq(result["input_bindings"]["key"].get("use"), 70, "a valid int override is kept")
	assert_false(result["input_bindings"]["key"].has("bad"), "a non-numeric override is dropped")
	assert_eq(result["input_bindings"]["btn"].get("sprint"), 3, "a float override is coerced to int")

func test_reset_clears_input_bindings():
	var s = _make()
	s.load_from_disk()
	s.set_key_binding("use", 70)
	s.reset()
	assert_eq(s.get_key_binding("use"), 0, "reset wipes input remaps")
