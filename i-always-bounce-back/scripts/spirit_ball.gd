# This code was downloaded from https://www.gdquest.com/libray

extends CharacterBody3D

signal bounced(count: int, point: Vector3, normal: Vector3)
signal finished
signal enemy_hit(enemy: Node, killed: bool)

@export_group("Physics")
@export var radius := 0.5
@export var enemy_restitution := 0.9
@export var enemy_pop := 5.0
@export var hover_damping := 5.0
@export var gravity := 14.0
@export var thrust_acceleration := 3.0
@export var thrust_time := 0.35
@export var restitution := 0.72
@export var surface_friction := 0.18
@export var impact_threshold := 0.8
@export var bounce_cooldown := 0.06
@export var max_bounces := 3
@export var max_flight_time := 7.0
@export var rest_speed := 0.6
@export var rest_time := 0.5
@export var stop_damping := 14.0

@export_group("Shape")
@export var squash_amount := 0.38
@export var squash_time := 0.3
@export var stretch_amount := 0.14
@export var stretch_speed := 24.0

@export_group("Aurora")
@export var core_material: Material
@export var shell_material: Material
@export var light_energy := 2.4
@export var reference_speed := 24.0
@export var pulse_decay := 3.5

var charge_level := 0.0
var bounce_count := 0
var flying := false
var age := 0.0
var visual_scale := 0.0
var damage := 10.0
var hovering := false

var _stopping := false
var _cooldown := 0.0
var _rest_timer := 0.0
var _squash_timer := -1.0
var _squash_normal := Vector3.UP
var _pulse := 0.0
var _excluded: Array[RID] = []

@onready var visual: Node3D = $Visual
@onready var halo: MeshInstance3D = $Halo
@onready var core_light: OmniLight3D = $CoreLight
@onready var aura_wisps: GPUParticles3D = $AuraWisps
@onready var aura_sparks: GPUParticles3D = $AuraSparks
@onready var trail_veil: GPUParticles3D = $TrailVeil
@onready var trail_streaks: GPUParticles3D = $TrailStreaks
@onready var trail_motes: GPUParticles3D = $TrailMotes
@onready var burst_ring: GPUParticles3D = $BurstRing
@onready var burst_sparks: GPUParticles3D = $BurstSparks
@onready var burst_veil: GPUParticles3D = $BurstVeil


func _ready() -> void:
	top_level = true
	_apply_materials()
	for system: GPUParticles3D in [aura_wisps, aura_sparks, trail_veil, trail_streaks, trail_motes]:
		system.emitting = true
		system.amount_ratio = 0.0
	for system: GPUParticles3D in [burst_ring, burst_sparks, burst_veil]:
		system.one_shot = true
		system.emitting = false
	deactivate()


func _apply_materials() -> void:
	var meshes := visual.find_children("*", "MeshInstance3D", true, false)
	var largest: MeshInstance3D = null
	var largest_size := -1.0
	for mesh: MeshInstance3D in meshes:
		var size := mesh.get_aabb().size.length() * mesh.global_transform.basis.get_scale().x
		if size > largest_size:
			largest_size = size
			largest = mesh
	for mesh: MeshInstance3D in meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh == largest and shell_material:
			mesh.material_override = shell_material
		elif core_material:
			mesh.material_override = core_material


func exclude_body(body: PhysicsBody3D) -> void:
	add_collision_exception_with(body)
	_excluded.append(body.get_rid())


func integrate_velocity(current: Vector3, time_alive: float, delta: float) -> Vector3:
	var result := current + Vector3.DOWN * gravity * delta
	if time_alive < thrust_time and result.length() > 0.001:
		result += result.normalized() * thrust_acceleration * delta
	return result


func bounce_velocity(incoming: Vector3, normal: Vector3) -> Vector3:
	var normal_part := normal * incoming.dot(normal)
	var tangent_part := incoming - normal_part
	return tangent_part * (1.0 - surface_friction) - normal_part * restitution


