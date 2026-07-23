# This script is loaded as a global in the project settings (autoloaded as `SaveData`).
extends Node
## Global persistent save file.
##
## Progression and settings are stored as JSON at `save_path` (user://save.json).
## The file is read on startup; the mutators below write it back automatically.
## A missing file is created from DEFAULTS; a malformed one falls back to them.
## On load every value is validated and any missing key is filled from DEFAULTS,
## so old save files keep working as the schema grows -- to add a field, add it
## to DEFAULTS and validate it in _normalize().

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
## Where the JSON lives. Overridable so tests can point at a temp file.
var save_path := SAVE_PATH


func _ready() -> void:
	load_from_disk()


## Reads and validates the save file, creating it from DEFAULTS if it's absent.
func load_from_disk() -> void:
	if not FileAccess.file_exists(save_path):
		data = DEFAULTS.duplicate(true)
		save()
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("SaveData: could not read %s; using defaults" % save_path)
		data = DEFAULTS.duplicate(true)
		return
	var text := file.get_as_text()
	file.close()
	# JSON.new().parse() returns an error code without logging an engine error on
	# malformed input (unlike JSON.parse_string), so a corrupt save is handled quietly.
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		data = _normalize(json.data)
	else:
		data = DEFAULTS.duplicate(true)


## Writes the current state to disk as pretty-printed JSON.
func save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveData: could not write %s" % save_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Restores the defaults and persists them.
func reset() -> void:
	data = DEFAULTS.duplicate(true)
	save()


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
