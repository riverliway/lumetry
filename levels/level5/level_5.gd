extends Level
## Level 5. Two bespoke pieces on top of the base Level (progression and
## presentation still come from the base):
##  - a middle detector rotates a pad when hit, redirecting the beam, and
##  - the win condition is a single detector (LaserDetector, wired straight to
##    _on_solved in level_5.tscn), NOT the base's default "every detector lit" --
##    so it opts out of that default check below.


## Level 5's win is the one detector wired to _on_solved in the scene, so skip the
## base's default all-detectors-lit wiring (which would also require the middle
## detector and fight the scene's trigger).
func _connect_win_condition() -> void:
	pass


func _on_middle_dector_detected(_color: int) -> void:
	$Room.rotate_pad($Room/RotationPad)
