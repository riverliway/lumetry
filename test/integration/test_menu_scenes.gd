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


func test_level_select_gates_and_focuses_first_unlocked() -> void:
	SaveData.data["levels_unlocked"][0] = true   # level 1 unlocked
	SaveData.data["levels_unlocked"][1] = false  # level 2 locked
	var screen: CanvasLayer = add_child_autofree(load(LEVEL_SELECT).instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	var level1: TextureButton = screen.get_node("LevelSelect/Level1")
	var level2: TextureButton = screen.get_node("LevelSelect/Level2")
	assert_false(level1.disabled, "unlocked level 1 is enabled")
	assert_true(level2.disabled, "locked level 2 is disabled")
	assert_true(level1.has_focus(), "cursor starts on the first unlocked level")
