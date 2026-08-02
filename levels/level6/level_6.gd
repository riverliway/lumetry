extends Level
## Level 6. One bespoke piece on top of the base Level:
##  - a mechanism detector (the blue one) unlocks a rotation pad while its beam is
##    present, so the player can spin the pad to redirect a beam; the pad locks
##    again when the beam clears, with a wire running vertically from the detector
##    down to the pad that lights while it is active.
##
## The win condition is the base default -- both GOAL detectors (the two red,
## non-mechanism ones) lit at the same time. The mechanism detector is excluded
## from the win automatically (see Level._reevaluate), so no override is needed;
## it is wired straight to the handlers below in level_6.tscn.


## The mechanism detector's beam arrived: unlock the rotation pad so the player can
## spin it, and light the wire running to it. The scene starts the pad with
## interactable = false and the wire deactivated.
func _on_mechanism_detected(_color: int) -> void:
	$Room/RotationPad.interactable = true
	$Wire.activate()


## The mechanism detector's beam cleared: lock the rotation pad again and dim the wire.
func _on_mechanism_cleared() -> void:
	$Room/RotationPad.interactable = false
	$Wire.deactivate()
