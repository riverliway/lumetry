extends GutTest
## Tests for the audio-bus bridge (global/audio.gd): the 0-100 percentage to
## decibel curve, and applying a level onto a real AudioServer bus. Bus tests
## resync the buses to the saved levels afterward so a test can't leave the
## running project's audio turned down.

const AudioScript := preload("res://global/audio.gd")


func after_each() -> void:
	Audio.apply_all()  # restore buses to the saved settings


func test_percent_to_db_endpoints():
	assert_eq(AudioScript.percent_to_db(0), -80.0, "0% is the silence floor")
	assert_almost_eq(AudioScript.percent_to_db(100), 0.0, 0.001, "100% is unity gain (0 dB)")
	assert_lt(AudioScript.percent_to_db(50), 0.0, "half volume is attenuated below unity")


func test_percent_to_db_is_monotonic():
	assert_lt(AudioScript.percent_to_db(25), AudioScript.percent_to_db(75), "louder percentage -> higher dB")


func test_apply_all_matches_the_saved_master_level():
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		pending("no Master bus in this environment")
		return
	Audio.apply_all()
	var expected := AudioScript.percent_to_db(int(SaveData.get_setting("master_audio")))
	assert_almost_eq(AudioServer.get_bus_volume_db(master), expected, 0.01, "Master bus reflects the saved level")


func test_live_setting_change_drives_the_bus():
	var sfx := AudioServer.get_bus_index("SFX")
	if sfx < 0:
		pending("no SFX bus in this environment")
		return
	Audio._on_setting_changed("sfx_audio", 0)
	assert_eq(AudioServer.get_bus_volume_db(sfx), -80.0, "0% mutes the SFX bus")
	Audio._on_setting_changed("sfx_audio", 100)
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx), 0.0, 0.01, "100% restores unity gain")
