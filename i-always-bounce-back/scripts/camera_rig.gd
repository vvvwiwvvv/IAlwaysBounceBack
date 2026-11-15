extends Node3D
## Hybrid camera: scroll the wheel to zoom smoothly between first person
## (fully zoomed in) and an orbiting third person view.

@export var mouse_sensitivity := 0.0025
@export var min_distance := 1.4
@export var max_distance := 9.0
@export var start_distance := 5.0
@export var zoom_step := 0.14
@export var zoom_smoothing := 9.0
@export var follow_smoothing := 16.0
@export var head_height := 1.55

var yaw := 0.0
var pitch := -0.25

var _target_distance := 5.0
var _distance := 5.0
var _pivot := Vector3.ZERO
var _player: CharacterBody3D
var _camera: Camera3D


func _ready() -> void:
	_player = get_parent()
	top_level = true
	_target_distance = start_distance
	_distance = start_distance
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.near = 0.08
	_camera.far = 3000.0
	add_child(_camera)
	_camera.make_current()
	_pivot = _player.global_position + Vector3.UP * head_height
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = wrapf(yaw - event.relative.x * mouse_sensitivity, -PI, PI)
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.45, 1.35)
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
		# Zooming in past the closest third person distance drops to first person.
		if _target_distance <= min_distance + 0.01:
			_target_distance = 0.0
		else:
			_target_distance = maxf(_target_distance * (1.0 - zoom_step), min_distance)
	elif _target_distance < min_distance:
		_target_distance = min_distance
	else:
		_target_distance = minf(_target_distance * (1.0 + zoom_step), max_distance)


func _physics_process(delta: float) -> void:
	_distance = lerpf(_distance, _target_distance, 1.0 - exp(-zoom_smoothing * delta))
	var is_first_person := _distance < 0.45
	_player.set_first_person(is_first_person)

	var head := _player.global_position + Vector3.UP * head_height
	if is_first_person:
		_pivot = head
	else:
		_pivot = _pivot.lerp(head, 1.0 - exp(-follow_smoothing * delta))

	var look := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var back := look * Vector3.BACK
	var distance := _distance
	if distance > 0.05:
		# Pull the camera in when terrain or a tree is between it and the player.
		var query := PhysicsRayQueryParameters3D.create(_pivot, _pivot + back * (distance + 0.3))
		query.exclude = [_player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			distance = clampf(_pivot.distance_to(hit.position) - 0.3, 0.0, distance)
	global_transform = Transform3D(look, _pivot + back * distance)
