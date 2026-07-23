extends GutTest
## Unit tests for the level-select gating (ui/LevelSelectButton/level_select.gd):
## unlocked levels are wired and enabled, locked levels are disabled and inert.
##
## Uses synthetic buttons (never the real level_select scene) and drives the global
## SaveData in memory, snapshotting/restoring its data so no save file is touched.

const LevelSelectScript := preload("res://ui/LevelSelectButton/level_select.gd")

var _saved


func before_each():
	_saved = SaveData.data.duplicate(true)

func after_each():
	SaveData.data = _saved


## A Control running the selector script with `count` TextureButton children
## named Level1..Level{count}, added to the tree so _ready() runs its gating.
func _make_selector(count: int) -> Control:
	var selector := Control.new()
	selector.set_script(LevelSelectScript)
	for i in range(1, count + 1):
		var button := TextureButton.new()
		button.name = "Level%d" % i
		selector.add_child(button)
	add_child_autofree(selector)
	return selector


func test_unlocked_levels_enabled_locked_levels_disabled():
	SaveData.data["levels_unlocked"][0] = true   # level 1
	SaveData.data["levels_unlocked"][1] = true   # level 2
	SaveData.data["levels_unlocked"][2] = false  # level 3 locked
	var selector := _make_selector(3)
	assert_false(selector.get_node("Level1").disabled, "unlocked level 1 is enabled")
	assert_false(selector.get_node("Level2").disabled, "unlocked level 2 is enabled")
	assert_true(selector.get_node("Level3").disabled, "locked level 3 is disabled")

func test_only_unlocked_buttons_are_wired():
	SaveData.data["levels_unlocked"][0] = true
	SaveData.data["levels_unlocked"][1] = false
	var selector := _make_selector(2)
	assert_gt(selector.get_node("Level1").pressed.get_connections().size(), 0, "unlocked button opens its level")
	assert_eq(selector.get_node("Level2").pressed.get_connections().size(), 0, "locked button is inert")
