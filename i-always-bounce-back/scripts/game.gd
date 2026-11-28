extends Node

signal style_popup(text:String)
signal style_changed
signal health_changed(current: float, maximum: float)
signal wave_changed(number: int)
signal enemies_changed(remaining: int)
signal points_changed(total: int)
signal kills_changed(total: int)
signal stats_changed
signal intermission_changed(seconds_left: float, active: bool)
signal player_hurt
signal shop_toggled(open: bool)
signal inventory_toggled(open: bool)
signal chest_toggled(open: bool, rarity: int)
signal game_over_started

var run_time := 0.0
var style = 0
enum Stat {HEALTH, SPEED, DAMAGE, STYLE }

@export_group("enemies")
@export var slime_scene: PackedScene
@export var goblin_scene: PackedScene
@export var bat_scene: PackedScene
@export var spawn_interval := 0.7
@export var spawn_radius_min := 16.0
@export var spawn_radius_max := 26.0
@export var arena_limit := 62.0

@export_group("waves")
@export var first_wave_delay := 3.0
@export var intermission_time := 10.0
@export var base_enemy_count := 4
@export var enemies_per_wave := 3

@export_group("player")
@export var style_per_enemy = 5
@export var base_base_style_mult = 0.1 #whatever man
@export var base_style_mult = 0.1
@export var base_max_health := 100.0
@export var base_speed_multiplier := 1.5
@export var speed_per_level := 0.15
@export var base_damage := 10.0
@export var damage_per_level := 6.0
@export var style_mult_per_level := 0.1
@export var health_per_level := 50
@export var upgrade_cost_step := 4

#base stats for apply stats
var _ball_base_bounces 
var _ball_base_flight  
var _ball_base_restitution  
var _ball_base_gravity  
var _ball_base_enemy_restitution  

var _ability_miss_cooldown 
var _ability_hit_cooldown 
var _ability_min_launch_speed 
var _ability_max_launch_speed 
var _ability_min_charge_time 
var _ability_max_charge_time 
var _ability_max_dashes 

@export var base_max_dashes = 1
var max_dashes = base_max_dashes
var parry_kb = 0

@export_group("Flow")
@export var menu_scene := "res://scenes/menu.tscn"
@export var fade_time := 1.4


var parry_damage = 1
var style_per_parry = 10
var style_mult = 0.0

var max_health = base_max_health
var health := 100.0
var wave := 0
var points := 09999999999
var kills := 0
var levels := {Stat.HEALTH: 1, Stat.SPEED: 1, Stat.DAMAGE: 1, Stat.STYLE: 1}
var alive := 0
var over := false
var shop_open := false
var inventory_open:= false
var chest_open := false 
var in_intermission := false
var glassed = false

var _queue: Array[int] = []
var _spawn_timer := 0.0
var _intermission_left := 0.0
var _player: CharacterBody3D
var _ability: Node
var _ball: CharacterBody3D
var _world: Node3D

@onready var music: AudioStreamPlayer = $Music
@onready var sfx_charge: AudioStreamPlayer = $SfxCharge
@onready var sfx_land: AudioStreamPlayer = $SfxLand
@onready var sfx_damage: AudioStreamPlayer = $SfxDamage
@onready var sfx_goblin_attack: AudioStreamPlayer = $SfxGoblinAttack
@onready var sfx_goblin_death: AudioStreamPlayer = $SfxGoblinDeath
@onready var sfx_bat_death: AudioStreamPlayer = $SfxBatDeath
@onready var sfx_slime_death: AudioStreamPlayer = $SfxSlimeDeath
@onready var sfx_parry: AudioStreamPlayer = $SfxParry

@onready var sfx_bounce = preload("res://audio/bounce.mp3")
@onready var sfx_explode = preload("res://audio/explode.mp3")

func sound(stream: AudioStream) -> void: #random pitch
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = randf_range(0.8, 1.2)
	add_child(player)
	player.finished.connect(player.queue_free) 
	player.play()

