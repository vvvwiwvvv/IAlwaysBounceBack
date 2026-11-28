extends Node3D

@onready var fire = $GPUParticles3D3
@onready var smoke = $GPUParticles3D
@onready var area = $Area3D
func start() -> void:
	fire.emitting = true
	smoke.emitting = true
	await get_tree().physics_frame #otherwise it doesnt detect, something about intit
	for e in area.get_overlapping_bodies():
		if e.is_in_group("enemies") and e.has_method("take_hit"):
			e.take_hit(scale.x,Vector3(0,0,0),0) #scales on oxplosion size 
		
	await fire.finished
	queue_free()
	
