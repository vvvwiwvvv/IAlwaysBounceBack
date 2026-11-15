# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends Control

@export var menu_scene := "res://scenes/menu.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hint := Label.new()
	hint.text = "Click or press any key to go back"
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
	hint.position = Vector2(400, 560)
	add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed
	var click: bool = event is InputEventMouseButton and event.pressed
	if key or click:
		get_tree().change_scene_to_file(menu_scene)
