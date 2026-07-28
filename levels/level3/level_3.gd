extends Level
## Level 3. Two bespoke pieces on top of the base Level (progression and
## presentation still come from the base):
##  - the first detector (LaserDetector) is a mechanism, not a goal: it powers a
##    second laser emitter, so that emitter's beam exists only while it is lit, and
##  - the win condition is a single goal detector (LaserDetector2, wired straight
##    to _on_solved in level_3.tscn), NOT the base's default "every detector lit"
##    (which would wrongly count the mechanism detector) -- so it opts out below.


## The win is the goal detector wired to _on_solved in the scene, so skip the
## base's default all-detectors-lit wiring (it would also require the mechanism
## detector and fight the scene's trigger).
func _connect_win_condition() -> void:
	pass


func _on_first_detector_off() -> void:
	$Room/LaserEmitter2.activated = false
	$Room.handle_laser_physics()


func _on_first_detector_on(_color: int) -> void:
	$Room/LaserEmitter2.activated = true
	$Room.handle_laser_physics()