func predict(origin: Vector3, launch_velocity: Vector3, max_steps: int) -> Dictionary:
	var points := PackedVector3Array()
	var directions := PackedVector3Array()
	var delta := 1.0 / 60.0
	var position_now := origin
	var velocity_now := launch_velocity
	var time_alive := 0.0
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.exclude_bodies = _excluded
	var result := PhysicsTestMotionResult3D.new()
	var hit := false
	var hit_point := Vector3.ZERO
	var hit_normal := Vector3.UP
	points.append(position_now)
	directions.append(velocity_now.normalized())
	for step in max_steps:
		time_alive += delta
		velocity_now = integrate_velocity(velocity_now, time_alive, delta)
		parameters.from = Transform3D(Basis.IDENTITY, position_now)
		parameters.motion = velocity_now * delta
		if PhysicsServer3D.body_test_motion(get_rid(), parameters, result):
			position_now += result.get_travel()
			points.append(position_now)
			directions.append(velocity_now.normalized())
			hit = true
			hit_point = result.get_collision_point()
			hit_normal = result.get_collision_normal()
			break
		position_now += velocity_now * delta
		points.append(position_now)
		directions.append(velocity_now.normalized())
	return {
		"points": points,
		"directions": directions,
		"hit": hit,
		"hit_point": hit_point,
		"hit_normal": hit_normal,
	}


func prepare(origin: Vector3, level: float) -> void:
	global_position = origin
	charge_level = level
	velocity = Vector3.ZERO
	bounce_count = 0
	age = 0.0
	flying = false
	hovering = false
	_stopping = false
	_cooldown = 0.0
	_rest_timer = 0.0
	_squash_timer = -1.0
	_pulse = 0.0
	visual_scale = 0.0
	visual.visible = true
	halo.visible = true
	set_process(true)
	set_physics_process(true)


func launch(launch_velocity: Vector3) -> void:
	velocity = launch_velocity
	age = 0.0
	flying = true
	_stopping = false


func hover() -> void:
	flying = false
	hovering = true
	_stopping = false


func relaunch(launch_velocity: Vector3) -> void:
	velocity = launch_velocity
	age = 0.0
	bounce_count = 0
	_rest_timer = 0.0
	hovering = false
	flying = true
	_pulse = 1.0


func deactivate() -> void:
	flying = false
	hovering = false
	_stopping = false
	velocity = Vector3.ZERO
	visual_scale = 0.0
	visual.visible = false
	halo.visible = false
	for system: GPUParticles3D in [aura_wisps, aura_sparks, trail_veil, trail_streaks, trail_motes]:
		system.amount_ratio = 0.0
	core_light.light_energy = 0.0
	set_process(false)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if flying:
		_fly(delta)
	elif hovering:
		velocity *= exp(-hover_damping * delta)
		var blocked := move_and_collide(velocity * delta)
		if blocked:
			velocity = velocity.slide(blocked.get_normal())
	elif _stopping:
		velocity *= exp(-stop_damping * delta)
		var collision := move_and_collide(velocity * delta)
		if collision:
			velocity = velocity.slide(collision.get_normal())


func _fly(delta: float) -> void:
	age += delta
	velocity = integrate_velocity(velocity, age, delta)
	var motion := velocity * delta
	var passes := 0
	while passes < 3 and motion.length() > 0.0001:
		var collision := move_and_collide(motion)
		if collision == null:
			break
		var normal := collision.get_normal()
		var into := velocity.dot(normal)
		var collider := collision.get_collider()
		if collider and collider.has_method("take_hit"):
			var killed: bool = collider.take_hit(damage, velocity)
			var rebound := bounce_velocity(velocity, normal)
			var normal_speed := rebound.dot(normal)
			rebound += normal * (absf(into) * enemy_restitution - normal_speed)
			rebound.y = maxf(rebound.y, enemy_pop)
			velocity = rebound
			motion = Vector3.ZERO
			_cooldown = bounce_cooldown
			_squash_timer = 0.0
			_squash_normal = normal
			_pulse = 1.0
			_rest_timer = 0.0
			_burst(collision.get_position(), normal)
			if killed:
				bounce_count = 0
				age = 0.0
			enemy_hit.emit(collider, killed)
		elif into < -impact_threshold and _cooldown <= 0.0:
			velocity = bounce_velocity(velocity, normal)
			motion = collision.get_remainder().bounce(normal) * restitution
			_register_bounce(collision.get_position(), normal)
			if not flying:
				return
		else:
			velocity = velocity.slide(normal)
			motion = collision.get_remainder().slide(normal)
		passes += 1
	if velocity.length() < rest_speed:
		_rest_timer += delta
	else:
		_rest_timer = 0.0
	if age >= max_flight_time or _rest_timer >= rest_time:
		_finish()


