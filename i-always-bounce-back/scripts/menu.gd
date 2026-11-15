# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends Control

const MUSIC := "res://audio/music.mp3"


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var stream := load(MUSIC) as AudioStreamMP3
	if stream:
		stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -14.0
		add_child(player)
		player.play()


func _on_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_texture_button_2_pressed() -> void:
	get_tree().quit()


func _on_texture_button_3_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/credits.tscn")
