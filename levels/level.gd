extends Node2D
class_name Level
## Root node for a playable room -- owns everything shared across the 18 levels.
##
## room.gd is the generalized puzzle engine (one per room, as the `Room` child):
## hex grid, laser physics, block pushing. This base wraps that with the logic
## that is the same in every room, so a per-level script only has to add what is
## unique to *that* room (see levels/level3 and levels/level5 for the two that do).
##
## It handles three things:
##
## * Presentation -- uniformly scaling the whole level so the entire board is
##   always on screen (a bigger grid renders smaller, a smaller one larger; the
##   view never pans), and dimming the floor cells under a wall. The hex floor
##   tiles themselves are baked into the scene by tools/generate_floor.py.
##
## * Win condition -- the room is solved when every laser detector in it is lit at
##   once. Each detector's on/off events drive a re-evaluation; `solved`/`unsolved`
##   fire on the transition, so a room can be un-solved again if a beam is later
##   broken. A level with a different win condition (e.g. one specific detector)
##   wires its own trigger straight to `_on_solved` in its scene.
##
## * Progression -- on the solving edge the room records completion (which also
##   unlocks the next level) and advances to the next room. Dialogue and
##   achievements are hooked here too but their subsystems aren't built yet, so
##   those two remain stubs.

## Emitted once when the room's win condition becomes satisfied.
signal solved
## Emitted once when a previously-solved room stops satisfying it.
signal unsolved

## Dim tint for floor cells under a wall, so the arena boundary reads darker than
## the open, movable cells. Matches the old hand-authored `is_background` look.
const WALL_FLOOR_MODULATE := Color("ffffff26")
## Pause menu overlay, added to every room so ESC always has a menu behind it.
const PAUSE_MENU := preload("res://ui/pause_menu.tscn")
## Where advancing past the final level lands (there is no next room to open).
const LEVEL_SELECT_SCENE := "res://level_select.tscn"
## Beat (seconds) held after a death or a win before the dialogue and the room
## reset / advance, with player input locked, so the player can register what
## happened.
const POST_EVENT_DELAY := 1.0

@onready var room: Room = $Room

var _solved := false  ## whether the win condition is currently satisfied


func _ready() -> void:
	dim_wall_floor()
	fit_to_screen()
	add_child(PAUSE_MENU.instantiate())
	_connect_win_condition()
	_connect_hazard()


## Wires the default win condition: the room is solved once every GOAL detector is
## lit at once (mechanism detectors are excluded -- see _reevaluate). Room is a
## child, so Room._ready() has already built the grid and registered every block;
## we connect each detector's on/off events to a re-evaluation, then capture the
## initial state (a detector's first `detected` fires during Room._ready(), before
## this could connect to it). A level with a bespoke win condition overrides this
## to wire its own trigger instead.
func _connect_win_condition() -> void:
	if room == null or room.grid == null:
		return
	for detector in room.grid.find_detectors():
		detector.detected.connect(_reevaluate)
		detector.cleared.connect(_reevaluate)
	_reevaluate()


## Wires the laser-hazard reactions the room raises: frying the player (a beam
## strikes them through their own action) resets the room after the "fried"
## dialogue, and bumping into a beam surfaces the one-time "singed" hint. Every
## level gets these (a bespoke level overrides _connect_win_condition, not _ready).
func _connect_hazard() -> void:
	if room == null:
		return
	room.player_fried.connect(_on_player_fried)
	room.player_singed.connect(_on_player_singed)


## Recomputes the win condition after any detector turns on or off. The optional
## argument absorbs the `detected(color)` parameter; `cleared()` passes none.
## `_on_solved`/`_on_unsolved` are idempotent, so this can be called freely (once
## per laser pass, per detector) -- the consequences fire only on the edge.
func _reevaluate(_arg = null) -> void:
	# Only goal detectors count toward the win. Mechanism detectors (is_mechanism --
	# the blue ones) drive an in-room device instead of the win, so they are left out
	# here; the room is solved once every GOAL detector is lit at the same time.
	var goals := room.grid.find_detectors().filter(func(d): return not d.is_mechanism)
	var all_lit := not goals.is_empty() and goals.all(func(d): return d.is_hit)
	if all_lit:
		_on_solved()
	else:
		_on_unsolved()


## The room's puzzle was just solved. Idempotent: fires the win consequences once
## per solve, so it is safe to invoke both from `_reevaluate` and from a level's
## own trigger (the `_arg` absorbs a `detected(color)` when wired to a detector).
func _on_solved(_arg = null) -> void:
	if _solved:
		return
	_solved = true
	solved.emit()
	# Record the win now, before the pause -- closing the game during the beat
	# must not lose progress the player already earned.
	_save_progress()
	await _pause_before_aftermath()
	# Dialogue/achievements aren't implemented yet, so those two remain stubs.
	_play_dialogue("level_%d_complete" % _level_number())
	_grant_achievement("clear_level_%d" % _level_number())
	_advance_to_next_room()


## A previously-solved room was un-solved (a detector lost its beam). Idempotent.
func _on_unsolved() -> void:
	if not _solved:
		return
	_solved = false
	unsolved.emit()


