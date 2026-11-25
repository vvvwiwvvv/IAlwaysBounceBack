
extends Node

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
signal chest_toggled(open: bool)
signal game_over_started
var run_time := 0.0

enum Stat {HEALTH, SPEED, DAMAGE, FORCE }

@export_group("Enemies")
@export var slime_scene: PackedScene
@export var goblin_scene: PackedScene
@export var bat_scene: PackedScene
@export var spawn_interval := 0.7
@export var spawn_radius_min := 16.0
@export var spawn_radius_max := 26.0
@export var arena_limit := 62.0

@export_group("Waves")
@export var first_wave_delay := 3.0
@export var intermission_time := 10.0
@export var base_enemy_count := 4
@export var enemies_per_wave := 3

@export_group("Player")
@export var max_health := 100.0
@export var base_speed_multiplier := 1.5
@export var speed_per_level := 0.15
@export var base_damage := 10.0
@export var damage_per_level := 6.0
@export var force_per_level := 0.12
@export var health_per_level := 50
@export var upgrade_cost_step := 4

@export_group("Flow")
@export var menu_scene := "res://scenes/menu.tscn"
@export var fade_time := 1.4

var health := 100.0
var wave := 0
var points := 0
var kills := 0
var levels := {Stat.HEALTH: 1, Stat.SPEED: 1, Stat.DAMAGE: 1, Stat.FORCE: 1}
var alive := 0
var over := false
var shop_open := false
var inventory_open:= false
var chest_open := false 
var in_intermission := false

var _queue: Array[int] = []
var _spawn_timer := 0.0
var _intermission_left := 0.0
var _player: CharacterBody3D
var _ability: Node
var _world: Node3D

@onready var music: AudioStreamPlayer = $Music
@onready var sfx_charge: AudioStreamPlayer = $SfxCharge
@onready var sfx_land: AudioStreamPlayer = $SfxLand
@onready var sfx_damage: AudioStreamPlayer = $SfxDamage
@onready var sfx_goblin_attack: AudioStreamPlayer = $SfxGoblinAttack
@onready var sfx_goblin_death: AudioStreamPlayer = $SfxGoblinDeath
@onready var sfx_bat_death: AudioStreamPlayer = $SfxBatDeath
@onready var sfx_slime_death: AudioStreamPlayer = $SfxSlimeDeath


func _ready() -> void:
	randomize()
	_world = get_parent()
	_player = _world.get_node("Player")
	_ability = _player.get_node("SpiritAbility")
	health = max_health
	_ability.charge_started.connect(_on_charge_started)
	_ability.charge_ended.connect(_on_charge_ended)
	_ability.ball_bounced.connect(_on_ball_bounced)
	_ability.ball_hit_enemy.connect(_on_ball_hit_enemy)
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


func stat_value(stat: Stat) -> float:
	var level: int = levels[stat]
	match stat:
		Stat.SPEED:
			return base_speed_multiplier + speed_per_level * float(level - 1)
		Stat.DAMAGE:
			return base_damage + damage_per_level * float(level - 1)
		Stat.HEALTH:
			return health + health_per_level * float(level - 1)
		_:
			return 1.0 + force_per_level * float(level - 1)


func stat_text(stat: Stat) -> String:
	match stat:
		Stat.SPEED:
			return "%.1f m/s" % (_player.run_speed * stat_value(stat))
		Stat.DAMAGE:
			return "%d dmg" % int(stat_value(stat))
		Stat.HEALTH:
			return "%d hp" % int(stat_value(stat))
		_:
			return "%d%%" % int(round(stat_value(stat) * 100.0))


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
	return true


func _apply_stats() -> void:
	_player.speed_multiplier = stat_value(Stat.SPEED)
	_ability.damage = stat_value(Stat.DAMAGE)
	_ability.force_multiplier = stat_value(Stat.FORCE)
	var mult = max_health
	max_health = int(stat_value(Stat.HEALTH))
	health *= max_health  / mult


func _process(delta: float) -> void:
	if not get_tree().paused:
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
	alive += 1
	enemies_changed.emit(_queue.size() + alive)


func _on_enemy_died(enemy: Node) -> void:
	alive -= 1
	kills += 1
	points += int(enemy.points)
	match int(enemy.kind):
		1:
			sfx_goblin_death.play()
		2:
			sfx_bat_death.play()
		_:
			sfx_slime_death.play()
	kills_changed.emit(kills)
	points_changed.emit(points)
	enemies_changed.emit(_queue.size() + alive)


func damage_player(amount: float, source: Node) -> void:
	if over or not _ability.is_vulnerable():
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	player_hurt.emit()
	sfx_damage.play()
	if source and int(source.kind) == 1:
		sfx_goblin_attack.play()
	if health <= 0.0:
		_game_over()


func _on_charge_started() -> void:
	sfx_charge.play()


func _on_charge_ended() -> void:
	sfx_charge.stop()


func _on_ball_bounced() -> void:
	sfx_land.play()


func _on_ball_hit_enemy(_killed: bool) -> void:
	sfx_land.play()


func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:# and (in_intermission or shop_open) and wave > 0:
			set_shop_open(not shop_open)
		elif event.physical_keycode == KEY_ESCAPE and shop_open:
			set_shop_open(false)
	if event.is_action_pressed("inventory"):
		set_inventory_open(not inventory_open)

func set_chest_open(open: bool)->void:
	if open == chest_open:
		return
	chest_open = open
	get_tree().paused = open
	chest_toggled.emit(open)

func set_shop_open(open: bool) -> void:
	if open == shop_open:
		return
	shop_open = open
	get_tree().paused = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	shop_toggled.emit(open)
	
func set_inventory_open(open: bool) -> void:
	if open == inventory_open:
		return
	inventory_open = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	inventory_toggled.emit(open)

func _game_over() -> void:
	over = true
	_ability.cancel()
	_player.control_locked = true
	sfx_charge.stop()
	game_over_started.emit()
	var timer := get_tree().create_timer(fade_time + 0.4, true, false, true)
	timer.timeout.connect(_return_to_menu)


func _return_to_menu() -> void:
	
	get_tree().paused = false
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(menu_scene)
