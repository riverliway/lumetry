extends GutTest
## Integration coverage for the options overlay (ui/options_menu.tscn): opening it
## reflects the saved settings, and each control writes its change back through
## SaveData. It loads the real scene, so it also guards the .tscn node wiring the
## script relies on. SaveData is snapshotted and rewritten afterward so the
## menu's writes don't linger in the running project's save.

const OptionsScene := preload("res://ui/options_menu.tscn")

var _saved


func before_each() -> void:
	_saved = SaveData.data.duplicate(true)

func after_each() -> void:
	SaveData.data = _saved
	SaveData.save()      # rewrite disk so test mutations don't persist
	Audio.apply_all()    # resync the buses to the restored levels


func _open_menu(show_reset := false):
	var menu = OptionsScene.instantiate()
	menu.show_reset = show_reset  # set before _ready so it configures the button
	add_child_autofree(menu)
	await get_tree().process_frame  # let _ready hide + wire the controls
	menu.open()
	return menu


func test_open_reflects_saved_audio_levels():
	SaveData.data["settings"]["master_audio"] = 40
	SaveData.data["settings"]["music_audio"] = 60
	SaveData.data["settings"]["sfx_audio"] = 80
	var menu = await _open_menu()
	assert_eq(menu.get_node("Center/Panel/Box/Master/Slider").value, 40.0, "master slider synced")
	assert_eq(menu.get_node("Center/Panel/Box/Music/Slider").value, 60.0, "music slider synced")
	assert_eq(menu.get_node("Center/Panel/Box/Sfx/Slider").value, 80.0, "sfx slider synced")
	assert_eq(menu.get_node("Center/Panel/Box/Master/Value").text, "40", "value label synced")


func test_open_reflects_colorblind_and_text_speed():
	SaveData.data["settings"]["colorblind_mode"] = "patterned"
	SaveData.data["settings"]["text_speed"] = "fast"
	var menu = await _open_menu()
	assert_eq(menu.get_node("Center/Panel/Box/Colorblind/Toggle").text, "On", "colorblind toggle reads On")
	assert_eq(menu.get_node("Center/Panel/Box/TextSpeed/Toggle").text, "Fast", "text speed reads Fast")


func test_changing_a_slider_persists_the_value():
	SaveData.data["settings"]["music_audio"] = 100
	var menu = await _open_menu()
	menu.get_node("Center/Panel/Box/Music/Slider").value = 25
	assert_eq(SaveData.get_setting("music_audio"), 25, "a slider change is written to settings")


func test_colorblind_toggle_flips_the_setting():
	SaveData.data["settings"]["colorblind_mode"] = "default"
	var menu = await _open_menu()
	var toggle = menu.get_node("Center/Panel/Box/Colorblind/Toggle")
	toggle.pressed.emit()
	assert_eq(SaveData.get_setting("colorblind_mode"), "patterned", "toggles on")
	toggle.pressed.emit()
	assert_eq(SaveData.get_setting("colorblind_mode"), "default", "toggles back off")


func test_text_speed_cycles_and_wraps():
	SaveData.data["settings"]["text_speed"] = "slow"
	var menu = await _open_menu()
	var btn = menu.get_node("Center/Panel/Box/TextSpeed/Toggle")
	btn.pressed.emit()
	assert_eq(SaveData.get_setting("text_speed"), "normal", "slow -> normal")
	btn.pressed.emit()
	assert_eq(SaveData.get_setting("text_speed"), "fast", "normal -> fast")
	btn.pressed.emit()
	assert_eq(SaveData.get_setting("text_speed"), "slow", "fast wraps to slow")


func test_reset_is_hidden_unless_from_the_title_screen():
	var menu = await _open_menu()  # in-game (pause) copy: show_reset defaults false
	var reset = menu.get_node("Center/Panel/Box/ResetSave")
	assert_false(reset.visible, "Reset Save is hidden in the in-level pause menu")
	assert_true(reset.disabled, "and disabled, so the cursor never lands on it")


func test_reset_button_opens_a_confirmation():
	var menu = await _open_menu(true)
	menu.get_node("Center/Panel/Box/ResetSave").pressed.emit()
	var confirm = menu.get_node("Confirm")
	assert_true(confirm.visible, "Reset Save opens a confirmation dialog")
	assert_eq(confirm.get_node("Center/Panel/Box/Message").text,
		"Reset all progress? This can't be undone.", "shows the reset prompt")


func test_reset_cancel_keeps_progress_and_reopens_menu():
	SaveData.data["levels"][3] = SaveData.LevelState.COMPLETED
	var menu = await _open_menu(true)
	menu.get_node("Center/Panel/Box/ResetSave").pressed.emit()
	menu.get_node("Confirm/Center/Panel/Box/Buttons/Cancel").pressed.emit()
	assert_false(menu.get_node("Confirm").visible, "cancel closes the confirmation")
	assert_true(menu.visible, "the options menu stays open after cancel")
	assert_eq(SaveData.get_level_state(3), SaveData.LevelState.COMPLETED, "cancel keeps progress")


func test_confirming_reset_wipes_progress_and_closes():
	SaveData.data["levels"][3] = SaveData.LevelState.COMPLETED
	var menu = await _open_menu(true)
	menu.get_node("Center/Panel/Box/ResetSave").pressed.emit()
	menu.get_node("Confirm/Center/Panel/Box/Buttons/Confirm").pressed.emit()
	assert_eq(SaveData.get_level_state(3), SaveData.LevelState.LOCKED, "reset wiped the completed level")
	assert_eq(SaveData.get_level_state(0), SaveData.LevelState.UNLOCKED, "level 1 is unlocked again")
	assert_false(menu.visible, "reset closes the options menu")


func test_close_hides_and_emits():
	var menu = await _open_menu()
	assert_true(menu.visible, "open shows the menu")
	watch_signals(menu)
	menu.close()
	assert_false(menu.visible, "close hides it")
	assert_signal_emitted(menu, "closed")


func test_esc_backs_out():
	var menu = await _open_menu()
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	menu._unhandled_input(esc)
	assert_false(menu.visible, "ESC closes the options menu")
