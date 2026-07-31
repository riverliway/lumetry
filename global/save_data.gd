# This script is loaded as a global in the project settings (autoloaded as `SaveData`).
extends Node
## Global persistent save file, stored redundantly so an interrupted or corrupt
## write can't lose progress.
##
## Two slot files (A/B) are derived from `save_path` -- save.0.json / save.1.json.
## Each save writes the *backup* slot (the one not written last), wrapped in an
## envelope carrying a monotonic write counter, a wall-clock timestamp, and a
## SHA-256 checksum of the payload. The newest good slot is therefore never the
## one being overwritten. On load we read both slots, discard any whose checksum
## fails (a torn or corrupt write), and keep the one with the highest counter --
## the counter, not the timestamp, is the source of truth for which write is
## newest, so a backward jump in the system clock can't pick the stale slot. The
## timestamp is retained only as a "last played" record. A missing/corrupt slot
## is repaired, and if neither survives we fall back to DEFAULTS.
##
## Every value is validated on load and any missing key is filled from DEFAULTS,
## so old saves keep working as the schema grows -- to add a field, add it to
## DEFAULTS and validate it in _normalize(). Mutators write back automatically.

## Emitted after a setting is changed via set_setting(), carrying the setting's
## key and its (validated) new value. Systems that react to settings live -- the
## audio buses, the colorblind beam/detector symbols -- listen for this so a
## change in the options menu takes effect immediately.
signal setting_changed(key: String, value)

const SAVE_PATH := "user://save.json"
const LEVEL_COUNT := 18
## Allowed values for settings.colorblind_mode.
const COLORBLIND_MODES := ["default", "patterned"]
## Allowed values for settings.text_speed (consumed by the dialogue system).
const TEXT_SPEEDS := ["slow", "normal", "fast"]
## Allowed values for settings.movement_scheme (consumed by the player controller).
## "four_key" is WASD with diagonals resolved by facing; "six_key" (the default,
## easier to learn) is one hex direction per key (QWE / ASD).
const MOVEMENT_SCHEMES := ["four_key", "six_key"]

## Per-level progression, stored in `levels` as one of these values per level.
## Ordered so higher means "further along" (LOCKED < UNLOCKED < COMPLETED).
enum LevelState { LOCKED, UNLOCKED, COMPLETED }

## Canonical defaults and schema. load_from_disk() starts from a deep copy of
## this and overlays the (validated) values found on disk.
const DEFAULTS := {
	# One LevelState per level; level 1 starts UNLOCKED, the rest LOCKED.
	"levels": [LevelState.UNLOCKED, LevelState.LOCKED, LevelState.LOCKED, LevelState.LOCKED,
		LevelState.LOCKED, LevelState.LOCKED, LevelState.LOCKED, LevelState.LOCKED, LevelState.LOCKED,
		LevelState.LOCKED, LevelState.LOCKED, LevelState.LOCKED, LevelState.LOCKED, LevelState.LOCKED,
		LevelState.LOCKED, LevelState.LOCKED, LevelState.LOCKED, LevelState.LOCKED],
	"sandbox_unlocked": false,
	# Ids of the one-time dialogues the player has already seen (e.g. the laser
	# "singed" hint). Persisted so such a hint fires only the first time, ever.
	"seen_dialogues": [],
	# Keys of the interact-hint nudges (the pulsing circle behind level 2's emitter
	# and level 4's pad) whose kind the player has already interacted with. Keyed by
	# KIND ("emitter" / "pad"), so interacting with any emitter (or any pad) retires
	# that nudge forever. Persisted so each shows only until its first interaction,
	# ever -- see InteractHint and Room.Grid._mark_first_interaction.
	"seen_hints": [],
	"settings": {
		"master_audio": 100,
		"music_audio": 100,
		"sfx_audio": 100,
		"colorblind_mode": "default",
		"text_speed": "normal",
		"movement_scheme": "six_key",
		# Fraction (0.0-DEADZONE_MAX) of the joystick's travel ignored near center,
		# so a resting/drifting stick doesn't register. Consumed by the player
		# controller's analog look stick.
		"joystick_deadzone": 0.2,
	},
}

## joystick_deadzone is clamped to this range. Capped below 1.0 so a full push
## always clears the deadzone and the stick can never be dead.
const DEADZONE_MAX := 0.95

## The live save state -- always a fully populated, validated copy of the schema.
var data: Dictionary = DEFAULTS.duplicate(true)
## Base save location; the two slot files derive from it. Overridable for tests.
var save_path := SAVE_PATH

## Slot (0 or 1) holding the newest good data; the next save writes the other one.
var _last_slot := 1
## Monotonic sequence number of the most recent write; the source of truth for
## which slot is newest. Increments on every save and never resets across loads.
var _counter := 0
## Wall-clock time of the loaded save's most recent write (unix seconds), kept
## as a "last played" record only -- it never decides which slot wins.
var last_played := 0.0


func _ready() -> void:
	load_from_disk()


