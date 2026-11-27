
extends Node3D

signal state_changed(previous: int, current: int)
signal charge_started
signal charge_ended
signal ball_bounced
signal ball_hit_enemy(killed: bool)

enum State { IDLE, CHARGING, FULLY_CHARGED, TRANSFORM_IN, FLYING, BOUNCING, AIR_CHARGING, TRANSFORM_OUT }

@export_group("Charge")
@export var charge_action := "charge"
@export var miss_cooldown := 3.0
@export var hit_cooldown := 1.0
@export var charge_light_energy := 2.6
@export var max_charge_time := 2.0
@export var min_charge_time := 0.2


@export_group("Launch")
@export var min_launch_speed := 9.0
@export var max_launch_speed := 24.0
@export var aim_loft_degrees := 22.0
@export var launch_height := 0.9
@export var base_damage := 10.0

@export_group("Time")
@export var charge_world_speed := 0.3
@export var slow_rate := 2.5
@export var restore_rate := 2.0

@export_group("Camera")
@export var charge_zoom := 0.6
@export var charge_sensitivity := 0.5
@export var charge_shoulder := 0.9
@export var flight_min_distance := 4.5
@export var flight_focus_height := 0.9

@export_group("Transformation")
@export var transform_in_time := 0.45
@export var transform_out_time := 0.55

@export_group("Trajectory")
@export var preview_steps := 150

var state := State.IDLE
var charge := 0.0
var level := 0.0
var locked_direction := Vector3.FORWARD
var locked_speed := 0.0
var locked_level := 0.0
var force_multiplier := 1.0
var damage := 10.0
var cooldown_left := 0.0
var relaunch_ready := false
var kills_this_flight := 0

var _player: CharacterBody3D
var _rig: Node3D
var _chargers: Array[Node] = []
var _timer := 0.0
var _world_speed := 1.0
var _owns_time := false
var _bounce_state_timer := 0.0
var _base_ticks := 60

@onready var ball: CharacterBody3D = $SpiritBall
@onready var trajectory: Node3D = $Trajectory
@onready var charge_light: OmniLight3D = $ChargeLight
@onready var fog: GPUParticles3D = $TransformFog
@onready var sparkle: GPUParticles3D = $TransformGlow
@onready var cooldown_label: Label3D = $CooldownLabel


func _ready() -> void:
	_player = get_parent()
	_rig = _player.get_node("CameraRig")
	_base_ticks = Engine.physics_ticks_per_second
	for node: Node in _player.find_children("*", "Node", true, false):
		if node.has_method("set_level"):
			_chargers.append(node)
	ball.exclude_body(_player)
	ball.bounced.connect(_on_ball_bounced)
	ball.finished.connect(_on_ball_finished)
	ball.enemy_hit.connect(_on_ball_enemy_hit)
	for system: GPUParticles3D in [fog, sparkle]:
		system.top_level = true
		system.one_shot = true
		system.emitting = false
	charge_light.light_energy = 0.0
	cooldown_label.visible = false


func _exit_tree() -> void:
	_apply_world_speed(1.0)


func is_active() -> bool:
	return state != State.IDLE


func is_ball() -> bool:
	return state == State.FLYING or state == State.BOUNCING or state == State.AIR_CHARGING


func is_vulnerable() -> bool:
	return state == State.IDLE or state == State.CHARGING or state == State.FULLY_CHARGED \
			or state == State.AIR_CHARGING


func is_charging() -> bool:
	return state == State.CHARGING or state == State.FULLY_CHARGED or state == State.AIR_CHARGING


func target_position() -> Vector3:
	if is_ball():
		return ball.global_position
	return _player.global_position + Vector3.UP * launch_height


