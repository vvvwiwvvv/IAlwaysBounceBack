# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends GPUParticles3D

func _ready() -> void:
	one_shot = true
	restart()
	await get_tree().create_timer(lifetime + 0.4).timeout
	queue_free()