func unfade():
	$HUD/ColorRect.visible = true
	await create_tween().tween_property($HUD/ColorRect, "modulate:a", 0.0, 2.0).finished
	$HUD/ColorRect.visible = false

func _ready() -> void:
	unfade()
	randomize()
	_world = get_parent()
	_player = _world.get_node("Player")
	_ability = _player.get_node("SpiritAbility")
	_ball = _ability.get_node("SpiritBall")
	
	_ball_base_bounces = _ball.max_bounces
	_ball_base_flight = _ball.max_flight_time
	_ball_base_restitution = _ball.restitution
	_ball_base_gravity = _ball.gravity
	_ball_base_enemy_restitution = _ball.enemy_restitution
	
	_ability_miss_cooldown = _ability.miss_cooldown
	_ability_hit_cooldown = _ability.hit_cooldown
	_ability_min_launch_speed = _ability.min_launch_speed
	_ability_max_launch_speed = _ability.max_launch_speed
	_ability_max_charge_time= _ability.max_charge_time
	_ability_min_charge_time=_ability.min_charge_time
	_ability_max_dashes = _ability.max_dashes 
	
	health = max_health
	_ability.charge_started.connect(_on_charge_started)
	_ability.charge_ended.connect(_on_charge_ended)
	_ability.ball_bounced.connect(_on_ball_bounced)
	_ability.ball_hit_enemy.connect(_on_ball_hit_enemy)
	_ball.finished.connect(_on_ball_finished)
	var stream := music.stream as AudioStreamMP3
	if stream:
		stream.loop = true
	music.play()
	_apply_stats()
	in_intermission = true
	_intermission_left = first_wave_delay
	_emit_all.call_deferred()


func _emit_all() -> void:
	health_changed.emit(health, max_health)
	wave_changed.emit(wave)
	enemies_changed.emit(0)
	points_changed.emit(points)
	kills_changed.emit(kills)
	stats_changed.emit()


func player_target() -> Vector3:
	return _ability.target_position()


func player_vulnerable() -> bool:
	return not over and _ability.is_vulnerable()


func ability() -> Node:
	return _ability


func stat_value(stat: Stat) -> float: #updates stat
	var level: int = levels[stat]
	match stat:
		Stat.SPEED:
			return base_speed_multiplier + speed_per_level * float(level - 1)
		Stat.DAMAGE:
			return base_damage + damage_per_level * float(level - 1)
		Stat.HEALTH:
			return base_max_health + health_per_level * float(level - 1)
		_:
			return 1.0 + style_mult_per_level * float(level - 1)


func stat_text(stat: Stat) -> String: #returns the stat in text form eg 2m/s
	match stat:
		Stat.SPEED:
			return "%.1f m/s" % (_player.run_speed * stat_value(stat))
		Stat.DAMAGE:
			return "%d dmg" % int(stat_value(stat))
		Stat.HEALTH:
			return "%d hp" % int(stat_value(stat))
		_:
			return "%d x %.2f = %d" % [style,(style_mult+stat_value(stat)), style*(1.0+style_mult+stat_value(stat))]


func upgrade_cost(stat: Stat) -> int:
	return upgrade_cost_step * int(levels[stat])


func try_upgrade(stat: Stat) -> bool:
	var cost := upgrade_cost(stat)
	if points < cost:
		return false
	points -= cost
	levels[stat] = int(levels[stat]) + 1
	_apply_stats()
	points_changed.emit(points)
	stats_changed.emit()
	health_changed.emit(health, max_health)
	style_changed.emit()
	return true

#stats: health, damage, damage_mult, speed_mult, bounces, cooldown_mult, 
#draw_mult, gravity_mult, restitution_mult, extra_dash, combo_mult, charge_power_mult, style_mult

#i dont like this implementation of stats but im too lazy to rewrite it so enjoy this mess
# x=y + z  where x is the stat, y is the base value, or value from the shop stat, and z is value from upgrades
#multipliers * instead so 50% is 0.5

