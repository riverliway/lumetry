extends Level
## Room-specific logic for Level 8.
##
## The base Level (levels/level.gd) handles the shared board presentation --
## generating the floor to the room's size and scaling it to fit the screen.
## room.gd is the generalized puzzle engine (hex grid, laser physics, block
## pushing). This script owns what is unique to *this* room: its win condition
## and what happens when it is met -- dialogue, advancing to the next room,
## saving progress, and achievements. Those subsystems are not built yet, so
## those hooks are stubs for now.
##
## Win condition: every laser detector in the room is lit at once. The detectors'
## on/off events (detected / cleared) drive a re-evaluation, and `solved` /
## `unsolved` fire on the transition -- so the room can be un-solved again if a
## beam is later broken, letting level code react to both.

## Emitted once when the room's win condition becomes satisfied.
signal solved
## Emitted once when a previously-solved room stops satisfying it.
signal unsolved

var _solved := false  ## whether the win condition is currently satisfied


func _ready() -> void:
	super._ready()  # generate the floor and fit the board to the screen
	# Room is a child, so Room._ready() has already built the grid and registered
	# every block. Wire each detector's on/off events to a re-evaluation, then
	# capture the initial state -- a detector's first `detected` fires during
	# Room._ready(), before this script could connect to it.
	for detector in room.grid.find_detectors():
		detector.detected.connect(_reevaluate)
		detector.cleared.connect(_reevaluate)
	_reevaluate()


## Recomputes the win condition after any detector turns on or off, firing the
## consequences only on a state change (not once per laser pass). The optional
## argument absorbs the `detected(color)` parameter; `cleared()` passes none.
func _reevaluate(_arg = null) -> void:
	var detectors := room.grid.find_detectors()
	var all_lit := not detectors.is_empty() and detectors.all(func(d): return d.is_hit)
	if all_lit and not _solved:
		_solved = true
		_on_solved()
	elif not all_lit and _solved:
		_solved = false
		_on_unsolved()


## The room's puzzle was just solved.
func _on_solved() -> void:
	solved.emit()
	# TODO: the following subsystems are not implemented yet.
	_play_dialogue("level_8_complete")
	_grant_achievement("clear_level_8")
	_save_progress()
	_advance_to_next_room()


## A previously-solved room was un-solved (a detector lost its beam).
func _on_unsolved() -> void:
	unsolved.emit()


# --- room-specific subsystems (not implemented yet) -------------------------

func _play_dialogue(dialogue_id: String) -> void:
	print("[Level8] TODO play dialogue '%s' (dialogue engine not implemented)" % dialogue_id)


func _advance_to_next_room() -> void:
	print("[Level8] TODO advance to the next room (room transitions not implemented)")


func _save_progress() -> void:
	print("[Level8] TODO save progress (save system not implemented)")


func _grant_achievement(achievement_id: String) -> void:
	print("[Level8] TODO grant achievement '%s' (achievements not implemented)" % achievement_id)
