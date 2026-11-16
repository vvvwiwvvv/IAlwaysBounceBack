# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends Node

@export var max_amount := 260
@export var growth_rate := 3.5
@export_range(0.0, 0.95) var start_threshold := 0.0
@export var starting_ratio := 0.02
@export var min_orbit_speed := 1.1
@export var max_orbit_speed := 4.2
@export var min_brightness := 0.5
@export var max_brightness := 2.6
@export var min_inward_pull := 0.1
@export var max_inward_pull := 0.45

var level := 0.0
var intensity := 0.0

@onready var particles: GPUParticles3D = get_parent()


func _ready() -> void:
	particles.amount = max_amount
	particles.emitting = true
	particles.amount_ratio = 0.0


func set_time_compensation(value: float) -> void:
	particles.speed_scale = value


func growth_curve(value: float) -> float:
	if growth_rate <= 0.001:
		return value
	return (exp(growth_rate * value) - 1.0) / (exp(growth_rate) - 1.0)


func set_level(value: float, active: bool) -> void:
	level = clampf(value, 0.0, 1.0)
	if not active:
		intensity = 0.0
		particles.amount_ratio = 0.0
		return
	var local := clampf((level - start_threshold) / (1.0 - start_threshold), 0.0, 1.0)
	if start_threshold > 0.0 and local <= 0.0:
		intensity = 0.0
		particles.amount_ratio = 0.0
		return
	intensity = growth_curve(local)
	particles.amount_ratio = lerpf(starting_ratio, 1.0, intensity)
	var material := particles.process_material as ShaderMaterial
	if material:
		material.set_shader_parameter("orbit_speed", lerpf(min_orbit_speed, max_orbit_speed, local))
		material.set_shader_parameter("brightness", lerpf(min_brightness, max_brightness, intensity))
		material.set_shader_parameter("inward_pull", lerpf(min_inward_pull, max_inward_pull, local))
