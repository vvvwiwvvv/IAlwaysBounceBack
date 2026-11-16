# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends TextureProgressBar

func _process(delta: float) -> void:
	tint_progress = lerp(Color(1, 0, 0, 1), Color(0, 1, 0, 1), value / max_value)
