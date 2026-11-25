extends CanvasLayer
var _game: Node
var _tween: Tween

@onready var panel = $Control/Panel
@onready var bg = $Control/Dim
@onready var health_text = $Control/Panel/stats/health
@onready var speed_text =$Control/Panel/stats/speed
@onready var cooldown_text =$Control/Panel/stats/cooldown
@onready var damage_text =$Control/Panel/stats/damage
@onready var map = $"../Minimap/Minimap"
@onready var points_label =$Control/Panel/stats/points
@onready var kills_label =$Control/Panel/info/kills
@onready var enemies_label =$Control/Panel/info/enemies
@onready var wave_label = $Control/Panel/info/wave
@onready var timer_label=$Control/Panel/info/time
@onready var name_label=$Control/Panel/info/lname

func _ready() -> void:
	_game = get_parent()
	panel.scale = Vector2(0.9, 0.9)
	bg.modulate.a = 0.0
	_game.inventory_toggled.connect(_on_inventory_toggled)


func _on_inventory_toggled(open: bool) -> void:
	_tween=create_tween().set_parallel(true)
	visible = open
	if open:
		refresh()
		_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(panel,"position", Vector2(131,20),0.3)
		_tween.tween_property(panel, "scale", Vector2(1.678,1.308), 0.3)
		_tween.tween_property(map,"position", Vector2(742,238),0.3)
		_tween.tween_property(map, "scale", Vector2(5,5), 0.3)
		_tween.tween_property(bg,"modulate:a", 0.4,  0.3)
	else:
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween.tween_property(panel, "position", Vector2(169.0,660.0),0.2)
		_tween.tween_property(panel, "scale", Vector2(0.2, 0.2),0.2)
		_tween.tween_property(map, "scale", Vector2(3.181,3.181), 0.3)
		_tween.tween_property(map,"position", Vector2(1023,1),0.3)
		
		_tween.tween_property(bg, "modulate:a", 0.0 ,0.2)



func refresh()-> void:
	
	health_text.text = "%d / %d" % [_game.health,_game.max_health]
	wave_label.text = "%d" % _game.wave
	name_label.text = "forest"
	kills_label.text = "%d" % _game.kills 
	enemies_label.text = "%d" % _game.alive
	points_label.text = "%d" % _game.points
	speed_text.text =  _game.stat_text(1)
	cooldown_text.text = _game.stat_text(3)
	damage_text.text =  _game.stat_text(2)
	
func refresh_time()->void:
	var t=int(_game.run_time)
	timer_label.text = "%d:%02d:%02d" % [t/3600,(t/60)%60,t%60]
