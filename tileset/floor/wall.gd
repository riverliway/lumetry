extends Node2D

var block_type = Util.BLOCK_TYPE.WALL

func _draw():
	draw_circle(Vector2.ZERO, 50, Color.RED)