func _set_state(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	_timer = 0.0
	state_changed.emit(previous, next)


func _real_delta(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.05)


func _apply_world_speed(value: float) -> void:
	Engine.time_scale = value
	Engine.physics_ticks_per_second = int(round(float(_base_ticks) / value))
	if _player:
		_player.time_compensation = 1.0 / value
	if _rig:
		_rig.time_compensation = 1.0 / value
	for charger: Node in _chargers:
		charger.set_time_compensation(1.0 / value)


func _process(delta: float) -> void:
	var real := _real_delta(delta)
	var slowed := is_charging() or state == State.TRANSFORM_IN
	var target := charge_world_speed if slowed else 1.0
	var rate := slow_rate if slowed else restore_rate
	if slowed:
		_owns_time = true
	if _owns_time:
		_world_speed = move_toward(_world_speed, target, rate * real)
		if not slowed and is_equal_approx(_world_speed, 1.0):
			_world_speed = 1.0
			_owns_time = false
		_apply_world_speed(_world_speed)
	var waiting := state == State.IDLE and cooldown_left > 0.0
	cooldown_label.visible = waiting
	if waiting:
		cooldown_label.text = "%.1f" % cooldown_left


func _physics_process(delta: float) -> void:
	var real := _real_delta(delta)
	cooldown_left = maxf(cooldown_left - real, 0.0)
	match state:
		State.IDLE:
			_tick_idle()
		State.CHARGING, State.FULLY_CHARGED:
			_tick_charging(real)
		State.TRANSFORM_IN:
			_tick_transform_in(real)
		State.FLYING, State.BOUNCING:
			_tick_flying(real)
		State.AIR_CHARGING:
			_tick_air_charging(real)
		State.TRANSFORM_OUT:
			_tick_transform_out(real)


func _tick_idle() -> void:
	if cooldown_left > 0.0 or _player.control_locked:
		return
	if Input.is_action_just_pressed(charge_action):
		_begin_charge()


func _begin_charge() -> void:
	charge = 0.0
	level = 0.0
	_player.aim_facing = true
	_focus_camera(true)
	charge_started.emit()
	_set_state(State.CHARGING)


func _focus_camera(enabled: bool) -> void:
	_rig.focus_zoom = charge_zoom
	_rig.focus_sensitivity = charge_sensitivity
	_rig.focus_shoulder = charge_shoulder
	_rig.focus_target = 1.0 if enabled else 0.0


func aim_direction() -> Vector3:
	return _rig.get_aim_direction(deg_to_rad(aim_loft_degrees))


func launch_origin() -> Vector3:
	return _player.global_position + Vector3.UP * launch_height


func launch_speed(for_level: float) -> float:
	return lerpf(min_launch_speed, max_launch_speed, for_level) * force_multiplier


func _accumulate(real: float, origin: Vector3) -> void:
	charge = minf(charge + real, max_charge_time)
	level = charge / max_charge_time
	for charger: Node in _chargers:
		charger.set_level(level, true)
	charge_light.light_energy = charge_light_energy * level * level
	var prediction: Dictionary = ball.predict(origin, aim_direction() * launch_speed(level), preview_steps)
	trajectory.show_path(prediction, level, real)


func _stop_charge_effects() -> void:
	trajectory.clear()
	for charger: Node in _chargers:
		charger.set_level(0.0, false)
	charge_light.light_energy = 0.0
	_player.aim_facing = false
	_focus_camera(false)
	charge_ended.emit()


func _tick_charging(real: float) -> void:
	_accumulate(real, launch_origin())
	if level >= 1.0 and state == State.CHARGING:
		_set_state(State.FULLY_CHARGED)
	if not Input.is_action_pressed(charge_action):
		_release()


func _release() -> void:
	_stop_charge_effects()
	if charge < min_charge_time:
		charge = 0.0
		level = 0.0
		cooldown_left = maxf(cooldown_left, 0.1)
		_set_state(State.IDLE)
		return
	locked_direction = aim_direction()
	locked_level = level
	locked_speed = launch_speed(level)
	charge = 0.0
	level = 0.0
	_begin_transform_in()


func _begin_transform_in() -> void:
	_player.control_locked = true
	_player.velocity = Vector3.ZERO
	kills_this_flight = 0
	relaunch_ready = false
	ball.damage = damage
	ball.prepare(launch_origin(), locked_level)
	_play_transform_effects(launch_origin())
	_set_state(State.TRANSFORM_IN)


func _play_transform_effects(point: Vector3) -> void:
	for system: GPUParticles3D in [fog, sparkle]:
		system.global_position = point
		system.restart()


func _ease(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _tick_transform_in(real: float) -> void:
	_timer += real
	var progress := _ease(_timer / transform_in_time)
	_player.visual_scale = 1.0 - progress
	_player.set_model_transparency(progress)
	ball.visual_scale = progress
	ball.global_position = launch_origin()
	if _timer >= transform_in_time:
		_launch()


func _launch() -> void:
	_player.set_model_visible(false)
	_player.set_body_enabled(false)
	ball.visual_scale = 1.0
	ball.launch(locked_direction * locked_speed)
	_rig.forced_distance_target = flight_min_distance
	_rig.height_target = flight_focus_height
	_set_state(State.FLYING)


func _follow_ball() -> void:
	_player.global_position = ball.global_position - Vector3.UP * ball.radius
	_player.velocity = Vector3.ZERO


func _tick_flying(real: float) -> void:
	_follow_ball()
	if state == State.BOUNCING:
		_bounce_state_timer -= real
		if _bounce_state_timer <= 0.0:
			_set_state(State.FLYING)
	if relaunch_ready and Input.is_action_just_pressed(charge_action):
		_begin_air_charge()


func _begin_air_charge() -> void:
	relaunch_ready = false
	charge = 0.0
	level = 0.0
	ball.hover()
	_focus_camera(true)
	charge_started.emit()
	_set_state(State.AIR_CHARGING)


func _tick_air_charging(real: float) -> void:
	_follow_ball()
	_accumulate(real, ball.global_position)
	if not Input.is_action_pressed(charge_action):
		_stop_charge_effects()
		var speed := launch_speed(level)
		ball.charge_level = level
		ball.relaunch(aim_direction() * speed)
		charge = 0.0
		level = 0.0
		_set_state(State.FLYING)


func _on_ball_bounced(_count: int, _point: Vector3, _normal: Vector3) -> void:
	ball_bounced.emit()
	if state == State.FLYING or state == State.BOUNCING:
		_bounce_state_timer = ball.squash_time
		_set_state(State.BOUNCING)


func _on_ball_enemy_hit(_enemy: Node, killed: bool) -> void:
	if killed:
		kills_this_flight += 1
		relaunch_ready = true
	ball_hit_enemy.emit(killed)


func _on_ball_finished() -> void:
	if state == State.FLYING or state == State.BOUNCING:
		_begin_transform_out()


func _begin_transform_out() -> void:
	_follow_ball()
	relaunch_ready = false
	var travel := Vector3(ball.velocity.x, 0.0, ball.velocity.z)
	if travel.length() > 0.2:
		_player.set_facing_direction(travel)
	_player.visual_scale = 0.0
	_player.set_model_transparency(1.0)
	_player.set_model_visible(true)
	_play_transform_effects(ball.global_position)
	_set_state(State.TRANSFORM_OUT)


func _tick_transform_out(real: float) -> void:
	_timer += real
	_follow_ball()
	var progress := _ease(_timer / transform_out_time)
	ball.visual_scale = 1.0 - progress
	_player.visual_scale = progress
	_player.set_model_transparency(1.0 - progress)
	if _timer >= transform_out_time:
		_finish()


func _restore_player() -> void:
	_player.visual_scale = 1.0
	_player.set_model_transparency(0.0)
	_player.set_model_visible(true)
	_player.set_body_enabled(true)
	_player.control_locked = false
	_player.aim_facing = false
	_rig.focus_target = 0.0
	_rig.forced_distance_target = 0.0
	_rig.height_target = -1.0


func _finish() -> void:
	ball.deactivate()
	_restore_player()
	cooldown_left = hit_cooldown if kills_this_flight > 0 else miss_cooldown
	_set_state(State.IDLE)


func cancel() -> void:
	if state == State.IDLE:
		return
	_stop_charge_effects()
	charge = 0.0
	level = 0.0
	relaunch_ready = false
	ball.deactivate()
	_restore_player()
	_world_speed = 1.0
	_owns_time = false
	_apply_world_speed(1.0)
	cooldown_left = hit_cooldown
	_set_state(State.IDLE)
