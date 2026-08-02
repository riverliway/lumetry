extends Control
## Level-select screen. Each "LevelN" button (N = 1..18) opens
## levels/levelN/level_N.tscn. Buttons are wired up generically by name so
## adding or reordering them needs no per-button handler. Each button reflects the
## level's SaveData state (0-based): LOCKED is disabled and inert, UNLOCKED is
## playable, and COMPLETED is playable and tinted.
##
## A button also carries placeholder status badges in its bottom corners for the
## level's failure history: a lightning bolt if the player has ever fried there, a
## padlock if they have ever softlocked (manually reset) there. The completed tint
## uses self_modulate so it colours only the button art, not the badges.
##
## A child MenuNav drives the focus cursor (mouse hover + WASD); ESC backs out to
## the title menu.

const TITLE_MENU_SCENE := "res://title_menu.tscn"
## Tint applied to a completed level's button. Placeholder until completed-state
## button art exists.
const COMPLETED_TINT := Color(0.55, 1.0, 0.55)

## Placeholder badges shown on a level the player has fried / softlocked in.
const FRY_ICON := preload("res://ui/icons/fry.png")
const SOFTLOCK_ICON := preload("res://ui/icons/softlock.png")
## Badge footprint and inset from the button's bottom corners.
const BADGE_SIZE := 84.0
const BADGE_MARGIN := 14.0


func _ready() -> void:
	for child in get_children():
		if child is TextureButton and String(child.name).begins_with("Level"):
			var number := String(child.name).trim_prefix("Level").to_int()
			if number < 1:
				continue
			var index := number - 1
			# Failure badges, independent of lock state (a locked level has none).
			# The completed tint below is self_modulate, so it never tints these.
			if SaveData.has_fried_level(index):
				_add_badge(child, FRY_ICON, "FryIcon", false)          # bottom-left
			if SaveData.has_softlocked_level(index):
				_add_badge(child, SOFTLOCK_ICON, "SoftlockIcon", true)  # bottom-right
			match SaveData.get_level_state(index):
				SaveData.LevelState.LOCKED:
					child.disabled = true
				SaveData.LevelState.COMPLETED:
					child.self_modulate = COMPLETED_TINT
					child.pressed.connect(_open_level.bind(number))
				_:  # UNLOCKED
					child.pressed.connect(_open_level.bind(number))


## Adds a status badge to a level button, pinned to a bottom corner so it holds
## position at whatever size the button is laid out to. Parented to the button so
## it draws over the button art; mouse_filter IGNORE so it never eats a click.
func _add_badge(button: Control, texture: Texture2D, badge_name: String, right: bool) -> void:
	var badge := TextureRect.new()
	badge.name = badge_name
	badge.texture = texture
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_top = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_top = -(BADGE_MARGIN + BADGE_SIZE)
	badge.offset_bottom = -BADGE_MARGIN
	if right:
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.offset_left = -(BADGE_MARGIN + BADGE_SIZE)
		badge.offset_right = -BADGE_MARGIN
	else:
		badge.offset_left = BADGE_MARGIN
		badge.offset_right = BADGE_MARGIN + BADGE_SIZE
	button.add_child(badge)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):  # ESC: back to the title menu
		Transition.change_scene_to(TITLE_MENU_SCENE)
		get_viewport().set_input_as_handled()


func _open_level(number: int) -> void:
	Transition.change_scene_to("res://levels/level%d/level_%d.tscn" % [number, number])
