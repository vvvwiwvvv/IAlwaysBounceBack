extends CanvasLayer

@onready var _game = $".."
@onready var points_label = $Root/Points
@onready var panels = $Root/Panels
@onready var item_manager = $"../../Player/ItemManage"

var items = Items.items
var rares = []
var legs = []
var commons = []

func _ready() -> void:
	visible = false
	_game.chest_toggled.connect(_on_chest_toggled)


func _on_chest_toggled(open: bool, rarity:int) -> void:
	var y=Items.get_items(rarity)
	y.shuffle() 
	visible = open
	var x = panels.get_children()
	if open:
		for i in 3:
			x[i].id = y[i]["id"]
			x[i].name_label.text=y[i]["name"]
			x[i].desc_label.text = y[i]["desc"]
			match y[i]["rarity"]:
				2:
					x[i].rarity_label.text = "LEGENDARY"
				1:
					x[i].rarity_label.text = "RARE"
				0:
					x[i].rarity_label.text = "COMMON"
			x[i].icon.texture = load(y[i]["icon"])
			
			
		x.shuffle()
		for i in x:
			i.visible = true
			i.play()
			await get_tree().create_timer(0.2).timeout
			sound(s1)
	else:
		for i in x:
			i.visible = false
			i.stop()
		
const s1 = preload("res://audio/thud.mp3")

func sound(stream: AudioStream) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = randf_range(0.8, 1.2)
	add_child(player)
	player.finished.connect(player.queue_free) 
	player.play()
	