# --- laser hazard -----------------------------------------------------------

## The player fried themselves on a beam. The room leaves the killing beam ON;
## hold a locked-input beat so the player can see what got them, THEN switch the
## emitters off, play the "fried" dialogue, and reset the room to its start.
## (Once the dialogue engine lands, the reset should wait for the dialogue to be
## dismissed rather than firing immediately.)
func _on_player_fried() -> void:
	await _pause_before_aftermath()  # hold with the killing beam still on screen
	room.shut_off_all_emitters()     # now the beams go dark -- the player has seen them
	_play_dialogue("fried")
	_reset_room()


## The player tried to cross a beam (the move was refused). Show the "singed"
## hint the first time it ever happens and remember it in the save, so the hint
## never repeats -- across rooms or playthroughs.
func _on_player_singed() -> void:
	if SaveData.has_seen_dialogue("singed"):
		return
	SaveData.mark_dialogue_seen("singed")
	_play_dialogue("singed")


## Locks player input and holds for POST_EVENT_DELAY, giving the player a beat to
## register a death or a win before the dialogue and the room reset / advance.
## Input stays locked afterward -- the reset/advance brings up a fresh, unlocked
## player. No-ops off a real numbered level (a synthetic test tree has no timing
## to honour and awaiting a real timer would hang the tests), matching the guard
## on _reset_room / _advance_to_next_room, so the callers stay synchronous there.
func _pause_before_aftermath() -> void:
	if _level_number() < 1:
		return
	_lock_player_input()
	await get_tree().create_timer(POST_EVENT_DELAY).timeout


## Stops the player from acting for the rest of this room (see Player.input_locked).
func _lock_player_input() -> void:
	var player := room.get_node_or_null("Player") if room else null
	if player:
		player.input_locked = true


## Reloads the room to its starting state, fading through black -- the same reset
## the pause menu offers. No-ops off a real numbered level (a synthetic test tree
## has no scene to reload); see _level_number.
func _reset_room() -> void:
	if _level_number() < 1:
		return
	Transition.transition(func(): get_tree().reload_current_scene())


# --- board presentation -----------------------------------------------------

## Dims each baked floor tile that sits on a wall cell, marking the non-playable
## boundary. Derived from the live grid, so it always matches the actual walls.
func dim_wall_floor() -> void:
	var floor_root := get_node_or_null("Floor")
	if floor_root == null or room == null:
		return
	for tile in floor_root.get_children():
		if tile is CanvasItem and room.grid.get_nearest_cell(tile.position).get_block_type() == Util.BLOCK_TYPE.WALL:
			tile.modulate = WALL_FLOOR_MODULATE


## Uniformly scales and centers this level so the room's board bounds fit the
## design viewport, keeping the whole room visible. Safe to re-run.
func fit_to_screen() -> void:
	if room == null or room.grid == null:
		return
	var design := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 3840),
		ProjectSettings.get_setting("display/window/size/viewport_height", 2160))
	var bounds := room.grid.board_bounds()
	var s: float = min(design.x / bounds.size.x, design.y / bounds.size.y)
	scale = Vector2(s, s)
	# Center the scaled board: map its top-left corner to the centered offset.
	position = (design - bounds.size * s) / 2.0 - bounds.position * s


# --- progression ------------------------------------------------------------

## This level's 1-based number parsed from its scene file
## ("res://levels/level5/level_5.tscn" -> 5), or -1 if the tree isn't a real
## numbered level scene -- e.g. a synthetic tree built in a test, which has no
## scene file, so the hooks below no-op safely off the real levels.
func _level_number() -> int:
	return level_number_from_path(scene_file_path)


## Parses "res://levels/levelN/level_N.tscn" -> N; -1 for anything else. Static so
## it can be unit-tested without loading a scene.
static func level_number_from_path(path: String) -> int:
	var stem := path.get_file().get_basename()  # e.g. "level_5"
	if not stem.begins_with("level_"):
		return -1
	var digits := stem.trim_prefix("level_")
	return digits.to_int() if digits.is_valid_int() else -1


## Records this level as completed, which also unlocks the next one. No-ops off a
## real numbered level (see `_level_number`).
func _save_progress() -> void:
	var n := _level_number()
	if n < 1:
		return
	SaveData.complete_level(n - 1)  # 0-based; also unlocks level n (the next one)


## Fades to the next level's scene -- or to the level select once the final level
## is cleared, since there is no next room. No-ops off a real numbered level.
func _advance_to_next_room() -> void:
	var n := _level_number()
	if n < 1:
		return
	var next := n + 1
	if next > SaveData.LEVEL_COUNT:
		Transition.change_scene_to(LEVEL_SELECT_SCENE)
	else:
		Transition.change_scene_to("res://levels/level%d/level_%d.tscn" % [next, next])


# --- unimplemented subsystems (stubs) ---------------------------------------

func _play_dialogue(dialogue_id: String) -> void:
	print("[Level] TODO play dialogue '%s' (dialogue engine not implemented)" % dialogue_id)


func _grant_achievement(achievement_id: String) -> void:
	print("[Level] TODO grant achievement '%s' (achievements not implemented)" % achievement_id)