func _apply_stats() -> void: 
	var stats= $"../Player/ItemManage".stats
	
	_player.speed_multiplier = stat_value(Stat.SPEED) * stats.get("speed_mult",1)
	_ability.damage = (stat_value(Stat.DAMAGE) + stats.get("damage",0)) * stats.get("damage_mult",1)
	style_mult = stat_value(Stat.STYLE) + stats.get("style",0)
	
	_ball.max_bounces = _ball_base_bounces+ stats.get("bounces",0)
	_ball.gravity =_ball_base_gravity * stats.get("gravity_mult",1)
	_ball.restitution =_ball_base_restitution * stats.get("restitution_mult",1)
	_ability.max_dashes = _ability_max_dashes + stats.get("extra_dash",0)
	_ability.miss_cooldown = _ability_miss_cooldown * stats.get("cooldown_mult",1)
	_ability.hit_cooldown = _ability_hit_cooldown* stats.get("cooldown_mult",1)
	_ability.max_charge_time = _ability_max_charge_time* stats.get("draw_mult",1)
	_ability.min_charge_time= _ability_min_charge_time* stats.get("draw_mult",1)
	_ability.min_launch_speed = _ability_min_launch_speed * stats.get("charge_power",1)
	_ability.max_launch_speed = _ability_max_launch_speed * stats.get("charge_power",1)
	
	#_player.max_dashes = max_dashes
	parry_kb = stats.get("parry_kb",0)
	max_dashes=base_max_dashes+ stats.get("extra_dash",0)
	base_style_mult = base_base_style_mult + stats.get("combo_mult",1)
	
	
	var mult:float = max_health
	max_health = int(stat_value(Stat.HEALTH)) + stats.get("health",0)
	health *= max_health  / mult


func _process(delta: float) -> void:
	if get_tree().paused: #dual purpose of ensuring run tiume is accurate, and not incrmenting wave times in menus
		return
		
	run_time += delta
	$Inventory.refresh_time()
	
	if in_intermission:
		_intermission_left -= delta
		intermission_changed.emit(maxf(_intermission_left, 0.0), wave > 0)
		if _intermission_left <= 0.0:
			_start_wave()
		return
	if _queue.size() > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_spawn(_queue.pop_back())
	elif alive <= 0:
		_start_intermission()
	


func _start_intermission() -> void:
	in_intermission = true
	_intermission_left = intermission_time
	intermission_changed.emit(_intermission_left, true)


func _start_wave() -> void:
	if shop_open:
		set_shop_open(false)
	in_intermission = false
	wave += 1
	_queue = _compose(wave)
	_spawn_timer = 0.0
	intermission_changed.emit(0.0, false)
	wave_changed.emit(wave)
	enemies_changed.emit(_queue.size() + alive)


func _compose(number: int) -> Array[int]:
	var total := base_enemy_count + enemies_per_wave * (number - 1)
	var bats := 0
	var goblins := 0
	if number >= 2:
		goblins = int(round(float(total) * minf(0.2 + 0.05 * float(number - 2), 0.45)))
	if number >= 3:
		bats = int(round(float(total) * minf(0.15 + 0.04 * float(number - 3), 0.3)))
	var slimes := maxi(total - goblins - bats, 1)
	var list: Array[int] = []
	for i in slimes:
		list.append(0)
	for i in goblins:
		list.append(1)
	for i in bats:
		list.append(2)
	list.shuffle()
	return list


func _spawn_point(flying: bool) -> Vector3:
	var space := _world.get_world_3d().direct_space_state
	var center := _player.global_position
	for attempt in 12:
		var angle := randf() * TAU
		var radius := randf_range(spawn_radius_min, spawn_radius_max)
		var spot := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		spot.x = clampf(spot.x, -arena_limit, arena_limit)
		spot.z = clampf(spot.z, -arena_limit, arena_limit)
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 60.0, spot + Vector3.DOWN * 60.0)
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		if hit and hit.normal.y > 0.8 and hit.position.y < 3.0 and hit.position.y > -1.0:
			if flying:
				return hit.position + Vector3.UP * 5.0
			return hit.position + Vector3.UP * 0.3
	return center + Vector3(spawn_radius_min, 4.0, 0.0)


