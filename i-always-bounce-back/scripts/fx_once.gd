
extends GPUParticles3D

func _ready() -> void:
	one_shot = true
	restart()
	await get_tree().create_timer(lifetime + 0.4).timeout
	queue_free()
