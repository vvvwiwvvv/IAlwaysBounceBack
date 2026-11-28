extends "res://scripts/enemy.gd"

signal SummonBats
signal Stomps(Position: Vector3)

enum State {Chase, Rest, Summon, Spin, Stomp}

var CurrentState := State.Chase
@export var RandomTimer = 10.0
@export var RestTime = 3.0
@export var StompTime = 0.6
@export var SpinTime = 3.0
@export var SpinSpeed = 9.0
@export var SpinDamage = 20.0
var CoolDown = RandomTimer
var StateTimer = 0.0

var NormalSpeed = 0.0
var NormalDamage = 0.0
var NormalRange = 0.0
var NormalCooldown = 0.0


func _ready() -> void:
	super()
	CoolDown = RandomTimer
	print("el boss has el spawned")
	#poop walk


func _physics_process(delta: float) -> void:
	if dead:
		super(delta)
		return

	match CurrentState:
		State.Chase:
			super(delta)
			CoolDown -= delta
			if CoolDown <= 0.0:
				print("RAHHH CHAAARGE")
				CoolDown = RandomTimer
				SaveStats()
				var attack = SpecialAttack()
				if attack == "Stomp":
					Stomp()
				elif attack == "Summon":
					Summon()
				elif attack == "Spin":
					Spin()

		State.Stomp:
			super(delta)
			StateTimer -= delta
			if StateTimer <= 0.0:
				Stomps.emit(global_position)
				Rest()

		State.Spin:
			super(delta)
			model.rotation.y += 25.0 * delta
			StateTimer -= delta
			if StateTimer <= 0.0:
				model.rotation.y = 0.0
				#pee spin
				Rest()

		State.Rest:
			super(delta)
			StateTimer -= delta
			if StateTimer <= 0.0:
				print("im back")
				#pee tired
				LoadStats()
				CurrentState = State.Chase
				#poop walk


func take_hit(amount: float, impulse: Vector3, knockback: float = 5.0) -> bool:
	if CurrentState == State.Spin:
		return false
	if CurrentState == State.Rest:
		amount = amount * 2
	return super(amount, impulse, knockback)


func SpecialAttack() -> String:
	var attacks = ["Stomp", "Summon", "Spin"]
	return attacks.pick_random()


func SaveStats() -> void:
	NormalSpeed = move_speed
	NormalDamage = damage
	NormalRange = attack_range
	NormalCooldown = attack_cooldown


func LoadStats() -> void:
	move_speed = NormalSpeed
	damage = NormalDamage
	attack_range = NormalRange
	attack_cooldown = NormalCooldown


func Rest() -> void:
	print("im tired")
	CurrentState = State.Rest
	StateTimer = RestTime
	move_speed = 0.0
	attack_range = 0.0
	#poop tired


func Stomp() -> void:
	print("stomp")
	CurrentState = State.Stomp
	StateTimer = StompTime
	move_speed = 0.0
	attack_range = 0.0
	#pee walk
	#poop stomp


func Summon() -> void:
	print("summon")
	#end walk
	#poop summon
	SummonBats.emit()
	Rest()


func Spin() -> void:
	print("spin")
	CurrentState = State.Spin
	StateTimer = SpinTime
	move_speed = SpinSpeed
	damage = SpinDamage
	attack_cooldown = 0.5