func _spawn(kind: int) -> void:
	var scene := slime_scene
	if kind == 1:
		scene = goblin_scene
	elif kind == 2:
		scene = bat_scene
	if scene == null:
		return
	var enemy: CharacterBody3D = scene.instantiate()
	enemy.game = self
	_world.add_child(enemy)
	enemy.global_position = _spawn_point(enemy.flying)
	enemy.scale_for_wave(wave)
	enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("SummonBats"):
		enemy.SummonBats.connect(SpawnBats)
	if enemy.has_signal("Stomps"):
		enemy.Stomps.connect(SpawnRocks)
	alive += 1
	enemies_changed.emit(_queue.size() + alive)


func _on_enemy_died(enemy: Node) -> void:
	alive -= 1
	kills += 1
	points += int(enemy.points)
	style+= style_per_enemy
	match int(enemy.kind):  #death sounds
		1:
			sfx_goblin_death.play()
		2:
			sfx_bat_death.play()
		3:
			sfx_slime_death.play()
		_:
			pass
	if false:  #ADD BOSS CHECK AZXAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAN
		style_popup.emit("Boss killed! +10")
	else:
		style_popup.emit("Enemy killed +5")
	kills_changed.emit(kills)
	points_changed.emit(points)
	style_changed.emit()

	enemies_changed.emit(_queue.size() + alive)



func parry(amount:float, source: Node)->void:
	$HUD/Parry.visible = true
	get_tree().paused = true
	await get_tree().create_timer(0.2).timeout
	$HUD/Parry.visible = false
	get_tree().paused = false
	sfx_parry.play()
	source.take_hit(amount+parry_damage,-_player.global_basis.z.normalized(),10+parry_kb) #it doesnt work well but goodnuff
	#cant even debug beaucse .basis z just returns 1.0????????
	style_popup.emit("Parry +10")
	style+= style_per_parry
		
var damage_label = preload("res://scenes/damage_numbers.tscn")
func damage_numbers(source:Node,amount:float)->void:
	if source:
		var n = damage_label.instantiate()
		get_tree().current_scene.add_child(n)
		n.global_position = source.global_position+Vector3(0,2,0)
		n.damage(amount)
func damage_player(amount: float, source: Node) -> void:
	if over or not _ability.is_vulnerable():
		return
	#thank you random reddit thread
	if source:
		var f =$"../Player"._model.global_basis.z #what does this mean
		var t= source.global_position - $"../Player".global_position
		f.y = 0
		t.y = 0
		if $"../Player"._shot_active("slash_shot") and rad_to_deg(f.angle_to(t)) < 45.0: #checks if in front for parry
			parry(amount, source)
			return
	damage_numbers($"../Player",amount)
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	player_hurt.emit()
	sfx_damage.play()
	if source and int(source.kind) == 1: #doesnt play on parry
		sfx_goblin_attack.play()
	if health <= 0.0:
		_game_over()

func heal_player(amount: float) -> void:
	health = minf(health+amount,max_health)
	health_changed.emit(health, max_health)

func _on_charge_started() -> void:
	sfx_charge.play()


func _on_charge_ended() -> void:
	sfx_charge.stop()


func _on_ball_bounced() -> void:
	sound(sfx_bounce)


func _on_ball_hit_enemy(_killed: bool) -> void:
	sound(sfx_bounce)
	
func _on_ball_finished()->void:
	sfx_land.play()

