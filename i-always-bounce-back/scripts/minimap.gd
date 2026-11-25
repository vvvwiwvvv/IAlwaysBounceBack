extends Control

@export var dot: Texture2D
@export var boss_dot: Texture2D
@onready var player : CharacterBody3D = $"../../../Player"
@onready var rig = $"../../../Player/CameraRig"

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c = size*0.5
	var r = c.x
	draw_circle(c, r, Color("080a14b8"))
	for e in get_tree().get_nodes_in_group("enemies"):
		var p = c+Vector2(e.global_position.x - player.global_position.x, e.global_position.z - player.global_position.z).rotated(rig.yaw)*r/30
		if (p-c).length() > r:
			p = c+(p-c).normalized()*r
		draw_texture(dot, p - dot.get_size() * 0.5)
	draw_circle(c, 1.0, Color("7777ff"))
