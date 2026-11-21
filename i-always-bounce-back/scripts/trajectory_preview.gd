
extends Node3D

@export var dot_mesh: Mesh
@export var ring_mesh: Mesh
@export var max_dots := 96
@export var max_rings := 14
@export var dot_step := 1
@export var ring_step := 7
@export var dot_size := 0.26
@export var ring_size := 0.8
@export var flow_speed := 7.0
@export var impact_size := 1.5

var _dots: MultiMesh
var _rings: MultiMesh
var _time := 0.0

@onready var dots_instance: MultiMeshInstance3D = $Dots
@onready var rings_instance: MultiMeshInstance3D = $Rings
@onready var impact: MeshInstance3D = $Impact


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_dots = _build(dot_mesh, max_dots)
	_rings = _build(ring_mesh, max_rings)
	dots_instance.multimesh = _dots
	rings_instance.multimesh = _rings
	dots_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rings_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clear()


func _build(mesh: Mesh, count: int) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.visible_instance_count = 0
	multimesh.custom_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	return multimesh


func clear() -> void:
	visible = false
	if _dots:
		_dots.visible_instance_count = 0
	if _rings:
		_rings.visible_instance_count = 0


func _sample(points: PackedVector3Array, index: float) -> Vector3:
	var last := points.size() - 1
	var base := clampi(int(floor(index)), 0, last)
	var next := mini(base + 1, last)
	return points[base].lerp(points[next], clampf(index - float(base), 0.0, 1.0))


func show_path(prediction: Dictionary, level: float, delta: float) -> void:
	var points: PackedVector3Array = prediction["points"]
	var directions: PackedVector3Array = prediction["directions"]
	var count := points.size()
	if count < 2:
		clear()
		return
	visible = true
	global_transform = Transform3D.IDENTITY
	_time += delta
	var strength := lerpf(0.45, 1.0, level)

	var used := 0
	var index := dot_step
	while index < count and used < max_dots:
		var fraction := float(index) / float(count)
		var size := dot_size * lerpf(1.0, 0.55, fraction) * lerpf(0.8, 1.25, level)
		_dots.set_instance_transform(used, Transform3D(Basis.from_scale(Vector3.ONE * size), points[index]))
		_dots.set_instance_color(used, Color(1, 1, 1, strength * lerpf(1.0, 0.35, fraction)))
		used += 1
		index += dot_step
	_dots.visible_instance_count = used

	used = 0
	var offset := fmod(_time * flow_speed, float(ring_step))
	var cursor := offset + 3.0
	while cursor < float(count - 1) and used < max_rings:
		var point := _sample(points, cursor)
		var direction := directions[clampi(int(cursor), 0, count - 1)]
		var fraction := cursor / float(count)
		var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		var basis_now := Basis.looking_at(direction, up).scaled(Vector3.ONE * ring_size * lerpf(0.8, 1.3, level))
		_rings.set_instance_transform(used, Transform3D(basis_now, point))
		_rings.set_instance_color(used, Color(1, 1, 1, strength * lerpf(0.9, 0.25, fraction)))
		used += 1
		cursor += float(ring_step)
	_rings.visible_instance_count = used

	if prediction["hit"]:
		var normal: Vector3 = prediction["hit_normal"]
		var side := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		var pulse := 1.0 + sin(_time * 6.0) * 0.08
		var marker_basis := Basis.looking_at(-normal, side).scaled(Vector3.ONE * impact_size * lerpf(0.75, 1.2, level) * pulse)
		var hit_point: Vector3 = prediction["hit_point"]
		impact.global_transform = Transform3D(marker_basis, hit_point + normal * 0.05)
		impact.visible = true
	else:
		impact.visible = false
