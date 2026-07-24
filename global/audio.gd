# This script is loaded as a global in the project settings (autoloaded as `Audio`).
extends Node
## Bridges the saved audio settings to the AudioServer buses. The Master / Music /
## SFX buses live in res://default_bus_layout.tres; SaveData stores each bus's
## level as a 0-100 percentage. On boot we push the saved levels onto the buses,
## and we mirror any live change (from the options menu) via SaveData.setting_changed
## so a dragged slider is heard immediately. No sound plays yet -- this is the
## volume plumbing the future SFX/music will route through.

## Which bus each audio setting drives, by name (resolved to an index at apply time
## so a missing bus is skipped rather than crashing).
const BUS_FOR := {
	"master_audio": "Master",
	"music_audio": "Music",
	"sfx_audio": "SFX",
}


func _ready() -> void:
	apply_all()
	SaveData.setting_changed.connect(_on_setting_changed)


## Pushes every saved audio level onto its bus. Safe to call any time.
func apply_all() -> void:
	for key in BUS_FOR:
		_apply(key, SaveData.get_setting(key))


func _on_setting_changed(key: String, value) -> void:
	if BUS_FOR.has(key):
		_apply(key, value)


## Sets bus `BUS_FOR[key]` to `percent` (0-100). A missing bus is ignored.
func _apply(key: String, percent) -> void:
	var idx := AudioServer.get_bus_index(BUS_FOR[key])
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, percent_to_db(int(percent)))


## Converts a 0-100 volume percentage to decibels. 0 is silence (a floor well
## below audibility); 100 is unity gain (0 dB). The curve is perceptual (linear
## amplitude -> dB), so the slider tracks loudness rather than raw amplitude.
static func percent_to_db(percent: int) -> float:
	if percent <= 0:
		return -80.0
	return linear_to_db(clampf(percent / 100.0, 0.0, 1.0))
