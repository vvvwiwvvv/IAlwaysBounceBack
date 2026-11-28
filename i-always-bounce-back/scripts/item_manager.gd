extends Node

@onready var player: CharacterBody3D = $".."
@onready var ability: Node = $"../SpiritAbility"
@onready var ball: CharacterBody3D=$"../SpiritAbility/SpiritBall"
@onready var game = $"../../Game"

var items  = []
var stats = {}
var effects = {}

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
	
							   
func apply_effects(item: Dictionary) -> void: #holy mess
	if item.has("effect"):
		if not effects.has(item.effect): #see if first pickup
			effects[item.effect]={"count":0,"value":0.0} #add to effestcs list
			if item.effect in repeated_effects:
				repeated(item)   #hook repeated ones to whatever
		effects[item.effect].count+=1
		effects[item.effect].value+=item.get("effect_value",0.0) # add values and ocunt (using get so no crash)
		one_off(item)  #should be okay to do aslong as its not in both functions (applies oneoff functions)
		
				
func one_off(item:Dictionary): #one off can stay unstacked so remmeber not do do funky things for one offs
		match item.effect:
			"glass": 
				game.max_health = 50
				game.health = 50
				game.glassed = true
				game.health_changed.emit(game.health, game.max_health)
				
				
				
#effects, ,chain_bolt,explode_bounce,auto_bounce,trail_damage,overcharge,fire_debuff,ice_debuff,hea_on_hit
#one offs: shureikens,shield,glass cannon

var repeated_effects = ["chain_bolt","explode_bounce","auto_bounce","trail_damage",
"overcharge","fire_debuff","ice_debuff","heal_on_hit"]

func repeated(item:Dictionary): #just binds functions bcus persistent should stack effect value
		match item.effect:
			"heal_on_hit":
				ball.enemy_hit.connect(_heal)
			"explode_bounce":
				ball.bounced.connect(_explode)
				ball.enemy_hit.connect(_explode2)
			"chain_bolt":
				ball.enemy_hit.connect(_chain_bolt)
			"fire_debuff":
				ball.enemy_hit.connect(_fire_debuff)
			"ice_debuff":
				ball.enemy_hit.connect(_ice_debuff)
			"speed_hit":
				ball.enemy_hit.connect(_speed_hit)

const _explosion = preload("res://scenes/explosion.tscn")
const _fire = preload("res://scenes/fire_debuff.tscn")
#effect functions remember to match parameters and use unused names (xyzabc) AND USE _ BECAUSE DEBUGGER WONT STFU
# todo effects, ,chain_bolt,auto_bounce,trail_damage,overcharge,"speed_hit"
#one offs: shureikens,shield,glass cannon

func _chain_bolt(_x,_y,_z):
	pass #tfdo ido now
func _speed_hit(enemy,_y):
	pass
func _ice_debuff(enemy,_y):
	if enemy:
		enemy.move_speed *= effects["ice_debuff"].value
		enemy.frost = true
		await get_tree().create_timer(effects["ice_debuff"].count*10).timeout #stacks x 10 is duration
		if enemy:
			enemy.frost = false
			enemy.move_speed /= effects["ice_debuff"].value
	
func _fire_debuff(enemy,_y):
	if enemy.has_method("take_hit"):
			var amount =  int(effects["fire_debuff"].count)
			var dmg =  int(effects["fire_debuff"].value)
			var fire = _fire.instantiate()
			enemy.add_child(fire)
			fire.global_position = enemy.global_position
			for i in amount*10:
				if enemy==null or enemy.dead:
					return
				await get_tree().create_timer(1/amount).timeout
				enemy.take_hit(dmg,Vector3(0,0,0),0)
			if enemy:
				fire.queue_free()


func _heal(_x,_y):
	game.heal_player(effects["heal_on_hit"].value) #stackable

func _explode(_x,_y,_z):
	game.sound(game.sfx_explode)
	var radius = effects["explode_bounce"].value
	var explosion = _explosion.instantiate()
	player.add_child(explosion)
	explosion.scale = Vector3(radius,radius,radius)
	explosion.global_position = player.global_position
	explosion.start()
func _explode2(_x,_z):
	game.sound(game.sfx_explode)
	var radius = effects["explode_bounce"].value
	var explosion = _explosion.instantiate() #create new explosion and add to player (idt nessesary but eh)
	player.add_child(explosion)
	explosion.scale = Vector3(radius,radius,radius)*2
	explosion.global_position = player.global_position
	explosion.start()