## Loads the newest valid slot. Reads both A/B slots, drops any that fail their
## checksum, and keeps the one with the highest write counter. Repairs a
## missing/corrupt slot and falls back to DEFAULTS if neither survives.
func load_from_disk() -> void:
	var slots := []  # each entry: [slot_index, {counter, timestamp, data}]
	for slot in [0, 1]:
		var read = _read_slot(slot)
		if read != null:
			slots.push_back([slot, read])

	if slots.is_empty():
		data = DEFAULTS.duplicate(true)
		_last_slot = 1
		_counter = 0
		save()  # write both slots so the backup exists from the very first run
		save()
		return

	# Highest counter wins -- the two slots always hold distinct counters.
	var best = slots[0]
	for entry in slots:
		if entry[1]["counter"] > best[1]["counter"]:
			best = entry
	data = _normalize(best[1]["data"])
	_last_slot = best[0]
	_counter = best[1]["counter"]
	last_played = best[1]["timestamp"]

	if slots.size() < 2:
		save()  # the other slot was missing/corrupt -- rewrite it to restore the backup


## Persists the current state to the backup slot (the one not written last), so
## an interrupted write can never destroy the newest good save. Ping-pongs A/B.
func save() -> void:
	var target := 1 - _last_slot
	_counter += 1
	last_played = Time.get_unix_time_from_system()
	_write_slot(target, _counter, last_played)
	_last_slot = target


## Restores the defaults and persists them to both slots.
func reset() -> void:
	data = DEFAULTS.duplicate(true)
	save()
	save()


## The file path for slot 0 or 1, derived from save_path (e.g. user://save.0.json).
func _slot_path(slot: int) -> String:
	return "%s.%d.%s" % [save_path.get_basename(), slot, save_path.get_extension()]


## Writes `data` to `slot` inside an envelope carrying the monotonic write
## counter, the write timestamp, and a SHA-256 checksum of the payload, so the
## newest write can be identified and a corrupt read detected on load.
func _write_slot(slot: int, counter: int, timestamp: float) -> void:
	var payload := JSON.stringify(data, "\t")
	var envelope := {
		"counter": counter,
		"timestamp": timestamp,
		"checksum": payload.sha256_text(),
		"payload": payload,
	}
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveData: could not write slot %d" % slot)
		return
	file.store_string(JSON.stringify(envelope, "\t"))
	file.close()


## Reads and verifies a slot. Returns {counter, timestamp, data} if intact, else
## null (missing, unparseable, malformed envelope, or checksum mismatch).
func _read_slot(slot: int) -> Variant:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	var envelope: Dictionary = json.data
	if not (envelope.has("counter") and envelope.has("timestamp") and envelope.has("checksum") and envelope.has("payload")):
		return null
	var payload = envelope["payload"]
	if not payload is String or payload.sha256_text() != envelope["checksum"]:
		return null  # corruption: the checksum doesn't match the payload
	var payload_json := JSON.new()
	if payload_json.parse(payload) != OK or not payload_json.data is Dictionary:
		return null
	return {"counter": int(envelope["counter"]), "timestamp": float(envelope["timestamp"]), "data": payload_json.data}


# ---------------------------------------------------------------- progression
## The LevelState of level `index` (0-based; 0 = level 1); LOCKED if out of range.
func get_level_state(index: int) -> LevelState:
	if index < 0 or index >= LEVEL_COUNT:
		return LevelState.LOCKED
	return data["levels"][index]


## Whether level `index` can be played (i.e. unlocked or already completed).
func is_level_unlocked(index: int) -> bool:
	return get_level_state(index) != LevelState.LOCKED


## Whether level `index` has been completed.
func is_level_completed(index: int) -> bool:
	return get_level_state(index) == LevelState.COMPLETED


## Unlocks level `index` (if it was locked) and saves. Never downgrades a level
## that is already completed.
func unlock_level(index: int) -> void:
	if index < 0 or index >= LEVEL_COUNT:
		push_warning("SaveData: level index %d out of range" % index)
		return
	if data["levels"][index] == LevelState.LOCKED:
		data["levels"][index] = LevelState.UNLOCKED
		save()


## Marks level `index` completed, unlocks the next level if it was locked, and
## saves.
func complete_level(index: int) -> void:
	if index < 0 or index >= LEVEL_COUNT:
		push_warning("SaveData: level index %d out of range" % index)
		return
	data["levels"][index] = LevelState.COMPLETED
	if index + 1 < LEVEL_COUNT and data["levels"][index + 1] == LevelState.LOCKED:
		data["levels"][index + 1] = LevelState.UNLOCKED
	save()


# ------------------------------------------------------------------ dialogues
## Whether the one-time dialogue `id` has already been shown to the player.
func has_seen_dialogue(id: String) -> bool:
	return id in data["seen_dialogues"]


## Records that the one-time dialogue `id` has been shown, and saves. A no-op (no
## save) if it was already recorded.
func mark_dialogue_seen(id: String) -> void:
	if id in data["seen_dialogues"]:
		return
	data["seen_dialogues"].push_back(id)
	save()


