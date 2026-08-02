extends Level
## Level 9. On top of the base Level (win condition, progression, presentation)
## this room adds two independent mechanism wires: each blue mechanism detector
## unlocks a rotation pad while its beam is present, letting the player spin the
## pad to redirect a beam; the pad locks again when the beam clears, with a wire
## running from the detector to the pad that lights while it is active.
##
##  - LaserDetector  -> RotationPad5 (Wire)
##  - LaserDetector3 -> RotationPad6 (Wire2)
##
## The win condition is the base default -- the room's GOAL detector (LaserDetector2,
## the red, non-mechanism one) lit. The mechanism detectors are excluded from the
## win automatically (see Level._reevaluate); they are wired straight to the
## handlers below in level_9.tscn. The scene starts both pads with
## interactable = false and both wires deactivated.


## LaserDetector's beam arrived: unlock RotationPad5 and light its wire.
func _on_detector_detected(_color: int) -> void:
	$Room/RotationPad5.interactable = true
	$Wire.activate()


## LaserDetector's beam cleared: lock RotationPad5 again and dim its wire.
func _on_detector_cleared() -> void:
	$Room/RotationPad5.interactable = false
	$Wire.deactivate()


## LaserDetector3's beam arrived: unlock RotationPad6 and light its wire.
func _on_detector3_detected(_color: int) -> void:
	$Room/RotationPad6.interactable = true
	$Wire2.activate()


## LaserDetector3's beam cleared: lock RotationPad6 again and dim its wire.
func _on_detector3_cleared() -> void:
	$Room/RotationPad6.interactable = false
	$Wire2.deactivate()
