extends Node

@onready var player: CharacterBody3D = $".."
@onready var ability: Node = $"../SpiritAbility"
@onready var ball: CharacterBody3D=$"../SpiritAbility/SpiritBall"
@onready var game = $"../../Game"

var items  = []
var stats = {}


func _ready() -> void:
	pass

func add_item(item: Dictionary) -> void:
	items.append(item)
	apply_effects(item)
	accumulate_stat(item)
	game._apply_stats()
	
#stats: health, damage, damage_mult, speed_mult, bounces, cooldown_mult, 
#draw_mult, gravity_mult, restitution_mult, extra_dash, combo_mult, charge_power_mult, style_mult



func accumulate_stat(item: Dictionary) -> void:
	for stat in ["speed", "damage", "health", "bounces", "extra_dash", "parry_kb"]:
		if item.has(stat):
			stats[stat] = stats.get(stat,0)+item[stat]
	for stat in ["damage_mult", "cooldown_mult","draw_mult","gravity_mult","restitution_mult","combo_mult","style_mult"]:
		if item.has(stat):
			stats[stat] = stats.get(stat,1)*item[stat]
			print(stats) 
	

func apply_effects(item: Dictionary) -> void:
	if item.has("effect"):
		match item.effect:
			"glass": #fix shop
				game.max_health = 50
				game.health = 50
				game.health_per_level = 10
				game.levels[2]=0
				game.health_changed.emit(game.health, game.max_health)
			"heal_on_hit":
				ball.enemy_hit.connect(_heal.bind(item.effect_value))
				

#effect functions
func _heal(e:Node,k:bool,amount:float)->void:
	game.heal_player(amount)
		
