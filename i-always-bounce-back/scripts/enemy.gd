
extends CharacterBody3D

signal died(enemy: Node)

@export_enum("Slime", "Goblin", "Bat") var kind := 0
@export var max_health := 20.0
@export var move_speed := 3.0
@export var acceleration := 6.0
@export var damage := 10.0
@export var attack_range := 1.5
@export var attack_cooldown := 1.0
@export var points := 2
@export var flying := false
@export var hover_height := 2.4
@export var dive_distance := 6.0
@export var gravity := 20.0
@export var turn_speed := 8.0
@export var hops := false
@export var hop_velocity := 4.5
@export var hop_interval := 0.7
@export var waddle := 0.0
@export var falls_on_death := false
@export var death_time := 0.4
@export var despawn_delay := 0.3
@export var death_animation := ""
@export var model_yaw_offset := 0.0
@export var hit_invulnerability := 0.2
@export var fog_scene: PackedScene
@export var albedo_texture: Texture2D

var health := 20.0
var dead := false
var game: Node

var _attack_timer := 0.5
var _hop_timer := 0.0
var _hurt_timer := 0.0
var _flash_timer := 0.0
var _death_timer := 0.0
var _stuck_timer := 0.0
var _sidestep_timer := 0.0
var _sidestep := Vector3.ZERO
var _time := 0.0
var _facing := 0.0
var _overlay: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _animation: AnimationPlayer

@onready var model: Node3D = $Model


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	health = max_health
	for node: Node in model.find_children("*", "", true, false):
		if node is Light3D or node is Camera3D:
			node.queue_free()
		elif node is MeshInstance3D:
			_meshes.append(node)
	if model is MeshInstance3D:
		_meshes.append(model)
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1.0, 0.08, 0.05, 0.0)
	var skin: StandardMaterial3D = null
	if albedo_texture:
		skin = StandardMaterial3D.new()
		skin.albedo_texture = albedo_texture
		skin.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		skin.roughness = 0.35
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = _overlay
		if skin:
			mesh.material_override = skin
	_animation = model.find_child("AnimationPlayer", true, false)
	if _animation:
		_play_loop()
	_time = randf() * 10.0
	_hop_timer = randf() * hop_interval


func _play_loop() -> void:
	var chosen := ""
	for clip: String in _animation.get_animation_list():
		if clip.to_lower().contains("idle") or clip.to_lower().contains("fly") or clip.to_lower().contains("walk"):
			chosen = clip
			break
	if chosen == "" and _animation.get_animation_list().size() > 0:
		chosen = _animation.get_animation_list()[0]
	if chosen == "":
		return
	_animation.get_animation(chosen).loop_mode = Animation.LOOP_LINEAR
	_animation.play(chosen)


func scale_for_wave(wave: int) -> void:
	var factor := 1.0 + 0.12 * float(wave - 1)
	max_health *= factor
	health = max_health
	move_speed *= minf(1.0 + 0.03 * float(wave - 1), 1.5)


func take_hit(amount: float, impulse: Vector3) -> bool:
	if dead or _hurt_timer > 0.0:
		return false
	_hurt_timer = hit_invulnerability
	_flash_timer = 0.15
	health -= amount
	var push := Vector3(impulse.x, 0.0, impulse.z)
	if push.length() > 0.1:
		velocity += push.normalized() * 5.0
	if health <= 0.0:
		_die()
		return true
	return false


func _die() -> void:
	dead = true
	collision_layer = 0
	_death_timer = 0.0
	_overlay.albedo_color.a = 0.6
	if _animation and death_animation != "" and _animation.has_animation(death_animation):
		var length := _animation.get_animation(death_animation).length
		_animation.play(death_animation, 0.05, length / maxf(death_time, 0.05))
	died.emit(self)
	if randf() < 0.01:
		print()


func _physics_process(delta: float) -> void:
	_time += delta
	if dead:
		_tick_death(delta)
		return
	_hurt_timer -= delta
	_attack_timer -= delta
	if _flash_timer > 0.0:
		_flash_timer -= delta
		_overlay.albedo_color.a = 0.55 if _flash_timer > 0.0 else 0.0
	if game == null:
		return
	var target: Vector3 = game.player_target()
	var offset := target - global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	var distance := flat.length()
	var direction := flat.normalized() if distance > 0.01 else Vector3.ZERO
	if _sidestep_timer > 0.0:
		_sidestep_timer -= delta
		direction = _sidestep
	if flying:
		_move_flying(target, distance, delta)
	else:
		_move_ground(direction, distance, delta)
	move_and_slide()
	_check_stuck(direction, distance, delta)
	if direction.length() > 0.1:
		_facing = lerp_angle(_facing, atan2(direction.x, direction.z) + model_yaw_offset, 1.0 - exp(-turn_speed * delta))
		rotation.y = _facing
	if waddle > 0.0:
		model.rotation.z = sin(_time * move_speed * 3.0) * waddle
		model.position.y = absf(sin(_time * move_speed * 3.0)) * waddle * 0.5
	if offset.length() <= attack_range and _attack_timer <= 0.0 and game.player_vulnerable():
		_attack_timer = attack_cooldown
		game.damage_player(damage, self)


func _move_ground(direction: Vector3, distance: float, delta: float) -> void:
	var wanted := direction * move_speed
	if distance < attack_range * 0.6:
		wanted = Vector3.ZERO
	var blend := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, wanted.x, blend)
	velocity.z = lerpf(velocity.z, wanted.z, blend)
	if is_on_floor():
		if hops:
			_hop_timer -= delta
			if _hop_timer <= 0.0:
				_hop_timer = hop_interval
				velocity.y = hop_velocity
		else:
			velocity.y = -0.5
	else:
		velocity.y -= gravity * delta


func _move_flying(target: Vector3, distance: float, delta: float) -> void:
	var goal := target
	if distance > dive_distance:
		goal.y = target.y + hover_height
	goal.y += sin(_time * 3.0) * 0.25
	var wanted := goal - global_position
	if wanted.length() > 0.3:
		wanted = wanted.normalized() * move_speed
	velocity = velocity.lerp(wanted, 1.0 - exp(-acceleration * delta))


func _check_stuck(direction: Vector3, distance: float, delta: float) -> void:
	if flying or distance < attack_range or _sidestep_timer > 0.0:
		_stuck_timer = 0.0
		return
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if speed < move_speed * 0.3:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	if _stuck_timer > 0.6:
		_stuck_timer = 0.0
		_sidestep_timer = 0.9
		var side := direction.cross(Vector3.UP).normalized()
		if randf() > 0.5:
			side = -side
		_sidestep = (side + direction * 0.3).normalized()


func _tick_death(delta: float) -> void:
	_death_timer += delta
	velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-8.0 * delta))
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	if falls_on_death:
		var progress := clampf(_death_timer / death_time, 0.0, 1.0)
		var eased := progress * progress
		model.rotation.x = -eased * PI * 0.5
		model.position.y = eased * 0.25
	var limit := death_time + despawn_delay if falls_on_death else despawn_delay
	if _death_timer >= limit:
		_spawn_fog()
		queue_free()


func _spawn_fog() -> void:
	if fog_scene == null:
		return
	var puff: Node3D = fog_scene.instantiate()
	get_parent().add_child(puff)
	puff.global_position = global_position + Vector3.UP * 0.5
