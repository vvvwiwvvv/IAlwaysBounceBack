extends Control

const MUSIC := "res://audio/forest2.mp3"
@onready var rect: ColorRect = $ColorRect
@onready var rect2: ColorRect = $ColorRect2
@onready var hover: AnimatedSprite2D = $hoverBtn
@onready var start: TextureButton = $startBtn
@onready var credits: TextureButton = $creditsBtn
@onready var quit: TextureButton = $quitBtn
@onready var p1 = start.position
@onready var p2 = credits.position
@onready var p3 = quit.position
@onready var creditplayer = $creditsAnim
@onready var titleplayer = $titleAnim
@onready var help = $credithelper
@onready var icon = $icon
var incredits = 0

func _ready() -> void:
	
	rect.color = Color(0, 0, 0, 1) 
	rect2.color = Color(0, 0, 0, 1) 
	
	fade(rect,0.0,0.5)
	fade(rect2,0.0,0.5)
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


func glide_to(obj,target: Vector2, duration: float = 1.0) -> void:
	var t=create_tween()
	var pos = obj.position + target
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(obj, "position", pos, duration)
	
func glide_hover(obj,target: Vector2, duration: float = 1.0) -> void:
	var t=create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(obj, "position", target, duration)
	
var t2: Tween
func btn_hover(btn: TextureButton, target: Vector2, duration: float = 1.0) -> void:
	if incredits == 1 or incredits == 2:
		return
	if target.x < 0:
		sound(s1)
	var pos
	if btn == start:
		pos = p1 + target
	if btn == quit:
		pos = p3 + target
	if btn == credits:
		pos = p2 + target
	t2 = create_tween()
	t2.set_trans(Tween.TRANS_SINE)
	t2.set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(btn, "position", pos, duration)

const s1 = preload("res://audio/hover.ogg")
const s2 = preload("res://audio/confirm.ogg")
const s3 = preload("res://audio/crack.mp3")

func sound(stream: AudioStream) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = randf_range(0.8, 1.2)
	add_child(player)
	player.finished.connect(player.queue_free) 
	player.play()
	

func fade(r: ColorRect, val:float = 1,duration: float = 1.0) -> void:
	await create_tween().tween_property(r, "modulate:a", val, duration).finished
	
func _on_texture_button_pressed() -> void: #start
	sound(s2)
	glide_hover($icon, Vector2(415,160), 0.5)
	await fade(rect,1,0.75)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_texture_button_2_pressed() -> void: #quit
	sound(s2)
	glide_hover($icon, Vector2(415,160), 0.5)
	await fade(rect,1,0.75)
	await fade(rect2,1,0.75)
	get_tree().quit()

@onready var moveables: Array[Node]= [$startBtn,$quitBtn,$creditsBtn,$icon,$title,$hoverBtn]
func _on_texture_button_3_pressed() -> void: #credits
	sound(s2)
	creditplayer.play("move")
	titleplayer.pause()
	credits.release_focus()
	create_tween().tween_property($vignette.material, "shader_parameter/opa", 0.0, 1.0)
	glide_to(help, Vector2(0,-30),0.1)
	incredits = 1
	for child in get_children():
		if child in moveables:
			glide_to(child, Vector2(-1500,0),0.75)
	await get_tree().create_timer(1.0).timeout
	incredits = 2

	
	

func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed
	var click: bool = event is InputEventMouseButton and event.pressed
	if (key or click) and incredits == 2:
		create_tween().tween_property($vignette.material, "shader_parameter/opa", 1.0, 1.0) #tween vignette parameters
		sound(s2)
		incredits = 0
		creditplayer.stop()
		glide_to(help, Vector2(0,30),0.1)
		for child in get_children():
			if child in moveables:
				glide_to(child, Vector2(1500,0),0.75)
		await get_tree().create_timer(1.0).timeout
		titleplayer.play()


func _on_start_btn_mouse_entered() -> void:
	btn_hover(start,Vector2(-10, -10), 0.2)
	glide_hover(hover, Vector2(397, 319), 0.2)


func _on_quit_btn_mouse_entered() -> void:
	btn_hover(quit,Vector2(-10, -10), 0.2)
	glide_hover(hover, Vector2(252, 575), 0.2)

func _on_credits_btn_mouse_entered() -> void:
	btn_hover(credits,Vector2(-10, -10), 0.2)
	glide_hover(hover, Vector2(330, 460), 0.2)


func _on_start_btn_mouse_exited() -> void:
	btn_hover(start,Vector2(0, 0), 0.2)


func _on_quit_btn_mouse_exited() -> void:
	btn_hover(quit,Vector2(0, 0), 0.2)


func _on_credits_btn_mouse_exited() -> void:
	btn_hover(credits,Vector2(0, 0), 0.2)


@onready var pos = icon.position
func _on_icon_pressed() -> void:
	sound(s3)
	$GPUParticles2D.emitting = true
	for i in 5:
		glide_to(icon, Vector2((randf()*30)-15,(randf()*30)-15),0.05)
		await get_tree().create_timer(0.05).timeout
	icon.position = pos
	$GPUParticles2D.emitting = false
	
	
