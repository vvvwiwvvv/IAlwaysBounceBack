# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends Node3D

@export var mouse_sensitivity := 0.0025
@export var min_distance := 1.4
@export var max_distance := 9.0
@export var start_distance := 5.0
@export var zoom_step := 0.14
@export var zoom_smoothing := 9.0
@export var follow_smoothing := 16.0
@export var head_height := 1.55
@export var focus_smoothing := 5.0

var yaw := 0.0
var pitch := -0.25
var time_compensation := 1.0
var focus_target := 0.0
var focus_zoom := 0.72
var focus_sensitivity := 0.5
var focus_shoulder := 0.9
var forced_distance_target := 0.0
var height_target := -1.0

var _target_distance := 5.0
var _distance := 5.0
var _pivot := Vector3.ZERO
var _focus := 0.0
var _forced_distance := 0.0
var _height := 1.55
var _player: CharacterBody3D
var _camera: Camera3D


func _ready() -> void:
	_player = get_parent()
	top_level = true
	_target_distance = start_distance
	_distance = start_distance
	_height = head_height
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.near = 0.08
	_camera.far = 3000.0
	add_child(_camera)
	_camera.make_current()
	_pivot = _player.global_position + Vector3.UP * head_height
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func current_sensitivity() -> float:
	return mouse_sensitivity * lerpf(1.0, focus_sensitivity, _focus)


func get_aim_direction(loft: float) -> Vector3:
	var aim_pitch := clampf(pitch + loft, -1.45, 1.45)
	return (Basis.from_euler(Vector3(aim_pitch, yaw, 0.0)) * Vector3.FORWARD).normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := current_sensitivity()
		yaw = wrapf(yaw - event.relative.x * sensitivity, -PI, PI)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.45, 1.35)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _zoom(direction: float) -> void:
	if direction < 0.0:
		if _target_distance <= min_distance + 0.01:
			_target_distance = 0.0
		else:
			_target_distance = maxf(_target_distance * (1.0 - zoom_step), min_distance)
	elif _target_distance < min_distance:
		_target_distance = min_distance
	else:
		_target_distance = minf(_target_distance * (1.0 + zoom_step), max_distance)


func _physics_process(tick: float) -> void:
	var delta := tick * time_compensation
	_distance = lerpf(_distance, _target_distance, 1.0 - exp(-zoom_smoothing * delta))
	_focus = lerpf(_focus, focus_target, 1.0 - exp(-focus_smoothing * delta))
	_forced_distance = lerpf(_forced_distance, forced_distance_target, 1.0 - exp(-focus_smoothing * delta))
	var wanted_height := head_height if height_target < 0.0 else height_target
	_height = lerpf(_height, wanted_height, 1.0 - exp(-focus_smoothing * delta))

	var is_first_person := _distance < 0.45 and _forced_distance < 0.3
	_player.set_first_person(is_first_person)

	var head := _player.global_position + Vector3.UP * _height
	if is_first_person:
		_pivot = head
	else:
		_pivot = _pivot.lerp(head, 1.0 - exp(-follow_smoothing * delta))

	var look := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var back := look * Vector3.BACK
	var distance := _distance
	var origin := _pivot
	if not is_first_person:
		distance *= lerpf(1.0, focus_zoom, _focus)
		origin += look * Vector3.RIGHT * focus_shoulder * _focus
	distance = maxf(distance, _forced_distance)
	if distance > 0.05:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + back * (distance + 0.3))
		query.exclude = [_player.get_rid()]
		query.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			distance = clampf(origin.distance_to(hit.position) - 0.3, 0.0, distance)
	global_transform = Transform3D(look, origin + back * distance)
