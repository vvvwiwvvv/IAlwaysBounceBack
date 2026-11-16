# ALL CODE WAS DOWNLOADED FROM GDQUEST
# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends CharacterBody3D

const HIPS := "mixamorig_Hips"
const HEAD_TOP := "mixamorig_HeadTop_End"
const CLIPS := {
	"idle": "res://player/idle.fbx",
	"run": "res://player/fast_run.fbx",
	"jump": "res://player/running_jump.fbx",
	"roll": "res://player/roll.fbx",
	"slash": "res://player/slash.fbx",
}

@export var target_height := 1.75
@export var boost := 1.15
@export var acceleration := 7.0
@export var friction := 3.5
@export var air_control := 2.0
@export var turn_speed := 12.0
@export var anim_smoothing := 8.0

var run_speed := 7.0
var gravity := 25.0
var jump_velocity := 7.0
var first_person := false
var control_locked := false
var aim_facing := false
var time_compensation := 1.0
var visual_scale := 1.0
var speed_multiplier := 1.0

var _model: Node3D
var _tree: AnimationTree
var _scale := 1.0
var _move_blend := 0.0
var _facing := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _jumping := false
var _jump_time := 0.0
var _rolling := false
var _roll_time := 0.0
var _roll_length := 1.0
var _roll_dir := Vector3.FORWARD
var _roll_times := PackedFloat32Array()
var _roll_z := PackedFloat32Array()

@onready var camera_rig: Node3D = $CameraRig
@onready var body_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_setup_input()
	_model = $Model
	var skel: Skeleton3D = _model.find_child("Skeleton3D", true, false)
	var head := skel.find_bone(HEAD_TOP)
	var rest_height := skel.get_bone_global_rest(head).origin.y if head >= 0 else 0.0104
	_scale = target_height / rest_height
	_model.scale = Vector3.ONE * _scale
	_build_animations()
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"roll": [KEY_CTRL],
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	var buttons := {
		"attack": MOUSE_BUTTON_LEFT,
		"charge": MOUSE_BUTTON_RIGHT,
	}
	for action: String in buttons:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var click := InputEventMouseButton.new()
		click.button_index = buttons[action]
		InputMap.action_add_event(action, click)


func _build_animations() -> void:
	var player: AnimationPlayer = _model.find_child("AnimationPlayer", true, false)
	var lib := player.get_animation_library(player.get_animation_library_list()[0])
	var jump_start := 0.0
	var jump_len := 0.9

	for clip: String in CLIPS:
		var scene: Node = (load(CLIPS[clip]) as PackedScene).instantiate()
		var src: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		var anim: Animation = src.get_animation(src.get_animation_list()[0]).duplicate(true)
		scene.free()

		var track := _hips_track(anim)
		var count := anim.track_get_key_count(track) if track >= 0 else 0
		var first: Vector3 = anim.track_get_key_value(track, 0) if count > 0 else Vector3.ZERO
		var last: Vector3 = anim.track_get_key_value(track, count - 1) if count > 0 else Vector3.ZERO

		match clip:
			"idle":
				anim.loop_mode = Animation.LOOP_LINEAR
			"run":
				anim.loop_mode = Animation.LOOP_LINEAR
				var dist := (last.z - first.z) * _scale
				if dist > 0.5:
					run_speed = dist / anim.length
			"jump":
				var peak := first.y
				for k in count:
					peak = maxf(peak, (anim.track_get_key_value(track, k) as Vector3).y)
				var threshold := first.y + (peak - first.y) * 0.12
				var takeoff := -1.0
				var landing := 0.0
				for k in count:
					var y := (anim.track_get_key_value(track, k) as Vector3).y
					if y > threshold:
						var t := anim.track_get_key_time(track, k)
						if takeoff < 0.0:
							takeoff = t
						landing = t
				var rise := (peak - first.y) * _scale
				var air := landing - takeoff
				if rise > 0.05 and air > 0.15:
					var height := rise * boost
					gravity = 8.0 * height / (air * air)
					jump_velocity = 4.0 * height / air
					jump_start = maxf(takeoff - 0.04, 0.0)
				jump_len = anim.length
				for k in count:
					var v: Vector3 = anim.track_get_key_value(track, k)
					anim.track_set_key_value(track, k, Vector3(v.x, minf(v.y, first.y), v.z))
			"roll":
				_roll_length = anim.length
				for k in count:
					_roll_times.append(anim.track_get_key_time(track, k))
					_roll_z.append(((anim.track_get_key_value(track, k) as Vector3).z - first.z) * _scale * boost)

		for k in count:
			var v: Vector3 = anim.track_get_key_value(track, k)
			anim.track_set_key_value(track, k, Vector3(first.x, v.y, first.z))
		lib.add_animation(clip, anim)

	var bt := AnimationNodeBlendTree.new()
	for clip: String in CLIPS:
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		if clip == "jump" and jump_start > 0.0:
			node.use_custom_timeline = true
			node.start_offset = jump_start
			node.timeline_length = jump_len - jump_start
			node.stretch_time_scale = false
		bt.add_node(clip, node)
	bt.add_node("run_scale", AnimationNodeTimeScale.new())
	bt.add_node("move", AnimationNodeBlend2.new())
	bt.add_node("jump_shot", _one_shot(0.12, 0.3))
	bt.add_node("roll_shot", _one_shot(0.1, 0.28))
	bt.add_node("slash_shot", _one_shot(0.15, 0.35))
	bt.connect_node("run_scale", 0, "run")
	bt.connect_node("move", 0, "idle")
	bt.connect_node("move", 1, "run_scale")
	bt.connect_node("jump_shot", 0, "move")
	bt.connect_node("jump_shot", 1, "jump")
	bt.connect_node("roll_shot", 0, "jump_shot")
	bt.connect_node("roll_shot", 1, "roll")
	bt.connect_node("slash_shot", 0, "roll_shot")
	bt.connect_node("slash_shot", 1, "slash")
	bt.connect_node("output", 0, "slash_shot")

	_tree = AnimationTree.new()
	_tree.tree_root = bt
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.active = true