## Whether the interact-hint `id` has already been dismissed (the player has
## interacted with the block it sat behind), so it should no longer appear.
func has_seen_hint(id: String) -> bool:
	return id in data["seen_hints"]


## Records that the interact-hint `id` has been dismissed, and saves. A no-op (no
## save) if it was already recorded.
func mark_hint_seen(id: String) -> void:
	if id in data["seen_hints"]:
		return
	data["seen_hints"].push_back(id)
	save()


func is_sandbox_unlocked() -> bool:
	return data["sandbox_unlocked"]


func set_sandbox_unlocked(value: bool) -> void:
	data["sandbox_unlocked"] = value
	save()


## Opens access to everything: unlocks every level (without downgrading any that
## are already completed) and unlocks the sandbox, then saves. Exposed only from
## the title-screen options menu as a progress shortcut.
func unlock_all() -> void:
	for i in range(LEVEL_COUNT):
		if data["levels"][i] == LevelState.LOCKED:
			data["levels"][i] = LevelState.UNLOCKED
	data["sandbox_unlocked"] = true
	save()


# ------------------------------------------------------------------- settings
## Current value of settings `key` (or its default if somehow unknown).
func get_setting(key: String) -> Variant:
	return data["settings"].get(key, DEFAULTS["settings"].get(key))


## Sets a validated setting, saves, and emits `setting_changed`. Audio is clamped
## to 0-100; colorblind_mode must be one of COLORBLIND_MODES, text_speed one of
## TEXT_SPEEDS, and movement_scheme one of MOVEMENT_SCHEMES; joystick_deadzone is
## clamped to 0.0-DEADZONE_MAX. Unknown keys and invalid values are ignored (no
## save, no signal).
func set_setting(key: String, value: Variant) -> void:
	match key:
		"master_audio", "music_audio", "sfx_audio":
			data["settings"][key] = clampi(int(value), 0, 100)
		"colorblind_mode":
			if not value in COLORBLIND_MODES:
				push_warning("SaveData: invalid colorblind_mode '%s'" % value)
				return
			data["settings"]["colorblind_mode"] = value
		"text_speed":
			if not value in TEXT_SPEEDS:
				push_warning("SaveData: invalid text_speed '%s'" % value)
				return
			data["settings"]["text_speed"] = value
		"movement_scheme":
			if not value in MOVEMENT_SCHEMES:
				push_warning("SaveData: invalid movement_scheme '%s'" % value)
				return
			data["settings"]["movement_scheme"] = value
		"joystick_deadzone":
			data["settings"][key] = clampf(float(value), 0.0, DEADZONE_MAX)
		_:
			push_warning("SaveData: unknown setting '%s'" % key)
			return
	save()
	setting_changed.emit(key, data["settings"][key])


# ------------------------------------------------------------------- internal
## Returns a fully populated, validated copy of the schema with `loaded` values
## overlaid: correct types, exactly LEVEL_COUNT LevelState values for levels (each
## clamped to a valid state), audio clamped to 0-100, and a valid colorblind mode.
func _normalize(loaded: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate(true)

	var levels = loaded.get("levels")
	if levels is Array:
		for i in range(LEVEL_COUNT):
			if i < levels.size():
				result["levels"][i] = clampi(int(levels[i]), LevelState.LOCKED, LevelState.COMPLETED)

	if "sandbox_unlocked" in loaded:
		result["sandbox_unlocked"] = bool(loaded["sandbox_unlocked"])

	var seen = loaded.get("seen_dialogues")
	if seen is Array:
		var ids: Array = []
		for entry in seen:
			if entry is String and not entry in ids:
				ids.push_back(entry)
		result["seen_dialogues"] = ids

	var hints = loaded.get("seen_hints")
	if hints is Array:
		var hint_ids: Array = []
		for entry in hints:
			if entry is String and not entry in hint_ids:
				hint_ids.push_back(entry)
		result["seen_hints"] = hint_ids

	var settings = loaded.get("settings")
	if settings is Dictionary:
		if "master_audio" in settings:
			result["settings"]["master_audio"] = clampi(int(settings["master_audio"]), 0, 100)
		if "music_audio" in settings:
			result["settings"]["music_audio"] = clampi(int(settings["music_audio"]), 0, 100)
		if "sfx_audio" in settings:
			result["settings"]["sfx_audio"] = clampi(int(settings["sfx_audio"]), 0, 100)
		if settings.get("colorblind_mode") in COLORBLIND_MODES:
			result["settings"]["colorblind_mode"] = settings["colorblind_mode"]
		if settings.get("text_speed") in TEXT_SPEEDS:
			result["settings"]["text_speed"] = settings["text_speed"]
		if settings.get("movement_scheme") in MOVEMENT_SCHEMES:
			result["settings"]["movement_scheme"] = settings["movement_scheme"]
		if "joystick_deadzone" in settings:
			result["settings"]["joystick_deadzone"] = clampf(float(settings["joystick_deadzone"]), 0.0, DEADZONE_MAX)

	return result
