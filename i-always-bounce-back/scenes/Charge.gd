extends Node

@export var charge_time := 3.0
@export var max_amount := 200

var charge := 0.0

@onready var particles: GPUParticles3D = get_parent()


func _ready() -> void:
	particles.amount = max_amount
	particles.emitting = true
	particles.amount_ratio = 0.0


func _process(delta: float) -> void:
	if Input.is_action_pressed("charge"):
		charge = minf(charge + delta, charge_time)
	else:
		charge = 0.0
	particles.amount_ratio = charge / charge_time
