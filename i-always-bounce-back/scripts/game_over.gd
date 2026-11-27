extends CanvasLayer

@onready var game = $".."
var rot = TAU/60
var on = true
var to_reset = 60
var ticks = 0
func _on_startagain_pressed() -> void:
	create_tween().tween_property($AudioStreamPlayer, "volume_db", -80.0, 2.0)
	await create_tween().tween_property($Dim,"modulate:a",1.0, 2.0).finished
	game._restart()


func _on_giveup_pressed() -> void:
	create_tween().tween_property($AudioStreamPlayer, "volume_db", -80.0, 2.0)
	await create_tween().tween_property($Dim,"modulate:a",1.0, 2.0).finished
	game._return_to_menu()


func _on_timer_timeout() -> void:
	if on:
		$AudioStreamPlayer.stream = load("res://audio/tick_on.mp3")
	else:
		$AudioStreamPlayer.stream = load("res://audio/tick_off.mp3")
	on=not on
	$AudioStreamPlayer.play()
	$Root/hand.rotation += rot
	ticks+=1
	if ticks == to_reset:
		$AudioStreamPlayer.stream = load("res://audio/tick_done.mp3")
		$Root/hand2.rotation += rot
		rot = 0
		$AudioStreamPlayer.play()
		create_tween().tween_property($AudioStreamPlayer, "volume_db", -80.0, 2.0)
		await create_tween().tween_property($Dim,"modulate:a",1.0, 2.0).finished
		game._return_to_menu()
