extends Node
class_name upgradebox

@export_enum("Health", "Speed", "Damage", "Cooldown") var sell := 0

var price := 0
var game: Node

@onready var name_label: Label = $Name
@onready var level_label: Label = $Level
@onready var button: TextureButton = $Button


func setup(owner_game: Node) -> void:
	game = owner_game


func refresh() -> void:
	if game == null:
		return
	var titles := ["HEALTH", "SPEED", "ATTACK", "CHARGE COOLDOWN"]
	price = game.upgrade_cost(sell)
	name_label.text = titles[sell]
	level_label.text = "LV %d   %s" % [int(game.levels[sell]), game.stat_text(sell)]
	var affordable: bool = game.points >= price
	button.disabled = not affordable
	button.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 1, 1, 0.45)


func _on_button_pressed() -> void:
	if game:
		game.try_upgrade(sell)