func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:# and (in_intermission or shop_open) and wave > 0:
			set_shop_open(not shop_open)
		elif event.physical_keycode == KEY_ESCAPE and shop_open:
			set_shop_open(false)
		if event.physical_keycode == KEY_Q: 
			q_action()
		if event.physical_keycode == KEY_I: #temp -------------------------------------------------------------
			set_chest_open(not chest_open,0)
		if event.physical_keycode == KEY_O: #temp -------------------------------------------------------------
			set_chest_open(not chest_open,1)
		if event.physical_keycode == KEY_P: #temp -------------------------------------------------------------
			set_chest_open(not chest_open,2)
		if event.physical_keycode == KEY_K: #temp -------------------------------------------------------------
			for e in get_tree().get_nodes_in_group("enemies"):
				e._die()
		if event.physical_keycode == KEY_L: #temp -------------------------------------------------------------
			damage_player(10,null)
	if event.is_action_pressed("inventory"):
		set_inventory_open(not inventory_open)
func q_action()->void:
	pass
func set_chest_open(open: bool,rarity:int)->void:
	if open != chest_open:
		chest_open = open
		get_tree().paused = open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
		chest_toggled.emit(open,rarity)

func set_shop_open(open: bool) -> void:
	if open != shop_open:
		shop_open = open
		get_tree().paused = open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
		shop_toggled.emit(open)
	
func set_inventory_open(open: bool) -> void:
	if open != inventory_open:
		inventory_open = open
		get_tree().paused = open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
		inventory_toggled.emit(open)

func _game_over() -> void:
	$GameOver/Root/hand.modulate.a=0.5
	$GameOver/Root/clock.modulate.a=0.5
	over = true
	_ability.cancel()
	_player.control_locked = true
	sfx_charge.stop()
	game_over_started.emit()
	await get_tree().create_timer(fade_time + 0.4, true, false, true).timeout
	game_over()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$GameOver/AudioStreamPlayer.play()
	create_tween().tween_property($GameOver/Dim,"modulate:a",0.0, 2.0)
	
	$GameOver.visible = true
	$Minimap.visible = false
	$HUD/Root/Style.visible = false

func game_over()->void:
	await create_tween().tween_property(music, "volume_db", -80.0, 1.0).finished
	music.stop()
	create_tween().tween_property($GameOver/AudioStreamPlayer, "volume_db", 0.0, 2.0)
	$GameOver/Root/Timer.start()
	
func _restart()->void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	
func _return_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(menu_scene)


var rock_scene = preload("res://scenes/Rock.tscn")

func SpawnBats() -> void:
	var PlayerPos = player_target()
	for i in 5:
		var angle: float = TAU * i / 5
		var spot = PlayerPos + Vector3(cos(angle) * 6.0, 3.0, sin(angle) * 6.0)
		var bat = bat_scene.instantiate()
		bat.game = self
		_world.add_child(bat)
		bat.global_position = spot
		bat.died.connect(_on_enemy_died)
		alive += 1
	enemies_changed.emit(_queue.size() + alive)


func SpawnRocks(Position: Vector3) -> void:
	var PlayerPos = player_target()
	var direction = Vector3(PlayerPos.x - Position.x, 0.0, PlayerPos.z - Position.z).normalized()
	for i in 6:
		var spot = Position + direction * (2.0 + i * 1.5)
		SpawnOneRock(spot)
		await get_tree().create_timer(0.15).timeout

func SpawnOneRock(spot: Vector3) -> void:
	var rock = rock_scene.instantiate()
	_world.add_child(rock)
	rock.global_position = spot + Vector3(0.0, -2.0, 0.0)

	var tween = create_tween()
	tween.tween_property(rock, "global_position", spot, 0.15)
	tween.tween_interval(0.8)
	tween.tween_property(rock, "global_position", spot + Vector3(0.0, -2.0, 0.0), 0.4)
	tween.tween_callback(rock.queue_free)

	await get_tree().create_timer(0.15).timeout
	var PlayerPos = player_target()
	var distance = Vector2(PlayerPos.x - spot.x, PlayerPos.z - spot.z).length()
	if distance < 1.2:
		damage_player(15.0, null)
