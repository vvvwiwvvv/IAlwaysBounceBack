extends CanvasLayer

var _game: Node

@onready var points_label: Label = $Root/Points
@onready var panels: Control = $Root/Panels

const s1 = preload("res://audio/thud.mp3")

func sound(stream: AudioStream) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = randf_range(0.8, 1.2)
	add_child(player)
	player.finished.connect(player.queue_free) 
	player.play()
	
func _ready() -> void:
	_game = get_parent()
	visible = false
	_game.shop_toggled.connect(_on_shop_toggled)
	_game.points_changed.connect(_on_points_changed)
	_game.stats_changed.connect(refresh)
	for panel: Node in panels.get_children():
		panel.setup(_game)


func _on_shop_toggled(open: bool) -> void:
	visible = open
	var x = panels.get_children()
	if open:
		x.shuffle()
		for i in x:
			i.visible = true
			i.play()
			await get_tree().create_timer(0.12).timeout
			sound(s1)
			await get_tree().create_timer(0.08).timeout

		refresh()
	else:
		for i in x:
			i.visible = false
			i.stop()
		


func _on_points_changed(_total: int) -> void:
	if visible:
		refresh()


func refresh() -> void:
	points_label.text = "POINTS  %d" % int(_game.points)
	for panel: Node in panels.get_children():
		panel.refresh()