func _one_shot(fade_in: float, fade_out: float) -> AnimationNodeOneShot:
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade_in
	shot.fadeout_time = fade_out
	var ease_curve := Curve.new()
	ease_curve.add_point(Vector2(0, 0), 0.0, 2.6)
	ease_curve.add_point(Vector2(1, 1), 0.0, 0.0)
	shot.fadein_curve = ease_curve
	shot.fadeout_curve = ease_curve
	return shot


func _hips_track(anim: Animation) -> int:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with(HIPS):
			return t
	return -1


func _roll_offset(t: float) -> float:
	var n := _roll_times.size()
	if n == 0:
		return 0.0
	if t <= _roll_times[0]:
		return _roll_z[0]
	for i in range(1, n):
		if t <= _roll_times[i]:
			var f := inverse_lerp(_roll_times[i - 1], _roll_times[i], t)
			return lerpf(_roll_z[i - 1], _roll_z[i], f)
	return _roll_z[n - 1]


func _shot_active(shot: String) -> bool:
	return _tree.get("parameters/%s/active" % shot)


func _fire(shot: String) -> void:
	_tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _fade_out(shot: String) -> void:
	_tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func _process(delta: float) -> void:
	_tree.advance(delta * time_compensation)


func _physics_process(tick: float) -> void:
	var delta := tick * time_compensation
	_apply_model_scale()
	if control_locked:
		velocity = Vector3.ZERO
		_rolling = false
		_jumping = false
		_update_animation(0.0, delta)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.yaw
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()

	var grounded := is_on_floor()
	_coyote = 0.12 if grounded else _coyote - delta
	_jump_buffer -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.15

	var slashing := _shot_active("slash_shot")
	if Input.is_action_just_pressed("attack") and grounded and not _rolling and not slashing \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_fire("slash_shot")
		slashing = true

	if Input.is_action_just_pressed("roll") and grounded and not _rolling:
		_rolling = true
		_roll_time = 0.0
		_roll_dir = wish.normalized() if wish.length() > 0.1 else Vector3(sin(_facing), 0.0, cos(_facing))
		_fade_out("slash_shot")
		_fire("roll_shot")

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _rolling:
		var step := _roll_offset(_roll_time + delta) - _roll_offset(_roll_time)
		horizontal = _roll_dir * (step / delta)
		_roll_time += delta
		if _roll_time >= _roll_length - 0.12:
			_rolling = false
	else:
		var target := Vector3.ZERO if slashing else wish * run_speed * speed_multiplier
		var rate := air_control
		if grounded:
			rate = acceleration if target.length() > 0.01 else friction
		horizontal = horizontal.lerp(target, 1.0 - exp(-rate * delta))

	if _jump_buffer > 0.0 and _coyote > 0.0 and not _rolling:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_jumping = true
		_jump_time = 0.0
		_fade_out("slash_shot")
		_fire("jump_shot")
	elif not grounded:
		velocity.y -= gravity * delta
	if _jumping:
		_jump_time += delta
		if grounded and _jump_time > 0.15:
			_jumping = false
			_fade_out("jump_shot")

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity *= time_compensation
	move_and_slide()
	velocity /= time_compensation

	_update_facing(Vector3(velocity.x, 0.0, velocity.z), yaw, delta)
	_update_animation(Vector3(velocity.x, 0.0, velocity.z).length(), delta)


func _update_facing(horizontal: Vector3, yaw: float, delta: float) -> void:
	var blend := 1.0 - exp(-turn_speed * delta)
	if first_person:
		_facing = lerp_angle(_facing, yaw + PI, minf(blend * 2.0, 1.0))
	elif aim_facing:
		_facing = lerp_angle(_facing, yaw + PI, blend)
	elif _rolling:
		_facing = lerp_angle(_facing, atan2(_roll_dir.x, _roll_dir.z), blend)
	elif horizontal.length() > 0.4:
		_facing = lerp_angle(_facing, atan2(horizontal.x, horizontal.z), blend)
	_model.rotation.y = _facing


func _update_animation(speed: float, delta: float) -> void:
	var ratio := clampf(speed / (run_speed * speed_multiplier), 0.0, 1.0)
	_move_blend = lerpf(_move_blend, ratio, 1.0 - exp(-anim_smoothing * delta))
	_tree.set("parameters/move/blend_amount", _move_blend)
	_tree.set("parameters/run_scale/scale", lerpf(0.55, 1.0, _move_blend) * sqrt(speed_multiplier))


func _apply_model_scale() -> void:
	_model.scale = Vector3.ONE * _scale * maxf(visual_scale, 0.001)


func set_first_person(enabled: bool) -> void:
	if enabled == first_person:
		return
	first_person = enabled
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = mode


func set_model_transparency(amount: float) -> void:
	var value := clampf(amount, 0.0, 1.0)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.transparency = value


func set_model_visible(shown: bool) -> void:
	_model.visible = shown


func set_body_enabled(enabled: bool) -> void:
	body_shape.set_deferred("disabled", not enabled)


func set_facing_direction(direction: Vector3) -> void:
	_facing = atan2(direction.x, direction.z)
	_model.rotation.y = _facing


func cancel_ability() -> void:
	var ability := get_node_or_null("SpiritAbility")
	if ability and ability.has_method("cancel"):
		ability.cancel()
