extends GutTest
## Integration coverage for the real menu scenes (title_menu.tscn,
## level_select.tscn): each instantiates with its script + MenuNav, the node
## paths its script relies on resolve, gating still runs, and the focus cursor
## lands on the first available button. These load the actual scenes (unlike the
## synthetic unit tests), so they guard the .tscn wiring itself.

const TITLE_MENU := "res://title_menu.tscn"
const LEVEL_SELECT := "res://level_select.tscn"

var _saved


func before_each() -> void:
	_saved = SaveData.data.duplicate(true)

func after_each() -> void:
	SaveData.data = _saved


func test_title_menu_wires_and_focuses_first_option() -> void:
	var menu: Control = add_child_autofree(load(TITLE_MENU).instantiate())
	await get_tree().process_frame  # let _ready wire buttons and MenuNav grab focus
	await get_tree().process_frame
	var experiments: Button = menu.get_node("Center/Menu/Experiments")
	assert_gt(experiments.pressed.get_connections().size(), 0, "the scene's script wired Experiments")
	assert_true(experiments.has_focus(), "cursor starts on the first option")


func test_drop_out_asks_for_confirmation_and_can_be_canceled() -> void:
	var menu: Control = add_child_autofree(load(TITLE_MENU).instantiate())
	await get_tree().process_frame
	var dialog: Control = menu.get_node("Confirm")
	assert_false(dialog.visible, "confirm dialog is hidden at first")
	menu.get_node("Center/Menu/DropOut").pressed.emit()  # click Drop Out
	assert_true(dialog.visible, "Drop Out opens the confirm dialog instead of quitting")
	dialog.get_node("Center/Panel/Box/Buttons/Cancel").pressed.emit()  # cancel
	assert_false(dialog.visible, "canceling closes the dialog")


func test_esc_asks_for_confirmation() -> void:
	var menu: Control = add_child_autofree(load(TITLE_MENU).instantiate())
	await get_tree().process_frame
	var dialog: Control = menu.get_node("Confirm")
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	menu._unhandled_input(esc)
	assert_true(dialog.visible, "ESC opens the confirm dialog instead of quitting")


func test_level_select_gates_and_focuses_first_unlocked() -> void:
	SaveData.data["levels"][0] = SaveData.LevelState.UNLOCKED  # level 1 unlocked
	SaveData.data["levels"][1] = SaveData.LevelState.LOCKED    # level 2 locked
	var screen: CanvasLayer = add_child_autofree(load(LEVEL_SELECT).instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	var level1: TextureButton = screen.get_node("LevelSelect/Level1")
	var level2: TextureButton = screen.get_node("LevelSelect/Level2")
	assert_false(level1.disabled, "unlocked level 1 is enabled")
	assert_true(level2.disabled, "locked level 2 is disabled")
	assert_true(level1.has_focus(), "cursor starts on the first unlocked level")
