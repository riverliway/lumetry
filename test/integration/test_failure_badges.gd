extends GutTest
## The level-select fry / softlock badges (GEN): a level records a fry when the
## player is fried there and a softlock when they manually reset there, and the
## level selector shows a lightning-bolt / padlock badge on those levels.
##
## SaveData is the autoload here (the level selector and Level read it live), so
## each test snapshots it and redirects its save file to a temp path -- recording
## calls save(), which must never touch the real user://save.json.

const LEVEL_SELECT := "res://level_select.tscn"
const LevelScript := preload("res://levels/level.gd")

var _saved_data
var _saved_path


func before_each() -> void:
	_saved_data = SaveData.data.duplicate(true)
	_saved_path = SaveData.save_path
	SaveData.save_path = "user://test_badges.json"
	SaveData.data["fried_levels"] = []
	SaveData.data["softlocked_levels"] = []


func after_each() -> void:
	SaveData.data = _saved_data
	SaveData.save_path = _saved_path
	for p in ["user://test_badges.0.json", "user://test_badges.1.json", "user://test_badges.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## A bare Level node standing in for the scene `path` belongs to (empty = none).
## Not added to the tree, so _ready() -- which wants a $Room -- never runs; only
## the number-from-path helpers under test are exercised.
func _level_for(path: String):
	var level = autofree(Node2D.new())
	level.set_script(LevelScript)
	level.scene_file_path = path
	return level


# ------------------------------------------------------------------ recording
func test_frying_records_a_fry_for_the_scenes_level() -> void:
	_level_for("res://levels/level3/level_3.tscn")._record_fry()
	assert_true(SaveData.has_fried_level(2), "level 3 records its fry (0-based index 2)")
	assert_false(SaveData.has_softlocked_level(2), "a fry is not also a softlock")

func test_manual_reset_records_a_softlock_for_the_scenes_level() -> void:
	Level.record_softlock(_level_for("res://levels/level4/level_4.tscn"))
	assert_true(SaveData.has_softlocked_level(3), "level 4 records its softlock (0-based index 3)")
	assert_false(SaveData.has_fried_level(3), "a softlock is not also a fry")

func test_recording_off_a_real_numbered_level_is_a_noop() -> void:
	var synthetic = _level_for("")  # a synthetic tree has no scene file
	synthetic._record_fry()
	Level.record_softlock(synthetic)
	Level.record_softlock(null)  # and a null scene must not crash
	assert_true(SaveData.data["fried_levels"].is_empty(), "no fry recorded off a real level")
	assert_true(SaveData.data["softlocked_levels"].is_empty(), "no softlock recorded off a real level")


# --------------------------------------------------------------- the badges
func test_level_select_shows_badges_only_where_recorded() -> void:
	SaveData.data["levels"][2] = SaveData.LevelState.UNLOCKED   # level 3
	SaveData.data["levels"][4] = SaveData.LevelState.COMPLETED  # level 5
	SaveData.data["levels"][5] = SaveData.LevelState.UNLOCKED   # level 6
	SaveData.data["levels"][6] = SaveData.LevelState.UNLOCKED   # level 7
	SaveData.data["fried_levels"] = [2, 6]        # levels 3 and 7
	SaveData.data["softlocked_levels"] = [4, 6]   # levels 5 and 7

	var screen: CanvasLayer = add_child_autofree(load(LEVEL_SELECT).instantiate())
	await get_tree().process_frame

	assert_true(_has_badge(screen, 3, "FryIcon"), "level 3 shows the fry badge")
	assert_false(_has_badge(screen, 3, "SoftlockIcon"), "level 3 shows no softlock badge")
	assert_true(_has_badge(screen, 5, "SoftlockIcon"), "level 5 shows the softlock badge")
	assert_false(_has_badge(screen, 5, "FryIcon"), "level 5 shows no fry badge")
	assert_true(_has_badge(screen, 7, "FryIcon"), "level 7 shows the fry badge")
	assert_true(_has_badge(screen, 7, "SoftlockIcon"), "level 7 shows the softlock badge")
	assert_false(_has_badge(screen, 6, "FryIcon"), "an unfailed level shows no fry badge")
	assert_false(_has_badge(screen, 6, "SoftlockIcon"), "an unfailed level shows no softlock badge")

func test_completed_tint_does_not_tint_the_badge() -> void:
	# The completed tint is self_modulate (button art only), so a completed level's
	# badge is not recoloured -- the button keeps a default (white) modulate.
	SaveData.data["levels"][4] = SaveData.LevelState.COMPLETED  # level 5
	SaveData.data["softlocked_levels"] = [4]

	var screen: CanvasLayer = add_child_autofree(load(LEVEL_SELECT).instantiate())
	await get_tree().process_frame

	var button: TextureButton = screen.get_node("LevelSelect/Level5")
	assert_eq(button.modulate, Color.WHITE, "modulate is untouched, so children stay untinted")
	assert_true(_has_badge(screen, 5, "SoftlockIcon"), "the badge is present on the completed level")


func _has_badge(screen: Node, level_number: int, badge_name: String) -> bool:
	var button := screen.get_node_or_null("LevelSelect/Level%d" % level_number)
	if button == null:
		return false
	var badge = button.get_node_or_null(badge_name)
	return badge != null and badge.visible
