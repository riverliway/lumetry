extends Level
## Level 5. Two bespoke pieces on top of the base Level (progression and
## presentation still come from the base):
##  - a middle detector unlocks a rotation pad while its beam is present, so the
##    player can spin the pad (and its mirror) to redirect the beam; the pad locks
##    again when the beam clears, and
##  - the win condition is a single detector (LaserDetector, wired straight to
##    _on_solved in level_5.tscn), NOT the base's default "every detector lit" --
##    so it opts out of that default check below.


## Level 5's win is the one detector wired to _on_solved in the scene, so skip the
## base's default all-detectors-lit wiring (which would also require the middle
## detector and fight the scene's trigger).
func _connect_win_condition() -> void:
	pass


## The middle detector gates the rotation pad: while its beam is present the pad
## is unlocked (player-rotatable, active sprite) and the wire running to it lights
## up; when the beam clears the pad locks again and the wire dims. Starts locked
## and unlit -- the scene sets `interactable = false` on the pad and the wire
## defaults to `activated = false`.
func _on_middle_dector_detected(_color: int) -> void:
	$Room/RotationPad.interactable = true
	$Wire.activate()


func _on_middle_dector_cleared() -> void:
	$Room/RotationPad.interactable = false
	$Wire.deactivate()
