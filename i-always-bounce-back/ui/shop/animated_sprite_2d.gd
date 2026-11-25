
extends AnimatedSprite2D

func _ready() -> void:
	match $"..".sell:
		0:
			frame = 0
		1:
			frame = 1
		2:
			frame = 2
		3:
			frame = 3
