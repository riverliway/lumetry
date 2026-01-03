extends Sprite2D

@export var is_background: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_background:
		modulate = Color('#ffffff26')


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
