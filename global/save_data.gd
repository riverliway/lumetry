# This script is loaded as a global in the project settings (autoloaded as `SaveData`).
extends Node
## Global persistent save file, stored redundantly so an interrupted or corrupt
## write can't lose progress.
##
## Two slot files (A/B) are derived from `save_path` -- save.0.json / save.1.json.
## Each save writes the *backup* slot (the one not written last), wrapped in an
## envelope with a wall-clock timestamp and a SHA-256 checksum of the payload.
## The newest good slot is therefore never the one being overwritten. On load we
## read both slots, discard any whose checksum fails (a torn or corrupt write),
## and take the most recent timestamp that survives; a missing/corrupt slot is
## repaired, and if neither survives we fall back to DEFAULTS.
##
## Every value is validated on load and any missing key is filled from DEFAULTS,
## so old saves keep working as the schema grows -- to add a field, add it to
## DEFAULTS and validate it in _normalize(). Mutators write back automatically.

const SAVE_PATH := "user://save.json"
const LEVEL_COUNT := 18
## Allowed values for settings.colorblind_mode.
const COLORBLIND_MODES := ["default", "patterned"]

## Canonical defaults and schema. load_from_disk() starts from a deep copy of
## this and overlays the (validated) values found on disk.
const DEFAULTS := {
	"levels_unlocked": [true, false, false, false, false, false, false, false, false,
		false, false, false, false, false, false, false, false, false],  # level 1 unlocked
	"sandbox_unlocked": false,
	"settings": {
		"music_audio": 100,
		"sfx_audio": 100,
		"colorblind_mode": "default",
	},
}

## The live save state -- always a fully populated, validated copy of the schema.
var data: Dictionary = DEFAULTS.duplicate(true)
## Base save location; the two slot files derive from it. Overridable for tests.
var save_path := SAVE_PATH

## Slot (0 or 1) holding the newest good data; the next save writes the other one.
var _last_slot := 1


func _ready() -> void:
	load_from_disk()


## Loads the newest valid slot. Reads both A/B slots, drops any that fail their
## checksum, and keeps the most recent timestamp. Repairs a missing/corrupt slot
## and falls back to DEFAULTS if neither survives.
func load_from_disk() -> void:
	var slots := []  # each entry: [slot_index, {timestamp, data}]
	for slot in [0, 1]:
		var read = _read_slot(slot)
		if read != null:
			slots.push_back([slot, read])

	if slots.is_empty():
		data = DEFAULTS.duplicate(true)
		_last_slot = 1
		save()  # write both slots so the backup exists from the very first run
		save()
		return

	var best = slots[0]
	for entry in slots:
		if entry[1]["timestamp"] > best[1]["timestamp"]:
			best = entry
	data = _normalize(best[1]["data"])
	_last_slot = best[0]

	if slots.size() < 2:
		save()  # the other slot was missing/corrupt -- rewrite it to restore the backup


## Persists the current state to the backup slot (the one not written last), so
## an interrupted write can never destroy the newest good save. Ping-pongs A/B.
func save() -> void:
	var target := 1 - _last_slot
	_write_slot(target, Time.get_unix_time_from_system())
	_last_slot = target


## Restores the defaults and persists them to both slots.
func reset() -> void:
	data = DEFAULTS.duplicate(true)
	save()
	save()


## The file path for slot 0 or 1, derived from save_path (e.g. user://save.0.json).
func _slot_path(slot: int) -> String:
	return "%s.%d.%s" % [save_path.get_basename(), slot, save_path.get_extension()]


## Writes `data` to `slot` inside an envelope carrying the write timestamp and a
## SHA-256 checksum of the payload, so a corrupt read can be detected on load.
func _write_slot(slot: int, timestamp: float) -> void:
	var payload := JSON.stringify(data, "\t")
	var envelope := {
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


## Reads and verifies a slot. Returns {timestamp, data} if intact, else null
## (missing, unparseable, malformed envelope, or checksum mismatch).
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
	if not (envelope.has("timestamp") and envelope.has("checksum") and envelope.has("payload")):
		return null
	var payload = envelope["payload"]
	if not payload is String or payload.sha256_text() != envelope["checksum"]:
		return null  # corruption: the checksum doesn't match the payload
	var payload_json := JSON.new()
	if payload_json.parse(payload) != OK or not payload_json.data is Dictionary:
		return null
	return {"timestamp": float(envelope["timestamp"]), "data": payload_json.data}


# ---------------------------------------------------------------- progression
## Whether level `index` (0-based; 0 = level 1) is unlocked.
func is_level_unlocked(index: int) -> bool:
	if index < 0 or index >= LEVEL_COUNT:
		return false
	return data["levels_unlocked"][index]


## Unlocks level `index` and saves.
func unlock_level(index: int) -> void:
	if index < 0 or index >= LEVEL_COUNT:
		push_warning("SaveData: level index %d out of range" % index)
		return
	data["levels_unlocked"][index] = true
	save()


func is_sandbox_unlocked() -> bool:
	return data["sandbox_unlocked"]


func set_sandbox_unlocked(value: bool) -> void:
	data["sandbox_unlocked"] = value
	save()


# ------------------------------------------------------------------- settings
## Current value of settings `key` (or its default if somehow unknown).
func get_setting(key: String) -> Variant:
	return data["settings"].get(key, DEFAULTS["settings"].get(key))


## Sets a validated setting and saves. Audio is clamped to 0-100; colorblind_mode
## must be one of COLORBLIND_MODES. Unknown keys and invalid values are ignored.
func set_setting(key: String, value: Variant) -> void:
	match key:
		"music_audio", "sfx_audio":
			data["settings"][key] = clampi(int(value), 0, 100)
		"colorblind_mode":
			if not value in COLORBLIND_MODES:
				push_warning("SaveData: invalid colorblind_mode '%s'" % value)
				return
			data["settings"]["colorblind_mode"] = value
		_:
			push_warning("SaveData: unknown setting '%s'" % key)
			return
	save()


# ------------------------------------------------------------------- internal
## Returns a fully populated, validated copy of the schema with `loaded` values
## overlaid: correct types, exactly LEVEL_COUNT booleans for levels_unlocked,
## audio clamped to 0-100, and a valid colorblind mode.
func _normalize(loaded: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate(true)

	var levels = loaded.get("levels_unlocked")
	if levels is Array:
		for i in range(LEVEL_COUNT):
			if i < levels.size():
				result["levels_unlocked"][i] = bool(levels[i])

	if "sandbox_unlocked" in loaded:
		result["sandbox_unlocked"] = bool(loaded["sandbox_unlocked"])

	var settings = loaded.get("settings")
	if settings is Dictionary:
		if "music_audio" in settings:
			result["settings"]["music_audio"] = clampi(int(settings["music_audio"]), 0, 100)
		if "sfx_audio" in settings:
			result["settings"]["sfx_audio"] = clampi(int(settings["sfx_audio"]), 0, 100)
		if settings.get("colorblind_mode") in COLORBLIND_MODES:
			result["settings"]["colorblind_mode"] = settings["colorblind_mode"]

	return result