func _register_bounce(point: Vector3, normal: Vector3) -> void:
	bounce_count += 1
	_cooldown = bounce_cooldown
	_squash_timer = 0.0
	_squash_normal = normal
	_pulse = 1.0
	_burst(point, normal)
	bounced.emit(bounce_count, point, normal)
	if bounce_count >= max_bounces:
		_finish()


func _finish() -> void:
	if not flying:
		return
	flying = false
	_stopping = true
	finished.emit()


func _burst(point: Vector3, normal: Vector3) -> void:
	var origin := point + normal * 0.15
	for system: GPUParticles3D in [burst_ring, burst_sparks, burst_veil]:
		system.global_position = origin
		system.restart()


func _deform_basis(axis: Vector3, along: float, across: float) -> Basis:
	var rotation_basis := Basis(Quaternion(Vector3.UP, axis.normalized()))
	return rotation_basis * Basis.from_scale(Vector3(across, along, across)) * rotation_basis.inverse()


func _process(delta: float) -> void:
	_pulse = maxf(_pulse - pulse_decay * delta, 0.0)
	var speed := velocity.length()
	var speed_ratio := clampf(speed / reference_speed, 0.0, 1.0)
	var shape := Basis.IDENTITY
	if _squash_timer >= 0.0:
		_squash_timer += delta
		var u := clampf(_squash_timer / squash_time, 0.0, 1.0)
		var wave := (1.0 - u) * (1.0 - u) * cos(u * PI * 2.5)
		shape = _deform_basis(_squash_normal, 1.0 - squash_amount * wave, 1.0 + squash_amount * 0.5 * wave)
		if u >= 1.0:
			_squash_timer = -1.0
	elif flying and speed > 1.0:
		var stretch := stretch_amount * clampf(speed / stretch_speed, 0.0, 1.0)
		shape = _deform_basis(velocity, 1.0 + stretch, 1.0 - stretch * 0.5)
	var size := maxf(visual_scale, 0.001)
	visual.basis = shape * Basis.from_scale(Vector3.ONE * size)

	var power := lerpf(0.4, 1.0, charge_level)
	var presence := clampf(visual_scale, 0.0, 1.0)
	var boost := 1.0 + _pulse * 1.4
	core_light.light_energy = light_energy * lerpf(0.5, 1.3, charge_level) * presence * boost
	halo.scale = Vector3.ONE * maxf(presence * lerpf(0.75, 1.15, charge_level) * (1.0 + _pulse * 0.6), 0.001)
	aura_wisps.amount_ratio = clampf(power * presence * boost, 0.0, 1.0)
	aura_sparks.amount_ratio = clampf(power * presence * boost, 0.0, 1.0)
	_set_brightness(aura_wisps, lerpf(0.6, 1.3, charge_level) * boost)
	_set_brightness(aura_sparks, lerpf(0.8, 1.8, charge_level) * boost)

	var moving := 1.0 if (flying or _stopping) else 0.0
	trail_veil.amount_ratio = clampf(power * lerpf(0.25, 1.0, speed_ratio) * moving * presence, 0.0, 1.0)
	trail_streaks.amount_ratio = clampf(power * pow(speed_ratio, 1.5) * moving, 0.0, 1.0)
	trail_motes.amount_ratio = clampf(power * lerpf(0.2, 1.0, speed_ratio) * moving, 0.0, 1.0)
	if speed > 0.5:
		var backward := -velocity.normalized()
		_set_direction(trail_veil, backward)
		_set_direction(trail_streaks, backward)


func _set_brightness(system: GPUParticles3D, value: float) -> void:
	var material := system.process_material as ShaderMaterial
	if material:
		material.set_shader_parameter("brightness", value)


func _set_direction(system: GPUParticles3D, direction: Vector3) -> void:
	var material := system.process_material as ParticleProcessMaterial
	if material:
		material.direction = direction
