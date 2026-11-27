extends Node
class_name upgradebox

@export_enum("Health", "Speed", "Damage", "Style") var sell := 0

var price := 0
@onready var game = $"../../../.."

@onready var name_label = $Name
@onready var level_label = $Level
@onready var button = $Button

const s2 = preload("res://audio/confirm.ogg")
const s3 = preload("res://audio/hover.ogg")
const s4 = preload("res://audio/coin.mp3")
func refresh() -> void:
	if game == null:
		return
	var titles := ["HEALTH", "SPEED", "ATTACK", "STYLE"]
	price = game.upgrade_cost(sell)
	name_label.text = titles[sell]
	level_label.text = "LV %d\n%s" % [int(game.levels[sell]), game.stat_text(sell)]
	if game.points >= price:
		button.modulate = Color(1, 1, 1, 1) 
		button.disabled = false
	else:
		button.disabled = true
		button.modulate = Color(1, 1, 1, 0.45)


func _on_button_pressed() -> void:
	game.try_upgrade(sell)
	$"../../..".sound(s2)
	$"../../..".sound(s4)
	


func _on_button_mouse_entered() -> void:
	$"../../..".sound(s3)
