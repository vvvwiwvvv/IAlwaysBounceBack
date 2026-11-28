extends Node3D
var enemy

@onready var hp_label =$hp
@onready var light_hp = $lighthp
@onready var dark_hp = $darkhp
var width
func move(enem,height:float):
	enemy = enem
	position.y=height
	
var camera
func _ready() -> void:
	width = light_hp.mesh.size.x
	camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void: 
	look_at(camera.global_position, Vector3.UP) 
	rotate_object_local(Vector3.UP, PI) #??
func update():
	if enemy and not enemy.dead and not enemy.health == 0:
		var hp_ratio = max(enemy.health/enemy.max_health,0)
		light_hp.scale.x = hp_ratio
		light_hp.position.x = -(1-hp_ratio)*(width * 0.5)
		hp_label.text = "%d/%d" % [enemy.health,enemy.max_health]
		
