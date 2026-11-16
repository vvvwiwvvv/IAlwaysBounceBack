# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends AnimatedSprite2D

func _ready() -> void:
	match $"..".sell:
		0:
			frame = 0
		1:
			frame = 1
		2:
			frame = 2
