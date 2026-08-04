extends Level
## Level 6. All shared room logic -- win condition, progression, presentation --
## lives in the base Level (levels/level.gd); this room adds nothing bespoke.

func _on_mechanism_detected(_color: int) -> void:
	$Room/RotationPad2.interactable = true
	$Wire.activate()


## The mechanism detector's beam cleared: lock the rotation pad again and dim the wire.
func _on_mechanism_cleared() -> void:
	$Room/RotationPad2.interactable = false
	$Wire.deactivate()
