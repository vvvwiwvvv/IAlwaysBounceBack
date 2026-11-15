extends Node3D
## Builds the island: terrain with collision, water, painted sky, and a sun
## that moves through a day/night cycle with matching fog and ambient light.

@export var terrain_scale := 5.0
@export var water_level := -1.6
## Seconds for one full day. Hold T in game to fast-forward.
@export var day_length := 420.0
## 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.
@export_range(0.0, 1.0) var time_of_day := 0.36

const DAY_TOP := Color(0.16, 0.44, 0.92)
const DAY_HORIZON := Color(0.68, 0.87, 1.0)
const DUSK_TOP := Color(0.3, 0.3, 0.62)
const DUSK_HORIZON := Color(1.0, 0.56, 0.32)
const NIGHT_TOP := Color(0.012, 0.025, 0.08)
const NIGHT_HORIZON := Color(0.06, 0.1, 0.22)

var _sun: DirectionalLight3D
var _env: Environment
var _sky_material: ShaderMaterial
var _spawn := Vector3(0, 5, 0)

@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	_build_terrain()
	_build_water()
	_build_lighting()
	_build_motes()
	_update_lighting()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_place_player()


func _build_terrain() -> void:
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = load("res://terrain/forest.obj")
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://terrain/color_g.png")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.95
	material.metallic_specular = 0.15
	terrain.material_override = material
	terrain.scale = Vector3.ONE * terrain_scale
	add_child(terrain)
	terrain.create_trimesh_collision()


func _build_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	water.mesh = plane
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var ripples := NoiseTexture2D.new()
	ripples.noise = noise
	ripples.seamless = true
	ripples.as_normal_map = true
	ripples.bump_strength = 5.0
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water.gdshader")
	material.set_shader_parameter("ripple_normal", ripples)
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position.y = water_level
	add_child(water)


func _build_lighting() -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_max_distance = 140.0
	_sun.light_angular_distance = 1.2
	_sun.shadow_blur = 1.5
	add_child(_sun)

	_sky_material = ShaderMaterial.new()
	_sky_material.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_sky_contribution = 0.8
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_white = 6.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_bloom = 0.12
	_env.glow_hdr_threshold = 1.0
	_env.ssao_enabled = true
	_env.ssao_radius = 1.6
	_env.ssao_intensity = 1.6
	_env.fog_enabled = true
	_env.fog_density = 0.0016
	_env.fog_aerial_perspective = 0.7
	_env.fog_sky_affect = 0.0
	_env.fog_sun_scatter = 0.25
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.006
	_env.volumetric_fog_anisotropy = 0.7
	_env.volumetric_fog_length = 160.0
	_env.volumetric_fog_ambient_inject = 0.4
	_env.volumetric_fog_sky_affect = 0.0
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.18
	_env.adjustment_contrast = 1.04
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = _env
	add_child(world_env)


func _build_motes() -> void:
	# Slow drifting specks of light around the player.
	var motes := GPUParticles3D.new()
	motes.name = "Motes"
	motes.amount = 140
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 30, 60))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(22, 5, 22)
	process.gravity = Vector3(0, 0.05, 0)
	process.direction = Vector3(1, 0.2, 0.3)
	process.spread = 60.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.5
	process.scale_min = 0.5
	process.scale_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0))
	fade.add_point(Vector2(0.25, 1))
	fade.add_point(Vector2(0.75, 1))
	fade.add_point(Vector2(1, 0))
	var fade_texture := CurveTexture.new()
	fade_texture.curve = fade
	process.scale_curve = fade_texture
	motes.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	glow.albedo_color = Color(1.0, 0.95, 0.7)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.9, 0.55)
	glow.emission_energy_multiplier = 3.0
	quad.material = glow
	motes.draw_pass_1 = quad
	motes.position = Vector3(0, 4, 0)
	player.add_child(motes)


func _place_player() -> void:
	# Drop onto the lowest open ground near the middle of the island.
	var space := get_world_3d().direct_space_state
	var best := Vector3.INF
	for x in range(-4, 5):
		for z in range(-4, 5):
			var from := Vector3(x * 5.0 + 12.0, 200.0, z * 5.0 + 6.0)
			var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 400.0)
			query.exclude = [player.get_rid()]
			var hit := space.intersect_ray(query)
			if hit and hit.normal.y > 0.95 and hit.position.y > water_level + 0.5:
				if best == Vector3.INF or hit.position.y < best.y - 0.01:
					best = hit.position
	if best != Vector3.INF:
		_spawn = best + Vector3.UP * 0.1
	player.global_position = _spawn
	player.velocity = Vector3.ZERO


func _process(delta: float) -> void:
	var speed := 40.0 if Input.is_physical_key_pressed(KEY_T) else 1.0
	time_of_day = fposmod(time_of_day + delta * speed / day_length, 1.0)
	_update_lighting()
	if player.global_position.y < water_level - 30.0:
		player.global_position = _spawn
		player.velocity = Vector3.ZERO


func _update_lighting() -> void:
	var angle := (time_of_day - 0.25) * TAU
	var sun_dir := Vector3(cos(angle), sin(angle), 0.4).normalized()
	var elevation := sun_dir.y
	var day := smoothstep(-0.12, 0.3, elevation)
	var dusk := 1.0 - smoothstep(0.0, 0.4, absf(elevation))

	if elevation >= 0.0:
		_sun.light_color = Color(1.0, 0.55, 0.3).lerp(Color(1.0, 0.95, 0.86), smoothstep(0.0, 0.45, elevation))
		_sun.light_energy = smoothstep(-0.01, 0.07, elevation) * 1.7
		_sun.look_at_from_position(sun_dir, Vector3.ZERO)
	else:
		# Below the horizon the same light becomes a dim blue moon.
		_sun.light_color = Color(0.55, 0.68, 1.0)
		_sun.light_energy = smoothstep(0.0, 0.2, -elevation) * 0.4
		_sun.look_at_from_position(-sun_dir, Vector3.ZERO)

	var top := NIGHT_TOP.lerp(DAY_TOP, day).lerp(DUSK_TOP, dusk * 0.55)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, day).lerp(DUSK_HORIZON, dusk * 0.8)
	var brightness := lerpf(0.12, 1.0, day)
	_sky_material.set_shader_parameter("top_color", top)
	_sky_material.set_shader_parameter("horizon_color", horizon)
	_sky_material.set_shader_parameter("cloud_color", Color.WHITE.lerp(Color(1.0, 0.75, 0.6), dusk) * brightness)
	_sky_material.set_shader_parameter("cloud_shadow_color", Color(0.6, 0.69, 0.87).lerp(Color(0.5, 0.36, 0.5), dusk) * brightness)
	_env.fog_light_color = horizon
	_env.volumetric_fog_albedo = Color.WHITE.lerp(horizon, 0.5)
	_env.ambient_light_energy = lerpf(0.7, 1.0, day) + dusk * 0.6
