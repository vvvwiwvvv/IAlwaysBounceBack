extends Node3D

@export var day_length := 420.0
@export_range(0.0, 1.0) var time_of_day := 0.36
@export var animate_time := true
@export var respawn_below := -30.0

const DAY_TOP := Color(0.16, 0.44, 0.92)
const DAY_HORIZON := Color(0.68, 0.87, 1.0)
const DUSK_TOP := Color(0.3, 0.3, 0.62)
const DUSK_HORIZON := Color(1.0, 0.56, 0.32)
const NIGHT_TOP := Color(0.012, 0.025, 0.08)
const NIGHT_HORIZON := Color(0.06, 0.1, 0.22)

@onready var sun: DirectionalLight3D = $Sun
@onready var player: CharacterBody3D = $Player
@onready var spawn: Marker3D = $PlayerSpawn

var _env: Environment
var _sky_material: ShaderMaterial


func _ready() -> void:
	var world_env: WorldEnvironment = $WorldEnvironment
	_env = world_env.environment
	if _env and _env.sky:
		_sky_material = _env.sky.sky_material as ShaderMaterial
	_respawn()
	_update_lighting()


func _process(delta: float) -> void:
	if animate_time:
		var speed := 40.0 if Input.is_physical_key_pressed(KEY_T) else 1.0
		time_of_day = fposmod(time_of_day + delta * speed / maxf(day_length, 1.0), 1.0)
	_update_lighting()
	if player.global_position.y < respawn_below:
		_respawn()


func _respawn() -> void:
	player.global_position = spawn.global_position
	player.velocity = Vector3.ZERO


func _update_lighting() -> void:
	var angle := (time_of_day - 0.25) * TAU
	var sun_dir := Vector3(cos(angle), sin(angle), 0.4).normalized()
	var elevation := sun_dir.y
	var day := smoothstep(-0.12, 0.3, elevation)
	var dusk := 1.0 - smoothstep(0.0, 0.4, absf(elevation))

	if elevation >= 0.0:
		sun.light_color = Color(1.0, 0.55, 0.3).lerp(Color(1.0, 0.95, 0.86), smoothstep(0.0, 0.45, elevation))
		sun.light_energy = smoothstep(-0.01, 0.07, elevation) * 1.7
		sun.look_at_from_position(sun_dir, Vector3.ZERO)
	else:
		sun.light_color = Color(0.55, 0.68, 1.0)
		sun.light_energy = smoothstep(0.0, 0.2, -elevation) * 0.4
		sun.look_at_from_position(-sun_dir, Vector3.ZERO)

	var top := NIGHT_TOP.lerp(DAY_TOP, day).lerp(DUSK_TOP, dusk * 0.55)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, day).lerp(DUSK_HORIZON, dusk * 0.8)
	var brightness := lerpf(0.12, 1.0, day)
	if _sky_material:
		_sky_material.set_shader_parameter("top_color", top)
		_sky_material.set_shader_parameter("horizon_color", horizon)
		_sky_material.set_shader_parameter("cloud_color", Color.WHITE.lerp(Color(1.0, 0.75, 0.6), dusk) * brightness)
		_sky_material.set_shader_parameter("cloud_shadow_color",
				Color(0.6, 0.69, 0.87).lerp(Color(0.5, 0.36, 0.5), dusk) * brightness)
	if _env:
		_env.fog_light_color = horizon
		_env.volumetric_fog_albedo = Color.WHITE.lerp(horizon, 0.5)
		_env.ambient_light_energy = lerpf(0.7, 1.0, day) + dusk * 0.6
