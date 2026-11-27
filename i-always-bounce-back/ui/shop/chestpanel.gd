extends Node

var id
var rarity
var texpath
@onready var item_manager = $"../../../../../Player/ItemManage"
@onready var name_label= $Name
@onready var desc_label= $Desc
@onready var rarity_label = $Rarity
@onready var button = $Button
@onready var icon = $Icon
@onready var game = $"../../../.."
const s2 = preload("res://audio/confirm_evil.ogg")
const s3 = preload("res://audio/hover_evil.ogg")


func _on_button_pressed() -> void:
	for i in Items.items:
		if i["id"] == id:
			item_manager.add_item(i)
			break
	game.set_chest_open(false,0)
	$"../../..".sound(s2)
	
func _on_button_mouse_entered() -> void:
	$"../../..".sound(s3)
