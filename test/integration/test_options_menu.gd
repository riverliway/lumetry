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


func _open_menu():
	var menu = add_child_autofree(OptionsScene.instantiate())
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
